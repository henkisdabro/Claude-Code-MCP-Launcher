# Implementation Plan V2: Complete MCP Server Control

**Status**: Active development on branch `feature/native-disable-arrays-support`

## Revised Architecture (Post-Testing)

### Control Mechanisms by Server Type

| Server Type | Control Array | Write Location | Behavior |
|------------|---------------|----------------|----------|
| **MCPJSON** | `disabledMcpjsonServers` | `./.claude/settings.local.json` | ✅ Working |
| **Direct-Global** | `disabledMcpServers` | `~/.claude.json` `.projects[cwd]` | ✅ Working |
| **Direct-Local** | `disabledMcpServers` | `~/.claude.json` `.projects[cwd]` | ✅ Working |
| **Plugin** | `enabledPlugins` | `./.claude/settings.local.json` | ✅ Working (with UI caveat) |

### Key Discoveries

1. **`disabledMcpServers` WORKS but location-restricted**:
   - ✅ Can disable Direct servers
   - ✅ ONLY in `~/.claude.json` (root or `.projects[cwd]`)
   - ❌ CANNOT be in settings files

2. **Direct server control WITHOUT migration**:
   - Write to `.projects[cwd].disabledMcpServers`
   - Project-specific, doesn't affect other projects
   - Server definition stays global

3. **Plugin UI disappearance confirmed**:
   - Setting `enabledPlugins[plugin] = false` hides from UI
   - Omit strategy needed for soft-disable

## Implementation Approach

### Multi-File Write Strategy

**File 1: `./.claude/settings.local.json`** (MCPJSON + Plugins)
```json
{
  "disabledMcpjsonServers": ["mcpjson-server"],
  "enabledPlugins": {
    "plugin@marketplace": true
    // omitted plugins = soft disabled
  },
  "enableAllProjectMcpServers": true
}
```

**File 2: `~/.claude.json`** (Direct servers ONLY)
```json
{
  "projects": {
    "/current/project/path": {
      "disabledMcpServers": ["direct-server"]
    }
  }
}
```

### Direct Server Toggle Options

**Option A: Quick Disable** (Default)
- Press `SPACE` on Direct server
- Tool writes to `~/.claude.json` `.projects[cwd].disabledMcpServers`
- Automatic backup created
- Quick, single-step

**Option B: Migration** (Alternative)
- Press `ALT-M` on Direct server (or choose from menu)
- Move definition to `./.mcp.json`
- Control via `./.claude/settings.local.json`
- Full project ownership

## Implementation Tasks

### Phase 1: Core Parsing Updates

#### Task 1.1: Update parse_claude_json_file() (mcp:292-344)

Add parsing for `disabledMcpServers` from `.projects[cwd]`:

```bash
parse_claude_json_file() {
  local file="$1"
  local cwd=$(pwd)

  # ... existing code for server definitions ...

  # NEW: Parse disabledMcpServers from .projects[cwd]
  local disabled
  disabled=$(jq -r --arg cwd "$cwd" '.projects[$cwd].disabledMcpServers[]? // empty' "$file" 2>/dev/null | sort -u)

  if [[ -n "$disabled" ]]; then
    while IFS= read -r server; do
      [[ -n "$server" ]] && echo "disable:$server:local:$file"
    done <<< "$disabled"
  fi
}
```

#### Task 1.2: Add marketplace plugin discovery

```bash
# NEW FUNCTION: After parse_claude_json_file()
discover_marketplace_plugins() {
  local marketplace_dir="$HOME/.claude/plugins/marketplaces"

  [[ ! -d "$marketplace_dir" ]] && return 0

  find "$marketplace_dir" -type f -name "marketplace.json" 2>/dev/null | while read -r file; do
    local marketplace=$(basename "$(dirname "$(dirname "$file")")")

    jq -r '.mcpServers | keys[]? // empty' "$file" 2>/dev/null | while IFS= read -r server; do
      [[ -n "$server" ]] && echo "def:$server:user:$file:plugin:$marketplace"
    done
  done
}
```

#### Task 1.3: Add plugin state parsing

```bash
# NEW FUNCTION
parse_plugin_state() {
  local file="$1"
  local scope="$2"

  [[ ! -f "$file" ]] && return 0

  jq -r '.enabledPlugins | to_entries[]? | "\(.key):\(.value)"' "$file" 2>/dev/null | \
  while IFS=: read -r plugin enabled; do
    if [[ "$enabled" == "true" ]]; then
      echo "enable:$plugin:$scope:$file"
    elif [[ "$enabled" == "false" ]]; then
      echo "disable-hard:$plugin:$scope:$file"
    fi
  done
}
```

#### Task 1.4: Update discover_and_parse_all_sources()

