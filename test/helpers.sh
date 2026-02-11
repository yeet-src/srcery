#!/usr/bin/env bash
set -euo pipefail

SRCERY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export SRCERY_ROOT
export PATH="$SRCERY_ROOT/cmd:$SRCERY_ROOT/lib:$PATH"

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

# create a git repo to make worktrees from
setup_repo() {
	local repo="$YEET_SRC_ROOT/$1"
	mkdir -p "$repo"
	git -C "$repo" init -q
	git -C "$repo" commit -q --allow-empty -m "init"
}

report() {
	echo ""
	echo "--- Results: $pass passed, $fail failed ---"
	[[ $fail -eq 0 ]]
}
