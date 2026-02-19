#!/usr/bin/env bash
# Tests for tmux window management (srcery_new_window, @wt-list, @wt-remove, srcery-notify)
source "$(dirname "$0")/helpers.sh"

# ===================
echo "--- srcery_new_window ---"

mkdir -p "$tmpdir/mywt"

t "srcery_new_window returns window ID"
win=$(srcery_new_window test-win "$tmpdir/mywt" sleep 999)
assert contains "$win" "@"

t "window appears in tmux"
list=$(tmux_windows)
assert contains "$list" "test-win"

t "process is running"
dead=$(tmux -L srcery-test display-message -t "$win" -p '#{pane_dead}')
assert test "$dead" = "0"

t "remain-on-exit is set globally"
val=$(tmux -L srcery-test show-options -gw -v remain-on-exit 2>/dev/null)
assert test "$val" = "on"

t "killing window removes it"
tmux -L srcery-test kill-window -t "$win"
list=$(tmux_windows)
assert_not contains "$list" "test-win"

# ===================
echo "--- @wt-list with pane info ---"

setup_repo listrepo
wt_path=$(@wt-create listrepo list-test)
wt_name=$(basename "$wt_path")
abs_wt_path=$(cd "$wt_path" && pwd -P)
srcery_new_window sleeper "$abs_wt_path" sleep 999 >/dev/null

t "wt-list shows pane info (not just dash)"
list=$(@wt-list)
row=$(echo "$list" | grep "$wt_name")
# PANES column should not be "-" since we have a running window
assert_not contains "$row" "  -"

t "wt-list shows status from pane-id status file"
pane_id=$(srcery_tmux list-panes -s -t "=srcery" -F '#{pane_id} #{pane_current_path}' \
	| grep "$abs_wt_path" | head -1 | awk '{print $1}')
mkdir -p "$SRCERY_DATA/status/$wt_name"
echo "idle" > "$SRCERY_DATA/status/$wt_name/$pane_id"
list=$(@wt-list)
row=$(echo "$list" | grep "$wt_name")
assert contains "$row" "idle"

# ===================
echo "--- @wt-remove kills windows + cleans status ---"

t "wt-remove kills tmux windows"
@wt-remove "$wt_name"
# window should be gone
list=$(tmux_windows 2>/dev/null || true)
assert_not contains "$list" "sleeper"

t "wt-remove cleans up status dir"
assert_not test -d "$SRCERY_DATA/status/$wt_name"

# ===================
echo "--- dead panes ---"

setup_repo deadrepo
wt_path=$(@wt-create deadrepo dead-test)
wt_name=$(basename "$wt_path")
abs_wt_path=$(cd "$wt_path" && pwd -P)
srcery_new_window die-cmd "$abs_wt_path" bash -c 'exit 1'
sleep 0.5

t "wt-list shows dead pane"
list=$(@wt-list)
row=$(echo "$list" | grep "$wt_name")
assert contains "$row" "dead"

@wt-remove "$wt_name"

# ===================
echo "--- srcery-notify no-ops ---"

t "srcery-notify exits silently outside tmux"
unset TMUX
echo '{}' | "$SRCERY_ROOT/lib/srcery-notify"
assert test $? -eq 0

t "srcery-notify exits silently with wrong socket"
TMUX="/tmp/wrong-socket,12345,0" TMUX_PANE="%99" \
	"$SRCERY_ROOT/lib/srcery-notify" <<< '{}' || true
assert test $? -eq 0

report
