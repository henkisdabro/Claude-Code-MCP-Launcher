# Testing Guide for MCP Server Selector v2.0

This document provides comprehensive testing instructions for the MCP Server Selector.

## Prerequisites

Ensure you have the required dependencies installed:

```bash
command -v fzf jq
```

If not installed, follow the installation instructions in the main error message.

## Test Modes

### Test Mode (Skip Claude Launch)

Set the `TEST_MODE` environment variable to skip the final Claude launch:

```bash
TEST_MODE=1 ./mcp
```

This allows you to test the TUI and configuration changes without actually launching Claude.

## Testing Scenarios

### 1. Basic Functionality with Local Config

**Setup:**
```bash
# Create test directory with local config
mkdir -p test-project/.claude
cp test-settings.json test-project/.claude/settings.local.json
cd test-project
```

**Test:**
```bash
TEST_MODE=1 ../mcp
```

**Expected behavior:**
- Detects `./.claude/settings.local.json`
- Shows scope as "project (local)"
- Displays 19 total servers (2 enabled, 17 disabled)
- All TUI features work (toggle, preview, etc.)

**What to test:**
- [ ] Press SPACE to toggle servers on/off
- [ ] Verify preview window updates correctly
- [ ] Press ENTER to save changes
- [ ] Check that `./.claude/settings.local.json` was updated correctly
- [ ] Press ESC to cancel (changes should not be saved)

### 2. New Project Flow (Create Local Config)

**Setup:**
```bash
# Create test directory WITHOUT local config
mkdir -p test-new-project
cd test-new-project

# Ensure global config exists
mkdir -p ~/.claude
cp ../test-settings.json ~/.claude/settings.json
```

**Test:**
```bash
TEST_MODE=1 ../mcp
```

**Expected behavior:**
- Detects no local config but finds global config
- Presents 3-choice menu
- Choose option 1 (Create local config)
- Creates `./.claude/settings.local.json`
- Launches TUI with new local config

**What to test:**
- [ ] Option 1: Verify `./.claude/settings.local.json` is created
- [ ] Option 1: Verify content matches global config
- [ ] Option 1: TUI launches successfully
- [ ] Option 2: Script skips TUI (would launch Claude in non-test mode)
- [ ] Option 3: Script exits without changes

### 3. Legacy Local Config

**Setup:**
```bash
# Create test directory with legacy config (settings.json, not settings.local.json)
mkdir -p test-legacy/.claude
cp test-settings.json test-legacy/.claude/settings.json
cd test-legacy
```

**Test:**
```bash
TEST_MODE=1 ../mcp
```

**Expected behavior:**
- Detects `./.claude/settings.json` (legacy)
- Shows scope as "project"
- TUI works normally

### 4. No Configuration Found

**Setup:**
```bash
# Create empty directory with no configs
mkdir -p test-no-config
cd test-no-config

# Temporarily rename global config
mv ~/.claude/settings.json ~/.claude/settings.json.bak
```

**Test:**
```bash
../mcp
```

**Expected behavior:**
- Shows error: "No local or global Claude configuration found"
- Exits gracefully

**Cleanup:**
```bash
mv ~/.claude/settings.json.bak ~/.claude/settings.json
```

### 5. Add Server Flow

**Setup:**
```bash
cd test-project
TEST_MODE=1 ../mcp
```

**Test:**
- Press `Ctrl-A` to add a server
- Enter a valid server name (e.g., "my-custom-server")
- Verify server appears in list as disabled
- Press ENTER to save
- Check that server was added to `disabledMcpjsonServers` array

**What to test:**
- [ ] Valid server name (alphanumeric, dashes, underscores)
- [ ] Invalid server name (special characters) - should show error
- [ ] Duplicate server name - should show warning
- [ ] Empty name (press Enter) - should cancel
- [ ] Server appears in TUI immediately after adding

### 6. Remove Server Flow

**Setup:**
```bash
cd test-project
TEST_MODE=1 ../mcp
```

**Test:**
- Highlight a server in the list
- Press `Ctrl-X` to remove
- Confirm with 'y'
- Verify server disappears from list
- Press ENTER to save
- Check that server was removed from settings file

