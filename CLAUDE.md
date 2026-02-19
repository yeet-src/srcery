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
  `$SRCERY_ROOT`, exports shared helpers (`die`, `srcery_tmux`, `srcery_new_window`),
  then `exec bash -euo pipefail "$@"` (options on exec, NOT via `export SHELLOPTS`)
- `lib/` — internal helper scripts, on `PATH` via `srcery-bash`
- `lib/srcery-notify` — Claude Code hook script for status notifications (self-discovering)
- `completions/completers/` — bash scripts that output candidates (one per line)
- `completions/generate` — produces `zsh/` and `fish/` wrappers from completers
- `completions/zsh/` — generated zsh completions (do not edit; run `make completions`)
- `completions/fish/` — generated fish completions (do not edit; run `make completions`)
- `data/` — gitignored runtime data (e.g. worktrees); path overridable via `SRCERY_DATA`
- `data/status/<wt>/%<pane_id>` — status files written by hooks (idle, attention), keyed by tmux pane ID
- `hooks/global/` — global hooks (`init`, `run`); run before repo hooks
- `hooks/by-repo/<repo>/` — per-repo hooks (`init`, `run`); take `$wt_path` as `$1`
- `test/` — test scripts

# Env vars (set by `.envrc`)

- `SRCERY_ROOT` — this project
- `YEET_SRC_ROOT` — parent dir (org root with sibling repos)
- `SRCERY_DATA` — data dir; defaults to `$SRCERY_ROOT/data` (set in `srcery-bash`)
- `EXTRA_FPATH` — zsh completions dir; picked up by user's zsh precmd hook
- `EXTRA_FISH_COMPLETE_PATH` — fish completions dir; user sources in fish config

# Commands

- `@dev REPO [BRANCH [BASE]]` — create worktree + start claude + shell + attach
  - Calls `@install-hooks` to ensure global hooks are present
  - Uses `--append-system-prompt` for background agent instructions
  - `CLAUDE_BIN` env var overrides claude binary (for testing)
- `@install-hooks` — merge srcery notification hooks into `~/.claude/settings.json` (idempotent)
- `@wt-create REPO [BRANCH [BASE]]` — create worktree (BRANCH = new branch name, BASE = start point)
- `@wt-list [REPO]` — list worktrees with pane commands and status
- `@ps [FILTER]` — detailed pane view: full command strings, grouped by worktree, nested under window names
- `@wt-remove NAME` — kill tmux windows + remove worktree
- `@wt-clear` — remove all worktrees (y/n confirmation)
- `@shell WT_NAME` — start a shell in a worktree + attach
- `@attach [TARGET]` — attach to tmux (no arg=master, `<wt>`=ephemeral worktree session, `@<name>`=ephemeral name session)
- `@help` — print command reference

# tmux architecture

All windows live on the srcery master session. No service abstraction — tmux is used directly.

- `srcery_new_window NAME PATH [CMD...]` — exported helper: ensures session, creates window, prints window ID
- Master session `srcery` — all windows
- Window names = descriptive: `claude`, `run`, `shell`, `storybook`
- Duplicate names allowed across worktrees (same name + different CWD)
- Worktree association: `basename(#{pane_current_path})` = wt_name
- `@attach` creates ephemeral filtered sessions on demand
  - `srcery/<wt>` with `destroy-unattached on` — auto-cleaned on detach
  - `srcery/@<name>` with `destroy-unattached on`
- All path comparisons use `pwd -P` (macOS `/tmp` → `/private/tmp`)
- `remain-on-exit on` globally on srcery tmux server — dead windows stay inspectable
- Dedicated tmux socket: `SRCERY_TMUX_SOCKET` (defaults to `srcery`, tests use `srcery-test`)
- `srcery_tmux` wrapper always uses `-L $SRCERY_TMUX_SOCKET`

# Claude Code notification hooks

Hooks are installed globally in `~/.claude/settings.json` via `@install-hooks`.
`srcery-notify` is self-discovering — it checks `$TMUX` and `$TMUX_PANE` to determine context:
- Bail if not in tmux, or wrong socket, or CWD isn't a managed worktree
- `Notification` (idle_prompt, permission_prompt) → writes status to `data/status/<wt>/%<pane_id>`, sends macOS notification
- `UserPromptSubmit` → clears status file
- `@wt-list` shows these statuses (idle, attention) next to pane commands

# Hooks

`@wt-create` runs hooks in order: global init → repo init → global run → repo run.
- `hooks/global/{init,run}` — optional, always run
- `hooks/by-repo/<repo>/{init,run}` — per-repo, take `$wt_path` as `$1`
- Fallback for repo hooks: `make wt_init` / `make wt_run` targets in the repo Makefile
- Run hooks use `srcery_new_window` to start tmux windows

# Shell style

- `#!/usr/bin/env srcery-bash` (no `set -euo pipefail` — srcery-bash handles it)
- Use `die "msg"` (exported from srcery-bash) not `echo >&2; exit 1`
- Prefer `[[ condition ]] || action` over `if` for single-line checks
- `[[ ]]` not `[ ]`

# Lint & Test

- `make check_lint` — shellcheck all `cmd/`, `lib/`, `hooks/`, and `completions/completers/` scripts (CI check)
- `make lint` — shellcheck + auto-apply fixes
- `make completions` — regenerate zsh + fish wrappers from completers
- `make test` — run tests (`test/test-tmux.sh`); operates entirely in tmpdir

# Nix

Optional. Flake provides a nixpkgs pin and dev shell. `nix develop` or direnv.
`shellcheck` provided via flake.

# Shell completions (zsh + fish)

Completion logic lives in `completions/completers/` (bash scripts). Run
`make completions` (or `completions/generate`) to regenerate `zsh/` and `fish/`
wrappers. Both generated dirs are committed.

**zsh**: direnv exports `EXTRA_FPATH`; user adds a precmd hook to `.zshrc`
that prepends it to `fpath` + runs `compinit`.

**fish**: direnv exports `EXTRA_FISH_COMPLETE_PATH`; user sources completions
from that dir in their fish config.