```bash
discover_and_parse_all_sources() {
  local temp_raw=$(mktemp)

  # Existing parsers
  parse_claude_json_file "$HOME/.claude.json" >> "$temp_raw"
  parse_mcp_json_file "$HOME/.mcp.json" "user" >> "$temp_raw"
  parse_mcp_json_file "./.mcp.json" "project" >> "$temp_raw"

  # NEW: Plugin discovery
  discover_marketplace_plugins >> "$temp_raw"

  # Existing settings parsers
  parse_settings_file "$HOME/.claude/settings.json" "user" >> "$temp_raw"
  # ... others ...

  # NEW: Plugin state parsing
  parse_plugin_state "$HOME/.claude/settings.json" "user" >> "$temp_raw"
  parse_plugin_state "./.claude/settings.local.json" "local" >> "$temp_raw"
  # ... others ...

  cat "$temp_raw"
  rm -f "$temp_raw"
}
```

### Phase 2: Write Logic Updates

#### Task 2.1: Create write function for Direct servers

```bash
# NEW FUNCTION
write_direct_servers_to_claude_json() {
  local -a disabled_direct=("$@")
  local target="$HOME/.claude.json"
  local cwd=$(pwd)

  # Create backup
  local backup="$target.backup.$(date +%Y%m%d_%H%M%S)"
  cp "$target" "$backup" || return 1

  # Build disabled array JSON
  local disabled_json=$(printf '%s\n' "${disabled_direct[@]}" | jq -R . | jq -s -c . || echo '[]')

  # Atomic update to .projects[cwd].disabledMcpServers
  local temp_file=$(mktemp)

  jq --arg cwd "$cwd" --argjson disabled "$disabled_json" \
     '.projects[$cwd].disabledMcpServers = $disabled' \
     "$target" > "$temp_file"

  # Validate
  if ! jq empty "$temp_file" 2>/dev/null; then
    msg_error "JSON validation failed, rolling back"
    rm "$temp_file"
    return 1
  fi

  mv "$temp_file" "$target"
  msg_success "Updated $target (.projects[cwd].disabledMcpServers)"
}
```

#### Task 2.2: Update save_state_to_settings()

```bash
save_state_to_settings() {
  local target="./.claude/settings.local.json"

  # Parse state file into categories
  local enabled_mcpjson=()
  local disabled_mcpjson=()
  local disabled_direct=()
  local plugin_states=()

  while IFS=: read -r state server scope file source_type marketplace; do
    [[ -z "$server" ]] && continue

    case "$source_type" in
      mcpjson)
        [[ "$state" == "on" ]] && enabled_mcpjson+=("$server")
        [[ "$state" == "off" ]] && disabled_mcpjson+=("$server")
        ;;
      direct-*)
        [[ "$state" == "off" ]] && disabled_direct+=("$server")
        ;;
      plugin)
        if [[ "$state" == "on" ]]; then
          plugin_states+=("$server:true")
        elif [[ "$state" == "hard-off" ]]; then
          plugin_states+=("$server:false")
        fi
        # soft-off: omit from array
        ;;
    esac
  done < "$STATE_FILE"

  # Write to local settings (MCPJSON + Plugins)
  mkdir -p "./.claude"
  [[ ! -f "$target" ]] && echo '{}' > "$target"

  local enabled_json=$(printf '%s\n' "${enabled_mcpjson[@]}" | jq -R . | jq -s -c . || echo '[]')
  local disabled_json=$(printf '%s\n' "${disabled_mcpjson[@]}" | jq -R . | jq -s -c . || echo '[]')

  # Build plugins object
  local plugins_json="{}"
  for entry in "${plugin_states[@]}"; do
    local name="${entry%:*}"
    local val="${entry#*:}"
    plugins_json=$(echo "$plugins_json" | jq --arg n "$name" --argjson v "$val" '.[$n] = $v')
  done

  local temp_file=$(mktemp)
  jq --argjson enabled "$enabled_json" \
     --argjson disabled "$disabled_json" \
     --argjson plugins "$plugins_json" \
     '.enabledMcpjsonServers = $enabled |
      .disabledMcpjsonServers = $disabled |
      .enabledPlugins = $plugins |
      .enableAllProjectMcpServers = true' \
     "$target" > "$temp_file"

  mv "$temp_file" "$target"

  # Write Direct servers to ~/.claude.json
  if [[ ${#disabled_direct[@]} -gt 0 ]]; then
    write_direct_servers_to_claude_json "${disabled_direct[@]}"
  fi
}
```

### Phase 3: Toggle Logic Updates

#### Task 3.1: Update toggle_server() for Direct servers

