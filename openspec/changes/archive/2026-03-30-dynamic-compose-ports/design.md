## Context

Beam currently hardcodes two SSH tunnel ports for wasp projects, reading `WASP_CLIENT_PORT` and `WASP_SERVER_PORT` from the remote worktree's `.env`. The user is prompted for local ports (defaulting to 3000/3001). Session state stores four named port fields. In practice, projects run 5-7 services (Postgres, Redis, Qdrant, FastAPI, etc.) all declared in `docker-compose.dev.yml` with parameterized port mappings like `"${DB_PORT:-5432}:5432"`.

The compose file already serves as the port manifest. Beam should read it instead of hardcoding wasp-specific variables.

## Goals / Non-Goals

**Goals:**
- Automatically discover all port mappings from `docker-compose.dev.yml`
- Resolve variable-based ports against `.env` to get actual remote host ports
- Use compose default values as local ports (canonical ports like 5432, 3000, etc.)
- Build N SSH tunnels dynamically
- Simplify conflict resolution to tear-down-or-abort

**Non-Goals:**
- Full YAML parsing — only extract `ports:` entries with known patterns
- Supporting multiple `.env` files (e.g., `./app/.env.server`) — only the root `.env`
- Supporting compose files at non-standard locations — always `docker-compose.dev.yml` at worktree root
- Backward compatibility with old state format — clean break

## Decisions

### 1. Compose parsing via grep/sed on the remote host

**Decision**: Parse `docker-compose.dev.yml` remotely using a single SSH command with grep/sed to extract port lines.

**Rationale**: No YAML parser is needed. Port declarations follow two patterns:
- `"${VAR:-DEFAULT}:CONTAINER"` — variable with default
- `"HOST:CONTAINER"` — literal

A targeted regex extracts these reliably. Parsing happens in one SSH round-trip alongside the `.env` read.

**Alternatives considered**:
- Install `yq` on remote servers — adds a dependency, overkill for this
- Copy compose file locally then parse — extra round-trip, no benefit

### 2. Port resolution: compose defaults as local, .env values as remote

**Decision**: For `"${DB_PORT:-5432}:5432"`:
- Local port = `5432` (the default/fallback value)
- Remote port = value of `DB_PORT` from `.env` (e.g., `15432`)
- If variable is not in `.env`, use the default for remote too

For literal ports `"8080:8080"`: both local and remote are `8080`.

**Rationale**: Developers always get canonical ports locally (`localhost:5432` is always the DB). The remote port is whatever the worktree's `.env` assigns to avoid collisions between worktrees on the server.

### 3. Session state: ports array replaces named fields

**Decision**: Replace `local_client_port`, `local_server_port`, `remote_client_port`, `remote_server_port` with a `ports` JSON array:

```json
{
  "ports": [
    {"local": 5432, "remote": 15432, "service": "db"},
    {"local": 3000, "remote": 17331, "service": "wasp"},
    {"local": 3001, "remote": 17332, "service": "wasp"}
  ]
}
```

The `service` field comes from the compose service name owning that port entry. Used for display only.

**Rationale**: Fixed fields can't represent N ports. The array scales to any compose layout.

### 4. Conflict detection: any overlap across all ports

**Decision**: `find_port_conflicts` iterates all local ports of the new session against all local ports of every live session. Any single overlap triggers a conflict.

**Rationale**: Since local ports are canonical defaults, any two sessions from projects with overlapping services (e.g., both have Postgres on 5432) will always conflict. The prompt becomes: "Session X is using ports that conflict. Tear it down? [y/N]".

### 5. Tunnel construction: single SSH command with N -L flags

**Decision**: Build the `ssh -fN` command dynamically by iterating the ports array and appending `-L local:localhost:remote` for each entry.

**Rationale**: SSH supports arbitrary numbers of `-L` flags. One process, one PID to track.

### 6. Worktree preview: show service count instead of client port

**Decision**: During worktree selection, show the number of mapped services (e.g., `patents.main  6 services`) instead of the old client port preview.

**Rationale**: A single port number is no longer meaningful. Service count gives a quick health signal that the compose file was parsed.

## Risks / Trade-offs

- **[Missing compose file]** → If `docker-compose.dev.yml` doesn't exist for a worktree, error with a clear message. This is a hard requirement now — projects without compose files can't use beam.
- **[Unparseable port format]** → If a port line doesn't match either pattern (variable or literal), skip it with a warning. Don't fail the entire session.
- **[State migration]** → Old sessions in state.json will have the old port format. On read, treat missing `ports` array as a dead session — the user can recreate it. No automated migration.
- **[Local port already in use by non-beam process]** → Not new, but more likely with 7 ports than 2. Current behavior (SSH fails) is acceptable. Could add `lsof` pre-check as a future enhancement.
