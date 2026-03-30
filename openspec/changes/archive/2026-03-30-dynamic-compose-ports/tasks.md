## 1. Compose Parsing & Port Resolution

- [x] 1.1 Create `parse_compose_ports` function: SSH to remote, grep `docker-compose.dev.yml` for port lines, extract variable name + default + service name for each entry
- [x] 1.2 Create `resolve_ports` function: take parsed port entries + `.env` contents, resolve each variable to produce `[{local, remote, service}]` JSON array
- [x] 1.3 Handle edge cases: missing compose file (fatal error), missing `.env` (use defaults), unrecognized port format (skip with warning)

## 2. Session State Migration

- [x] 2.1 Update `read_session` to return ports as a JSON array instead of four named fields; treat sessions with old format as zero-port (dead)
- [x] 2.2 Update session creation in `cmd_session_create` to write `ports` array to state instead of `local_client_port`, `local_server_port`, `remote_client_port`, `remote_server_port`

## 3. Tunnel Management

- [x] 3.1 Rewrite `start_tunnel` to accept host + ports JSON array, build `ssh -fN` with N `-L` flags dynamically
- [x] 3.2 Update `find_port_conflicts` to accept a list of local ports and check each against all local ports of every live session
- [x] 3.3 Update `resolve_conflict` / `check_and_resolve_conflicts` to use tear-down-or-abort prompt instead of alternate port selection
- [x] 3.4 Update `print_ports` to iterate ports array and render one line per entry with service label

## 4. Session Creation Flow

- [x] 4.1 Replace `.env`-only port reading in `cmd_session_create` with `parse_compose_ports` + `resolve_ports`
- [x] 4.2 Remove local port prompts (lines 773-778) — local ports come from compose defaults
- [x] 4.3 Update worktree preview to show service count from compose instead of client port
- [x] 4.4 Update `activate_and_report` and any callers to work with ports array

## 5. Dashboard & Display

- [x] 5.1 Update dashboard rendering to display N port rows per session with service labels
- [x] 5.2 Update `cmd_session_ls` and any other session display commands to use new port format

## 6. Tests

- [x] 6.1 Add tests for `parse_compose_ports` — variable ports, literal ports, multi-port services, no-port services, unrecognized format
- [x] 6.2 Add tests for `resolve_ports` — variable present in .env, variable absent, literal, no .env
- [x] 6.3 Update existing port conflict tests for N-port model
- [x] 6.4 Update session creation tests for compose-driven flow
- [x] 6.5 Update tunnel start tests for dynamic `-L` flag generation
