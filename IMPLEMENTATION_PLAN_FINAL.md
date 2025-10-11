# MCP Server Control - Final Implementation Plan

**Branch**: `feature/native-disable-arrays-support`
**Last Updated**: October 11, 2025
**Status**: Phase 1 Complete, Ready for Phase 2

---

## Critical Discoveries & Decisions

### 🔍 What We Learned (Testing Results)

1. **`disabledMcpServers` (without "json") IS FUNCTIONAL**
   - ✅ **ONLY works in `~/.claude.json`** (root or `.projects[cwd]` section)
   - ❌ **CANNOT be used in settings files** (`.claude/settings*.json`)
   - ✅ **Controls Direct-Global and Direct-Local servers**
   - This was initially thought to be non-functional, but works when in correct location

2. **`disabledMcpjsonServers` (with "json")**
   - ✅ **ONLY works in settings files** (`.claude/settings*.json`)
   - ❌ **CANNOT be used in `~/.claude.json`**
   - ✅ **Controls MCPJSON servers** (from `.mcp.json` files)

3. **`enabledPlugins` Object**
   - ✅ **ONLY works in settings files** (`.claude/settings*.json`)
   - ❌ **CANNOT be used in `~/.claude.json`**
   - ⚠️ **Setting to `false` makes plugin disappear from Claude UI entirely** (user cannot re-enable without editing config)
   - ✅ **Solution**: Use "omit strategy" (don't include plugin in object) for soft-disable

4. **Location Restrictions Are Critical**
   - Each control array ONLY works in specific file types
   - Attempting to use arrays in wrong locations has ZERO effect
   - This explains why previous tests showed arrays as "non-functional"

### 🎯 Architectural Decisions Made

**Decision 1: Direct Server Control (Option A Default)**
- ✅ **Default**: Quick-disable by writing to `~/.claude.json` `.projects[cwd].disabledMcpServers`
- ✅ **Alternative**: Migration to `./.mcp.json` (accessible via ALT-M keybinding)
- **Rationale**: Quick-disable is one-step, migration is for full project ownership

**Decision 2: Multi-File Write Strategy**
- Write to TWO different files based on server type:
  - **MCPJSON + Plugins** → `./.claude/settings.local.json`
  - **Direct servers** → `~/.claude.json` `.projects[cwd].disabledMcpServers`
- Both operations atomic with backups

**Decision 3: Plugin Disable Strategy**
- ✅ **Default (SPACE)**: Soft-disable (omit from `enabledPlugins` object)
- ✅ **Alternative (SHIFT-SPACE)**: Hard-disable (set to `false`, hides from UI)
- **Rationale**: Soft-disable preserves UI access for re-enabling

**Decision 4: No Longer "Always-On"**
- Direct servers are NOW controllable (not "always-on" anymore)
- Update UI indicators from `[⚠]` to `[ON]`/`[OFF]`
- Migration still valuable for project ownership of definition

---

## Server Type Control Matrix (Final)

| Server Type | Source | Control Array | Write Location | Status |
|------------|--------|--------------|----------------|--------|
| **MCPJSON** | `.mcp.json` files | `disabledMcpjsonServers` | `./.claude/settings.local.json` | ✅ Working |
| **Direct-Global** | `~/.claude.json` root `.mcpServers` | `disabledMcpServers` | `~/.claude.json` `.projects[cwd]` | ✅ Working |
| **Direct-Local** | `~/.claude.json` `.projects[cwd].mcpServers` | `disabledMcpServers` | `~/.claude.json` `.projects[cwd]` | ✅ Working |
| **Plugin** | Marketplace `marketplace.json` | `enabledPlugins` | `./.claude/settings.local.json` | ✅ Working |

---

## What's Been Completed (Phase 1)

### ✅ Completed Tasks

1. **Comprehensive Testing** (`MCP_CONTROL_TESTING_REPORT.md`)
   - Tested all arrays in all locations
   - Discovered location restrictions
   - Documented precedence rules

2. **Documentation Updates** (`.claude/CLAUDE.md`)
   - 4 server types documented
   - Control mechanisms for each
   - Quick-disable vs Migration options
   - Location restrictions clearly stated

3. **Code Changes** (`mcp` script line 345-354)
   - Added parsing for `disabledMcpServers` from `.projects[cwd]`
   ```bash
   # Parse local-scope disabled DIRECT servers (.projects[cwd].disabledMcpServers)
   local disabled_direct
   disabled_direct=$(jq -r --arg cwd "$cwd" '.projects[$cwd].disabledMcpServers[]? // empty' "$file" 2>/dev/null | sort -u)

   if [[ -n "$disabled_direct" ]]; then
       while IFS= read -r server; do
           [[ -n "$server" ]] && echo "disable:$server:local:$file"
       done <<< "$disabled_direct"
   fi
   ```

4. **Git Commit** (ae60a06)
   - Branch: `feature/native-disable-arrays-support`
   - All changes committed and ready for next phase

---

## Next Steps - Phase 2 (Write Logic)

### Task 2.1: Create `write_direct_servers_to_claude_json()` Function

**Location**: After `save_state_to_settings()` function (around line 1098)

**Code to Add**:
```bash
# ============================================================================
# DIRECT SERVER WRITE FUNCTIONS
# ============================================================================

# Write disabled Direct servers to ~/.claude.json .projects[cwd].disabledMcpServers
# Args: Array of server names to disable
# Returns: 0 on success, 1 on failure
write_direct_servers_to_claude_json() {
    local -a disabled_direct=("$@")
    local target="$HOME/.claude.json"
    local cwd=$(pwd)

    # Create timestamped backup
    local backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
    if ! cp "$target" "$backup" 2>/dev/null; then
        msg_error "Failed to create backup of $target"
        return 1
    fi
    msg_info "Backup created: $backup"

    # Build disabled array JSON
    local disabled_json
    if [[ ${#disabled_direct[@]} -eq 0 ]]; then
        disabled_json="[]"
    else
        disabled_json=$(printf '%s\n' "${disabled_direct[@]}" | jq -R . | jq -s -c .)
    fi

    # Atomic update to .projects[cwd].disabledMcpServers
    local temp_file=$(mktemp)

    jq --arg cwd "$cwd" --argjson disabled "$disabled_json" \
       '.projects[$cwd].disabledMcpServers = $disabled' \
       "$target" > "$temp_file"

    # Validate JSON
    if ! jq empty "$temp_file" 2>/dev/null; then
        msg_error "JSON validation failed, rolling back"
        rm "$temp_file"
        return 1
    fi

    mv "$temp_file" "$target"
    msg_success "Updated $target (.projects[$cwd].disabledMcpServers)"

    return 0
}
```

### Task 2.2: Update `save_state_to_settings()` Function

**Location**: Line 1041-1098

**Changes Needed**:

1. Add separate tracking for Direct servers
2. Call `write_direct_servers_to_claude_json()` for Direct servers
3. Keep existing logic for MCPJSON servers

**Modified Code** (replace existing function):
```bash
save_state_to_settings() {
    local target="./.claude/settings.local.json"

    # Create .claude directory if it doesn't exist
    if [[ ! -d "./.claude" ]]; then
        mkdir -p "./.claude"
        msg_info "Created .claude/ directory"
    fi

    # Parse state file into categories
    local enabled_mcpjson=()
    local disabled_mcpjson=()
    local disabled_direct=()  # NEW: Track Direct servers separately

    while IFS=: read -r state server scope file source_type; do
        [[ -z "$server" ]] && continue

        # NEW: Handle Direct servers separately
        if [[ "$source_type" == "direct-global" ]] || [[ "$source_type" == "direct-local" ]]; then
            if [[ "$state" == "off" ]]; then
                disabled_direct+=("$server")
            fi
            continue
        fi

        # Existing: MCPJSON servers
        if [[ "$state" == "on" ]]; then
            enabled_mcpjson+=("$server")
        elif [[ "$state" == "off" ]]; then
            disabled_mcpjson+=("$server")
        fi
    done < "$STATE_FILE"

    # Build JSON arrays for MCPJSON servers
    local enabled_json
    local disabled_json

    if [[ ${#enabled_mcpjson[@]} -eq 0 ]]; then
        enabled_json="[]"
    else
        enabled_json=$(printf '%s\n' "${enabled_mcpjson[@]}" | jq -R . | jq -s -c .)
    fi

    if [[ ${#disabled_mcpjson[@]} -eq 0 ]]; then
        disabled_json="[]"
    else
        disabled_json=$(printf '%s\n' "${disabled_mcpjson[@]}" | jq -R . | jq -s -c .)
    fi

    # Initialize with empty object if file doesn't exist
    if [[ ! -f "$target" ]]; then
        echo '{}' > "$target"
        msg_info "Created $target"
    fi

    # Atomic update for MCPJSON servers (existing logic)
    local temp_file
    temp_file=$(mktemp)

    jq --argjson enabled "$enabled_json" \
       --argjson disabled "$disabled_json" \
       '.enabledMcpjsonServers = $enabled | .disabledMcpjsonServers = $disabled' \
       "$target" > "$temp_file"

    mv "$temp_file" "$target"

    # NEW: Write Direct servers to ~/.claude.json if any are disabled
    if [[ ${#disabled_direct[@]} -gt 0 ]]; then
        write_direct_servers_to_claude_json "${disabled_direct[@]}"
    else
        # Clear disabledMcpServers if no Direct servers are disabled
        write_direct_servers_to_claude_json  # Empty array
    fi
}
```

**Key Changes**:
- Line ~1054: Add `disabled_direct=()` array
- Line ~1057-1063: NEW block to handle Direct servers separately
- Line ~1093-1099: NEW block to write Direct servers to `~/.claude.json`

---

## Next Steps - Phase 3 (Toggle Logic)

### Task 3.1: Update `toggle_server()` Function

**Location**: Line 898-969

**Current Behavior**: Shows migration prompt for Direct servers

**New Behavior**:
- Direct servers: Toggle on/off (quick-disable to `.projects[cwd]`)
- Keep migration available via ALT-M keybinding

**Modified Code**:
```bash
toggle_server() {
    local raw_input="$1"

    # Strip ANSI codes, prefixes, and scope suffix to get clean server name
    local server
    server=$(echo "$raw_input" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^\[ON \] *//' | sed 's/^\[OFF\] *//' | sed 's/^\[⚠ \] *//' | sed 's/^     *//' | sed 's/ *(.*)$//')

    # Get source type
    local source_type
    source_type=$(get_server_source_type "$server")

    # NEW: Direct servers now toggle normally (quick-disable)
    if [[ "$source_type" == "direct-global" ]] || [[ "$source_type" == "direct-local" ]]; then
        # Simple toggle in state file (same as MCPJSON)
        local temp_state
        temp_state=$(mktemp)

        while IFS=: read -r state srv scope file stype; do
            if [[ "$srv" == "$server" ]]; then
                # Toggle state, preserve scope, file, and source type
                if [[ "$state" == "on" ]]; then
                    echo "off:$srv:$scope:$file:$stype" >> "$temp_state"
                else
                    echo "on:$srv:$scope:$file:$stype" >> "$temp_state"
                fi
            else
                # Keep unchanged
                echo "$state:$srv:$scope:$file:$stype" >> "$temp_state"
            fi
        done < "$STATE_FILE"

        mv "$temp_state" "$STATE_FILE"
        return 0
    fi

    # EXISTING: MCPJSON servers (no changes)
    local temp_state
    temp_state=$(mktemp)

    while IFS=: read -r state srv scope file source_type; do
        if [[ "$srv" == "$server" ]]; then
            # Toggle state, preserve scope, file, and source type
            if [[ "$state" == "on" ]]; then
                echo "off:$srv:$scope:$file:$source_type" >> "$temp_state"
            else
                echo "on:$srv:$scope:$file:$source_type" >> "$temp_state"
            fi
        else
            # Keep unchanged
            echo "$state:$srv:$scope:$file:$source_type" >> "$temp_state"
        fi
    done < "$STATE_FILE"

    mv "$temp_state" "$STATE_FILE"
}
```

### Task 3.2: Add ALT-M Keybinding for Migration

**Location**: In `launch_fzf_tui()` function, around line 1417-1423

**Add This Keybinding**:
```bash
--bind="alt-m:execute(migrate_direct_server_flow {})+reload(generate_fzf_list)+refresh-preview"
```

**Add This Function** (after `remove_server_flow()`, around line 1331):
```bash
# Migration flow for Direct servers (Option B - Alternative)
# Args: $1 - server line from fzf
migrate_direct_server_flow() {
    local raw_input="$1"

    # Strip to get server name
    local server
    server=$(echo "$raw_input" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^\[ON \] *//' | sed 's/^\[OFF\] *//' | sed 's/^     *//' | sed 's/ *(.*)$//')

    if [[ -z "$server" ]]; then
        return 0
    fi

    # Check if this is a Direct server
    local source_type
    source_type=$(get_server_source_type "$server")

    if [[ "$source_type" != "direct-global" ]] && [[ "$source_type" != "direct-local" ]]; then
        # Redirect to tty for message
        exec < /dev/tty
        echo ""
        msg_warning "Migration only available for Direct servers"
        sleep 1
        return 0
    fi

    # Get definition location
    local location def_file
    location=$(get_server_definition_location "$server")
    def_file=$(echo "$location" | cut -d: -f2-)

    # Existing migration prompt and logic
    if prompt_for_migration "$server" "$source_type" "$def_file"; then
        if migrate_server_to_project_mcpjson "$server"; then
            load_servers
            msg_info "Reloaded server list - server is now controllable"
            sleep 1
        else
            msg_error "Migration failed"
            sleep 2
        fi
    fi
}
```

---

## Next Steps - Phase 4 (UI Updates)

### Task 4.1: Update `generate_fzf_list()`

**Location**: Line 1104-1135

**Change**: Remove `[⚠]` indicator, show Direct servers as `[ON]`/`[OFF]`

**Modified Code**:
```bash
generate_fzf_list() {
    if [[ ! -f "$STATE_FILE" ]] || [[ ! -s "$STATE_FILE" ]]; then
        echo ""
        return
    fi

    local dim='\033[2m'

    while IFS=: read -r state server scope file source_type; do
        [[ -z "$server" ]] && continue

        # Direct servers: Show as ON/OFF (no longer always-on)
        if [[ "$source_type" == "direct-global" ]] || [[ "$source_type" == "direct-local" ]]; then
            if [[ "$state" == "on" ]]; then
                echo -e "${COLOR_GREEN}[ON ]${COLOR_RESET} $server ${dim}($scope, $source_type)${COLOR_RESET}"
            else
                echo -e "${COLOR_RED}[OFF]${COLOR_RESET} $server ${dim}($scope, $source_type)${COLOR_RESET}"
            fi
            continue
        fi

        # MCPJSON servers (existing logic)
        if [[ "$state" == "on" ]]; then
            echo -e "${COLOR_GREEN}[ON ]${COLOR_RESET} $server ${dim}($scope, $source_type)${COLOR_RESET}"
        elif [[ "$state" == "off" ]]; then
            echo -e "${COLOR_RED}[OFF]${COLOR_RESET} $server ${dim}($scope, $source_type)${COLOR_RESET}"
        fi
    done < "$STATE_FILE"
}
```

### Task 4.2: Update `generate_preview()`

**Location**: Line 1137-1272

**Add Section for Direct Servers** (insert after line ~1220, before existing code):
```bash
# NEW: Direct server preview
if [[ "$source_type" == "direct-global" ]] || [[ "$source_type" == "direct-local" ]]; then
    # Source type
    echo -e "${COLOR_CYAN}Source Type${COLOR_RESET}"
    if [[ "$source_type" == "direct-global" ]]; then
        echo -e "  ${COLOR_YELLOW}Direct (global)${COLOR_RESET}"
    else
        echo -e "  ${COLOR_YELLOW}Direct (local)${COLOR_RESET}"
    fi
    echo ""

    # Definition source
    echo -e "${COLOR_CYAN}Definition${COLOR_RESET}"
    echo -e "  Scope: $def_scope"
    echo -e "  File:  $def_file"
    echo ""

    # Status and control method
    echo -e "${COLOR_CYAN}Status & Control${COLOR_RESET}"
    if [[ "$current_state" == "off" ]]; then
        echo -e "  ${COLOR_RED}Disabled${COLOR_RESET} (quick-disable)"
        echo -e "  • Disabled via ${COLOR_CYAN}~/.claude.json${COLOR_RESET}"
        echo -e "  • Location: ${COLOR_CYAN}.projects[cwd].disabledMcpServers${COLOR_RESET}"
        echo -e "  • Definition remains global"
        echo ""
        echo -e "Press ${COLOR_CYAN}SPACE${COLOR_RESET} to re-enable"
        echo -e "Press ${COLOR_CYAN}ALT-M${COLOR_RESET} to migrate to project"
    else
        echo -e "  ${COLOR_GREEN}Enabled${COLOR_RESET}"
        echo -e "  • Definition in: ${COLOR_CYAN}$def_file${COLOR_RESET}"
        echo ""
        echo -e "Press ${COLOR_CYAN}SPACE${COLOR_RESET} to quick-disable"
        echo -e "Press ${COLOR_CYAN}ALT-M${COLOR_RESET} to migrate to project"
    fi

    echo ""
    echo "$preview_line"
    echo -e "${COLOR_WHITE}Quick Disable${COLOR_RESET} - Fast, modifies ~/.claude.json .projects[cwd]"
    echo -e "${COLOR_WHITE}Migration (ALT-M)${COLOR_RESET} - Full ownership, project-local"
    return
fi
```

### Task 4.3: Update Header with ALT-M Keybinding

**Location**: Around line 1394-1400

**Update to**:
```bash
printf -v header "%b" "${shortcuts_line}
${COLOR_WHITE}Shortcuts:${COLOR_RESET}
${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}[SPACE]${COLOR_RESET}     Toggle       ${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_WHITE}[ENTER]${COLOR_RESET} Save & Exit
${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}[ALT-M]${COLOR_RESET}     Migrate      ${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_WHITE}[CTRL-A]${COLOR_RESET} Add Server
${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}[CTRL-X]${COLOR_RESET}    Remove       ${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_WHITE}[ALT-E]${COLOR_RESET} Enable All
${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}[ALT-D]${COLOR_RESET}     Disable All  ${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_WHITE}[ESC]${COLOR_RESET} Cancel
${shortcuts_line}"
```

---

## Plugin Support (Phase 5 - Optional)

**Note**: Plugin support is NOT critical for Direct server control. Can be implemented later.

**If Adding Plugins**:
1. Add `discover_marketplace_plugins()` function
2. Add `parse_plugin_state()` function
3. Update state file format to 6 fields: `state:server:scope:file:source_type:marketplace`
4. Add SHIFT-SPACE keybinding for hard-disable
5. Update `save_state_to_settings()` to write `enabledPlugins` object

**See `IMPLEMENTATION_PLAN_V2.md` Phase 5 for detailed code.**

---

## Testing Checklist

After implementing Phases 2-4:

- [ ] Direct-Global server toggle (SPACE) - writes to `.projects[cwd].disabledMcpServers`
- [ ] Direct-Local server toggle (SPACE) - writes to `.projects[cwd].disabledMcpServers`
- [ ] Direct server migration (ALT-M) - moves to `./.mcp.json`
- [ ] MCPJSON server toggle (existing) - still works
- [ ] Mixed servers in same session (Direct + MCPJSON)
- [ ] Backup created before modifying `~/.claude.json`
- [ ] JSON validation catches errors
- [ ] State persists across tool invocations
- [ ] Preview shows correct control method
- [ ] Verify with `claude mcp list` (won't show disabled Direct servers in UI)

---

## Key Files & Line Numbers

**Main Script** (`mcp`):
- Line 345-354: Parse `disabledMcpServers` (✅ Complete)
- Line 898-969: `toggle_server()` function (needs update)
- Line 1041-1098: `save_state_to_settings()` function (needs update)
- Line 1099+: NEW `write_direct_servers_to_claude_json()` function (needs adding)
- Line 1104-1135: `generate_fzf_list()` (needs update)
- Line 1137-1272: `generate_preview()` (needs update)
- Line 1331+: NEW `migrate_direct_server_flow()` function (needs adding)
- Line 1417-1423: fzf keybindings (needs ALT-M)
- Line 1394-1400: Header shortcuts (needs update)

**Documentation**:
- `.claude/CLAUDE.md` - ✅ Complete (architecture documented)
- `MCP_CONTROL_TESTING_REPORT.md` - ✅ Complete (test evidence)
- `IMPLEMENTATION_PLAN_V2.md` - Reference for detailed code examples
- `README.md` - Needs update after implementation

---

## Critical Reminders

1. **Location Restrictions Matter**
   - `disabledMcpServers` ONLY in `~/.claude.json`
   - `disabledMcpjsonServers` ONLY in settings files
   - Don't mix them up!

2. **Two-File Write Strategy**
   - `./.claude/settings.local.json` for MCPJSON
   - `~/.claude.json` `.projects[cwd]` for Direct servers
   - Both atomic with backups

3. **Migration Still Valuable**
   - Quick-disable: Fast, keeps definition global
   - Migration: Full ownership, project-local
   - User chooses based on needs

4. **State Format** (current):
   ```
   state:server:scope:file:source_type
   ```
   No changes needed for Direct server support.

5. **Direct Servers Are Now Controllable**
   - Not "always-on" anymore
   - Update UI indicators from `[⚠]` to `[ON]`/`[OFF]`
   - Preview explains control method

---

## Success Criteria

✅ **Phase 1 Complete**
- Parsing works for `disabledMcpServers`
- Documentation updated
- Testing complete

🎯 **Phase 2-4 Success** (Next to implement):
- Direct servers toggle on/off via SPACE
- Changes write to `.projects[cwd].disabledMcpServers`
- Migration available via ALT-M
- UI shows correct indicators and control methods
- No regression on MCPJSON server control

---

## Quick Start for Next Session

1. **Review this document** - All decisions and learnings captured here
2. **Start with Phase 2, Task 2.1** - Add `write_direct_servers_to_claude_json()` function
3. **Follow code examples exactly** - Line numbers and code provided
4. **Test after each phase** - Use checklist above
5. **Commit after each phase** - Keep changes atomic

**Branch**: `feature/native-disable-arrays-support`
**Last Commit**: ae60a06 - feat: add disabledMcpServers support and testing

Ready to continue! 🚀
