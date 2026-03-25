## ADDED Requirements

### Requirement: State file location
The system SHALL store all state in `~/.local/state/beam/state.json`.

#### Scenario: State file does not exist
- **WHEN** any beam command runs and the state file does not exist
- **THEN** the system creates `~/.local/state/beam/state.json` with an empty state structure `{"spaces": {}}`

#### Scenario: State directory does not exist
- **WHEN** any beam command runs and `~/.local/state/beam/` does not exist
- **THEN** the system creates the directory and the state file

### Requirement: State file structure
The system SHALL maintain a JSON state file containing spaces, sessions, port mappings, tunnel status, and PIDs.

#### Scenario: State reflects session creation
- **WHEN** a session is created
- **THEN** the state file contains the session under its space with host, project, worktree, remote_client_port, remote_server_port, local_client_port, local_server_port, status ("live" or "dormant"), and pid (integer or null)

#### Scenario: State reflects session status change
- **WHEN** a session transitions between live and dormant
- **THEN** the state file is updated with the new status and pid (set on live, cleared on dormant)

### Requirement: State file atomic operations
The system SHALL read and write the state file for each command invocation, not hold it open.

#### Scenario: Concurrent reads
- **WHEN** two terminals run `beam` simultaneously
- **THEN** both read the current state file independently and display consistent information
