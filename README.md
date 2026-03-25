# Beam

Session-based SSH tunnel manager for [Wasp](https://wasp-lang.dev/) projects.

Beam replaces one-shot SSH utilities with persistent, named tunnel sessions organized into **spaces**. Run multiple tunnels simultaneously, switch between them, and recover tunnels after disruptions like laptop sleep/wake — all from a single Bash script.

## Features

- **Spaces & Sessions** — organize tunnels into named groups; each session maps local ports to a remote Wasp client/server pair
- **Background tunnels** — uses `ssh -fN` so tunnels survive terminal close
- **Persistent state** — session definitions saved to `~/.local/state/beam/state.json`, accessible from any terminal
- **Health checks** — PID + port binding verification to detect dead tunnels
- **Hydration** — `beam hydrate` reconnects all dead tunnels in one command
- **Port conflict detection** — automatic detection across all spaces with interactive resolution
- **Interactive menus** — arrow-key/vim-key selection for hosts, projects, worktrees, and sessions

## Prerequisites

- macOS or Linux with Bash 4+
- `ssh` with key-based authentication configured for your remote hosts
- [`jq`](https://jqlang.github.io/jq/) — install via `brew install jq` (macOS) or your system package manager
- Remote servers with Wasp projects in `~/codebases/`, each containing a `.env` with `WASP_CLIENT_PORT` and `WASP_SERVER_PORT`

## Installation

```bash
# Copy to somewhere on your PATH
cp beam ~/.local/bin/beam
chmod +x ~/.local/bin/beam
```

No build step required — Beam is a single executable Bash script.

## Usage

```bash
# Dashboard — shows all spaces, sessions, tunnel health, and port mappings
beam

# Help
beam help
```

### Spaces

```bash
beam space ls                  # List all spaces
beam space create <name>       # Create a new space
beam space rm <name> [--force] # Remove a space (--force skips confirmation)
```

### Sessions

```bash
beam <space> create            # Create a session (interactive: picks host, project, worktree)
beam <space> ls                # List sessions with live/dormant status
beam <space> up [session]      # Activate a dormant session
beam <space> down [session]    # Sleep a live session
beam <space> switch [session]  # Switch to a session (auto-sleeps conflicting ones)
beam <space> rm [session]      # Remove a session
```

### Hydration

```bash
beam hydrate                   # Reconnect all tunnels marked live that have died
```

## How It Works

1. During **session creation**, Beam SSHes into the remote host, scans `~/codebases/` for projects and git worktrees, reads port assignments from the worktree's `.env` file, and sets up dual port forwarding (client dev server + API server).
2. Sessions are auto-named as `<host>:<worktree>` (e.g., `hetzner1:myapp.feature-branch`).
3. Tunnels run in the background via `ssh -fN -L`, decoupled from any terminal.
4. State is persisted to `~/.local/state/beam/state.json` so sessions survive across terminal windows and shell restarts.

## Project Structure

```
beam/
  beam                          # The CLI — a single Bash script
  openspec/changes/beam-cli/    # Design documentation
    proposal.md                 #   Motivation and scope
    design.md                   #   Architecture decisions and trade-offs
    tasks.md                    #   Implementation task checklist
    specs/                      #   Feature specifications
      dashboard/spec.md
      hydration/spec.md
      session-lifecycle/spec.md
      space-management/spec.md
      state-persistence/spec.md
      tunnel-management/spec.md
```

## License

This project is not currently licensed. All rights reserved.
