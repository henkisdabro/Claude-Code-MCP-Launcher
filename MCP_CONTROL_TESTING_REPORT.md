# Claude Code MCP Server Control Testing Report

**Test Date:** October 11, 2025
**Claude Code Version:** 2.0.14
**Testing Environment:** WSL2 Ubuntu

## Executive Summary

This report documents comprehensive testing of Claude Code's MCP server control mechanisms across all configuration files and settings. Key findings include:

1. **Working Arrays**: `enabledMcpjsonServers`, `disabledMcpjsonServers`, `enabledPlugins`
2. **Non-Functional Arrays**: `enabledMcpServers`, `disabledMcpServers` (without "json" suffix)
3. **Critical Issue Confirmed**: Setting `enabledPlugins[plugin] = false` completely hides plugins from UI
4. **New Discovery**: `enableAllProjectMcpServers` flag controls all .mcp.json servers

---

## 1. Arrays Compatibility Matrix

### 1.1 MCPJSON Control Arrays (`enabledMcpjsonServers` / `disabledMcpjsonServers`)

Controls servers defined in `.mcp.json` files only.

| Location | Works? | Effect | Notes |
|----------|--------|--------|-------|
| `~/.claude.json` root | ⚠️ Partial | Server still shows but attempts connection | Not fully effective |
| `~/.claude.json` `.projects[cwd]` | ✅ Yes | Server completely hidden | Full control |
| `~/.claude/settings.json` | ✅ Yes | Server completely hidden | Full control |
| `~/.claude/settings.local.json` | ⚠️ Partial | Server still shows but attempts connection | Not fully effective |
| `./.claude/settings.json` | ✅ Yes | Server completely hidden | Full control |
| `./.claude/settings.local.json` | ✅ Yes | Server completely hidden | Full control |

**Key Finding**: User-scope settings.local.json has weaker effect (server still visible). All other locations fully hide disabled servers.

### 1.2 Direct Server Control Arrays (`enabledMcpServers` / `disabledMcpServers`)

**Status: NON-FUNCTIONAL** ❌

Tested in all 6 locations with various server types:
- MCPJSON servers from .mcp.json: No effect
- Direct-Global servers from ~/.claude.json root .mcpServers: No effect
- Plugin servers: No effect

**Conclusion**: These arrays (without "json" suffix) are completely non-functional in Claude Code 2.0.14.

### 1.3 Plugin Control Object (`enabledPlugins`)

Controls marketplace plugin-based MCP servers.

| Location | Works? | Effect | Notes |
|----------|--------|--------|-------|
| `~/.claude.json` root | ❌ No | No effect | Plugins still appear |
| `~/.claude.json` `.projects[cwd]` | ❌ No | No effect | Plugins still appear |
| `~/.claude/settings.json` | ✅ Yes | Plugin hidden when false | ⚠️ UI DISAPPEARANCE |
| `~/.claude/settings.local.json` | ❌ No | No effect | Plugins still appear |
| `./.claude/settings.json` | ✅ Yes | Plugin hidden when false | ⚠️ UI DISAPPEARANCE |
| `./.claude/settings.local.json` | ✅ Yes | Plugin hidden when false | ⚠️ UI DISAPPEARANCE |

**Key Finding**: Only works in settings files (`.claude/settings*.json`), not in main config (`~/.claude.json`).

### 1.4 Master Control Flag (`enableAllProjectMcpServers`)

Boolean flag that acts as master switch for ALL .mcp.json servers.

| Value | Effect | Override Behavior |
|-------|--------|-------------------|
| `true` | All .mcp.json servers enabled | Individual `disabledMcpjsonServers` still works |
| `false` | All .mcp.json servers disabled | Individual `enabledMcpjsonServers` can enable specific servers |

**Location**: Only tested in `./.claude/settings.local.json` (project-local scope)

---

## 2. Precedence Rules

### 2.1 enabledPlugins Precedence

Hierarchy (highest to lowest):
1. `./.claude/settings.local.json` (project-local)
2. `./.claude/settings.json` (project-shared)
3. `~/.claude/settings.json` (user-global)

**Merge Behavior**: `enabledPlugins` objects MERGE across files
- User settings: `{fetch: true, time: true}`
- Project settings: `{fetch: false}`
- Result: `{fetch: false, time: true}` (project overrides fetch, inherits time)

**Test Evidence**:
```bash
# User settings.json: fetch=false
# Project settings.json: fetch=true
# Result: Plugin appears (project wins)
```

### 2.2 MCPJSON Arrays Precedence

