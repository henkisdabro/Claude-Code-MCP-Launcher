Of course. I will first verify the recommended improvements and tool choices, and then construct a detailed Product Requirements Document (PRD) for your coding LLM agent.

***

### Part 1: Verification of Recommendations and Tool Selection

I have reviewed the documentation and community best practices for the tools in question (`bash`, `fzf`, `jq`, `git`) to verify the feasibility and optimality of the proposed improvements.

1.  **`fzf` Capabilities Verification:**
    *   **Dynamic Pre-selection:** `fzf` does not have a simple `--select` flag for individual items. However, the proposed goal is achievable. The standard, robust method is to use the `fzf --multi` flag and combine it with a `reload` binding. A shell function can generate an updated list of servers (with pre-selected items marked), and the `reload` action will refresh `fzf`'s list with the output of that function. This provides a highly dynamic and state-aware interface.
    *   **Key Bindings for State Changes:** The `--bind` option is extremely powerful. We can bind keys like `space` to execute a shell function that toggles a server's state in a temporary state file and then reloads `fzf`. This is a confirmed and effective technique.
    *   **Adding/Removing Items:** The `--bind "ctrl-a:execute(add_server_func)+reload(...)"` pattern is valid. A function can prompt the user for a new server name, append it to the master list, and then `reload` `fzf`. This is entirely feasible.
    *   **Preview Window:** The `--preview` flag is a core feature of `fzf`. It can execute a command based on the currently highlighted line, making it perfect for displaying detailed status information ("Current: ON", "New: OFF").
    *   **Conclusion:** All recommended `fzf`-based TUI improvements are technically sound and leverage core features of the tool.

2.  **`jq` Capabilities Verification:**
    *   **JSON Manipulation:** `jq` is the gold standard for shell-based JSON processing. The syntax used in the original script and proposed for the new script (`--argjson`, `-r`, building arrays with `jq -R . | jq -s .`) are standard, correct, and highly efficient patterns.
    *   **Conclusion:** `jq` is the ideal tool for this task. It is fast, powerful, and universally available.

3.  **Bash Scripting and Portability Verification:**
    *   **Portability (`readlink -f`):** `readlink -f` is indeed a GNU extension and will fail on systems like macOS. The standard solution is to create a small shell function that emulates this behavior using `cd` and `pwd`, ensuring cross-platform compatibility.
    *   **OS Detection:** Using `uname` to determine the OS (`Linux`, `Darwin`, etc.) is the correct, POSIX-compliant method for running platform-specific code (like package manager commands).
    *   **Error Handling:** Using `set -euo pipefail` and `trap` for cleanup are confirmed best practices for writing robust shell scripts.
    *   **Conclusion:** The goal of creating a portable, robust bash script is achievable by paying careful attention to common cross-platform "gotchas."

4.  **Distribution (`curl`/`wget` and Git) Verification:**
    *   **Installation Method:** The `curl | bash` method is a widely adopted standard for distributing CLI tools and is considered safe when pulling from a trusted, version-controlled source (like a specific tag or commit on GitHub). It provides the "one-command install" experience requested.
    *   **Conclusion:** The proposed distribution strategy is industry standard and meets the user's requirements perfectly.

**Overall Tool Choice Confirmation:** Sticking with **Bash + fzf + jq** is the optimal choice. This combination leverages best-in-class, specialized tools, resulting in a highly performant and feature-rich TUI with minimal overhead. Rewriting in another language like Python or Go would introduce new runtime dependencies and significant development complexity for little functional gain in this context. The chosen stack is the right tool for the job.

***

### Part 2: Product Requirements Document (PRD)

**Project Title:** MCP Server Selector v2.0 Rework

**Author:** AI Architect

**Version:** 1.0

**Target Audience:** Advanced Coding LLM Agent

---

### 1.0 Overview & Project Goals

This document outlines the requirements for a complete rework of the "MCP Server Selector," a bash-based TUI tool. The original script is functional but lacks robustness, portability, and an optimal user experience.

The primary goal of this project is to refactor and enhance the tool to be **production-grade**, **cross-platform compatible**, and **easily distributable**, suitable for a public GitHub release. The final product should be a polished, intuitive, and powerful TUI for managing server configurations stored in a JSON file.

### 2.0 Core Philosophy & Design Principles for the Agent

As the coding agent, you must adhere to the following principles throughout the development process:

1.  **Robustness Over Brevity:** Prioritize error handling, input validation, and graceful failure over terse code. The script should never exit unexpectedly or corrupt the user's configuration file.
2.  **Portability First:** The script must run flawlessly on modern Linux distributions (Debian/Ubuntu, Fedora/CentOS) and macOS. Avoid any GNU-specific flags or platform-dependent commands without providing a portable alternative.
3.  **User-Centric Design:** The TUI should be intuitive. The state of the system should always be clear to the user. All actions should be explicit and reversible until confirmed.
4.  **Maintainability & Readability:** The final code must be well-structured, commented, and broken down into logical functions. Use meaningful variable names.
5.  **Idempotence:** Operations should be safe to run multiple times. For example, enabling an already-enabled server should have no negative effect.