```bash
toggle_server() {
  local raw_input="$1"
  local server=$(extract_clean_server_name "$raw_input")
  local source_type=$(get_server_source_type "$server")

  # Direct servers: Quick disable (Option A)
  if [[ "$source_type" == "direct-global" ]] || [[ "$source_type" == "direct-local" ]]; then
    toggle_direct_server "$server"
    return
  fi

  # Plugin servers
  if [[ "$source_type" == "plugin" ]]; then
    toggle_plugin_server "$server"  # soft-disable by default
    return
  fi

  # MCPJSON servers (existing logic)
  toggle_mcpjson_server "$server"
}

# NEW FUNCTION
toggle_direct_server() {
  local server="$1"
  local temp_state=$(mktemp)

  while IFS=: read -r state srv scope file stype marketplace; do
    if [[ "$srv" == "$server" ]]; then
      if [[ "$state" == "on" ]]; then
        echo "off:$srv:$scope:$file:$stype:$marketplace" >> "$temp_state"
      else
        echo "on:$srv:$scope:$file:$stype:$marketplace" >> "$temp_state"
      fi
    else
      echo "$state:$srv:$scope:$file:$stype:$marketplace" >> "$temp_state"
    fi
  done < "$STATE_FILE"

  mv "$temp_state" "$STATE_FILE"
}

# NEW FUNCTION
toggle_plugin_server() {
  local server="$1"
  local temp_state=$(mktemp)

  while IFS=: read -r state srv scope file stype marketplace; do
    if [[ "$srv" == "$server" ]]; then
      case "$state" in
        on) echo "soft-off:$srv:$scope:$file:$stype:$marketplace" >> "$temp_state" ;;
        soft-off) echo "on:$srv:$scope:$file:$stype:$marketplace" >> "$temp_state" ;;
        hard-off) echo "on:$srv:$scope:$file:$stype:$marketplace" >> "$temp_state" ;;
      esac
    else
      echo "$state:$srv:$scope:$file:$stype:$marketplace" >> "$temp_state"
    fi
  done < "$STATE_FILE"

  mv "$temp_state" "$STATE_FILE"
}
```

#### Task 3.2: Add migration keybinding (ALT-M)

```bash
# In launch_fzf_tui(), add keybinding
--bind="alt-m:execute(migrate_server_flow {})+reload(generate_fzf_list)+refresh-preview"

# NEW FUNCTION
migrate_server_flow() {
  local raw_input="$1"
  local server=$(extract_clean_server_name "$raw_input")
  local source_type=$(get_server_source_type "$server")

  # Only offer migration for direct servers
  if [[ "$source_type" != "direct-global" ]] && [[ "$source_type" != "direct-local" ]]; then
    return 0
  fi

  # Existing migration prompt and logic
  if prompt_for_migration "$server" "$source_type" "..."; then
    migrate_server_to_project_mcpjson "$server"
  fi
}
```

### Phase 4: UI Updates

#### Task 4.1: Update generate_fzf_list()

```bash
generate_fzf_list() {
  local dim='\033[2m'

  while IFS=: read -r state server scope file source_type marketplace; do
    [[ -z "$server" ]] && continue

    case "$source_type" in
      plugin)
        if [[ "$state" == "on" ]]; then
          echo -e "${COLOR_GREEN}[ON ]${COLOR_RESET} $server ${dim}($scope, plugin:$marketplace)${COLOR_RESET}"
        elif [[ "$state" == "soft-off" ]]; then
          echo -e "${COLOR_YELLOW}[~  ]${COLOR_RESET} $server ${dim}($scope, soft-disabled)${COLOR_RESET}"
        elif [[ "$state" == "hard-off" ]]; then
          echo -e "${COLOR_RED}[OFF]${COLOR_RESET} $server ${dim}($scope, hard-disabled)${COLOR_RESET}"
        fi
        ;;

      direct-*)
        if [[ "$state" == "on" ]]; then
          echo -e "${COLOR_GREEN}[ON ]${COLOR_RESET} $server ${dim}($scope, $source_type)${COLOR_RESET}"
        else
          echo -e "${COLOR_RED}[OFF]${COLOR_RESET} $server ${dim}($scope, $source_type)${COLOR_RESET}"
        fi
        ;;

      mcpjson)
        # Existing logic
        ;;
    esac
  done < "$STATE_FILE"
}
```

#### Task 4.2: Update preview for Direct servers

