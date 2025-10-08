#!/usr/bin/env bash

# MCP Server Selector - Installation Script
# One-line install: curl -fsSL https://raw.githubusercontent.com/henkisdabro/cc-mcp-launcher/main/install.sh | bash

set -euo pipefail

# ============================================================================
# CONSTANTS
# ============================================================================

readonly REPO_URL="https://github.com/henkisdabro/cc-mcp-launcher.git"
readonly INSTALL_DIR="$HOME/.config/mcp-selector"
readonly BIN_DIR="$HOME/.local/bin"
readonly SYMLINK_PATH="$BIN_DIR/mcp"

# Color codes
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1m'

# Markers
readonly MARK_ERROR="✗"
readonly MARK_SUCCESS="✓"
readonly MARK_WARNING="⚠"
readonly MARK_INFO="→"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

msg_info() {
    echo -e "${COLOR_CYAN}${MARK_INFO}${COLOR_RESET} $*"
}

msg_success() {
    echo -e "${COLOR_GREEN}${MARK_SUCCESS}${COLOR_RESET} $*"
}

msg_error() {
    echo -e "${COLOR_RED}${MARK_ERROR}${COLOR_RESET} $*" >&2
}

msg_warning() {
    echo -e "${COLOR_YELLOW}${MARK_WARNING}${COLOR_RESET} $*"
}

msg_header() {
    echo -e "${COLOR_WHITE}${COLOR_CYAN}$*${COLOR_RESET}"
}

detect_os() {
    uname -s
}

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

check_dependencies() {
    local missing_deps=()
    local os
    os=$(detect_os)

    # Check for git, fzf, jq
    for cmd in git fzf jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        return 0
    fi

    msg_error "Missing required dependencies: ${missing_deps[*]}"
    echo ""

    case "$os" in
        Linux)
            if command -v apt &> /dev/null; then
                echo -e "${COLOR_CYAN}Install with:${COLOR_RESET}"
                echo "  sudo apt update && sudo apt install ${missing_deps[*]}"
            elif command -v dnf &> /dev/null; then
                echo -e "${COLOR_CYAN}Install with:${COLOR_RESET}"
                echo "  sudo dnf install ${missing_deps[*]}"
            elif command -v yum &> /dev/null; then
                echo -e "${COLOR_CYAN}Install with:${COLOR_RESET}"
                echo "  sudo yum install ${missing_deps[*]}"
            elif command -v pacman &> /dev/null; then
                echo -e "${COLOR_CYAN}Install with:${COLOR_RESET}"
                echo "  sudo pacman -S ${missing_deps[*]}"
            else
                echo -e "${COLOR_CYAN}Install using your system's package manager${COLOR_RESET}"
            fi
            ;;
        Darwin)
            if command -v brew &> /dev/null; then
                echo -e "${COLOR_CYAN}Install with:${COLOR_RESET}"
                echo "  brew install ${missing_deps[*]}"
            else
                echo -e "${COLOR_CYAN}Install Homebrew first:${COLOR_RESET}"
                echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                echo ""
                echo -e "${COLOR_CYAN}Then install dependencies:${COLOR_RESET}"
                echo "  brew install ${missing_deps[*]}"
            fi
            ;;
        *)
            echo -e "${COLOR_CYAN}Please install: ${missing_deps[*]}${COLOR_RESET}"
            ;;
    esac

    exit 1
}

# ============================================================================
# INSTALLATION
# ============================================================================

install_mcp_selector() {
    msg_header "MCP Server Selector - Installation"
    echo ""

    # Check dependencies
    msg_info "Checking dependencies..."
    check_dependencies
    msg_success "All dependencies found"
    echo ""

    # Remove existing installation if present
    if [[ -d "$INSTALL_DIR" ]]; then
        msg_warning "Removing existing installation at $INSTALL_DIR"
        rm -rf "$INSTALL_DIR"
    fi

    # Clone repository
    msg_info "Cloning repository..."
    git clone --depth=1 "$REPO_URL" "$INSTALL_DIR" 2>&1 | grep -v "Cloning into" || true
    msg_success "Repository cloned to $INSTALL_DIR"
    echo ""

    # Create bin directory if it doesn't exist
    if [[ ! -d "$BIN_DIR" ]]; then
        msg_info "Creating $BIN_DIR"
        mkdir -p "$BIN_DIR"
    fi

    # Remove existing symlink if present
    if [[ -L "$SYMLINK_PATH" ]] || [[ -f "$SYMLINK_PATH" ]]; then
        msg_warning "Removing existing symlink at $SYMLINK_PATH"
        rm -f "$SYMLINK_PATH"
    fi

    # Create symlink
    msg_info "Creating symlink..."
    ln -s "$INSTALL_DIR/mcp" "$SYMLINK_PATH"
    chmod +x "$INSTALL_DIR/mcp"
    msg_success "Symlink created: $SYMLINK_PATH → $INSTALL_DIR/mcp"
    echo ""

    # Check if BIN_DIR is in PATH
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        msg_warning "$BIN_DIR is not in your PATH"
        echo ""
        echo "Add this line to your ~/.bashrc or ~/.zshrc:"
        echo ""
        echo -e "  ${COLOR_CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${COLOR_RESET}"
        echo ""
        echo "Then reload your shell:"
        echo -e "  ${COLOR_CYAN}source ~/.bashrc${COLOR_RESET}  (or source ~/.zshrc)"
        echo ""
    fi

    # Success message
    msg_success "Installation complete!"
    echo ""
    echo -e "${COLOR_CYAN}Usage:${COLOR_RESET}"
    echo "  Run ${COLOR_WHITE}mcp${COLOR_RESET} in any directory with a Claude project"
    echo ""
    echo -e "${COLOR_CYAN}Features:${COLOR_RESET}"
    echo "  • ${COLOR_GREEN}SPACE${COLOR_RESET} - Toggle server on/off"
    echo "  • ${COLOR_GREEN}ENTER${COLOR_RESET} - Save changes and launch Claude"
    echo "  • ${COLOR_GREEN}Ctrl-A${COLOR_RESET} - Add new server"
    echo "  • ${COLOR_GREEN}Ctrl-X${COLOR_RESET} - Remove server"
    echo "  • ${COLOR_GREEN}ESC${COLOR_RESET} - Cancel without saving"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

install_mcp_selector
