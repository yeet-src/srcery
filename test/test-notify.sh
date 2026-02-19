#!/usr/bin/env bash
# Tests for srcery-notify (self-discovering hook)
source "$(dirname "$0")/helpers.sh"

# ===================
echo "--- srcery-notify ---"

notify_input() {
	echo "{\"hook_event_name\":\"$1\",\"notification_type\":\"$2\",\"message\":\"$3\"}"
}

# Create a managed worktree directory so srcery-notify recognizes it
wt_name="notify_wt"
mkdir -p "$SRCERY_DATA/worktrees/$wt_name"

# Start a tmux window in that worktree so we have a real pane
abs_wt_path=$(cd "$SRCERY_DATA/worktrees/$wt_name" && pwd -P)
win=$(srcery_new_window notify-test "$abs_wt_path" sleep 999)

# Get the pane ID for this window
pane_id=$(srcery_tmux list-panes -t "$win" -F '#{pane_id}')

# Build the TMUX env var that srcery-notify checks
tmux_socket_path=$(srcery_tmux display-message -p '#{socket_path}')
tmux_env="$tmux_socket_path,$$,0"

t "srcery-notify writes idle status"
notify_input Notification idle_prompt "Done" \
	| TMUX="$tmux_env" TMUX_PANE="$pane_id" \
	  SRCERY_TMUX_SOCKET="$SRCERY_TMUX_SOCKET" \
	  SRCERY_DATA="$SRCERY_DATA" SRCERY_ROOT="$SRCERY_ROOT" \
	  "$SRCERY_ROOT/lib/srcery-notify"
assert test -f "$SRCERY_DATA/status/$wt_name/$pane_id"
assert test "$(cat "$SRCERY_DATA/status/$wt_name/$pane_id")" = "idle"

t "srcery-notify writes attention status"
notify_input Notification permission_prompt "Need permission" \
	| TMUX="$tmux_env" TMUX_PANE="$pane_id" \
	  SRCERY_TMUX_SOCKET="$SRCERY_TMUX_SOCKET" \
	  SRCERY_DATA="$SRCERY_DATA" SRCERY_ROOT="$SRCERY_ROOT" \
	  "$SRCERY_ROOT/lib/srcery-notify"
assert test "$(cat "$SRCERY_DATA/status/$wt_name/$pane_id")" = "attention"

t "srcery-notify clears status on UserPromptSubmit"
notify_input UserPromptSubmit "" "" \
	| TMUX="$tmux_env" TMUX_PANE="$pane_id" \
	  SRCERY_TMUX_SOCKET="$SRCERY_TMUX_SOCKET" \
	  SRCERY_DATA="$SRCERY_DATA" SRCERY_ROOT="$SRCERY_ROOT" \
	  "$SRCERY_ROOT/lib/srcery-notify"
assert_not test -f "$SRCERY_DATA/status/$wt_name/$pane_id"

t "srcery-notify ignores unknown notification types"
notify_input Notification auth_success "" \
	| TMUX="$tmux_env" TMUX_PANE="$pane_id" \
	  SRCERY_TMUX_SOCKET="$SRCERY_TMUX_SOCKET" \
	  SRCERY_DATA="$SRCERY_DATA" SRCERY_ROOT="$SRCERY_ROOT" \
	  "$SRCERY_ROOT/lib/srcery-notify"
assert_not test -f "$SRCERY_DATA/status/$wt_name/$pane_id"

t "srcery-notify exits silently outside tmux"
notify_input Notification idle_prompt "Done" \
	| TMUX="" TMUX_PANE="" \
	  SRCERY_DATA="$SRCERY_DATA" SRCERY_ROOT="$SRCERY_ROOT" \
	  "$SRCERY_ROOT/lib/srcery-notify"
assert test $? -eq 0

t "srcery-notify exits silently with wrong socket"
notify_input Notification idle_prompt "Done" \
	| TMUX="/tmp/wrong-socket,$$,0" TMUX_PANE="$pane_id" \
	  SRCERY_TMUX_SOCKET="$SRCERY_TMUX_SOCKET" \
	  SRCERY_DATA="$SRCERY_DATA" SRCERY_ROOT="$SRCERY_ROOT" \
	  "$SRCERY_ROOT/lib/srcery-notify"
assert_not test -f "$SRCERY_DATA/status/$wt_name/$pane_id"

t "srcery-notify exits silently for non-worktree CWD"
# Create a window in a dir that's NOT a managed worktree
mkdir -p "$tmpdir/random_dir"
random_abs=$(cd "$tmpdir/random_dir" && pwd -P)
rwin=$(srcery_new_window random-test "$random_abs" sleep 999)
rpane=$(srcery_tmux list-panes -t "$rwin" -F '#{pane_id}')
notify_input Notification idle_prompt "Done" \
	| TMUX="$tmux_env" TMUX_PANE="$rpane" \
	  SRCERY_TMUX_SOCKET="$SRCERY_TMUX_SOCKET" \
	  SRCERY_DATA="$SRCERY_DATA" SRCERY_ROOT="$SRCERY_ROOT" \
	  "$SRCERY_ROOT/lib/srcery-notify"
assert_not test -f "$SRCERY_DATA/status/random_dir/$rpane"

srcery_tmux kill-window -t "$win" 2>/dev/null || true
srcery_tmux kill-window -t "$rwin" 2>/dev/null || true

report