### 3.0 Functional Requirements

#### 3.1 Script Core Logic

*   **Dependency Checking:** On startup, the script must verify that `jq` and `fzf` are installed and in the user's `PATH`.
    *   If a dependency is missing, it must inform the user, detect their OS (`Linux` vs. `macOS`), and suggest the correct installation command (e.g., `sudo apt install`, `brew install`). It will then exit gracefully.
*   **Configuration Discovery:** The script must automatically find the `settings.json` file by searching in the following order of priority:
    1.  `./.claude/settings.json` (Project-specific)
    2.  `$HOME/.claude/settings.json` (Global)
    *   If no file is found, it must notify the user and exit gracefully.
*   **Configuration Parsing:** The script must safely parse the `enabledMcpjsonServers` and `disabledMcpjsonServers` arrays from the JSON file using `jq`. It must gracefully handle cases where the keys or arrays are missing or empty.
*   **Configuration Update:** Upon user confirmation in the TUI, the script must atomically update the `settings.json` file.
    *   **Chain-of-Thought:** To prevent data loss, first write the new JSON content to a temporary file. Then, use the `mv` command to replace the original file. This ensures the original file is not corrupted if the write operation fails.
    *   The updated `enabledMcpjsonServers` and `disabledMcpjsonServers` arrays must be correctly formatted and contain the new server selections.

#### 3.2 TUI Behavior & User Experience

*   **Unified List:** The TUI must display a single, alphabetized list of all servers.
*   **State Indication:** Each server in the list must have a clear visual indicator of its **current status** (e.g., `[ON] `) and its **selection status for the change** (e.g., a marker `▶`).
*   **Dynamic Preview:** A preview window must be implemented. When a user highlights a server, the preview pane will show detailed information:
    *   Server Name
    *   Current Status (Enabled/Disabled)
    *   Status After Confirm (Enabled/Disabled)
*   **Key Bindings:** The TUI must respond to the following key presses:
    *   `space`: Toggles the "to-be-enabled" status of the highlighted server. The UI (list and preview) must immediately update to reflect this pending change.
    *   `enter`: Confirms all selections made. The script then proceeds to update the configuration file.
    *   `esc` or `ctrl-c`: Aborts the operation. The script must exit without making any changes.
    *   `ctrl-a`: Triggers an "Add Server" flow. The user is prompted to enter a new server name. Upon submission, the new server is added to the list in a disabled state and the TUI reloads.
    *   `ctrl-x`: Triggers a "Remove Server" flow. The user is prompted for confirmation. If confirmed, the highlighted server is removed from the master list and the TUI reloads.
*   **Header & Footer:** The `fzf` header should display the scope (project or global) and a summary of keybindings (`space`=toggle, `enter`=confirm, etc.).

#### 3.3 Installation & Distribution

*   **`install.sh` Script:** A standalone installation script is required.
    *   It must be runnable via `curl ... | bash`.
    *   It must check for `git`, `jq`, and `fzf` and guide the user to install them if missing.
    *   It will clone the public GitHub repository into a well-known location (e.g., `$HOME/.config/mcp-selector`).
    *   It will create a symlink of the main script to a location in the user's `PATH`, preferably `$HOME/.local/bin/mcp`. It should check if this directory exists and create it if not.
    *   It must print a success message with instructions on how to run the tool.

### 4.0 Technical Implementation Plan (Chain-of-Thought for Agent)

Follow this step-by-step plan to construct the solution.

#### **Phase A: Script Structure & Initialization (`mcp`)**

1.  **Shebang & Safety:** Start with `#!/usr/bin/env bash` and immediately follow with `set -euo pipefail`.
2.  **Main Guard:** Structure the entire script execution within a `main()` function, called at the end of the script: `main "$@"`.
3.  **Globals:** Define global constants at the top for colors, markers, and application directory names to make them easy to change.
4.  **Utility Functions:**
    *   Create a messaging function (e.g., `msg_info`, `msg_error`) for consistent, colored output.
    *   Create a portable `realpath_portable()` function that works on both Linux and macOS to resolve the location of the actual `claude` binary.
5.  **Dependency Check Function (`check_dependencies`)**:
    *   Use a `for` loop and `command -v` to check for `jq` and `fzf`.
    *   If a command is missing, call an OS detection function.
    *   The `detect_os()` function will use `uname` in a `case` statement to identify `"Linux"` or `"Darwin"` and provide tailored installation instructions. Exit with a non-zero status.

#### **Phase B: State Management & Logic**

1.  **State File:** Use `mktemp` to create a temporary file that will store the *current selection state*. This file will be the single source of truth for the TUI. It will be read and written to by your shell functions called from `fzf`.
    *   **`trap` for Cleanup:** Implement a `trap 'rm -f "$STATE_FILE"' EXIT` command at the beginning of `main` to ensure this file is always deleted.
