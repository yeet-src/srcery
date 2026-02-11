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
assert contains "$list" "$wt_name/claude"

t "@dev service uses mock claude binary"
dead=$(tmux -L srcery-test display-message -t "=srcery:=$wt_name/claude" -p '#{pane_dead}')
assert test "$dead" = "0"

@wt-remove "$wt_name"
unset CLAUDE_BIN

report