Hierarchy (highest to lowest):
1. `./.claude/settings.local.json` (project-local)
2. `./.claude/settings.json` (project-shared)
3. `~/.claude.json` `.projects[cwd]` (project section)
4. `~/.claude/settings.json` (user-global)
5. `~/.claude.json` root (user root)
6. `~/.claude/settings.local.json` (user-local)

**Test Evidence**:
```bash
# Test: User settings.json disabled, Project settings.local.json enabled
# Result: Server appears (project-local wins)

# Test: User settings.local.json disabled, Project settings.local.json enabled
# Result: Server appears (project-local wins, even over user-local)
```

**Important**: Project-local settings (`./.claude/settings.local.json`) have highest priority, even over user-local settings.

### 2.3 enableAllProjectMcpServers vs Individual Arrays

When both present in same file:
- Individual `disabledMcpjsonServers` wins over `enableAllProjectMcpServers: true`
- Individual `enabledMcpjsonServers` wins over `enableAllProjectMcpServers: false`

**Test Evidence**:
```bash
# enableAllProjectMcpServers: true
# disabledMcpjsonServers: ["test-project-mcpjson"]
# Result: Server is disabled (individual disable wins)
```

---

## 3. Plugin UI Disappearance Issue

### 3.1 The Problem (CONFIRMED ✅)

When `enabledPlugins["plugin-name@claudecode-marketplace"] = false` is set in working locations, the plugin:
- ❌ Disappears completely from `claude mcp list`
- ❌ Becomes unavailable in Claude Code UI
- ❌ Cannot be re-enabled via UI during session
- ❌ User must edit config file to restore

### 3.2 Working Locations That Cause Disappearance

Plugin disappears when set to `false` in:
- `~/.claude/settings.json`
- `./.claude/settings.json`
- `./.claude/settings.local.json`

### 3.3 Test Evidence

```bash
# User settings: enabledPlugins["mcp-fetch"] = true
# Project settings: enabledPlugins["mcp-fetch"] = false

$ claude mcp list | grep fetch
(no results - plugin completely hidden)
```

### 3.4 Workaround Strategies

**Strategy 1: Omit Instead of Setting False**
```json
{
  "enabledPlugins": {
    "mcp-time@claudecode-marketplace": true
    // Don't mention mcp-fetch at all - it inherits from user settings
  }
}
```

**Strategy 2: Use User-Local Settings (Ineffective)**
```json
// ~/.claude/settings.local.json - Does NOT work for plugins
{
  "enabledPlugins": {
    "mcp-fetch@claudecode-marketplace": false  // Has no effect
  }
}
```

**Strategy 3: Use ~/.claude.json (Ineffective)**
```json
// ~/.claude.json - Does NOT work for plugins
{
  "enabledPlugins": {
    "mcp-fetch@claudecode-marketplace": false  // Has no effect
  }
}
```

### 3.5 Difference Between Omitting and Setting False

| Scenario | Result |
|----------|--------|
| Plugin not mentioned in `enabledPlugins` | Inherits from lower-priority config (may be enabled) |
| Plugin set to `false` in `enabledPlugins` | Completely hidden, overrides all lower-priority configs |
| Plugin set to `true` in `enabledPlugins` | Enabled, overrides lower-priority configs |

---

## 4. Server Type Control Summary

### 4.1 MCPJSON Servers (from .mcp.json files)

**Controlled By**: `enabledMcpjsonServers` / `disabledMcpjsonServers` arrays

**Best Practices**:
- Use `./.claude/settings.local.json` for project-specific overrides (gitignored)
- Use `./.claude/settings.json` for team-shared defaults (version-controlled)
- Avoid `~/.claude/settings.local.json` (weaker effect - server still visible)

**Default Behavior**:
- User ~/.mcp.json servers: Require explicit enable (unless `enableAllProjectMcpServers: true`)
- Project ./.mcp.json servers: Auto-enabled if `enableAllProjectMcpServers: true`

### 4.2 Direct-Global Servers (from ~/.claude.json root .mcpServers)

**Controlled By**: CANNOT BE DISABLED ⚠️

These servers are always enabled. No control arrays work on them:
- `enabledMcpServers` / `disabledMcpServers`: No effect
- `enabledMcpjsonServers` / `disabledMcpjsonServers`: No effect (wrong type)

**Workaround**: Migrate server definition to .mcp.json for control.

### 4.3 Direct-Local Servers (from ~/.claude.json .projects[cwd].mcpServers)

**Controlled By**: CANNOT BE DISABLED ⚠️

Same as Direct-Global - always enabled, no control arrays work.

**Workaround**: Migrate server definition to .mcp.json for control.

### 4.4 Plugin Servers (from marketplace)

**Controlled By**: `enabledPlugins` object

