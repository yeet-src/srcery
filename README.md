# srcery

Orchestrates dependencies and workflows across the yeet-src multi-repo project
(sibling directories under `yeet/`). Lightweight scripts that call into real
code in those other repos.

## Setup

Requires [direnv](https://direnv.net/) and optionally [Nix](https://nixos.org/)
(provides shellcheck, tmux via flake).

```
cd yeet/srcery
direnv allow
```

### Shell completions

direnv can't modify shell-internal completion paths, so you need a small
snippet in your shell config. The `.envrc` exports the env vars; your
config wires them in.

**zsh** — add to `~/.zshrc`:

```zsh
_srcery_fpath_hook() {
  if [[ -n "$EXTRA_FPATH" ]] && (( ! ${fpath[(I)$EXTRA_FPATH]} )); then
    fpath=("$EXTRA_FPATH" $fpath)
    compinit
  fi
}
add-zsh-hook precmd _srcery_fpath_hook
```

**fish** — add to `~/.config/fish/config.fish` (after `direnv hook fish | source`):

```fish
function _srcery_fish_completions --on-variable EXTRA_FISH_COMPLETE_PATH
    if set -q EXTRA_FISH_COMPLETE_PATH; and not contains $EXTRA_FISH_COMPLETE_PATH $fish_complete_path
        set -p fish_complete_path $EXTRA_FISH_COMPLETE_PATH
    end
end
_srcery_fish_completions  # run once at startup in case already set
```

## Quick start

```
@dev REPO   # create worktree, start claude, attach in tmux
```

## Commands

### Worktrees

```
@wt-create REPO       Create a worktree for REPO, setup & run
@wt-list [REPO]       List worktrees, optionally filtered by REPO
@wt-remove NAME       Remove a worktree (stops its services)
@wt-clear             Remove all worktrees (with confirmation)
```

### Services

Services are tmux windows on a dedicated socket (`-L srcery`).

```
@svc-start WT NAME CMD...    Start CMD in tmux window
@svc-stop WINDOW             Stop service (kill tmux window)
@svc-list [-w PAT] [-n PAT]  List services, filter by worktree/name
```

### Sessions

```
@shell WT_NAME           Start a shell in a worktree + attach
@attach                  Attach to all services
@attach <wt>             Attach to one worktree's services
@attach @<name>          Attach to all services with a given name
```

### Repo hooks

Repos define optional make targets that `@wt-create` calls:

- `make wt_init` — build/setup (e.g. `cp -r node_modules`)
- `make wt_run` — long-running service (started via `@svc-start`)

## Development

```
make check_lint   # shellcheck all cmd/ scripts
make test         # run test suite
```