```bash
generate_preview() {
  # ... existing code ...

  if [[ "$source_type" == "direct-global" ]] || [[ "$source_type" == "direct-local" ]]; then
    echo -e "${COLOR_CYAN}Control Method${COLOR_RESET}"

    if [[ "$current_state" == "off" ]]; then
      echo -e "  ${COLOR_YELLOW}Quick Disabled${COLOR_RESET}"
      echo -e "  • Disabled via ${COLOR_CYAN}~/.claude.json${COLOR_RESET}"
      echo -e "  • Location: ${COLOR_CYAN}.projects[cwd].disabledMcpServers${COLOR_RESET}"
      echo -e "  • Definition remains global"
      echo ""
      echo -e "Press ${COLOR_CYAN}SPACE${COLOR_RESET} to re-enable"
      echo -e "Press ${COLOR_CYAN}ALT-M${COLOR_RESET} to migrate to project"
    else
      echo -e "  ${COLOR_GREEN}Enabled${COLOR_RESET} (global definition)"
      echo -e "  • Defined in: ${COLOR_CYAN}$def_file${COLOR_RESET}"
      echo ""
      echo -e "Press ${COLOR_CYAN}SPACE${COLOR_RESET} to quick-disable"
      echo -e "Press ${COLOR_CYAN}ALT-M${COLOR_RESET} to migrate to project"
    fi

    echo ""
    echo "$preview_line"
    echo -e "${COLOR_WHITE}Quick Disable${COLOR_RESET} - Fast, modifies global file"
    echo -e "${COLOR_WHITE}Migration${COLOR_RESET} - Full ownership, project-local"
    return
  fi

  # ... existing code for other types ...
}
```

#### Task 4.3: Update header with keybinding info

```bash
printf -v header "%b" "${shortcuts_line}
${COLOR_WHITE}Shortcuts:${COLOR_RESET}
${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}[SPACE]${COLOR_RESET}     Toggle       ${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_WHITE}[ENTER]${COLOR_RESET} Save & Exit
${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}[ALT-M]${COLOR_RESET}     Migrate      ${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_WHITE}[SHIFT-SPACE]${COLOR_RESET} Hard-disable plugin
${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}[CTRL-A]${COLOR_RESET}    Add Server   ${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_WHITE}[CTRL-X]${COLOR_RESET} Remove Server
${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}[ALT-E]${COLOR_RESET}     Enable All   ${COLOR_CYAN}│${COLOR_RESET}  ${COLOR_WHITE}[ALT-D]${COLOR_RESET} Disable All
${COLOR_CYAN}│${COLOR_RESET} ${COLOR_WHITE}[ESC]${COLOR_RESET}       Cancel
${shortcuts_line}"
```

### Phase 5: State File Updates

Update state file format to support 6 fields:

```
on:fetch:project:./.mcp.json:mcpjson:
off:time:user:~/.claude.json:direct-global:
soft-off:mcp-time:user:~/.../marketplace.json:plugin:claudecode-marketplace
```

Format: `state:server:scope:file:source_type:marketplace`

## Testing Checklist

- [ ] MCPJSON toggle (existing functionality)
- [ ] Direct server quick-disable (writes to .projects[cwd])
- [ ] Direct server migration (Option B)
- [ ] Plugin soft-disable (omit from enabledPlugins)
- [ ] Plugin hard-disable (Shift+Space, set to false)
- [ ] Mixed server types in single session
- [ ] Backup/restore for ~/.claude.json modifications
- [ ] Precedence: project settings override user settings
- [ ] State persistence across tool invocations
- [ ] Edge case: Empty .projects[cwd] section

## Success Criteria

- ✅ All 4 server types controllable
- ✅ Direct servers: Quick-disable as default
- ✅ Direct servers: Migration as alternative (ALT-M)
- ✅ Plugins: Soft-disable by default (omit strategy)
- ✅ Plugins: Hard-disable available (Shift+Space)
- ✅ Clear UI indicating control method
- ✅ Atomic updates with backups
- ✅ No regression on existing features
- ✅ Documentation updated

## Files to Modify

1. **`mcp`** (main script) - ~300 lines of changes
   - parse_claude_json_file() - Add disabledMcpServers parsing
   - discover_marketplace_plugins() - NEW
   - parse_plugin_state() - NEW
   - discover_and_parse_all_sources() - Update
   - write_direct_servers_to_claude_json() - NEW
   - save_state_to_settings() - Update (multi-file)
   - toggle_server() - Update (route to correct handler)
   - toggle_direct_server() - NEW
   - toggle_plugin_server() - NEW
   - migrate_server_flow() - NEW
   - generate_fzf_list() - Update (4 server types)
   - generate_preview() - Update (show control methods)
   - launch_fzf_tui() - Add keybindings

2. **`.claude/CLAUDE.md`** - ✅ Already updated

3. **`README.md`** - Update with new control methods

## Timeline

- Phase 1 (Parsing): 2-3 hours
- Phase 2 (Write logic): 2-3 hours
- Phase 3 (Toggle logic): 1-2 hours
- Phase 4 (UI): 2-3 hours
- Phase 5 (Testing): 2-3 hours
- **Total**: 9-14 hours over 2-3 days
