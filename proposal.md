## Why

The current `ssf` tool is a one-shot SSH utility — it connects to a server, scans for projects/worktrees, forwards ports, and gives you a shell. When you disconnect, everything is gone. There's no memory, no ability to manage multiple projects, and no way to quickly swap between worktrees without re-scanning. For a workflow involving multiple Wasp projects across different servers and worktrees, this creates constant friction.

`beam` replaces `ssf` with a session-based CLI that manages persistent port-forwarding tunnels, organized into named spaces, with the ability to run multiple sessions simultaneously and switch between them from any terminal.

## What Changes

- **New CLI tool `beam`** replaces `ssf` entirely
- **Spaces** — top-level organizational groups (e.g., `proteinea`, `personal`) that contain sessions
- **Sessions** — named tunnel definitions (`server:project.worktree`) that map local ports to remote Wasp client/server ports. Sessions can be live (tunnel running) or dormant.
- **Multi-session support** — multiple sessions can be live simultaneously as long as their local ports don't conflict
- **Conflict resolution** — when activating a session whose ports conflict with a live session, the user is prompted to sleep the conflicting session
- **Background tunnels** — uses `ssh -fN` (no remote shell), decoupled from any terminal session
- **Persistent state** — session definitions and tunnel state stored on disk, accessible from any terminal
- **`beam hydrate`** — reconnects all sessions marked as live (e.g., after laptop sleep/wake)
- **Removal of `ssf`** — the old tool is fully replaced. **BREAKING**

## Capabilities

### New Capabilities
- `space-management`: Creating, listing, and removing organizational spaces
- `session-lifecycle`: Creating, activating, sleeping, and removing tunnel sessions within spaces
- `tunnel-management`: Background SSH tunnel creation, teardown, health checking, and port conflict detection
- `state-persistence`: On-disk state file tracking all spaces, sessions, tunnel PIDs, and port mappings
- `hydration`: Reconnecting all live sessions after tunnel death (sleep/wake, network blip)
- `dashboard`: Top-level view of all spaces, sessions, health status across the tool

### Modified Capabilities

(none — this is a new tool)

## Impact

- **Replaces** `~/.local/bin/ssf` with `~/.local/bin/beam`
- **New state directory** at `~/.local/state/beam/` (or similar XDG-compliant path)
- **Dependency**: `ssh` (already present), no new external dependencies
- **Wasp-specific**: reads `WASP_CLIENT_PORT`, `WASP_SERVER_PORT` from remote `.env` files during session creation
- **No server-side changes** — all state is local, remote is only accessed during `create` (scan) and tunnel establishment