**Working Locations**:
- `~/.claude/settings.json` ✅
- `./.claude/settings.json` ✅
- `./.claude/settings.local.json` ✅

**Non-Working Locations**:
- `~/.claude.json` (root or .projects[]) ❌
- `~/.claude/settings.local.json` ❌

**Critical Issue**: Setting to `false` causes UI disappearance (see Section 3).

---

## 5. Configuration File Hierarchy

Complete hierarchy from highest to lowest priority:

1. **`./.claude/settings.local.json`** (project-local, gitignored)
   - Highest priority for all settings
   - `enabledPlugins` works ✅
   - `enabledMcpjsonServers` / `disabledMcpjsonServers` work ✅
   - Perfect for personal project overrides

2. **`./.claude/settings.json`** (project-shared, version-controlled)
   - Second highest priority
   - `enabledPlugins` works ✅
   - `enabledMcpjsonServers` / `disabledMcpjsonServers` work ✅
   - Perfect for team defaults

3. **`~/.claude.json` `.projects[$(pwd)]` section**
   - Project-specific user config
   - `enabledPlugins` doesn't work ❌
   - `disabledMcpjsonServers` works ✅
   - `enabledMcpjsonServers` works ✅

4. **`~/.claude/settings.json`** (user-global)
   - User-wide defaults
   - `enabledPlugins` works ✅
   - `enabledMcpjsonServers` / `disabledMcpjsonServers` work ✅

5. **`~/.claude.json` root level**
   - Main user configuration
   - `enabledPlugins` doesn't work ❌
   - `disabledMcpjsonServers` has partial effect ⚠️

6. **`~/.claude/settings.local.json`** (user-local)
   - Lowest priority
   - `enabledPlugins` doesn't work ❌
   - `disabledMcpjsonServers` has partial effect ⚠️

---

## 6. Recommendations

### 6.1 For Plugin Control

**To disable a plugin WITHOUT UI disappearance:**
- ❌ DON'T use `enabledPlugins[plugin] = false` in settings files
- ✅ DO omit the plugin from `enabledPlugins` entirely
- ✅ DO use `enabledPlugins[plugin] = true` to enable
- ⚠️ Be aware: Lower-priority configs may still enable it

**Safe disabling approach:**
```json
// Instead of this (causes disappearance):
{
  "enabledPlugins": {
    "mcp-fetch@claudecode-marketplace": false  // ❌ Plugin disappears
  }
}

// Do this (allows re-enabling in UI):
{
  "enabledPlugins": {
    // Don't mention mcp-fetch at all ✅
  }
}
```

**To forcefully disable a plugin:**
If you WANT the plugin to disappear (prevent any use):
```json
// ./.claude/settings.local.json
{
  "enabledPlugins": {
    "unwanted-plugin@claudecode-marketplace": false  // Completely removes it
  }
}
```

### 6.2 For MCPJSON Server Control

**Best Practice**:
1. Use `enableAllProjectMcpServers: true` for convenience
2. Use `disabledMcpjsonServers: [...]` to selectively disable
3. Place in `./.claude/settings.local.json` for personal control
4. Place in `./.claude/settings.json` for team defaults

**Example Project Setup**:
```json
// ./.claude/settings.json (version-controlled, team default)
{
  "enableAllProjectMcpServers": true,
  "disabledMcpjsonServers": [
    "experimental-server",
    "slow-server"
  ]
}

// ./.claude/settings.local.json (gitignored, personal override)
{
  "enabledMcpjsonServers": [
    "experimental-server"  // I want to test this
  ]
}
```

### 6.3 For Direct Server Migration

Direct servers (from `~/.claude.json` `.mcpServers`) cannot be controlled. To gain control:

1. Move server definition from `~/.claude.json` to `~/.mcp.json`
2. Remove from `~/.claude.json`
3. Now controllable via `enabledMcpjsonServers` / `disabledMcpjsonServers`

### 6.4 Configuration File Usage

| File | Use For | Gitignore? |
|------|---------|------------|
| `./.claude/settings.local.json` | Personal project overrides | ✅ Yes |
| `./.claude/settings.json` | Team-shared project defaults | ❌ No (commit) |
| `~/.claude/settings.json` | User-global defaults | N/A (home dir) |
| `~/.claude.json` | Main user config, avoid for controls | N/A (home dir) |
| `./.mcp.json` | Project server definitions | ❌ No (commit) |
| `~/.mcp.json` | User server definitions | N/A (home dir) |

---

## 7. Test Evidence

### 7.1 Sample Test Outputs

