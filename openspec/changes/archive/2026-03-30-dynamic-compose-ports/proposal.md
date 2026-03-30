## Why

Beam currently hardcodes two wasp-specific ports (3000/3001), reading `WASP_CLIENT_PORT` and `WASP_SERVER_PORT` from `.env`. Real projects run many more services (Postgres, Redis, Qdrant, FastAPI, etc.) all defined in `docker-compose.dev.yml`. Developers must manually tunnel these extra ports or go without. The compose file already declares every port mapping — beam should read it and tunnel all of them automatically.

## What Changes

- **Parse `docker-compose.dev.yml`** from the selected worktree on the remote host to discover all port mappings
- **Resolve port variables** against the worktree's `.env` to get actual remote host ports
- **Map local ports to compose defaults** — the default/fallback value in `${VAR:-DEFAULT}` becomes the local port, giving the developer canonical ports (`localhost:5432`, `localhost:3000`, etc.) regardless of worktree
- **Build N SSH tunnels** dynamically instead of exactly 2
- **BREAKING**: Replace the 4 named port fields in session state (`local_client_port`, `local_server_port`, `remote_client_port`, `remote_server_port`) with a `ports` array
- **Remove local port prompts** — local ports are determined by the compose file, not user input
- **Update conflict detection** to check all N ports against live sessions
- **Update conflict resolution** — on conflict, prompt user to tear down the existing session (y/N) instead of asking for alternate ports

## Capabilities

### New Capabilities
- `compose-port-discovery`: Parse `docker-compose.dev.yml` port mappings and resolve variables against `.env` to produce a list of local/remote port pairs
- `dynamic-tunnels`: Build and manage SSH tunnels for an arbitrary number of port pairs instead of a fixed two

### Modified Capabilities
- `session-lifecycle`: Session creation no longer prompts for local ports; reads compose file instead. Session state stores a `ports` array. Conflict resolution changes to tear-down-or-abort.
- `tunnel-management`: `start_tunnel` accepts N port pairs. `find_port_conflicts` checks N ports. `print_ports` renders N rows.

## Impact

- **`beam` script**: Major changes to `cmd_session_create`, `start_tunnel`, `find_port_conflicts`, `print_ports`, session state read/write, and dashboard rendering
- **State file** (`~/.local/state/beam/state.json`): Schema change — existing sessions with old port fields will be incompatible
- **Tests**: All port-related tests need updating for the new array-based port model
- **No new dependencies**: Compose parsing uses grep/sed on the remote host (no YAML parser needed)
