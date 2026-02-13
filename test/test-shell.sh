#!/usr/bin/env bash
# Tests for @shell
source "$(dirname "$0")/helpers.sh"

# ===================
echo "--- @shell ---"

# Set up two worktrees with services
setup_repo shellrepo
wt_a=$(@wt-create shellrepo shell-a)
wt_b=$(@wt-create shellrepo shell-b)
@svc-start "$wt_a" claude sleep 999 >/dev/null
@svc-start "$wt_b" claude sleep 999 >/dev/null

t "@shell starts a shell service"
@shell shell-a 2>&1 || true
wins=$(tmux -L srcery-test list-windows -t "=srcery" -F '#{window_name}')
assert contains "$wins" "shell-a/shell"

t "@shell service starts in worktree directory"
sleep 0.1
pane_path=$(tmux -L srcery-test display-message -t "=srcery:=shell-a/shell" -p '#{pane_current_path}')
# resolve symlinks (/tmp -> /private/tmp on macOS)
expected=$(cd "$wt_a" && pwd -P)
actual=$(cd "$pane_path" && pwd -P)
assert test "$actual" = "$expected"

t "@shell worktree session only has its own services"
wt_wins=$(tmux -L srcery-test list-windows -t "=srcery/shell-a" -F '#{window_name}')
assert_not contains "$wt_wins" "shell-b/"

t "@shell is repeatable (second call creates shell-2)"
@shell shell-a 2>&1 || true
wins=$(tmux -L srcery-test list-windows -t "=srcery/shell-a" -F '#{window_name}')
assert contains "$wins" "shell-a/shell-2"

t "@shell third call creates shell-3"
@shell shell-a 2>&1 || true
wins=$(tmux -L srcery-test list-windows -t "=srcery/shell-a" -F '#{window_name}')
assert contains "$wins" "shell-a/shell-3"

t "@shell attaches to worktree session (not master)"
err=$(@shell shell-b 2>&1 || true)
assert contains "$err" "open terminal failed"

# cleanup
@svc-stop "shell-a/claude" >/dev/null
@svc-stop "shell-b/claude" >/dev/null

report
