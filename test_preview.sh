#!/usr/bin/env bash

# Test preview output with colors

COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[1m'

preview_line() {
    local text="$1"
    echo -e "$text"
}

echo "Testing new simplified preview format:"
echo ""

# Example 1: MCPJSON server (enabled)
preview_line "╭─────────────────────────────────────────────────╮"
preview_line ""
preview_line " ${COLOR_WHITE}gemini-bridge${COLOR_RESET}"
preview_line ""
preview_line " ${COLOR_CYAN}Source Type${COLOR_RESET}"
preview_line "   ${COLOR_GREEN}MCP.json${COLOR_RESET} (controllable)"
preview_line ""
preview_line " ${COLOR_CYAN}Definition${COLOR_RESET}"
preview_line "   Scope: project"
preview_line "   File:  ./.mcp.json"
preview_line ""
preview_line " ${COLOR_CYAN}Status${COLOR_RESET}"
preview_line "   ${COLOR_GREEN}● Enabled${COLOR_RESET}"
preview_line ""
preview_line " ${COLOR_CYAN}Press SPACE to toggle${COLOR_RESET}"
preview_line ""
preview_line " ${COLOR_YELLOW}Changes write to:${COLOR_RESET}"
preview_line "   ./.claude/settings.local.json"
preview_line ""
preview_line "╰─────────────────────────────────────────────────╯"

echo ""
echo "=========================================="
echo ""

# Example 2: Direct server (disabled)
preview_line "╭─────────────────────────────────────────────────╮"
preview_line ""
preview_line " ${COLOR_WHITE}time${COLOR_RESET}"
preview_line ""
preview_line " ${COLOR_CYAN}Source Type${COLOR_RESET}"
preview_line "   ${COLOR_YELLOW}Direct (global)${COLOR_RESET}"
preview_line ""
preview_line " ${COLOR_CYAN}Definition${COLOR_RESET}"
preview_line "   Scope: user"
preview_line "   File:  ~/.claude.json"
preview_line ""
preview_line " ${COLOR_CYAN}Status & Control${COLOR_RESET}"
preview_line "   ${COLOR_RED}● Disabled${COLOR_RESET} (quick-disable)"
preview_line "   Disabled via ${COLOR_CYAN}~/.claude.json${COLOR_RESET}"
preview_line "   Location: .projects[cwd]"
preview_line "   Definition remains global"
preview_line ""
preview_line " ${COLOR_CYAN}Press SPACE to re-enable${COLOR_RESET}"
preview_line " ${COLOR_CYAN}Press ALT-M to migrate${COLOR_RESET}"
preview_line ""
preview_line " ${COLOR_WHITE}Quick Disable${COLOR_RESET} - Modifies global"
preview_line " ${COLOR_WHITE}Migration${COLOR_RESET} - Full project control"
preview_line ""
preview_line "╰─────────────────────────────────────────────────╯"
