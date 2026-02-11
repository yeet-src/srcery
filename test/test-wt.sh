#!/usr/bin/env bash
# Tests for @wt-create, @wt-remove, @wt-list, @wt-clear
source "$(dirname "$0")/helpers.sh"

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
echo "--- @wt-remove with sibling services (regression) ---"
# Bug: [[ test ]] && action in piped while loop returns exit 1 when
# no windows match, killing the script via set -e + pipefail.

setup_repo regr_repo

wt_a=$(@wt-create regr_repo regr-has-svc)
wt_b=$(@wt-create regr_repo regr-no-svc)
name_a=$(basename "$wt_a")
name_b=$(basename "$wt_b")

@svc-start "$wt_a" some-svc sleep 999 >/dev/null

t "wt-remove succeeds when sibling worktree has services"
@wt-remove "$name_b"
assert_not test -d "$wt_b"

t "sibling worktree still exists"
assert test -d "$wt_a"

t "wt-clear removes all remaining worktrees"
echo "y" | @wt-clear >/dev/null 2>&1
list=$(@wt-list)
assert_not contains "$list" "$name_a"

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

report
