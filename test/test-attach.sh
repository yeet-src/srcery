#!/usr/bin/env bash
# Tests for @attach
source "$(dirname "$0")/helpers.sh"

# ===================
echo "--- @attach ---"

mkdir -p "$tmpdir/att_wt"
win=$(@svc-start "$tmpdir/att_wt" att-svc sleep 999)

t "attach (no args) finds master session"
err=$(@attach 2>&1 || true)
assert contains "$err" "open terminal failed"

t "master session has the service window"
wins=$(tmux -L srcery-test list-windows -t "=srcery" -F '#{window_name}')
assert contains "$wins" "att_wt/att-svc"

t "attach <wt> finds worktree session"
err=$(@attach att_wt 2>&1 || true)
assert contains "$err" "open terminal failed"

t "worktree session has the service window"
wins=$(tmux -L srcery-test list-windows -t "=srcery/att_wt" -F '#{window_name}')
assert contains "$wins" "att_wt/att-svc"

t "attach @<name> finds name session"
err=$(@attach @att-svc 2>&1 || true)
assert contains "$err" "open terminal failed"

t "name session has the service window"
wins=$(tmux -L srcery-test list-windows -t "=srcery/@att-svc" -F '#{window_name}')
assert contains "$wins" "att_wt/att-svc"

t "attach nonexistent target fails"
err=$(@attach nonexistent 2>&1 || true)
assert contains "$err" "can't find session"

@svc-stop "$win" >/dev/null

report
