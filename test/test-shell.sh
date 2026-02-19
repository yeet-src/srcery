#!/usr/bin/env bash
# Tests for @shell
source "$(dirname "$0")/helpers.sh"

# ===================
echo "--- @shell ---"

# Set up two worktrees with windows
setup_repo shellrepo
wt_a=$(@wt-create shellrepo shell-a)
wt_b=$(@wt-create shellrepo shell-b)
abs_wt_a=$(cd "$wt_a" && pwd -P)
abs_wt_b=$(cd "$wt_b" && pwd -P)
srcery_new_window claude "$abs_wt_a" sleep 999 >/dev/null
srcery_new_window claude "$abs_wt_b" sleep 999 >/dev/null

t "@shell starts a shell window"
@shell shell-a 2>&1 || true
wins=$(tmux -L srcery-test list-windows -t "=srcery" -F '#{window_name}')
assert contains "$wins" "shell"

t "@shell window starts in worktree directory"
sleep 0.1
# find the shell window for shell-a by checking CWD
shell_info=$(tmux -L srcery-test list-windows -t "=srcery" -F '#{window_name} #{pane_current_path}' \
	| grep "^shell " | head -1)
pane_path=$(echo "$shell_info" | awk '{print $2}')
actual=$(cd "$pane_path" && pwd -P)
assert test "$actual" = "$abs_wt_a"

t "@shell attaches via worktree session (not master)"
err=$(@shell shell-b 2>&1 || true)
assert contains "$err" "open terminal failed"
# ephemeral session srcery/<wt> should exist (or have existed)
sessions=$(tmux -L srcery-test list-sessions -F '#{session_name}' 2>/dev/null || true)
assert contains "$sessions" "srcery/shell-b"

t "@shell same worktree reuses same session as @attach"
# @attach shell-a should use srcery/shell-a
@attach shell-a 2>&1 || true
sessions=$(tmux -L srcery-test list-sessions -F '#{session_name}' 2>/dev/null || true)
assert contains "$sessions" "srcery/shell-a"

report
