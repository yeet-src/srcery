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
  exports shared helpers (`die`), then `exec bash "$@"`
- `completions/` — zsh completion files (`_@command` with `#compdef` headers)
- `data/` — gitignored runtime data (e.g. worktrees, svcs); path overridable via `SRCERY_DATA`
- `test/` — test scripts

# Env vars (set by `.envrc`)

- `SRCERY_ROOT` — this project
- `YEET_SRC_ROOT` — parent dir (org root with sibling repos)
- `SRCERY_DATA` — data dir; defaults to `$SRCERY_ROOT/data` (set in `srcery-bash`)
- `EXTRA_FPATH` — completions dir; picked up by user's zsh precmd hook

# Commands

- `@wt-create REPO` — create worktree, run repo-defined hooks, start services
- `@wt-list [REPO]` — list worktrees, optionally filtered
- `@wt-remove NAME` — stop services + remove worktree
- `@wt-clear` — remove all worktrees (y/n confirmation)
- `@svc-start WT NAME CMD...` — background CMD, store metadata in `data/svcs/<uuid>/`
- `@svc-stop UUID` — kill process, clean up svc dir
- `@svc-list [-w PAT] [-n PAT]` — list services; `-w` filters by worktree, `-n` by name
- `@svc-logs UUID [out|err]` — `tail -f` service stdout or stderr
- `@help` — print command reference

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
