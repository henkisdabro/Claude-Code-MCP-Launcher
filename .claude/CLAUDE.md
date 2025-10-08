# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a bash-based TUI (Text User Interface) tool for managing MCP (Model Context Protocol) servers in Claude Code. The tool provides an interactive interface using `fzf` for enabling/disabling MCP servers stored in Claude's `settings.json` file.

## Architecture

### Core Components

**Main Script: `cc-mcp-launcher`**
- Bash script that wraps the Claude Code CLI with an interactive server selector
- Finds and parses Claude settings files (`.claude/settings.json`)
- Uses `fzf` for interactive selection and `jq` for JSON manipulation
- Atomically updates configuration using temp file + `mv` pattern
- Automatically launches Claude after configuration changes

### Configuration Discovery

Settings files are searched in priority order:
1. `./.claude/settings.json` (project-specific)
2. `$HOME/.claude/settings.json` (global)

### Data Flow

1. Script checks for dependencies (`fzf`, `jq`)
2. Locates and reads `settings.json`
3. Parses `enabledMcpjsonServers` and `disabledMcpjsonServers` arrays
4. Presents unified alphabetized list in `fzf` TUI
5. User toggles servers with `SPACE`, confirms with `ENTER`
6. Updates JSON atomically (temp file → `mv`)
7. Launches Claude with updated configuration

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

### Atomic File Updates

Always use temp file pattern to prevent corruption:
```bash
TMP_FILE=$(mktemp)
jq --argjson enabled "$NEW_ENABLED_JSON" \
   --argjson disabled "$NEW_DISABLED_JSON" \
   '.enabledMcpjsonServers = $enabled | .disabledMcpjsonServers = $disabled' \
   "$SETTINGS" > "$TMP_FILE"
mv "$TMP_FILE" "$SETTINGS"
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

Selected items from `fzf` include ANSI color codes that must be stripped:
```bash
sed 's/\x1b\[[0-9;]*m//g'  # Remove ANSI codes
sed 's/^\[ON \] *//'        # Remove state prefix
```


## Important Notes

- Configuration updates are atomic (no partial writes)
- Fallback to Claude without selector if dependencies missing
- Handles empty/malformed JSON gracefully
- Exit code 130 from `fzf` = user cancelled (ESC/Ctrl-C)
