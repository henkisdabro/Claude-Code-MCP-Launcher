# Implementation Plan: Plugin & Native Array Support

## Executive Summary

Based on comprehensive testing (see `MCP_CONTROL_TESTING_REPORT.md`), we're adding support for:
1. **Marketplace Plugin Servers** (4th server type)
2. **`enableAllProjectMcpServers` flag** (master switch for MCPJSON servers)
3. **Smart plugin disable strategy** (omit vs hard-disable)

**NOT implementing:**
- `disabledMcpServers` / `enabledMcpServers` arrays (tested as non-functional)
- Direct server control via arrays (migration remains the only option)

## Key Findings from Testing

### What Works
✅ `enabledMcpjsonServers` / `disabledMcpjsonServers` - Controls .mcp.json servers
✅ `enabledPlugins` - Controls marketplace plugins (in `.claude/settings*.json` only)
✅ `enableAllProjectMcpServers` - Master switch for .mcp.json servers

### What Doesn't Work
❌ `disabledMcpServers` / `enabledMcpServers` (without "json") - Zero effect on any server type
❌ Direct server control - Still always enabled, migration required

### Critical Issue
⚠️ **Plugin UI Disappearance**: Setting `enabledPlugins[plugin] = false` makes plugin completely disappear from Claude UI
- User cannot re-enable without editing config files
- Our tool needs smart handling to avoid this UX trap

## Design Decisions

### 1. Plugin Control Approach

**Default Behavior: "Soft Disable" (Omit Strategy)**
- When user toggles plugin OFF, we OMIT it from `enabledPlugins`
- Plugin remains visible in Claude UI
- Lower-priority configs may still enable it (precedence issue)
- **Trade-off**: Less predictable, but preserves UI access

**Optional: "Hard Disable" (Set to False)**
- Accessible via special keybinding (Shift+Space)
- Sets `enabledPlugins[plugin] = false`
- Plugin completely disappears from UI
- **Trade-off**: Guaranteed disabled, but lost UI access

**UI Communication**:
- Preview shows "Soft disabled (can be re-enabled in Claude UI)"
- Preview shows "Hard disabled (hidden from UI)" when Shift+Space used
- Clear warnings about consequences

### 2. Server Type Handling

**Updated Server Types** (from 3 to 4):

| Type | Source | Control Mechanism | UI Indicator |
|------|--------|------------------|--------------|
| MCPJSON | `.mcp.json` files | `disabledMcpjsonServers` | `[ON]` / `[OFF]` green/red |
| Direct-Global | `~/.claude.json` root | Migration only | `[⚠]` yellow "always-on" |
| Direct-Local | `~/.claude.json` projects | Migration only | `[⚠]` yellow "always-on" |
| Plugin | Marketplace | `enabledPlugins` (omit strategy) | `[ON]` / `[OFF]` with badge |

**State File Format Update**:
```
# Current format
on:fetch:project:./.mcp.json:mcpjson

# New format for plugins
on:mcp-time:user:~/.claude/plugins/.../marketplace.json:plugin:claudecode-marketplace
soft-off:mcp-fetch:user:~/.claude/plugins/.../marketplace.json:plugin:claudecode-marketplace
hard-off:mcp-serena:user:~/.claude/plugins/.../marketplace.json:plugin:claudecode-marketplace
```

**State Values**:
- `on` - Enabled
- `off` - Disabled (MCPJSON servers only)
- `soft-off` - Plugin omitted from enabledPlugins (soft disable)
- `hard-off` - Plugin set to false in enabledPlugins (hard disable)

### 3. Write Strategy

**Current (MCPJSON only)**:
```json
{
  "enabledMcpjsonServers": [...],
  "disabledMcpjsonServers": [...]
}
```

**New (MCPJSON + Plugins + Master Switch)**:
```json
{
  "enabledMcpjsonServers": [...],
  "disabledMcpjsonServers": [...],
  "enableAllProjectMcpServers": true,
  "enabledPlugins": {
    "mcp-time@claudecode-marketplace": true,
    // mcp-fetch omitted (soft disabled)
    "mcp-serena@claudecode-marketplace": false  // hard disabled (if user chose)
  }
}
```

**Writing Location**: Remains `./.claude/settings.local.json` (no change to core principle)

## Implementation Tasks

### Phase 1: Plugin Discovery & Parsing (mcp:445-479)

