#!/usr/bin/env bash
# Tests for @dev
source "$(dirname "$0")/helpers.sh"

# ===================
echo "--- @dev ---"

setup_repo devrepo

# mock claude binary
cat > "$tmpdir/mock-claude" <<'MOCK'
#!/usr/bin/env bash
sleep 999
MOCK
chmod +x "$tmpdir/mock-claude"

export CLAUDE_BIN="$tmpdir/mock-claude"

t "@dev creates worktree and starts service"
@dev devrepo dev-test 2>/dev/null || true
wt_name="dev-test"
assert test -d "$SRCERY_DATA/worktrees/$wt_name"

t "@dev writes hook settings file"
assert test -f "$SRCERY_DATA/worktrees/$wt_name/.claude/settings.local.json"
settings=$(cat "$SRCERY_DATA/worktrees/$wt_name/.claude/settings.local.json")
assert contains "$settings" "srcery-notify"
assert contains "$settings" "Notification"
assert contains "$settings" "UserPromptSubmit"

t "@dev starts claude service"
list=$(@svc-list -n claude)
assert contains "$list" "claude"

t "@dev service is running in worktree"
list=$(@svc-list -w "$wt_name")
assert contains "$list" "claude"

t "@dev attaches via worktree session"
sessions=$(tmux -L srcery-test list-sessions -F '#{session_name}' 2>/dev/null || true)
assert contains "$sessions" "srcery/$wt_name"

@wt-remove "$wt_name"
unset CLAUDE_BIN

report
