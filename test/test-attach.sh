#!/usr/bin/env bash
# Tests for @attach
source "$(dirname "$0")/helpers.sh"

# ===================
echo "--- @attach ---"

mkdir -p "$tmpdir/att_wt"
win=$(srcery_new_window att-svc "$tmpdir/att_wt" sleep 999)

t "attach (no args) finds master session"
err=$(@attach 2>&1 || true)
assert contains "$err" "open terminal failed"

t "master session has the service window"
wins=$(tmux -L srcery-test list-windows -t "=srcery" -F '#{window_name}')
assert contains "$wins" "att-svc"

t "attach <wt> creates ephemeral worktree session"
err=$(@attach att_wt 2>&1 || true)
assert contains "$err" "open terminal failed"

t "worktree session has the service window"
wins=$(tmux -L srcery-test list-windows -t "=srcery/att_wt" -F '#{window_name}')
assert contains "$wins" "att-svc"

t "attach @<name> creates ephemeral name session"
err=$(@attach @att-svc 2>&1 || true)
assert contains "$err" "open terminal failed"

t "name session has the service window"
wins=$(tmux -L srcery-test list-windows -t "=srcery/@att-svc" -F '#{window_name}')
assert contains "$wins" "att-svc"

t "attach nonexistent target fails"
err=$(@attach nonexistent 2>&1 || true)
assert contains "$err" "no matching panes"

t "attach reuses existing ephemeral session"
# srcery/att_wt was created above; attaching again should succeed
err=$(@attach att_wt 2>&1 || true)
assert contains "$err" "open terminal failed"

t "worktree session start dir is the worktree CWD"
start_dir=$(tmux -L srcery-test list-sessions -F '#{session_name} #{session_path}' \
	| grep '^srcery/att_wt ' | awk '{print $2}')
expected=$(cd "$tmpdir/att_wt" && pwd -P)
assert test "$start_dir" = "$expected"

tmux -L srcery-test kill-window -t "$win" 2>/dev/null || true

# ===================
echo "--- @attach + @shell consistency ---"

setup_repo consrepo
wt_path=$(@wt-create consrepo cons-wt)
abs_wt_path=$(cd "$wt_path" && pwd -P)
srcery_new_window claude "$abs_wt_path" sleep 999 >/dev/null

t "@shell uses same session type as @attach"
@shell cons-wt 2>&1 || true
@attach cons-wt 2>&1 || true
# both should route through srcery/cons-wt
sessions=$(tmux -L srcery-test list-sessions -F '#{session_name}' 2>/dev/null || true)
assert contains "$sessions" "srcery/cons-wt"

t "@shell service visible via @attach worktree filter"
wins=$(tmux -L srcery-test list-windows -t "=srcery/cons-wt" -F '#{window_name}' 2>/dev/null || true)
assert contains "$wins" "shell"
assert contains "$wins" "claude"

@wt-remove cons-wt

report