**Add marketplace plugin discovery**:
```bash
# New function: discover_marketplace_plugins()
# Location: After parse_claude_json_file()
# Output format: def:server:user:file:plugin:marketplace-name

discover_marketplace_plugins() {
  local marketplace_dir="$HOME/.claude/plugins/marketplaces"

  if [[ ! -d "$marketplace_dir" ]]; then
    return 0
  fi

  # Find all marketplace.json files
  find "$marketplace_dir" -type f -name "marketplace.json" 2>/dev/null | while read -r file; do
    # Extract marketplace name from path
    local marketplace_name=$(basename "$(dirname "$(dirname "$file")")")

    # Parse mcpServers from marketplace.json
    local servers
    servers=$(jq -r '.mcpServers | keys[]? // empty' "$file" 2>/dev/null)

    if [[ -n "$servers" ]]; then
      while IFS= read -r server; do
        [[ -n "$server" ]] && echo "def:$server:user:$file:plugin:$marketplace_name"
      done <<< "$servers"
    fi
  done
}
```

**Update discover_and_parse_all_sources()**:
```bash
# Add after parse_mcp_json_file() calls
discover_marketplace_plugins >> "$temp_raw"
```

**Add plugin state parsing**:
```bash
# New function: parse_plugin_state()
# Parse enabledPlugins from settings files

parse_plugin_state() {
  local file="$1"
  local scope="$2"

  if [[ ! -f "$file" ]] || ! jq empty "$file" 2>/dev/null; then
    return 0
  fi

  # Extract enabledPlugins object
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

### Phase 2: State Tracking Updates (mcp:486-589)

**Update load_servers()** to handle plugin type:
```bash
# In the parsing loop, add handling for "plugin" source_type
if [[ "$type" == "def" ]]; then
  # ... existing code ...

  # NEW: Track if this is a plugin server
  if [[ "$source_type" == "plugin" ]]; then
    # Store marketplace name separately for plugin servers
    plugin_marketplace[$server]="$marketplace"  # 6th field from discover output
  fi
fi

# NEW: Handle hard-disable for plugins
elif [[ "$type" == "disable-hard" ]]; then
  local new_value="$priority:hard-off"
  # ... same precedence logic ...
fi
```

**Update state file writing**:
```bash
# When writing merged state, preserve soft/hard disable for plugins
for server in "${!server_definitions[@]}"; do
  # ... existing extraction ...

  local state="on"
  if [[ -n "${server_states[$server]:-}" ]]; then
    local state_value="${server_states[$server]}"
    state=$(echo "$state_value" | cut -d: -f2)  # Can be: on, off, hard-off
  fi

  # For plugins with no explicit state, check for soft-off
  if [[ "$source_type" == "plugin" ]] && [[ "$state" == "off" ]]; then
    # Default to soft-off for plugins (omit strategy)
    state="soft-off"
  fi

  echo "$state:$server:$def_scope:$def_file:$source_type" >> "$STATE_FILE"
done
```

### Phase 3: Toggle Logic Updates (mcp:898-969)

**Update toggle_server()** to handle plugins:
```bash
toggle_server() {
  local raw_input="$1"
  local server=$(extract_clean_server_name "$raw_input")

  # Get source type
  local source_type=$(get_server_source_type "$server")

  # Handle direct servers (existing migration flow)
  if [[ "$source_type" == "direct-global" ]] || [[ "$source_type" == "direct-local" ]]; then
    # ... existing migration prompt ...
    return
  fi

  # NEW: Handle plugin servers
  if [[ "$source_type" == "plugin" ]]; then
    toggle_plugin_server "$server"
    return
  fi

  # Existing: Handle MCPJSON servers
  toggle_mcpjson_server "$server"
}

# NEW FUNCTION
toggle_plugin_server() {
  local server="$1"
  local temp_state=$(mktemp)

  while IFS=: read -r state srv scope file stype; do
    if [[ "$srv" == "$server" ]]; then
      # Toggle: on -> soft-off -> on
      if [[ "$state" == "on" ]]; then
        echo "soft-off:$srv:$scope:$file:$stype" >> "$temp_state"
      elif [[ "$state" == "soft-off" ]]; then
        echo "on:$srv:$scope:$file:$stype" >> "$temp_state"
      elif [[ "$state" == "hard-off" ]]; then
        # Hard-off requires explicit re-enable
        echo "on:$srv:$scope:$file:$stype" >> "$temp_state"
      fi
    else
      echo "$state:$srv:$scope:$file:$stype" >> "$temp_state"
    fi
  done < "$STATE_FILE"

  mv "$temp_state" "$STATE_FILE"
}

