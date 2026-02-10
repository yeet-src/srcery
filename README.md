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

Attach to filtered views:

```
tmux -L srcery attach -t srcery             # all services
tmux -L srcery attach -t 'srcery/<wt>'      # one worktree's services
tmux -L srcery attach -t 'srcery/@<name>'   # all services with a given name
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
