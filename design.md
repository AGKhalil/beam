## Context

The current `ssf` tool at `~/.local/bin/ssf` is a single-use bash script that SSHes into a remote server, scans `~/codebases/` for projects and worktrees, reads `.env` files for Wasp port configuration, and establishes an SSH session with port forwarding. It is terminal-bound — when the SSH session ends, the port mappings are gone. There is no persistence, no multi-session support, and no way to manage tunnels from a separate terminal.

The target workflow involves multiple Wasp projects across multiple servers and worktrees, with frequent context switching between them. The developer needs tunnels to persist across terminal sessions, the ability to have multiple tunnels active simultaneously (on non-conflicting ports), and a quick way to restore tunnels after laptop sleep/wake cycles.

## Goals / Non-Goals

**Goals:**
- Replace `ssf` with a new `beam` CLI tool
- Manage named spaces containing named sessions
- Support multiple simultaneous live tunnels on non-conflicting local ports
- Persist all session state to disk, accessible from any terminal
- Provide a dashboard view of all spaces, sessions, and tunnel health
- Handle port conflicts gracefully with user prompts
- Provide a `hydrate` command to restore all live tunnels after disruption

**Non-Goals:**
- Auto-reconnection / daemon mode (explicit `hydrate` is the recovery mechanism)
- Remote shell access (use plain `ssh` separately)
- Support for non-Wasp projects (tool reads `WASP_CLIENT_PORT` / `WASP_SERVER_PORT` from `.env`)
- Server-side state or agents
- GUI or TUI beyond basic terminal prompts

## Decisions

### 1. Bash script, not a compiled tool

**Decision**: `beam` will be a bash script, same as `ssf`.

**Rationale**: The tool's logic is straightforward — SSH commands, file I/O, JSON manipulation. Bash keeps it zero-dependency (beyond `ssh` and `jq`), easy to install (copy to `~/.local/bin/`), and easy to modify. No build step, no runtime.

**Alternatives considered**:
- Go/Rust binary: Better argument parsing and JSON handling, but adds a build step and is overkill for this scope.
- Python script: Better than bash for JSON, but adds a runtime dependency.

### 2. State file format: JSON with `jq`

**Decision**: Store state in `~/.local/state/beam/state.json`, manipulate with `jq`.

**Rationale**: JSON is structured enough to represent nested spaces/sessions, and `jq` is widely available and powerful for in-place edits. The state file is small (dozens of sessions at most) so performance is not a concern.

**State file structure**:
```json
{
  "spaces": {
    "proteinea": {
      "sessions": {
        "hetzner1:proj1.auth": {
          "host": "ag@hetzner1",
          "project": "proj1",
          "worktree": "proj1.auth",
          "remote_client_port": 17331,
          "remote_server_port": 17332,
          "local_client_port": 3000,
          "local_server_port": 3001,
          "status": "live",
          "pid": 48291
        }
      }
    }
  }
}
```

### 3. Background tunnels via `ssh -fN`

**Decision**: Use `ssh -fN -L <local>:localhost:<remote>` for tunnels. Track the PID in state.

**Rationale**: `-f` backgrounds after authentication, `-N` skips remote command execution. This gives us a clean background process with a known PID that we can kill later. No daemon, no wrapper — just a backgrounded SSH process.

**SSH options**: Include `-o ServerAliveInterval=30 -o ServerAliveCountMax=3` to detect dead connections faster (90s instead of TCP default timeout). Also `-o ExitOnForwardFailure=yes` to fail immediately if ports are already bound.

### 4. Session naming convention: `host:project.worktree`

**Decision**: Auto-generate session names as `<ssh-host-shortname>:<worktree-dir>`, e.g., `hetzner1:proj1.auth`.

**Rationale**: Unique, descriptive, no user input needed. The host shortname is extracted from the SSH host (strip user@ prefix). The worktree dir is the folder name under `~/codebases/`.

### 5. Port conflict resolution via prompt

**Decision**: When `beam <space> up <session>` detects that the requested local ports are already in use by another live session, prompt the user to sleep the conflicting session.

**Rationale**: The user explicitly stated they don't want silent background connections. The prompt makes the swap intentional. No auto-sleep, no rejection — just a clear y/n choice.

### 6. Subcommand routing via positional arguments

**Decision**: Use a simple positional dispatch pattern:
- `beam` → dashboard
- `beam space <action>` → space management
- `beam <space> <action> [session]` → session management within a space
- `beam hydrate` → global hydration

**Rationale**: Avoids the need for a full argument parser. The first argument determines the routing: if it's `space` or `hydrate`, it's a top-level command; otherwise it's treated as a space name, and the second argument is the action.

### 7. Health checking: PID + port binding verification

**Decision**: Health check verifies (a) the stored PID is still running and (b) the local ports are actually bound.

**Rationale**: A PID can be running but the tunnel dead (e.g., SSH process hung). Checking port binding with `lsof -i :PORT` confirms the tunnel is actually functional. This runs on the active session when viewing the dashboard.

## Risks / Trade-offs

- **[jq dependency]** → `jq` is not installed by default on macOS. Mitigation: check for `jq` on first run and provide install instructions (`brew install jq`). Acceptable since this is a developer tool.

- **[PID file races]** → If the user runs two `beam` commands simultaneously, state file writes could race. Mitigation: Acceptable risk for a single-user CLI tool. Could add file locking later if needed.

- **[Stale PIDs]** → A PID could be reused by the OS after the SSH process dies. Mitigation: Combine PID check with port binding check (`lsof`) to confirm it's actually our tunnel.

- **[SSH key/agent auth required]** → `ssh -fN` backgrounds after auth, so it needs non-interactive auth (key-based). Mitigation: This is already the case for the user's workflow. Document as a requirement.

- **[Remote .env changes not synced]** → If remote ports change in `.env`, stored session has stale values. Mitigation: Accepted — ports are stable per-worktree. User can `rm` and `create` to rescan if needed.