# NEW FUNCTION (for Shift+Space keybinding)
hard_disable_plugin() {
  local server="$1"
  local temp_state=$(mktemp)

  while IFS=: read -r state srv scope file stype; do
    if [[ "$srv" == "$server" ]] && [[ "$stype" == "plugin" ]]; then
      echo "hard-off:$srv:$scope:$file:$stype" >> "$temp_state"
    else
      echo "$state:$srv:$scope:$file:$stype" >> "$temp_state"
    fi
  done < "$STATE_FILE"

  mv "$temp_state" "$STATE_FILE"
}
```

### Phase 4: Write Logic Updates (mcp:1041-1098)

**Update save_state_to_settings()** to handle plugins and master switch:
```bash
save_state_to_settings() {
  local target="./.claude/settings.local.json"

  # Create directory if needed
  mkdir -p "./.claude"

  # Parse state file into three categories
  local enabled_mcpjson=()
  local disabled_mcpjson=()
  local plugin_states=()  # Format: "plugin-name:true/false"

  while IFS=: read -r state server scope file source_type; do
    [[ -z "$server" ]] && continue

    if [[ "$source_type" == "plugin" ]]; then
      if [[ "$state" == "on" ]]; then
        plugin_states+=("$server:true")
      elif [[ "$state" == "hard-off" ]]; then
        plugin_states+=("$server:false")
      fi
      # soft-off: omit from array

    elif [[ "$source_type" == "mcpjson" ]]; then
      if [[ "$state" == "on" ]]; then
        enabled_mcpjson+=("$server")
      elif [[ "$state" == "off" ]]; then
        disabled_mcpjson+=("$server")
      fi
    fi
  done < "$STATE_FILE"

  # Build JSON arrays
  local enabled_json=$(printf '%s\n' "${enabled_mcpjson[@]}" | jq -R . | jq -s -c . || echo '[]')
  local disabled_json=$(printf '%s\n' "${disabled_mcpjson[@]}" | jq -R . | jq -s -c . || echo '[]')

  # Build enabledPlugins object
  local plugins_json="{}"
  for entry in "${plugin_states[@]}"; do
    local plugin_name="${entry%:*}"
    local plugin_value="${entry#*:}"
    plugins_json=$(echo "$plugins_json" | jq --arg name "$plugin_name" --argjson val "$plugin_value" '.[$name] = $val')
  done

  # Initialize target file
  [[ ! -f "$target" ]] && echo '{}' > "$target"

  # Atomic update
  local temp_file=$(mktemp)

  jq --argjson enabled "$enabled_json" \
     --argjson disabled "$disabled_json" \
     --argjson plugins "$plugins_json" \
     '
     .enabledMcpjsonServers = $enabled |
     .disabledMcpjsonServers = $disabled |
     .enabledPlugins = $plugins |
     .enableAllProjectMcpServers = true
     ' \
     "$target" > "$temp_file"

  mv "$temp_file" "$target"
}
```

### Phase 5: UI Updates (mcp:1104-1469)

**Update generate_fzf_list()** to show plugin servers:
```bash
generate_fzf_list() {
  # ... existing code ...

  while IFS=: read -r state server scope file source_type; do
    [[ -z "$server" ]] && continue

    # Plugin servers
    if [[ "$source_type" == "plugin" ]]; then
      local marketplace=$(get_plugin_marketplace "$server")

      if [[ "$state" == "on" ]]; then
        echo -e "${COLOR_GREEN}[ON ]${COLOR_RESET} $server ${dim}($scope, plugin:$marketplace)${COLOR_RESET}"
      elif [[ "$state" == "soft-off" ]]; then
        echo -e "${COLOR_YELLOW}[~  ]${COLOR_RESET} $server ${dim}($scope, soft-disabled)${COLOR_RESET}"
      elif [[ "$state" == "hard-off" ]]; then
        echo -e "${COLOR_RED}[OFF]${COLOR_RESET} $server ${dim}($scope, hard-disabled)${COLOR_RESET}"
      fi
      continue
    fi

    # ... existing MCPJSON and Direct server handling ...
  done < "$STATE_FILE"
}
```

**Update keybindings** in launch_fzf_tui():
```bash
# Add Shift+Space for hard-disable (plugins only)
--bind="shift-space:execute(hard_disable_plugin_if_applicable {})+reload(generate_fzf_list)+refresh-preview"
```

**Update generate_preview()** to show plugin warnings:
```bash
generate_preview() {
  # ... existing extraction ...

  if [[ "$source_type" == "plugin" ]]; then
    echo -e "${COLOR_CYAN}Source Type${COLOR_RESET}"
    echo -e "  ${COLOR_BLUE}Marketplace Plugin${COLOR_RESET}"
    echo ""

    if [[ "$current_state" == "soft-off" ]]; then
      echo -e "${COLOR_YELLOW}Status: Soft Disabled${COLOR_RESET}"
      echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} Still visible in Claude UI"
      echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} Can be re-enabled in UI"
      echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} Lower-priority configs may enable it"
      echo ""
      echo -e "Press ${COLOR_CYAN}SHIFT+SPACE${COLOR_RESET} for hard disable"

    elif [[ "$current_state" == "hard-off" ]]; then
      echo -e "${COLOR_RED}Status: Hard Disabled${COLOR_RESET}"
      echo -e "  ${COLOR_RED}✗${COLOR_RESET} Hidden from Claude UI"
      echo -e "  ${COLOR_RED}✗${COLOR_RESET} Cannot re-enable in UI"
      echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} Completely disabled"
      echo ""
      echo -e "Press ${COLOR_CYAN}SPACE${COLOR_RESET} to re-enable"
    fi

    return
  fi

  # ... existing code for other server types ...
}
```

**Update header** to show plugin info:
```bash
# Add plugin count to header
local plugin_count=0
plugin_count=$(grep -c ':plugin:' "$STATE_FILE" 2>/dev/null || true)

