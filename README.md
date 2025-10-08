# Claude Code MCP Server Selector

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-lightgrey.svg)]()
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)]()

**[🌐 Visit Website](https://henkisdabro.github.io/Claude-Code-MCP-Launcher/)** | **[📖 Documentation](#readme)** | **[⚡ Quick Start](#quick-start)**

A fast, beautiful TUI for managing MCP (Model Context Protocol) servers in Claude Code. Optimize your context window by enabling only the servers you need, when you need them.

![MCP Server Selector Screenshot](/docs/demo.gif)

## Why MCP Server Selector?

**Every enabled MCP server bloats your Claude Code context window with tool descriptions, parameters, and usage notes—wasting precious tokens on tools you're not using.**

**The Real Numbers:**
- **Average MCP server:** 20-30 tools, consuming ~15,000-25,000 tokens each
- **Each tool:** ~600-800 tokens on average (descriptions, parameters, examples, usage notes)
- **Large servers** (google_workspace, alphavantage, mikrotik): 60-100+ tools consuming 50,000-85,000 tokens each
- **10 enabled servers:** Easily 200,000-250,000 tokens consumed (100-125% of your entire context budget)
- **Result:** Context budget exhausted before typing your first prompt

This means:

- **Massive token waste** - 200k+ tokens on tool definitions you're not using
- **Context overflow** - Already at/over budget before your actual code and conversations
- **Severe performance impact** - Processing hundreds of unused tools slows every response
- **Dramatically higher costs** - Paying for 2-5x more tokens than necessary

MCP Server Selector solves this: exit Claude, run `mcp`, enable only the 1-3 servers you need for your current task, and launch Claude with a minimal, optimized context window. Toggle servers with a keypress, see changes in real-time, and launch with optimal settings—all in under a second.

## Features

- **Context Window Optimization** - Enable only the MCP servers you need, minimize token waste
- **Interactive TUI** - Fast, intuitive interface powered by fzf
- **Real-time Updates** - Toggle servers instantly with visual feedback
- **Multi-Source Configuration** - Discovers and merges 7 configuration sources with scope precedence
- **Smart Migration** - Automatically migrate global servers to project-level control
- **Safe by Design** - Atomic updates, automatic backups, explicit consent for global changes
- **Cross-Platform** - Works on Linux and macOS out of the box
- **Zero Dependencies** - Just bash, fzf, and jq (easy to install)

## Quick Start

### Installation

One-line install (recommended):

```bash
curl -fsSL https://raw.githubusercontent.com/henkisdabro/cc-mcp-launcher/main/install.sh | bash
```

### Usage

Simply run `mcp` or `claudemcp` in any directory:

```bash
mcp        # Short command
claudemcp  # Descriptive command (same functionality)
```

The tool will:

1. Detect your Claude configuration (project or global)
2. Launch the interactive TUI showing all available MCP servers
3. Let you enable/disable servers with SPACE (enable only what you need!)
4. Save your changes when you press ENTER
5. **Automatically launch Claude Code** with your optimized, minimal configuration

**Pro tip:** Exit Claude before running this tool to refresh with new settings. Enable only 2-3 servers per session for maximum efficiency.

### Keybindings

| Key | Action |
|-----|--------|
| `SPACE` | Toggle server on/off (or trigger migration for always-on servers) |
| `ENTER` | Save changes and launch Claude |
| `ESC` | Cancel without saving |
| `Ctrl-A` | Add new server |
| `Ctrl-X` | Remove selected server |
| `Alt-E` | Enable all servers |
| `Alt-D` | Disable all servers |
| `↑/↓` or `/` | Navigate and filter |

### UI Indicators

The TUI shows server status with color-coded indicators:

| Indicator | Meaning | Source Type | Controllable? |
|-----------|---------|-------------|---------------|
| `[ON ]` (green) | Server enabled | MCPJSON (from `.mcp.json`) | ✅ Yes |
| `[OFF]` (red) | Server disabled | MCPJSON (from `.mcp.json`) | ✅ Yes |
| `[⚠ ]` (yellow) | Always enabled | Direct (from `~/.claude.json`) | ⚠️ Requires migration |

**Scope labels** show where the server is defined:
- `(local, mcpjson)` - Project-local, controllable
- `(project, mcpjson)` - Project-shared, controllable
- `(user, mcpjson)` - User-global, controllable
- `(user, always-on)` - User-global, requires migration
- `(local, always-on)` - Project-specific in global config, requires migration

## Recommended Workflow

For optimal context window management:

1. **Exit Claude Code** (if running)
2. **Run `claudemcp`** in your project directory
3. **Enable only the 2-3 MCP servers** you need for your next task (e.g., if working with web APIs, enable `fetch`; if debugging time zones, enable `time`)
4. **Press ENTER** - tool saves changes and launches Claude automatically
5. **Work efficiently** with a minimal context window
6. **Repeat when you need different tools** - exit Claude, run `claudemcp`, adjust servers, continue

This workflow ensures Claude's context is focused on your code and task, not filled with unused tool definitions.

## Best Practices

### Organize Your Server Definitions

**Move servers to `.mcp.json` files for maximum control:**

1. **Audit servers in** `~/.claude.json`:
   ```bash
   jq '.mcpServers | keys' ~/.claude.json
   ```

2. **Migrate to controllable format:**
   - Run `mcp` in any project
   - Look for servers marked with `[⚠]` (yellow, always-on)
   - Press `SPACE` on any always-on server to trigger migration
   - Tool will automatically move it to `./.mcp.json` with backup

3. **Define new servers in** `.mcp.json` files:
   - User-global servers → `~/.mcp.json`
   - Project-specific servers → `./.mcp.json`
   - Never add to `~/.claude.json` (they become always-on)

### Minimize Default Enabled Servers

After migrating your servers, keep your global settings minimal:

```bash
# View your global enabled servers
jq '.enabledMcpjsonServers' ~/.claude/settings.json
```

**Recommendation:** Start with everything disabled by default:

```json
{
  "enabledMcpjsonServers": [],
  "disabledMcpjsonServers": [
    "fetch",
    "time",
    "notion",
    "playwright"
  ]
}
```

Then use `mcp` to enable only what you need, per project, per task.

### Project-Level Control

For team projects, use version-controlled settings:

1. **Define shared servers** in `./.mcp.json` (committed to git)
2. **Set team defaults** in `./.claude/settings.json` (committed)
3. **Personal overrides** go in `./.claude/settings.local.json` (gitignored)

This ensures:
- Team members have consistent server availability
- Individual developers can optimize their own context
- No conflicts from personal preferences

## Installation

### Prerequisites

The tool requires three lightweight dependencies:

- **bash** 4.0+ (usually pre-installed)
- **fzf** 0.20+ (command-line fuzzy finder)
- **jq** 1.6+ (JSON processor)

### One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/henkisdabro/cc-mcp-launcher/main/install.sh | bash
```

The installer will:

- Check for dependencies and offer to install them
- Clone the repository to `~/.config/mcp-selector`
- Create symlinks in `~/.local/bin/`
- Add `~/.local/bin` to your PATH if needed

### Manual Install

```bash
# Clone the repository
git clone https://github.com/henkisdabro/cc-mcp-launcher.git ~/.config/mcp-selector

# Create symlinks
ln -s ~/.config/mcp-selector/mcp ~/.local/bin/mcp
ln -s ~/.config/mcp-selector/mcp ~/.local/bin/claudemcp

# Make executable
chmod +x ~/.config/mcp-selector/mcp
```

### Installing Dependencies

**Ubuntu/Debian:**

```bash
sudo apt update && sudo apt install fzf jq
```

**macOS:**

```bash
brew install fzf jq
```

**Fedora/RHEL:**

```bash
sudo dnf install fzf jq
```

**Arch Linux:**

```bash
sudo pacman -S fzf jq
```

**Alpine Linux:**

```bash
sudo apk add fzf jq
```

**openSUSE:**

```bash
sudo zypper install fzf jq
```

**NixOS:**

```bash
nix-env -iA nixpkgs.fzf nixpkgs.jq
```

## How It Works

### The Context Window Problem

**The problem is far worse than you might think.** Every MCP server you enable adds tool definitions to Claude's context window—and each tool consumes significant tokens.

**The Math:**
- **Each tool:** ~600-800 tokens on average (descriptions, parameters, examples, usage notes)
- **Average server:** 20-30 tools = ~15,000-25,000 tokens per server
- **Large servers:** 60-100+ tools = 50,000-85,000 tokens each
- **10 enabled servers:** ~200,000-250,000 tokens (100-125% of your 200k context budget)

**The Impact:**
- Context budget exhausted or exceeded before your first prompt
- Claude processes hundreds of tool definitions you're not using
- Less space for your actual code, files, and conversation
- Slower responses and higher costs from token overhead

**The Solution:**
This tool lets you enable servers only when needed. Disable unnecessary servers and reclaim 100k-200k+ tokens for your actual work. Enable only the 1-3 servers relevant to your current task.

### Configuration Architecture

MCP Server Selector understands two separate but related concepts:

#### 1. Server Definitions (`mcpServers` object)

These define **what** servers exist and **how** to run them:

```json
{
  "mcpServers": {
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"]
    },
    "time": {
      "command": "uvx",
      "args": ["mcp-server-time"]
    }
  }
}
```

**Can be defined in any of these files:**
- `~/.claude.json` (user-global or project-specific via `.projects[cwd]`)
- `~/.mcp.json` (user-global)
- `./.mcp.json` (project-local)

#### 2. Enable/Disable State (control arrays)

These control **which** servers are active:

```json
{
  "enabledMcpjsonServers": ["fetch", "time"],
  "disabledMcpjsonServers": ["github", "notion"]
}
```

**Can be configured in any of these files:**
- `./.claude/settings.local.json` (project-local, highest priority)
- `./.claude/settings.json` (project-shared)
- `~/.claude/settings.local.json` (user-local)
- `~/.claude/settings.json` (user-global)

**Critical Limitation:** These arrays **only work** for servers defined in `.mcp.json` files. Servers defined directly in `~/.claude.json` are always enabled.

### Seven Configuration Sources

The tool discovers and merges all available configuration files:

**LOCAL SCOPE** (highest priority):
1. `./.claude/settings.local.json` - Project-local overrides (gitignored, **where changes are saved**)

**PROJECT SCOPE**:
2. `./.claude/settings.json` - Project-shared settings (version-controlled)
3. `./.mcp.json` - Project MCP server definitions

**USER SCOPE** (lowest priority):
4. `~/.claude/settings.local.json` - User-local settings
5. `~/.claude/settings.json` - User-global settings
6. `~/.claude.json` - Main user configuration (definitions and project overrides)
7. `~/.mcp.json` - User MCP server definitions

### Server Types

The tool categorizes servers into three types:

#### MCPJSON Servers (Controllable)
- **Source**: Defined in `.mcp.json` files
- **Control**: Can be toggled via enable/disable arrays
- **UI Indicator**: `[ON]` (green) or `[OFF]` (red)
- **Label**: Shows scope and type, e.g., `[ON ] fetch (project, mcpjson)`

#### Direct-Global Servers (Always Enabled)
- **Source**: Defined in `~/.claude.json` root `.mcpServers`
- **Control**: Always enabled, cannot be disabled without migration
- **UI Indicator**: `[⚠]` (yellow) with "always-on" label
- **Migration**: Can be migrated to `./.mcp.json` for project control

#### Direct-Local Servers (Always Enabled)
- **Source**: Defined in `~/.claude.json` `.projects[cwd].mcpServers`
- **Control**: Always enabled, cannot be disabled without migration
- **UI Indicator**: `[⚠]` (yellow) with "always-on" label
- **Migration**: Can be migrated to `./.mcp.json` for project control

### Dual Precedence Resolution

The tool applies precedence **independently** for definitions and state:

**Definition Precedence** (which server configuration to use):
- Local > Project > User scope
- If `fetch` defined in multiple files, the highest scope wins

**State Precedence** (whether server is on/off):
- Local > Project > User scope
- If `fetch` enabled in one file but disabled in another, highest scope wins

**Example:**
```
User scope: fetch defined with default args + enabled
Project scope: fetch defined with custom args + disabled
Result: Uses project definition (custom args) + disabled state
Display: [OFF] fetch (project, mcpjson)
```

### Migration System

When you try to disable a server marked with `[⚠]` (always-on), the tool offers to migrate it:

**What migration does:**
1. Creates timestamped backup of `~/.claude.json`
2. Copies server definition to `./.mcp.json`
3. Removes server from `~/.claude.json`
4. Marks server as migrated (prevents re-prompting)
5. Reloads server list - server is now controllable

**Migration options:**
- `[y]` Yes - Migrate and disable (recommended for project control)
- `[v]` View - Show full server definition before deciding
- `[n]` No - Keep enabled globally (cancel migration)

**Safety features:**
- Explicit user consent required
- Automatic backups before modification
- Atomic operations with validation
- Automatic rollback on failure

### New Project Flow

When you run `mcp` in a directory without local configuration:

1. **Detects global config exists**
2. **Prompts you to choose:**
   - Create local config (copies global as template)
   - Continue with global only (changes still saved locally)
   - Abort
3. **All changes save to** `./.claude/settings.local.json`

**Important:** Changes are always saved to project-local settings, never to global configuration (unless you explicitly choose to migrate a server).

### State Management

The tool uses a temporary state file to track changes:

- Blazing fast interactions (sub-50ms toggles)
- Safe experimentation (cancel anytime with ESC)
- Atomic writes (no partial updates or corruption)
- Real-time preview updates

## Configuration Files Reference

Understanding which files do what:

### Server Definition Files

These files contain `mcpServers` objects that define what servers exist and how to run them:

| File | Scope | Purpose | Controllable? |
|------|-------|---------|---------------|
| `~/.claude.json` (root `.mcpServers`) | User | Global server definitions | ❌ Always enabled |
| `~/.claude.json` (`.projects[cwd].mcpServers`) | Local | Project-specific definitions in global file | ❌ Always enabled |
| `~/.mcp.json` | User | User-global MCPJSON servers | ✅ Via enable/disable arrays |
| `./.mcp.json` | Project | Project-local MCPJSON servers | ✅ Via enable/disable arrays |

### Control Files (Enable/Disable Arrays)

These files contain `enabledMcpjsonServers` and `disabledMcpjsonServers` arrays that control which MCPJSON servers are active:

| File | Scope | Purpose | Priority |
|------|-------|---------|----------|
| `./.claude/settings.local.json` | Local | **Where this tool saves changes** (gitignored) | Highest |
| `./.claude/settings.json` | Project | Shared project settings (version-controlled) | Medium-High |
| `~/.claude/settings.local.json` | User | User-local overrides | Medium-Low |
| `~/.claude/settings.json` | User | User-global settings | Lowest |

### Which Files Control What?

**For MCPJSON servers** (defined in `.mcp.json` files):
- **Definition** comes from: Highest scope `.mcp.json` file (local > project > user)
- **State** (on/off) comes from: Highest scope settings file with enable/disable arrays

**For Direct servers** (defined in `~/.claude.json`):
- **Definition** comes from: `~/.claude.json` (root or `.projects[cwd]`)
- **State**: Always enabled, cannot be controlled via arrays
- **To control**: Must migrate to `./.mcp.json` first (tool handles this automatically)

### Recommended File Organization

**For maximum flexibility and control:**

1. **Define servers in** `.mcp.json` files (not `~/.claude.json`)
   - User-global servers → `~/.mcp.json`
   - Project-specific servers → `./.mcp.json`

2. **Control servers via** settings files
   - Let this tool manage `./.claude/settings.local.json`
   - Or manually edit enable/disable arrays

3. **Migrate existing direct servers**
   - Use this tool to migrate servers from `~/.claude.json` to `./.mcp.json`
   - Gain project-level control over previously global servers

## Uninstall

To completely remove MCP Server Selector:

```bash
# Remove symlinks
rm ~/.local/bin/mcp ~/.local/bin/claudemcp

