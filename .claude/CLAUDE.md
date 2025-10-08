# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a bash-based TUI (Text User Interface) tool for managing MCP (Model Context Protocol) servers in Claude Code. The tool provides an interactive interface using `fzf` for enabling/disabling MCP servers from multiple configuration sources, with scope awareness and project-local override management.

## Architecture

### Core Components

**Main Script: `mcp`**
- Bash script that wraps the Claude Code CLI with an interactive server selector
- Discovers and parses 7 configuration sources (local/project/user scopes)
- Uses `fzf` for interactive selection with preview window and `jq` for JSON manipulation
- Always writes changes to `./.claude/settings.local.json` (project-local overrides)
- Atomically updates configuration using temp file + `mv` pattern
- Automatically launches Claude after configuration changes

### Configuration Sources (7 Files)

The tool reads from all available configuration files and merges them with precedence:

**LOCAL SCOPE** (highest priority):
- `./.claude/settings.local.json` - Project-local settings (gitignored)

**PROJECT SCOPE**:
- `./.claude/settings.json` - Project-shared settings (version-controlled)
- `./.mcp.json` - Project MCP server definitions

**USER SCOPE** (lowest priority):
- `~/.claude/settings.local.json` - User-local settings
- `~/.claude/settings.json` - User-global settings
- `~/.claude.json` - Main user configuration
- `~/.mcp.json` - User MCP server definitions

### Two Separate Concepts

**Concept 1: Server Definitions** (`mcpServers` object)
- **What**: Actual server configurations (command, args, env, etc.)
- **Where**: Can exist in ANY of the 7 config files
- **Format**:
```json
{
  "mcpServers": {
    "fetch": { "command": "uvx", "args": ["mcp-server-fetch"] },
    "time": { "command": "uvx", "args": ["mcp-server-time"] }
  }
}
```
- **Purpose**: Defines WHAT servers exist and HOW to run them
- **Precedence**: When same server defined in multiple files, local > project > user

**Concept 2: Enable/Disable State** (`enabledMcpjsonServers`/`disabledMcpjsonServers` arrays)
- **What**: Toggle switches for servers (ON/OFF)
- **Where**: Can exist in settings files (`.claude/settings*.json`)
- **Format**:
```json
{
  "enabledMcpjsonServers": ["fetch", "time"],
  "disabledMcpjsonServers": ["github"]
}
```
- **Purpose**: Controls which defined servers are active
- **Precedence**: Same hierarchy applies (local > project > user)
- **CRITICAL LIMITATION**: These arrays ONLY work for servers defined in `.mcp.json` files
- **Servers in `~/.claude.json`**: Always enabled, cannot be controlled via these arrays

### Server Types

The tool categorizes servers into three types based on their source:

1. **MCPJSON Servers** (from `.mcp.json` files)
   - **Controllable**: Yes, via `enabledMcpjsonServers`/`disabledMcpjsonServers`
   - **Sources**: `~/.mcp.json` (user scope), `./.mcp.json` (project scope)
   - **UI Indicator**: `[ON]` or `[OFF]` with green/red color

2. **Direct-Global Servers** (from `~/.claude.json` root `.mcpServers`)
   - **Controllable**: No, always enabled
   - **Sources**: `~/.claude.json` root level `.mcpServers` object
   - **UI Indicator**: `[⚠]` with yellow color, labeled "always-on"
   - **Migration**: Can be migrated to `./.mcp.json` for project-level control

3. **Direct-Local Servers** (from `~/.claude.json` `.projects[cwd].mcpServers`)
   - **Controllable**: No, always enabled
   - **Sources**: `~/.claude.json` `.projects[cwd].mcpServers` object
   - **UI Indicator**: `[⚠]` with yellow color, labeled "always-on"
   - **Migration**: Can be migrated to `./.mcp.json` for project-level control

### Dual Precedence Resolution

The tool applies precedence SEPARATELY for definitions and state:

**Definition Precedence** (where server config comes from):
- If `fetch` defined in both user and project scopes → use project definition
- Local > Project > User scope