echo -e "${COLOR_WHITE}Total: ${COLOR_RESET}${total_count}  ${COLOR_WHITE}│${COLOR_RESET}  ${COLOR_GREEN}Enabled: ${COLOR_RESET}${enabled_count}  ${COLOR_WHITE}│${COLOR_RESET}  ${COLOR_BLUE}Plugins: ${COLOR_RESET}${plugin_count}"
```

### Phase 6: Documentation Updates

**README.md updates**:
- Add plugin servers to server types table
- Document soft vs hard disable
- Add Shift+Space keybinding
- Update best practices for plugin management

**CLAUDE.md updates**:
- ✅ Already updated with plugin section
- ✅ Already updated with testing findings

## Testing Plan

### Unit Testing

1. **Plugin Discovery**:
   ```bash
   # Test with real marketplace plugin
   # Verify server appears with plugin:marketplace label
   ```

2. **Soft Disable**:
   ```bash
   # Toggle plugin off
   # Verify omitted from enabledPlugins
   # Verify still visible in claude mcp list
   ```

3. **Hard Disable**:
   ```bash
   # Shift+Space on plugin
   # Verify set to false in enabledPlugins
   # Verify disappears from claude mcp list
   ```

4. **Precedence**:
   ```bash
   # Set plugin enabled in user settings
   # Set plugin soft-disabled in project settings
   # Verify project wins (omitted)
   ```

### Integration Testing

1. **Round-trip**: Toggle plugin off → save → launch Claude → verify state
2. **Mixed servers**: MCPJSON + Direct + Plugin in same session
3. **Migration + Plugin**: Migrate direct server, toggle plugin in same session
4. **Master switch**: Set enableAllProjectMcpServers, verify MCPJSON behavior unaffected by plugin changes

## Rollout Approach

### Phase 1: Core Plugin Support (PR #1)
- Plugin discovery and parsing
- Basic toggle (soft-disable only)
- UI indicators
- Testing with real marketplace plugins

### Phase 2: Advanced Features (PR #2)
- Hard-disable with Shift+Space
- Master switch support
- Enhanced preview warnings
- Documentation updates

### Phase 3: Polish (PR #3)
- Performance optimization
- Edge case handling
- User feedback incorporation

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Marketplace path changes | Medium | High | Make path discovery flexible, handle missing gracefully |
| Plugin naming conflicts | Low | Medium | Use full `name@marketplace` format everywhere |
| UI disappearance confusion | High | Medium | Clear preview warnings, default to soft-disable |
| enabledPlugins merge complexity | Medium | Medium | Thorough testing of precedence, clear documentation |
| Performance with many plugins | Low | Low | Lazy loading, efficient jq queries |

## Success Criteria

- ✅ Plugin servers appear in TUI with correct labels
- ✅ Soft-disable omits from enabledPlugins, keeps visible in Claude
- ✅ Hard-disable sets to false, hides from Claude (with clear warning)
- ✅ Precedence works correctly (project > user)
- ✅ Migration system unaffected
- ✅ No performance degradation
- ✅ Clear documentation and warnings
- ✅ Backwards compatible with existing configs

## Timeline Estimate

- Phase 1 (Core): 4-6 hours
- Phase 2 (Advanced): 2-3 hours
- Phase 3 (Polish): 2-3 hours
- Testing: 2-3 hours
- **Total**: 10-15 hours over 2-3 days

## Questions for User

1. Should we auto-enable enableAllProjectMcpServers when saving, or leave it to user?
2. Default label for soft-disabled plugins: `[~ ]` or `[S ]` or something else?
3. Should hard-disable require confirmation prompt?
4. Any preferred marketplace we should prioritize testing with?
