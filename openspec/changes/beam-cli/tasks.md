## 1. Foundation

- [x] 1.1 Create `beam` script at `~/.local/bin/beam` with shebang, `set -euo pipefail`, and `jq` dependency check
- [x] 1.2 Implement state file initialization — create `~/.local/state/beam/state.json` with `{"spaces": {}}` if it doesn't exist
- [x] 1.3 Implement state read/write helper functions (`read_state`, `write_state`) using `jq`
- [x] 1.4 Implement subcommand routing — parse positional arguments to dispatch to `space`, `hydrate`, dashboard, or `<space> <action>` handlers

## 2. Space Management

- [x] 2.1 Implement `beam space ls` — list all space names from state
- [x] 2.2 Implement `beam space create <name>` — add empty space to state, error if exists
- [x] 2.3 Implement `beam space rm <name>` — remove space if empty, error if non-empty without `--force`, kill tunnels and remove all sessions with `--force`

## 3. Tunnel Core

- [x] 3.1 Implement `start_tunnel` function — runs `ssh -fN -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -L ... -L ... <host>`, captures PID, updates state
- [x] 3.2 Implement `kill_tunnel` function — sends SIGTERM to stored PID, verifies exit, clears PID in state
- [x] 3.3 Implement `check_health` function — verify PID is running and local ports are bound via `lsof -i :<port>`
- [x] 3.4 Implement `find_port_conflicts` function — scan all live sessions across all spaces for local port collisions

## 4. Session Lifecycle

- [x] 4.1 Implement `beam <space> create` — prompt for SSH host, SSH in to scan `~/codebases/`, display projects and worktree selection, read `.env` for ports, prompt for local ports (default/custom), auto-name session as `host:worktree`, create session in state, and activate tunnel
- [x] 4.2 Implement `beam <space> ls` — display sessions in a space with name, host, port mappings, and status
- [x] 4.3 Implement `beam <space> up <session>` — check for port conflicts, prompt to sleep conflicting session if needed, start tunnel
- [x] 4.4 Implement `beam <space> down <session>` — kill tunnel, mark session dormant
- [x] 4.5 Implement `beam <space> rm <session>` — kill tunnel if live, remove session from state
- [x] 4.6 Implement `beam <space> switch <session>` — detect port conflicts, prompt y/n to sleep conflicting session, activate target session

## 5. Dashboard

- [x] 5.1 Implement `beam` (no args) — display all spaces and sessions, run health checks on live sessions, show ●/blank for live/dormant, show port mappings and health status, suggest `beam hydrate` if dead tunnels found

## 6. Hydration

- [x] 6.1 Implement `beam hydrate` — iterate all live sessions across all spaces, check health, reconnect dead tunnels, skip healthy ones, handle conflicts and failures gracefully, report per-session results

## 7. Cleanup & Install

- [x] 7.1 Remove old `ssf` script from `~/.local/bin/ssf`
- [x] 7.2 Make `beam` executable and verify it runs from any terminal
- [x] 7.3 End-to-end manual test: create space, create session, verify tunnel, down/up/switch, hydrate, rm session, rm space