**State Precedence** (whether server is on/off):
- If `fetch` enabled in user scope, disabled in project scope → use project state (disabled)
- Local > Project > User scope
- Independent of where server is defined

**Example**:
```
User scope: fetch defined + enabled
Project scope: fetch defined with different args + disabled
Result: Uses project definition (different args) + disabled state
Display: [OFF] fetch (project)
```

### Data Flow

1. Script checks for dependencies (`fzf`, `jq`)
2. Discovers all 7 configuration sources
3. Parses both settings arrays and MCP server definitions
4. Merges servers with precedence resolution
5. Presents unified list in `fzf` TUI with scope labels: `[ON ] server (scope)`
6. User interacts:
   - `SPACE` - Toggle server on/off
   - `CTRL-A` - Add new server
   - `CTRL-X` - Remove server
   - `ALT-E` - Enable all servers
   - `ALT-D` - Disable all servers
   - `ENTER` - Save changes
7. Changes saved atomically to `./.claude/settings.local.json` only
8. Launches Claude with updated configuration

## Development Commands

### Testing

No automated tests currently exist. Manual testing workflow:
```bash
# Run the script directly
./cc-mcp-launcher

# Test with sample settings.json (see prd.md section 7.0 for sample)
```

### Validation

```bash
# Check bash syntax
bash -n cc-mcp-launcher

# Verify dependencies
command -v fzf jq
```

## Key Technical Patterns

### Multi-Source Discovery

Discovers and parses all 7 configuration sources:
```bash
discover_and_parse_all_sources() {
  # Parses settings files (both mcpServers AND enable/disable arrays)
  parse_settings_file "$HOME/.claude/settings.json" "user"
  # Outputs:
  #   def:fetch:user:~/.claude/settings.json
  #   enable:fetch:user:~/.claude/settings.json

  # Parses .mcp.json files (mcpServers object keys only)
  parse_mcp_json_file "./.mcp.json" "project"
  # Outputs:
  #   def:time:project:./.mcp.json
}
```

Three output types:
- `def:server:scope:file` - Server is defined here
- `enable:server:scope:file` - Server is enabled here
- `disable:server:scope:file` - Server is disabled here

### Dual Precedence Resolution

Uses two separate associative arrays and numeric priorities:
```bash
get_scope_priority() {
  case "$1" in
    local) echo 3 ;;    # Highest
    project) echo 2 ;;
    user) echo 1 ;;     # Lowest
  esac
}

# Map 1: Server definitions (where configured)
declare -A server_definitions
# server_name -> priority:scope:file

# Map 2: Enable/disable state (whether active)
declare -A server_states
# server_name -> priority:on/off

# Merge: For each defined server, attach its state
# Result: state:server:def_scope:def_file
```

Higher priority wins independently for both definitions and state.

### State File Format

Internal state file stores merged results of dual precedence:
```
on:fetch:project:./.mcp.json:mcpjson
on:time:user:~/.claude.json:direct-global
off:github:project:./.mcp.json:mcpjson
```

Format: `state:server:def_scope:def_file:source_type`
- `state`: on/off (from enable/disable precedence or always-on for direct servers)
- `server`: server name
- `def_scope`: scope where server is DEFINED (local/project/user)
- `def_file`: file where winning server definition lives
- `source_type`: mcpjson, direct-global, or direct-local

**Important**: The scope/file shown is where the server is DEFINED, NOT where it's enabled/disabled. These can differ!

### Atomic File Updates

Always writes to `./.claude/settings.local.json` using temp file pattern:
```bash
TMP_FILE=$(mktemp)
jq --argjson enabled "$ENABLED_JSON" \
   --argjson disabled "$DISABLED_JSON" \
   '.enabledMcpjsonServers = $enabled | .disabledMcpjsonServers = $disabled' \
   "./.claude/settings.local.json" > "$TMP_FILE"
mv "$TMP_FILE" "./.claude/settings.local.json"
```