# Remove repository
rm -rf ~/.config/mcp-selector
```

Your Claude configuration files (`.claude/settings.json`) will not be affected.

## Troubleshooting

### Dependencies not found

The installer will detect your package manager and provide installation instructions. See the [Installing Dependencies](#installing-dependencies) section above.

### $HOME/.local/bin not in PATH

The installer will offer to automatically add `~/.local/bin` to your PATH. If you declined or need to do it manually:

**Bash/Zsh:**

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc  # or source ~/.zshrc
```

**Fish:**

```bash
echo 'set -gx PATH "$HOME/.local/bin" $PATH' >> ~/.config/fish/config.fish
source ~/.config/fish/config.fish
```

### Can't find claude binary

The tool looks for Claude in:

1. `~/.local/bin/claude` (symlink)
2. Output of `command -v claude`

Make sure Claude Code is properly installed.

### Server shows [⚠] (always-on) indicator

This means the server is defined in `~/.claude.json` and cannot be disabled via enable/disable arrays. To gain control:

1. Press `SPACE` on the server to trigger migration
2. Choose `[y]` to migrate (tool creates automatic backup)
3. Server moves to `./.mcp.json` and becomes controllable

Alternatively, choose `[n]` to keep the server enabled globally.

### Migration failed or want to rollback