2.  **Data Loading (`load_servers`)**:
    *   Implement the project/global `settings.json` discovery logic.
    *   Use `jq` to read the enabled and disabled servers into two separate Bash variables.
    *   Combine them, sort them uniquely, and write the initial state to your `$STATE_FILE`. The state file should be a simple list of server names, with a prefix indicating their intended state, e.g., `on:server-a`, `off:server-b`.
3.  **State Toggling Function (`toggle_server`)**:
    *   This function will take a server name as an argument.
    *   It will read the `$STATE_FILE`, find the line for that server, and flip its prefix (e.g., `on:server-name` becomes `off:server-name`).
    *   It will overwrite the `$STATE_FILE` with the updated content. This function is the core of the dynamic TUI.
4.  **Data Persistence (`update_settings_file`)**:
    *   This function is called after `fzf` exits successfully.
    *   It reads the final `$STATE_FILE`.
    *   It creates two JSON arrays using `jq`: one for servers prefixed with `on:`, and one for `off:`.
    *   It uses `jq` to update `enabledMcpjsonServers` and `disabledMcpjsonServers` in the original settings file, using the atomic `mv` technique.

#### **Phase C: TUI Implementation (`launch_fzf_tui`)**

1.  **`fzf` List Generation (`generate_fzf_list`)**:
    *   This function reads the `$STATE_FILE`.
    *   For each line, it formats it for display in `fzf`. Example: if `on:server-a` is in the state file, it outputs a line like `[ON] server-a`.
    *   This function will be called by `fzf`'s `reload` action.
2.  **`fzf` Preview Generation (`generate_fzf_preview`)**:
    *   This function receives the full line from `fzf` (e.g., `[ON] server-a`). It extracts the server name.
    *   It looks up the *original* status of the server and the *new* (pending) status from the `$STATE_FILE`.
    *   It prints a formatted string for the preview window.
3.  **The `fzf` Command:** Assemble the final `fzf` command. It will be complex:
    ```bash
    fzf --multi --ansi \
        --header="[SPACE] Toggle | [Enter] Confirm | [Ctrl-A] Add | [Ctrl-X] Remove" \
        --preview='generate_fzf_preview {}' \
        --bind="space:execute(toggle_server {1})+reload(generate_fzf_list)" \
        --bind="ctrl-a:execute(add_server_flow)+reload(generate_fzf_list)" \
        --bind="ctrl-x:execute(remove_server_flow {1})+reload(generate_fzf_list)" \
        --bind="enter:accept" \
        --bind="esc:abort"
    ```
    *   **Chain-of-Thought:** Notice how each action (`space`, `ctrl-a`, `ctrl-x`) calls a shell function to update the state, and then immediately calls `reload` to refresh the `fzf` display with the new state. This creates the interactive experience. The `{1}` is an `fzf` placeholder for the first field of the current line (the server name, if we format our input carefully).

#### **Phase D: Installation Script (`install.sh`)**

1.  Create a separate file `install.sh`.
2.  Implement the dependency checks and installation guidance as described in 3.3.
3.  Use `git clone --depth=1 https://github.com/user/repo.git "$INSTALL_DIR"`.
4.  Check if `$HOME/.local/bin` is in the user's `$PATH`. If not, print a warning and suggest they add it to their `.bashrc`/`.zshrc`.
5.  Create the symlink: `ln -s "$INSTALL_DIR/mcp" "$HOME/.local/bin/mcp"`.
6.  Finish with a clear success message.

### 5.0 Error Handling & Edge Cases

The agent must explicitly code for the following scenarios:

*   **`settings.json` is malformed:** `jq` will exit with an error. The script must catch this, inform the user the file is corrupt, and exit.
*   **`settings.json` is missing keys:** The `jq` commands must handle `null` values gracefully (e.g., using the `// empty` operator).
*   **`fzf` is cancelled:** `fzf` exits with code 130 when `ESC` or `Ctrl-C` is pressed. The script must detect this exit code and silently exit without saving.
*   **Empty server list:** If no servers are found in the configuration, display a message and exit.
*   **Permissions issues:** If the script cannot write to `settings.json` or create the symlink, it must fail with a clear error message.

### 6.0 Final Deliverables

1.  **`mcp`:** The main, refactored executable bash script.
2.  **`install.sh`:** The standalone installation script.
3.  **`README.md`:** Comprehensive documentation including a project description, a GIF of the new TUI, installation instructions (the one-liner), and usage details.

---
### 7.0 Appendix: Sample `settings.json`

Use this sample for development and testing.

```json
{
  "enabledMcpjsonServers": [
    "fetch",
    "time"
  ],
  "disabledMcpjsonServers": [
    "alphavantage",
    "chrome-devtools",
    "cloudflare-docs",
    "coingecko_api",
    "context7",
    "currency-conversion",
    "firecrawl",
    "gemini-bridge",
    "google_workspace",
    "mcphub",
    "microsoft_docs",
    "mikrotik",
    "n8n-mcp",
    "notion",
    "open-meteo",
    "playwright",
    "serena"
  ]
}
```