### Safe Error Handling

Script uses `set -euo pipefail` but disables during `fzf` interaction:
```bash
set +e  # Before fzf
# ... fzf interaction ...
FZF_EXIT=$?
set -e  # After capturing exit code
```

### ANSI Parsing

Selected items from `fzf` include ANSI codes and scope labels that must be stripped:
```bash
sed 's/\x1b\[[0-9;]*m//g'  # Remove ANSI codes
sed 's/^\[ON \] *//'        # Remove state prefix
sed 's/ *(.*)$//'           # Remove scope suffix
```

### Preview Window

Shows detailed source information with dual precedence awareness:
- **Defined In**: Where server configuration comes from (command, args, etc.)
- **Enabled/Disabled In**: Where enable/disable state comes from (if different)
- **All Sources**: Lists all definitions and enable/disable directives when multiple exist
- Marks active definition and active state with ✓
- Current vs pending status
- Write target information

**Example when definition and state come from different files**:
```
Server: fetch
Defined In: ./.claude/settings.json (project)
Enabled In: ~/.claude/settings.json (user)

Current Status: Enabled
```

## Migration System

### Why Migration is Needed

Servers defined in `~/.claude.json` (root `.mcpServers` or `.projects[cwd].mcpServers`) are **always enabled** by Claude Code. The `enabledMcpjsonServers`/`disabledMcpjsonServers` arrays are **ignored** for these servers.

To enable project-level control, the tool can migrate these servers to `./.mcp.json` (project scope).

### Migration Process

When user tries to disable a direct server (marked with `[⚠]`):

1. **Detection**: Tool detects server is a "direct" type (always enabled)
2. **Prompt**: User is shown migration options:
   - `[y]` Migrate and disable (recommended)
   - `[v]` View full server definition first
   - `[n]` Keep enabled globally (cancel)
3. **Backup**: Automatic timestamped backup of `~/.claude.json` created
4. **Migration Steps** (if user confirms):
   - Extract server definition from `~/.claude.json`
   - Add server to `./.mcp.json` (creates file if needed)
   - Remove server from `~/.claude.json`
   - Validate both JSON files
   - Mark server as migrated (prevents re-prompting)
   - Reload server list
5. **Control**: Server is now controllable via enable/disable arrays
6. **Rollback**: If any step fails, automatic rollback to backup

### Migration Tracking

- Migrated servers are tracked in `./.claude/.mcp_migrations`
- Format: `server_name:timestamp`
- Prevents re-prompting for already migrated servers
- Migrated servers show as normal controllable servers after migration

### Migration Safety Features

- **Explicit Consent**: User must confirm before any modification
- **Automatic Backups**: Timestamped backup before modifying `~/.claude.json`
- **Atomic Operations**: All file updates use temp files + atomic move
- **JSON Validation**: Validates both source and destination files
- **Rollback on Failure**: Restores backup if any step fails
- **Error Recovery**: Detailed error messages guide user

## Important Notes

- **CAN modify global config** - ONLY when user explicitly requests migration
- **Server definitions**: Tool can move definitions during migration (with consent)
- **Scope labels show definition source** - `[ON] fetch (project, mcpjson)` shows controllable server
- **Warning indicator** - `[⚠] time (user, always-on)` shows direct server needs migration
- **Dual precedence** - Definition source and enable/disable state resolved independently
- Configuration updates are atomic (no partial writes)
- Handles empty/malformed JSON gracefully (skips bad files, continues with others)
- MCPJSON servers default to enabled unless explicitly disabled
- Preview window updates on every toggle/change and shows migration instructions for direct servers
- Exit code 130 from `fzf` = user cancelled (ESC/Ctrl-C)
- Creates `.claude/` directory automatically if needed

## New Project Flow

When run in a directory without local configuration:
1. Detects global configuration exists
2. Prompts user to:
   - Create local config (copies global as template)
   - Continue with global only (changes still saved locally)
   - Abort
3. If user continues, changes are always saved to `./.claude/settings.local.json`