If migration fails, the tool automatically restores from backup. To manually rollback:

```bash
# Find backup files
ls -lt ~/.claude.json.backup.*

# Restore specific backup
cp ~/.claude.json.backup.YYYYMMDD_HHMMSS ~/.claude.json
```

Backups are timestamped and created before any modification to `~/.claude.json`.

### Changes not taking effect

After saving changes with `ENTER`:

1. Tool automatically launches Claude with new settings
2. If Claude was already running, exit and run `mcp` again
3. Check that changes were saved to `./.claude/settings.local.json`:
   ```bash
   jq '.enabledMcpjsonServers' ./.claude/settings.local.json
   ```

## Development

### Project Structure

```
cc-mcp-launcher/
├── mcp              # Main executable
├── install.sh       # Installation script
├── README.md        # This file
```

### Testing

Create a test settings file:

```bash
mkdir -p ./.claude
cat > ./.claude/settings.local.json <<'EOF'
{
  "enabledMcpjsonServers": ["fetch", "time"],
  "disabledMcpjsonServers": ["notion", "playwright"]
}
EOF
```

Run the tool:

```bash
./mcp
```

### Design Principles

1. **Speed** - Sub-second launch, instant interactions
2. **Safety** - Atomic writes, validation, never corrupt configs
3. **Clarity** - Always show current vs pending state
4. **Portability** - Works on Linux + macOS without modification
5. **Explicitness** - Prompt before creating or modifying configurations

