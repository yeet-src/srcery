#!/usr/bin/env bash
# Tests for @svc-start, @svc-stop, @svc-list
source "$(dirname "$0")/helpers.sh"

# ===================
echo "--- @svc-start / @svc-stop ---"

mkdir -p "$tmpdir/mywt"

t "svc-start returns window name"
win=$(@svc-start "$tmpdir/mywt" test-svc sleep 999)
assert test "$win" = "mywt/test-svc"

t "svc-start window appears in tmux"
list=$(tmux_windows)
assert contains "$list" "mywt/test-svc"

t "svc-start process is running"
dead=$(tmux -L srcery-test display-message -t "=srcery:=mywt/test-svc" -p '#{pane_dead}')
assert test "$dead" = "0"

t "svc-start creates per-worktree session"
assert tmux -L srcery-test has-session -t "=srcery/mywt"

t "svc-start creates per-name session"
assert tmux -L srcery-test has-session -t "=srcery/@test-svc"

t "svc-start rejects duplicate"
assert_not @svc-start "$tmpdir/mywt" test-svc sleep 999 2>/dev/null

t "svc-stop removes the window"
@svc-stop "mywt/test-svc" >/dev/null
list=$(tmux_windows)
assert_not contains "$list" "mywt/test-svc"

# ===================
echo "--- @svc-list ---"

mkdir -p "$tmpdir/wt_a" "$tmpdir/wt_b"
win1=$(@svc-start "$tmpdir/wt_a" svc-a sleep 999)
win2=$(@svc-start "$tmpdir/wt_b" svc-b sleep 999)

t "svc-list shows both services"
list=$(@svc-list)
assert contains "$list" "wt_a/svc-a"
assert contains "$list" "wt_b/svc-b"

t "svc-list -n filters by name"
list=$(@svc-list -n svc-a)
assert contains "$list" "wt_a/svc-a"
assert_not contains "$list" "wt_b/svc-b"

t "svc-list -w filters by worktree"
list=$(@svc-list -w wt_b)
assert_not contains "$list" "wt_a/svc-a"
assert contains "$list" "wt_b/svc-b"

# cleanup
@svc-stop "$win1" >/dev/null
@svc-stop "$win2" >/dev/null

# ===================
echo "--- @svc-list dead status ---"

mkdir -p "$tmpdir/deadwt"
win=$(@svc-start "$tmpdir/deadwt" die-svc bash -c 'exit 1')
sleep 0.5

t "svc-list shows dead status"
list=$(@svc-list)
assert contains "$list" "dead"

@svc-stop "$win" >/dev/null

# ===================
echo "--- @svc-list with status ---"

mkdir -p "$tmpdir/st_wt"
win=$(@svc-start "$tmpdir/st_wt" st-svc sleep 999)

t "svc-list shows running by default"
list=$(@svc-list)
row=$(echo "$list" | grep "st_wt/st-svc")
assert contains "$row" "running"

t "svc-list shows idle when status file exists"
mkdir -p "$SRCERY_DATA/status/st_wt"
echo "idle" > "$SRCERY_DATA/status/st_wt/st-svc"
list=$(@svc-list)
row=$(echo "$list" | grep "st_wt/st-svc")
assert contains "$row" "idle"

t "wt-list shows status in services column"
# need a real worktree for wt-list
setup_repo statusrepo
wt_path=$(@wt-create statusrepo status-test)
wt_name=$(basename "$wt_path")
@svc-start "$wt_path" claude sleep 999 >/dev/null
mkdir -p "$SRCERY_DATA/status/$wt_name"
echo "idle" > "$SRCERY_DATA/status/$wt_name/claude"
list=$(@wt-list)
row=$(echo "$list" | grep "$wt_name")
assert contains "$row" "claude(idle)"
@wt-remove "$wt_name"

t "wt-remove cleans up status dir"
assert_not test -d "$SRCERY_DATA/status/$wt_name"

rm -f "$SRCERY_DATA/status/st_wt/st-svc"
@svc-stop "$win" >/dev/null

report
