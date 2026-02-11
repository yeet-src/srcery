**Keep this file up to date.** Aggressively update it every session —
after adding commands, changing conventions, or learning preferences.
Keep style terse — no filler, no restating what's readable from source.
**Always verify your work** — run `make check_lint`, test commands, etc.
before declaring something done. Don't assume tool flags or syntax; check.

# Project

**srcery** orchestrates dependencies and workflows across the yeet-src
multi-repo project (sibling directories under `yeet/`). Mostly lightweight
scripts that call into real code in those other repos.

# Layout

- `cmd/` — executable commands, on `PATH` via direnv
- `cmd/srcery-bash` — shebang target (`#!/usr/bin/env srcery-bash`); `cd`s to
  `$SRCERY_ROOT`, sets `set -euo pipefail` (propagated via `SHELLOPTS`),
  exports shared helpers (`die`, `srcery_tmux`), then `exec bash "$@"`
- `completions/` — zsh completion files (`_@command` with `#compdef` headers)
- `data/` — gitignored runtime data (e.g. worktrees); path overridable via `SRCERY_DATA`
- `test/` — test scripts

# Env vars (set by `.envrc`)

- `SRCERY_ROOT` — this project
- `YEET_SRC_ROOT` — parent dir (org root with sibling repos)
- `SRCERY_DATA` — data dir; defaults to `$SRCERY_ROOT/data` (set in `srcery-bash`)
- `EXTRA_FPATH` — completions dir; picked up by user's zsh precmd hook

# Commands

- `@dev REPO [BRANCH [BASE]]` — create worktree + start claude as service + attach in tmux
- `@wt-create REPO [BRANCH [BASE]]` — create worktree (BRANCH = new branch name, BASE = start point)
- `@wt-list [REPO]` — list worktrees, optionally filtered
- `@wt-remove NAME` — stop services + remove worktree
- `@wt-clear` — remove all worktrees (y/n confirmation)
- `@svc-start WT NAME CMD...` — start CMD in tmux window (`srcery` session)
- `@svc-stop WINDOW` — kill tmux window (auto-unlinks from all sessions)
- `@svc-list [-w PAT] [-n PAT]` — list services; `-w` filters by worktree, `-n` by name
- `@attach [TARGET]` — attach to tmux session (no arg=all, `<wt>`=worktree, `@<name>`=by name)
- `@help` — print command reference

# tmux service architecture

Services are tmux windows. Filtered views are sessions with linked windows.

- Master session `srcery` — all service windows
- `srcery/<wt_name>` — per-worktree session (linked windows)
- `srcery/@<svc_name>` — per-name session (linked windows)
- Window name format: `<wt_name>/<svc_name>` (e.g. `wt_a1b2_repo/run`)
- `remain-on-exit on` globally on srcery tmux server — dead services stay inspectable
- Dedicated tmux socket: `SRCERY_TMUX_SOCKET` (defaults to `srcery`, tests use `srcery-test`)
- `srcery_tmux` wrapper always uses `-L $SRCERY_TMUX_SOCKET`
- Attach: `@attach` (or raw: `tmux -L srcery attach -t srcery`)

# Repo hooks

Repos define optional make targets that `@wt-create` calls:
- `make wt_init` — build/setup (e.g. `cp -r node_modules`)
- `make wt_run` — long-running service (run via `@svc-start`)

# Shell style

- `#!/usr/bin/env srcery-bash` (no `set -euo pipefail` — srcery-bash handles it)
- Use `die "msg"` (exported from srcery-bash) not `echo >&2; exit 1`
- Prefer `[[ condition ]] || action` over `if` for single-line checks
- `[[ ]]` not `[ ]`

# Lint & Test

- `make check_lint` — shellcheck all `cmd/` scripts (CI check)
- `make lint` — shellcheck + auto-apply fixes
- `make test` — run tests (`test/test-svc.sh`); operates entirely in tmpdir

# Nix

Optional. Flake provides a nixpkgs pin and dev shell. `nix develop` or direnv.
`shellcheck` provided via flake.

# Zsh completions

direnv can't modify `fpath`. We export `EXTRA_FPATH` and the user adds a
`precmd` hook to their `.zshrc` that prepends it to `fpath` + runs `compinit`.
Completion files must guard against empty lists (`(( ${#arr} )) && _values ...`).
