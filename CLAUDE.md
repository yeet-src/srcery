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
  `$SRCERY_ROOT`, exports shared helpers (`die`, `srcery_tmux`), then
  `exec bash -euo pipefail "$@"` (options on exec, NOT via `export SHELLOPTS`)
- `lib/` — internal helper scripts, on `PATH` via `srcery-bash`
- `lib/srcery-notify` — Claude Code hook script for status notifications
- `completions/completers/` — bash scripts that output candidates (one per line)
- `completions/generate` — produces `zsh/` and `fish/` wrappers from completers
- `completions/zsh/` — generated zsh completions (do not edit; run `make completions`)
- `completions/fish/` — generated fish completions (do not edit; run `make completions`)
- `data/` — gitignored runtime data (e.g. worktrees); path overridable via `SRCERY_DATA`
- `data/status/<wt>/<svc>` — service status files written by hooks (idle, attention)
- `hooks/by-repo/<repo>/` — per-repo hooks (`init`, `run`); take `$wt_path` as `$1`
- `test/` — test scripts

# Env vars (set by `.envrc`)

- `SRCERY_ROOT` — this project
- `YEET_SRC_ROOT` — parent dir (org root with sibling repos)
- `SRCERY_DATA` — data dir; defaults to `$SRCERY_ROOT/data` (set in `srcery-bash`)
- `EXTRA_FPATH` — zsh completions dir; picked up by user's zsh precmd hook
- `EXTRA_FISH_COMPLETE_PATH` — fish completions dir; user sources in fish config

# Commands

- `@dev REPO [BRANCH [BASE]]` — create worktree + start claude as service + attach in tmux
  - Writes `.claude/settings.local.json` with notification hooks
  - Uses `--append-system-prompt` for background agent instructions
  - `CLAUDE_BIN` env var overrides claude binary (for testing)
- `@wt-create REPO [BRANCH [BASE]]` — create worktree (BRANCH = new branch name, BASE = start point)
- `@wt-list [REPO]` — list worktrees, optionally filtered
- `@wt-remove NAME` — stop services + remove worktree
- `@wt-clear` — remove all worktrees (y/n confirmation)
- `@svc-start WT_PATH NAME CMD...` — start CMD in tmux window, returns window ID (`@N`)
- `@svc-stop WINDOW_ID` — kill tmux window by ID (`@N`), cleans up status file
- `@svc-list [-w PAT] [-n PAT]` — list services; `-w` filters by worktree, `-n` by name
- `@shell WT_NAME` — start a shell in a worktree + attach
- `@attach [TARGET]` — attach to tmux (no arg=master, `<wt>`=ephemeral worktree session, `@<name>`=ephemeral name session)
- `@help` — print command reference

# tmux service architecture

Services are tmux windows. Worktree association derived from `#{pane_current_path}` at query time.

- Master session `srcery` — all service windows
- Window names = just the service name: `claude`, `run`, `shell`, `shell-2`
- Duplicate names allowed across worktrees (same name + different CWD)
- Windows targeted by tmux window ID (`@0`, `@1`, etc.) — always unambiguous
- No eager linked sessions — `@attach` creates ephemeral filtered sessions on demand
  - `srcery/<wt>` with `destroy-unattached on` — auto-cleaned on detach
  - `srcery/@<name>` with `destroy-unattached on`
- Worktree association: `basename(#{pane_current_path})` = wt_name
- All path comparisons use `pwd -P` (macOS `/tmp` → `/private/tmp`)
- `remain-on-exit on` globally on srcery tmux server — dead services stay inspectable
- Dedicated tmux socket: `SRCERY_TMUX_SOCKET` (defaults to `srcery`, tests use `srcery-test`)
- `srcery_tmux` wrapper always uses `-L $SRCERY_TMUX_SOCKET`
- Attach: `@attach` (or raw: `tmux -L srcery attach -t srcery`)

# Claude Code notification hooks

`@dev` wires Claude Code hooks via `.claude/settings.local.json` in the worktree:
- `Notification` (idle_prompt, permission_prompt) → writes status to `data/status/`, sends macOS notification (osascript) or terminal bell fallback
- `UserPromptSubmit` → clears status file
- `@svc-list` and `@wt-list` show these statuses (idle, attention) instead of "running"
- `SRCERY_SVC_WINDOW` env var tells the hook which status file to write

# Repo hooks

`@wt-create` checks for hooks in `hooks/by-repo/<repo>/` first, falls back to make targets:
- `hooks/by-repo/<repo>/init` — setup script, receives `$wt_path` as `$1`
- `hooks/by-repo/<repo>/run` — long-running service, receives `$wt_path` as `$1` (run via `@svc-start`)
- Fallback: `make wt_init` / `make wt_run` targets in the repo Makefile

# Shell style

- `#!/usr/bin/env srcery-bash` (no `set -euo pipefail` — srcery-bash handles it)
- Use `die "msg"` (exported from srcery-bash) not `echo >&2; exit 1`
- Prefer `[[ condition ]] || action` over `if` for single-line checks
- `[[ ]]` not `[ ]`

# Lint & Test

- `make check_lint` — shellcheck all `cmd/`, `lib/`, `hooks/`, and `completions/completers/` scripts (CI check)
- `make lint` — shellcheck + auto-apply fixes
- `make completions` — regenerate zsh + fish wrappers from completers
- `make test` — run tests (`test/test-svc.sh`); operates entirely in tmpdir

# Nix

Optional. Flake provides a nixpkgs pin and dev shell. `nix develop` or direnv.
`shellcheck` provided via flake.

# Shell completions (zsh + fish)

Completion logic lives in `completions/completers/` (bash scripts). Run
`make completions` (or `completions/generate`) to regenerate `zsh/` and `fish/`
wrappers. Both generated dirs are committed. `@svc-list` is a special case
(flags only) — emitted directly by the generator.

**zsh**: direnv exports `EXTRA_FPATH`; user adds a precmd hook to `.zshrc`
that prepends it to `fpath` + runs `compinit`.

**fish**: direnv exports `EXTRA_FISH_COMPLETE_PATH`; user sources completions
from that dir in their fish config.
