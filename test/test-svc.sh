#!/usr/bin/env bash
set -euo pipefail

SRCERY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export SRCERY_ROOT
export PATH="$SRCERY_ROOT/cmd:$PATH"

tmpdir=$(mktemp -d)
trap 'tmux -L srcery-test kill-server 2>/dev/null || true; rm -rf "$tmpdir"' EXIT

export SRCERY_DATA="$tmpdir/data"
export YEET_SRC_ROOT="$tmpdir/repos"
export SRCERY_TMUX_SOCKET="srcery-test"
mkdir -p "$YEET_SRC_ROOT"

pass=0
fail=0
test_name=""

t()          { test_name="$1"; }
ok()         { pass=$((pass + 1)); echo "  ok: $test_name"; }
fail()       { fail=$((fail + 1)); echo "FAIL: $test_name"; }
assert()     { if "$@"; then ok; else fail; fi; }
assert_not() { if "$@"; then fail; else ok; fi; }
contains()   { [[ "$1" == *"$2"* ]]; }

# helper: query tmux
tmux_windows() {
	tmux -L srcery-test list-windows -t "=srcery" -F '#{window_name}' 2>/dev/null || true
}

# --- setup: create a git repo to make worktrees from ---
setup_repo() {
	local repo="$YEET_SRC_ROOT/$1"
	mkdir -p "$repo"
	git -C "$repo" init -q
	git -C "$repo" commit -q --allow-empty -m "init"
}

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
echo "--- @svc-list status ---"

mkdir -p "$tmpdir/deadwt"
win=$(@svc-start "$tmpdir/deadwt" die-svc bash -c 'exit 1')
sleep 0.5

t "svc-list shows dead status"
list=$(@svc-list)
assert contains "$list" "dead"

@svc-stop "$win" >/dev/null

# ===================
echo "--- @wt-create / @wt-remove ---"

setup_repo fakerepo

t "wt-create creates a worktree"
wt_path=$(@wt-create fakerepo)
assert test -d "$wt_path"
assert test -f "$wt_path/.git"

t "wt-list shows the worktree"
wt_name=$(basename "$wt_path")
list=$(@wt-list)
assert contains "$list" "$wt_name"

t "wt-list has header"
assert contains "$list" "NAME"

t "wt-list shows repo and branch columns"
# tab-separated: NAME\tREPO\tBRANCH\tSERVICES
row=$(echo "$list" | grep "$wt_name")
assert contains "$row" "fakerepo"

t "wt-list filters by repo"
list=$(@wt-list fakerepo)
assert contains "$list" "$wt_name"
list=$(@wt-list nonexistent || true)
assert_not contains "${list:-}" "$wt_name"

t "wt-remove removes the worktree"
@wt-remove "$wt_name"
assert_not test -d "$wt_path"

# ===================
echo "--- @wt-create with branch name ---"

t "wt-create REPO BRANCH names the branch and worktree"
wt_path=$(@wt-create fakerepo my-feature)
wt_name=$(basename "$wt_path")
assert test "$wt_name" = "my-feature"
branch=$(git -C "$wt_path" branch --show-current)
assert test "$branch" = "my-feature"
@wt-remove "$wt_name"

t "wt-create REPO BRANCH with / sanitizes dir name"
wt_path=$(@wt-create fakerepo feat/slash-test)
wt_name=$(basename "$wt_path")
assert test "$wt_name" = "feat-slash-test"
branch=$(git -C "$wt_path" branch --show-current)
assert test "$branch" = "feat/slash-test"
@wt-remove "$wt_name"

t "wt-create REPO BRANCH BASE starts from base"
git -C "$YEET_SRC_ROOT/fakerepo" checkout -q -b base-branch
git -C "$YEET_SRC_ROOT/fakerepo" commit -q --allow-empty -m "base commit"
base_sha=$(git -C "$YEET_SRC_ROOT/fakerepo" rev-parse base-branch)
git -C "$YEET_SRC_ROOT/fakerepo" checkout -q master

wt_path=$(@wt-create fakerepo from-base base-branch)
wt_sha=$(git -C "$wt_path" rev-parse HEAD)
assert test "$wt_sha" = "$base_sha"
@wt-remove "$(basename "$wt_path")"

t "wt-create reuses existing worktree"
wt_path=$(@wt-create fakerepo reuse-me)
wt_path2=$(@wt-create fakerepo reuse-me)
assert test "$wt_path" = "$wt_path2"
@wt-remove "$(basename "$wt_path")"

t "wt-create checks out existing branch without -b"
git -C "$YEET_SRC_ROOT/fakerepo" checkout -q -b existing-branch
git -C "$YEET_SRC_ROOT/fakerepo" commit -q --allow-empty -m "existing"
existing_sha=$(git -C "$YEET_SRC_ROOT/fakerepo" rev-parse existing-branch)
git -C "$YEET_SRC_ROOT/fakerepo" checkout -q master

wt_path=$(@wt-create fakerepo existing-branch)
wt_sha=$(git -C "$wt_path" rev-parse HEAD)
assert test "$wt_sha" = "$existing_sha"
branch=$(git -C "$wt_path" branch --show-current)
assert test "$branch" = "existing-branch"
@wt-remove "$(basename "$wt_path")"

# ===================
echo "--- @wt-create with make hooks ---"

setup_repo hookrepo
cat > "$YEET_SRC_ROOT/hookrepo/Makefile" <<'MAKEFILE'
.PHONY: wt_init wt_run
wt_init:
	touch .initialized
wt_run:
	sleep 999
MAKEFILE
git -C "$YEET_SRC_ROOT/hookrepo" add -A
git -C "$YEET_SRC_ROOT/hookrepo" commit -q -m "add Makefile"

t "wt-create runs wt_init"
wt_path=$(@wt-create hookrepo)
assert test -f "$wt_path/.initialized"

t "wt-create starts wt_run as a service"
wt_name=$(basename "$wt_path")
list=$(@svc-list -w "$wt_name")
assert contains "$list" "running"

t "wt-create uses 'run' as service name"
assert contains "$list" "${wt_name}/run"

t "wt-list shows running services"
wt_list=$(@wt-list)
wt_row=$(echo "$wt_list" | grep "$wt_name")
assert contains "$wt_row" "run"

t "wt-remove stops the service"
@wt-remove "$wt_name"
sleep 0.2
list=$(@svc-list 2>/dev/null || true)
assert_not contains "${list:-}" "$wt_name"

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

# ===================
echo ""
echo "--- Results: $pass passed, $fail failed ---"
[[ $fail -eq 0 ]]
