Excellent addition. This scenario is critical for making the tool robust and user-friendly in a real-world workflow. Modifying a user's global configuration implicitly is dangerous; creating a local override is the correct pattern.

I have updated the Product Requirements Document. The changes are integrated directly into the relevant sections and are marked with **[NEW REQUIREMENT]** for clarity.

***

### **Product Requirements Document (PRD) - ADDENDUM 1.1**

**Project Title:** MCP Server Selector v2.0 Rework

**Version:** 1.1 (Includes New Project Initialization Logic)

---

### 1.0 Overview & Project Goals

*(No changes to this section. The goal remains to create a production-grade, cross-platform, easily distributable TUI tool.)*

### 2.0 Core Philosophy & Design Principles for the Agent

*(This new principle is added to the list.)*

6.  **Principle of Least Privilege & Explicitness:** The tool must never modify the global (`$HOME`) configuration file. All actions should be explicit. When operating in a directory without a local configuration, the tool must stop and ask the user for their intent rather than making an assumption.

### 3.0 Functional Requirements

#### 3.1 Script Core Logic

*   **Dependency Checking:** *(No changes to this requirement.)*

*   **Configuration Discovery & Initialization:** *(This section is heavily modified to incorporate the new logic.)*

    The script's configuration discovery logic is critical and must follow this precise order of operations:

    1.  **Highest Priority (Local Override):** Search for a file named `settings.local.json` inside a `.claude` directory in the current working directory (`./.claude/settings.local.json`). If found, this file **must** be used for all subsequent read and write operations. The `SCOPE` should be set to `project (local)`.

    2.  **Second Priority (Legacy Local):** If the above is not found, search for `./.claude/settings.json`. If found, use this file. The `SCOPE` should be set to `project`.

    3.  **[NEW REQUIREMENT] "New Project" Detection:** If neither local configuration file is found, the script must check for the existence of the global configuration file at `$HOME/.claude/settings.json`.
        *   **If the global file does not exist:** The script is in a completely unconfigured state. It should display an error message like "No local or global Claude configuration found. Please configure Claude first." and exit gracefully.
        *   **If the global file *does* exist:** This triggers the "New Project Initialization" flow.

*   **[NEW REQUIREMENT] New Project Initialization Flow:**
    *   When triggered, the script must halt execution of the TUI and present a clear, text-based prompt to the user. The prompt should be similar to:
        ```
        You are in a new project without a local Claude configuration.

        The global configuration will be used as a template.
        What would you like to do?

        1) Create a new local configuration (.claude/settings.local.json) for this project. (Recommended)
        2) Use global settings for this command only (no changes will be saved).
        3) Abort.

        Enter your choice [1-3]:
        ```
    *   The script must handle the user's input:
        *   **Choice 1 (Create Local Config):**
            *   Create the local directory: `mkdir -p ./.claude`
            *   **Copy** the global file to the new local file: `cp "$HOME/.claude/settings.json" "./.claude/settings.local.json"`
            *   Set the active configuration file path to `./.claude/settings.local.json`.
            *   Proceed to launch the TUI to allow the user to immediately customize this new local configuration.
        *   **Choice 2 (Use Global):**
            *   Do not launch the TUI.
            *   Print a message like "Proceeding with global settings..."
            *   Immediately `exec` the original `claude` binary, passing through all arguments. The wrapper script's job is done.
        *   **Choice 3 (Abort) or any other input:**
            *   Print a message "Operation cancelled." and exit gracefully.

*   **Configuration Parsing:** *(No changes, but it must operate on the file path determined by the discovery logic.)*

*   **Configuration Update:** *(No changes, but it must operate on the file path determined by the discovery logic, and it will never write to the global file.)*

#### 3.2 TUI Behavior & User Experience

*(This section has a minor addition for clarity.)*

*   **Header & Footer:** The `fzf` header should display the **full context**, including the `SCOPE` determined during the discovery phase (e.g., `(project: .claude/settings.local.json)` or `(global)`) and the summary of keybindings.

*   *(All other TUI requirements remain the same.)*

### 4.0 Technical Implementation Plan (Chain-of-Thought for Agent)

*(The plan is updated to reflect the new logic.)*

#### **Phase A: Script Structure & Initialization (`mcp`)**

1.  *(Steps 1-4 remain the same.)*
2.  **Dependency Check Function (`check_dependencies`)**: *(No changes.)*

#### **Phase B: State Management & Logic**

1.  **Main Function - Top Level Logic:** The `main` function should be the orchestrator for the new discovery flow.
    *   Declare a variable `SETTINGS_FILE_PATH=""`.
    *   Implement the full discovery logic from section 3.1.
    *   If the "New Project" flow is triggered, call a new function like `handle_new_project_prompt()`. This function will return the path to the newly created local file, an "exec" signal, or an "abort" signal.
    *   Based on the result, `main` will either set `SETTINGS_FILE_PATH`, `exec claude`, or `exit`.
    *   If a settings file path is determined, store it in `SETTINGS_FILE_PATH` and pass this variable to all subsequent functions that need it (`load_servers`, `update_settings_file`).
2.  **State File & `trap`:** *(No changes.)*
3.  **Data Loading (`load_servers`)**:
    *   This function must now accept the `SETTINGS_FILE_PATH` as an argument.
    *   It will read from this specified path instead of having its own discovery logic.
4.  **State Toggling Function (`toggle_server`)**: *(No changes.)*
5.  **Data Persistence (`update_settings_file`)**:
    *   This function must now accept the `SETTINGS_FILE_PATH` as an argument.
    *   It will perform the atomic write operation on the specified file path.

#### **Phase C: TUI Implementation (`launch_fzf_tui`)**

*(The agent should ensure the `$SCOPE` variable, determined during the discovery phase, is passed to this function so it can be displayed in the header.)*

1.  *(All other TUI implementation steps remain the same.)*

#### **Phase D: Installation Script (`install.sh`)**

*(No changes to this file.)*

### 5.0 Error Handling & Edge Cases

*(This new edge case is added.)*

*   **No Global Config:** If the "New Project" flow is triggered but the global `$HOME/.claude/settings.json` file doesn't exist to be used as a template, the script must not offer to create a new local file. It should display a specific error and exit.

### 6.0 Final Deliverables

*(No changes to the list of deliverables.)*

### 7.0 Appendix: Sample `settings.json`

*(No changes to the appendix.)*