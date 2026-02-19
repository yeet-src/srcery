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

# mock @install-hooks (avoid touching real ~/.claude/settings.json)
cat > "$tmpdir/mock-install-hooks" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$tmpdir/mock-install-hooks"
# put mock first on PATH so @install-hooks resolves to it
mkdir -p "$tmpdir/bin"
cp "$tmpdir/mock-install-hooks" "$tmpdir/bin/@install-hooks"
export PATH="$tmpdir/bin:$PATH"

t "@dev creates worktree and starts claude window"
@dev devrepo dev-test 2>/dev/null || true
wt_name="dev-test"
assert test -d "$SRCERY_DATA/worktrees/$wt_name"

t "@dev starts claude window"
wins=$(tmux -L srcery-test list-windows -t "=srcery" -F '#{window_name}' 2>/dev/null || true)
assert contains "$wins" "claude"

t "@dev starts shell window"
assert contains "$wins" "shell"

t "@dev attaches via worktree session"
sessions=$(tmux -L srcery-test list-sessions -F '#{session_name}' 2>/dev/null || true)
assert contains "$sessions" "srcery/$wt_name"

@wt-remove "$wt_name"
unset CLAUDE_BIN

report
