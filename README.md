# MCP Server Selector v2.0

A fast, beautiful TUI for managing MCP (Model Context Protocol) servers in Claude Code. Built with bash, fzf, and jq for instant interactions and cross-platform compatibility.

## Features

- **Interactive TUI** - Fast, intuitive interface powered by fzf
- **Real-time Updates** - Toggle servers instantly with visual feedback
- **Smart Configuration** - Automatically detects project vs global settings
- **Safe by Design** - Never modifies global config without explicit consent
- **Cross-Platform** - Works on Linux and macOS out of the box
- **Zero Dependencies** - Just bash, fzf, and jq (easy to install)

## Quick Start

### Installation

One-line install (recommended):

```bash
curl -fsSL https://raw.githubusercontent.com/henkisdabro/cc-mcp-launcher/main/install.sh | bash
```

Or manual install:

```bash
git clone https://github.com/henkisdabro/cc-mcp-launcher.git ~/.config/mcp-selector
ln -s ~/.config/mcp-selector/mcp ~/.local/bin/mcp
chmod +x ~/.local/bin/mcp
```

### Usage

Simply run `mcp` in any directory:

```bash
mcp
```

The tool will:
1. Detect your Claude configuration (project or global)
2. Launch the interactive TUI
3. Save your changes when you press Enter
4. Launch Claude Code with your updated settings

## Keybindings

| Key | Action |
|-----|--------|
| `SPACE` | Toggle server on/off |
| `ENTER` | Save changes and launch Claude |
| `ESC` | Cancel without saving |
| `Ctrl-A` | Add new server |
| `Ctrl-X` | Remove selected server |
| `↑/↓` or `/` | Navigate and filter |

## Configuration Priority

The tool searches for configuration files in this order:

1. `./.claude/settings.local.json` (project-specific, highest priority)
2. `./.claude/settings.json` (legacy project-specific)
3. New Project Flow (if global config exists but no local config)

### New Project Flow

When you run `mcp` in a directory without local configuration, you'll be prompted to:

1. **Create local config** - Copies global settings to `./.claude/settings.local.json` (recommended)
2. **Use global for this session** - Skips TUI, launches Claude with global settings (read-only)
3. **Abort** - Exit without making changes

**Important:** The tool will never modify your global `~/.claude/settings.json` file. All changes are saved to local project configs.

## Architecture

### State Management

The tool uses a temporary state file to track changes, enabling instant UI updates without touching your settings file until you confirm. This means:

- Blazing fast interactions (sub-50ms toggles)
- Safe experimentation (cancel anytime with ESC)
- Atomic writes (no partial updates or corruption)

### Configuration Format

Settings are stored in JSON format:

```json
{
  "enabledMcpjsonServers": [
    "fetch",
    "time"
  ],
  "disabledMcpjsonServers": [
    "alphavantage",
    "chrome-devtools",
    "notion"
  ]
}
```

## Development

### Requirements

- bash 4.0+
- [fzf](https://github.com/junegunn/fzf) 0.20+
- [jq](https://stedolan.github.io/jq/) 1.6+

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

### Project Structure

```
cc-mcp-launcher/
├── mcp              # Main executable
├── install.sh       # Installation script
├── README.md        # This file
├── prd.md           # Product requirements document
└── prd-addendum.md  # Additional requirements
```

## Design Principles

1. **Speed** - Sub-second launch, instant interactions
2. **Safety** - Atomic writes, validation, never corrupt configs
3. **Clarity** - Always show current vs pending state
4. **Portability** - Works on Linux + macOS without modification
5. **Explicitness** - Prompt before creating or modifying configurations

## Troubleshooting

### Dependencies not found

Install dependencies based on your OS:

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

### $HOME/.local/bin not in PATH

Add this to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then reload:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

### Can't find claude binary

The tool looks for Claude in:
1. `~/.local/bin/claude` (symlink)
2. Output of `command -v claude`

Make sure Claude Code is properly installed.

## Credits

Built by [Henrik Söderlund](https://www.henriksoderlund.com) for the Claude Code community.

Powered by:
- [fzf](https://github.com/junegunn/fzf) - Command-line fuzzy finder
- [jq](https://stedolan.github.io/jq/) - JSON processor

## License

MIT License - see repository for details