**What to test:**
- [ ] Confirm 'y' - server is removed
- [ ] Confirm 'n' - server remains
- [ ] Cancel with empty input - server remains

### 7. Empty Server List

**Setup:**
```bash
# Create config with no servers
cat > test-empty/.claude/settings.local.json <<'EOF'
{
  "enabledMcpjsonServers": [],
  "disabledMcpjsonServers": []
}
EOF
cd test-empty
```

**Test:**
```bash
TEST_MODE=1 ../mcp
```

**Expected behavior:**
- Shows warning: "No MCP servers found"
- Displays tip about using Ctrl-A to add servers
- TUI launches with empty list
- Ctrl-A still works to add servers

### 8. Malformed JSON

**Setup:**
```bash
# Create invalid JSON
echo "{invalid json" > test-invalid/.claude/settings.local.json
cd test-invalid
```

**Test:**
```bash
../mcp
```

**Expected behavior:**
- Shows error: "Settings file is malformed JSON"
- Exits gracefully without crashing

### 9. Missing JSON Keys

**Setup:**
```bash
# Create JSON without server arrays
cat > test-missing-keys/.claude/settings.local.json <<'EOF'
{
  "someOtherKey": "value"
}
EOF
cd test-missing-keys
```

**Test:**
```bash
TEST_MODE=1 ../mcp
```

**Expected behavior:**
- Handles missing keys gracefully
- Shows "No MCP servers found" warning
- TUI launches with empty list

### 10. Toggle Multiple Servers

**Test:**
```bash
cd test-project
TEST_MODE=1 ../mcp
```

**What to test:**
- [ ] Toggle multiple servers from OFF to ON
- [ ] Toggle some from ON to OFF
- [ ] Verify preview window reflects pending changes
- [ ] Save with ENTER
- [ ] Verify all changes were saved correctly
- [ ] Verify enabled/disabled arrays are correct in JSON

### 11. Cancel Without Saving

**Test:**
```bash
cd test-project
TEST_MODE=1 ../mcp
```

**What to test:**
- [ ] Make several changes (toggle servers, add/remove)
- [ ] Press ESC to cancel
- [ ] Verify no changes were saved to settings file
- [ ] Re-run tool, verify original state is intact

### 12. Dependency Check

**Test:**
```bash
# Simulate missing dependency
alias fzf='command_not_found'
./mcp
unalias fzf
```

**Expected behavior:**
- Detects missing dependency
- Shows installation instructions for your OS
- Exits gracefully

## Performance Testing

### Launch Speed

**Test:**
```bash
time TEST_MODE=1 ./mcp
# Press ESC immediately
```

**Expected:** < 1 second to launch TUI

### Toggle Speed

**Test:**
- Launch TUI
- Toggle a server with SPACE
- Measure visual feedback delay

**Expected:** < 50ms (instant visual update)

## Cross-Platform Testing

### Linux (Ubuntu/Debian)

```bash
# Verify OS detection
./mcp  # If deps missing, should show apt install commands
```

### macOS

```bash
# Verify OS detection
./mcp  # If deps missing, should show brew install commands
```

## Automated Syntax Check

```bash
# Verify bash syntax
bash -n ./mcp

# Verify install.sh syntax
bash -n ./install.sh
```

## JSON Validation

```bash
# Verify test settings file
jq empty test-settings.json

# Verify settings after changes
jq empty .claude/settings.local.json
```

## Checklist: Before Release

- [ ] All manual testing scenarios pass
- [ ] Syntax check passes on bash 4.0+
- [ ] Works on Linux (tested on Ubuntu or Debian)
- [ ] Works on macOS (if available for testing)
- [ ] All error cases handled gracefully
- [ ] No crashes or data loss in any scenario
- [ ] Installation script works
- [ ] README is accurate and complete
- [ ] No hardcoded paths or user-specific values

## Reporting Issues

If you find bugs during testing:

1. Note the exact scenario (which test case)
2. Record the error message or unexpected behavior
3. Check the settings file state (was it corrupted?)
4. Note your OS and versions (bash, fzf, jq)
5. Create a GitHub issue with all details