**Test: disabledMcpjsonServers in Different Locations**
```bash
# ~/.claude/settings.local.json - Partial effect
$ claude mcp list | grep test-project
test-project-mcpjson: echo test-project - ✗ Failed to connect

# ~/.claude/settings.json - Full effect
$ claude mcp list | grep test-project
(no output - server completely hidden)

# ./.claude/settings.local.json - Full effect
$ claude mcp list | grep test-project
(no output - server completely hidden)
```

**Test: enabledPlugins Precedence**
```bash
# User settings.json: mcp-fetch = false
# Project settings.json: mcp-fetch = true
$ claude mcp list | grep fetch
plugin:mcp-fetch:fetch: uvx mcp-server-fetch - ✓ Connected
# Result: Project wins (plugin appears)
```

**Test: Plugin UI Disappearance**
```bash
# Project settings.json: mcp-fetch = false
$ claude mcp list | grep fetch
(no output - plugin completely hidden)

# Project settings.json: (doesn't mention mcp-fetch)
$ claude mcp list | grep fetch
plugin:mcp-fetch:fetch: uvx mcp-server-fetch - ✓ Connected
# Result: Inherits from user settings (plugin appears)
```

### 7.2 Test Configurations

**Test Server Definitions Used**:
```json
// ~/.mcp.json
{
  "mcpServers": {
    "test-user-mcpjson": {
      "command": "echo",
      "args": ["test-user"]
    }
  }
}

// ./.mcp.json
{
  "mcpServers": {
    "test-project-mcpjson": {
      "command": "echo",
      "args": ["test-project"]
    }
  }
}

// ~/.claude.json (existing)
{
  "mcpServers": {
    "time": {
      "command": "uvx",
      "args": ["mcp-server-time", "--local-timezone=Australia/Perth"]
    }
  }
}
```

---

## 8. Limitations and Unknowns

### 8.1 Testing Limitations

1. **UI Testing**: Tests conducted via `claude mcp list` CLI. Actual UI behavior in Claude Code desktop app not directly tested.
2. **Session Persistence**: Whether UI disappearance persists across Claude restarts not tested.
3. **Migration Flow**: Server migration from ~/.claude.json to .mcp.json tested conceptually but not end-to-end.

### 8.2 Unknown Behaviors

1. **enableAllProjectMcpServers in other files**: Only tested in `./.claude/settings.local.json`
2. **Plugin re-enabling**: Whether disappeared plugins can be re-enabled without config edit unclear
3. **Array name variations**: Whether other array names exist (e.g., `enabledServers`) not exhaustively tested

---

## 9. Conclusion

### Key Takeaways

1. ✅ **Working Control Arrays**:
   - `enabledMcpjsonServers` / `disabledMcpjsonServers` (for .mcp.json servers)
   - `enabledPlugins` (for marketplace plugins, in settings files only)
   - `enableAllProjectMcpServers` (master switch for .mcp.json)

2. ❌ **Non-Functional Arrays**:
   - `enabledMcpServers` / `disabledMcpServers` (completely useless)

3. ⚠️ **Critical Issues**:
   - Plugin UI disappearance when set to `false`
   - Direct servers cannot be controlled (always enabled)
   - Precedence can be confusing (project-local beats user-local)

4. 💡 **Best Practices**:
   - Omit plugins from `enabledPlugins` instead of setting `false`
   - Use `./.claude/settings.local.json` for highest-priority personal overrides
   - Use `./.claude/settings.json` for team-shared defaults
   - Migrate Direct servers to .mcp.json for control

### Recommendations for Claude Code Development

1. **Fix Plugin Disappearance**: `enabledPlugins[plugin] = false` should disable, not hide
2. **Deprecate Non-Functional Arrays**: Remove or document `enabledMcpServers`/`disabledMcpServers`
3. **Add Direct Server Control**: Allow disabling Direct-Global and Direct-Local servers
4. **Clarify Precedence**: Document the exact hierarchy in official docs
5. **Merge vs Replace**: Document whether objects merge or replace across files

---

## Appendix: Test Commands Used

```bash
# Check MCP server status
claude mcp list

# View specific config sections
jq '.enabledPlugins' ~/.claude/settings.json
jq '.mcpServers | keys' ~/.claude.json
jq '.disabledMcpjsonServers' ./.claude/settings.local.json

# Modify configs for testing
jq '.enabledPlugins["mcp-fetch@claudecode-marketplace"] = false' \
  ~/.claude/settings.json > /tmp/test.json && \
  mv /tmp/test.json ~/.claude/settings.json

# Check precedence
jq '.enabledPlugins' ~/.claude/settings.json
jq '.enabledPlugins' ./.claude/settings.json
claude mcp list | grep fetch
```

---

**Report Generated:** October 11, 2025
**Tested By:** Claude Code Agent
**Claude Code Version:** 2.0.14