## Quick Reference

### File Roles Cheat Sheet

| File | Contains | Controls What | Priority |
|------|----------|---------------|----------|
| `./.claude/settings.local.json` | Enable/disable arrays | MCPJSON servers on/off | **Highest** (tool writes here) |
| `./.mcp.json` | Server definitions | Project server configs | High (project scope) |
| `~/.claude.json` | Server definitions | Global/project servers | Medium (always-on unless migrated) |
| `~/.mcp.json` | Server definitions | User-global servers | Medium (controllable) |
| `~/.claude/settings.json` | Enable/disable arrays | MCPJSON servers on/off | Low (user-global) |

### Server Type Quick Lookup

```
[ON ] fetch (project, mcpjson)  → Defined in ./.mcp.json, can toggle on/off
[OFF] time (user, mcpjson)      → Defined in ~/.mcp.json, can toggle on/off
[⚠ ] github (user, always-on)   → Defined in ~/.claude.json, needs migration
```

### Common Commands

```bash
# Launch tool
mcp         # Short command
claudemcp   # Descriptive command

# Check server definitions
jq '.mcpServers | keys' ~/.claude.json      # Global direct servers (always-on)
jq '.mcpServers | keys' ~/.mcp.json         # Global MCPJSON servers
jq '.mcpServers | keys' ./.mcp.json         # Project MCPJSON servers

# Check enabled/disabled state
jq '.enabledMcpjsonServers' ./.claude/settings.local.json   # Local overrides
jq '.disabledMcpjsonServers' ./.claude/settings.local.json  # Local overrides

# Find migration backups
ls -lt ~/.claude.json.backup.*
```

### Decision Tree

**When adding a new server:**
1. ✅ Define in `./.mcp.json` (project) or `~/.mcp.json` (user)
2. ❌ Don't define in `~/.claude.json` (becomes always-on)

**When you see [⚠]:**
1. Server is always enabled (can't toggle off)
2. Press SPACE → choose [y] to migrate
3. Server moves to `./.mcp.json` → becomes controllable

**When setting defaults:**
1. Disable all servers globally: `~/.claude/settings.json`
2. Enable per-project: Let this tool manage `./.claude/settings.local.json`
3. Team defaults: `./.claude/settings.json` (committed to git)

## Credits

Built by [Henrik Söderlund](https://www.henriksoderlund.com) for the Claude Code community.

Powered by:

- [fzf](https://github.com/junegunn/fzf) - Command-line fuzzy finder
- [jq](https://stedolan.github.io/jq/) - JSON processor

## License

MIT License - see [LICENSE](LICENSE) file for details.
