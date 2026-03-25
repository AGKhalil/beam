## ADDED Requirements

### Requirement: Create a session interactively
The system SHALL scan a remote server for Wasp projects and worktrees and create a named session when the user runs `beam <space> create`.

#### Scenario: Full interactive create flow
- **WHEN** the user runs `beam proteinea create`
- **THEN** the system prompts for an SSH host, SSHes in to scan `~/codebases/` for projects and worktrees, displays projects with worktree counts, prompts the user to select a project, displays worktrees with their `WASP_CLIENT_PORT` from `.env`, prompts the user to select a worktree, reads `WASP_CLIENT_PORT` and `WASP_SERVER_PORT` from the worktree's `.env`, prompts for local ports (default 3000/3001 or custom), creates the session with auto-generated name `<host>:<worktree>`, and activates it immediately

#### Scenario: Create in nonexistent space
- **WHEN** the user runs `beam nonexistent create` and no space named "nonexistent" exists
- **THEN** the system displays an error indicating the space does not exist

#### Scenario: Session name already exists
- **WHEN** the user creates a session and the auto-generated name matches an existing session in the space
- **THEN** the system displays an error indicating a session with that name already exists

#### Scenario: Remote .env missing required ports
- **WHEN** the user selects a worktree whose `.env` does not contain `WASP_CLIENT_PORT` or `WASP_SERVER_PORT`
- **THEN** the system displays an error with the missing variable names and does not create the session

### Requirement: List sessions in a space
The system SHALL display all sessions in a space when the user runs `beam <space> ls`.

#### Scenario: Sessions exist
- **WHEN** the user runs `beam proteinea ls` and sessions exist in the space
- **THEN** the system displays each session with its name, host, worktree, local→remote port mappings, and status (live/dormant)

#### Scenario: No sessions exist
- **WHEN** the user runs `beam proteinea ls` and no sessions exist in the space
- **THEN** the system displays a message indicating no sessions in this space

### Requirement: Activate a session
The system SHALL activate a dormant session when the user runs `beam <space> up <session>`.

#### Scenario: Activate session with no port conflicts
- **WHEN** the user runs `beam proteinea up hetzner1:proj1.auth` and no live session uses the same local ports
- **THEN** the system starts a background SSH tunnel and marks the session as live

#### Scenario: Activate session with port conflict
- **WHEN** the user runs `beam proteinea up hetzner1:proj1.payments` and another live session (in any space) uses the same local ports
- **THEN** the system displays which session conflicts and its ports, prompts the user to confirm sleeping the conflicting session (y/n), and if confirmed, sleeps the conflicting session and activates the requested one

#### Scenario: User declines conflict resolution
- **WHEN** the user is prompted about a port conflict and enters `n`
- **THEN** the system cancels the activation and leaves both sessions unchanged

#### Scenario: Activate already live session
- **WHEN** the user runs `beam proteinea up hetzner1:proj1.auth` and the session is already live
- **THEN** the system displays a message indicating the session is already live

### Requirement: Sleep a session
The system SHALL sleep a live session when the user runs `beam <space> down <session>`.

#### Scenario: Sleep a live session
- **WHEN** the user runs `beam proteinea down hetzner1:proj1.auth` and the session is live
- **THEN** the system kills the SSH tunnel process, marks the session as dormant, and confirms

#### Scenario: Sleep an already dormant session
- **WHEN** the user runs `beam proteinea down hetzner1:proj1.auth` and the session is already dormant
- **THEN** the system displays a message indicating the session is already dormant

### Requirement: Remove a session
The system SHALL remove a session when the user runs `beam <space> rm <session>`.

#### Scenario: Remove a dormant session
- **WHEN** the user runs `beam proteinea rm hetzner1:proj1.auth` and the session is dormant
- **THEN** the system removes the session from state and confirms

#### Scenario: Remove a live session
- **WHEN** the user runs `beam proteinea rm hetzner1:proj1.auth` and the session is live
- **THEN** the system kills the tunnel, removes the session from state, and confirms

#### Scenario: Remove nonexistent session
- **WHEN** the user runs `beam proteinea rm nonexistent` and no such session exists
- **THEN** the system displays an error indicating the session does not exist

### Requirement: Switch to a session
The system SHALL provide `beam <space> switch <session>` as a convenience that activates a session, automatically sleeping any conflicting live session.

#### Scenario: Switch with conflict
- **WHEN** the user runs `beam proteinea switch hetzner1:proj1.payments` and `hetzner1:proj1.auth` is live on the same ports
- **THEN** the system displays which session will be slept and prompts for confirmation (y/n), and if confirmed, sleeps the conflicting session and activates the target

#### Scenario: Switch with no conflict
- **WHEN** the user runs `beam proteinea switch hetzner1:proj1.payments` and no port conflict exists
- **THEN** the system activates the session directly (same as `up`)
