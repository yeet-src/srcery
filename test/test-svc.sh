#!/usr/bin/env bash
set -euo pipefail

SRCERY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export SRCERY_ROOT
export PATH="$SRCERY_ROOT/cmd:$PATH"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

export SRCERY_DATA="$tmpdir/data"
export YEET_SRC_ROOT="$tmpdir/repos"
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

# --- setup: create a git repo to make worktrees from ---
setup_repo() {
	local repo="$YEET_SRC_ROOT/$1"
	mkdir -p "$repo"
	git -C "$repo" init -q
	git -C "$repo" commit -q --allow-empty -m "init"
}

# ===================
echo "--- @svc-start / @svc-stop ---"

t "svc-start creates metadata files"
uuid=$(@svc-start "$tmpdir" test-svc sleep 999)
svc_dir="$SRCERY_DATA/svcs/$uuid"
assert test -f "$svc_dir/worktree"
assert test -f "$svc_dir/name"
assert test -f "$svc_dir/pid"
assert test -f "$svc_dir/out"
assert test -f "$svc_dir/err"

t "svc-start stores correct worktree"
assert test "$(<"$svc_dir/worktree")" = "$tmpdir"

t "svc-start stores correct name"
assert test "$(<"$svc_dir/name")" = "test-svc"

t "svc-start process is alive"
pid=$(<"$svc_dir/pid")
assert kill -0 "$pid"

t "svc-stop kills process and cleans up"
@svc-stop "$uuid" >/dev/null
sleep 0.1
assert_not kill -0 "$pid" 2>/dev/null
assert_not test -d "$svc_dir"

# ===================
echo "--- @svc-list ---"

uuid1=$(@svc-start "$tmpdir/a" svc-a sleep 999)
uuid2=$(@svc-start "$tmpdir/b" svc-b sleep 999)

t "svc-list shows both services"
list=$(@svc-list)
assert contains "$list" "$uuid1"
assert contains "$list" "$uuid2"

t "svc-list -n filters by name"
list=$(@svc-list -n svc-a)
assert contains "$list" "$uuid1"
assert_not contains "$list" "$uuid2"

t "svc-list -w filters by worktree"
list=$(@svc-list -w "/b")
assert_not contains "$list" "$uuid1"
assert contains "$list" "$uuid2"

# cleanup
@svc-stop "$uuid1" >/dev/null
@svc-stop "$uuid2" >/dev/null

# ===================
echo "--- @svc-logs ---"

t "svc-logs captures stdout"
uuid=$(@svc-start "$tmpdir" echo-svc bash -c 'echo hello-from-svc')
sleep 0.3
assert contains "$(<"$SRCERY_DATA/svcs/$uuid/out")" "hello-from-svc"
@svc-stop "$uuid" >/dev/null 2>&1 || true

t "svc-logs captures stderr"
uuid=$(@svc-start "$tmpdir" err-svc bash -c 'echo oops >&2')
sleep 0.3
assert contains "$(<"$SRCERY_DATA/svcs/$uuid/err")" "oops"
@svc-stop "$uuid" >/dev/null 2>&1 || true

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

t "wt-list filters by repo"
list=$(@wt-list fakerepo)
assert contains "$list" "$wt_name"
list=$(@wt-list nonexistent || true)
assert_not contains "${list:-}" "$wt_name"

t "wt-remove removes the worktree"
@wt-remove "$wt_name"
assert_not test -d "$wt_path"

# ===================
echo "--- @wt-create with make hooks ---"

setup_repo hookrepo
cat > "$YEET_SRC_ROOT/hookrepo/Makefile" <<'MAKEFILE'
.PHONY: wt-init wt-run
wt-init:
	touch .initialized
wt-run:
	sleep 999
MAKEFILE
git -C "$YEET_SRC_ROOT/hookrepo" add -A
git -C "$YEET_SRC_ROOT/hookrepo" commit -q -m "add Makefile"

t "wt-create runs wt-init"
wt_path=$(@wt-create hookrepo)
assert test -f "$wt_path/.initialized"

t "wt-create starts wt-run as a service"
list=$(@svc-list -w "$wt_path")
assert contains "$list" "running"

t "wt-remove stops the service"
wt_name=$(basename "$wt_path")
@wt-remove "$wt_name"
sleep 0.2
list=$(@svc-list 2>/dev/null || true)
assert_not contains "${list:-}" "$wt_name"

# ===================
echo ""
echo "--- Results: $pass passed, $fail failed ---"
[[ $fail -eq 0 ]]
