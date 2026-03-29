## ADDED Requirements

### Requirement: Bats test infrastructure

The project SHALL include a `tests/` directory with a bats-based test suite that can be run via `bats tests/` without requiring real SSH connections or remote hosts.

#### Scenario: Tests run without network access
- **WHEN** a developer runs `bats tests/`
- **THEN** all tests SHALL pass without making any real SSH connections
- **AND** tests SHALL use mock SSH commands and temporary state files

#### Scenario: Test setup provides isolated state
- **WHEN** a test begins
- **THEN** a fresh temporary directory SHALL be created for `STATE_DIR` and `STATE_FILE`
- **AND** the test SHALL not affect or read from `~/.local/state/beam/`

### Requirement: Session existence check tests

The test suite SHALL include tests that validate the session existence check behavior in `cmd_session_create()`.

#### Scenario: Creating a session when none exists succeeds
- **WHEN** the state file has a space `testspace` with no sessions
- **AND** the create flow is exercised for a new session name
- **THEN** the session SHALL be created in the state file

#### Scenario: Creating a session that already exists triggers replace prompt
- **WHEN** the state file has a space `testspace` with session `host1:proj.wt`
- **AND** the create flow is exercised for the same session name
- **THEN** the output SHALL contain the replace prompt text

### Requirement: State management tests

The test suite SHALL include tests for state file read/write operations, space creation, and session CRUD.

#### Scenario: init_state creates state file if missing
- **WHEN** `STATE_FILE` does not exist
- **AND** `init_state` is called
- **THEN** `STATE_FILE` SHALL exist with content `{"spaces": {}}`

#### Scenario: Space create adds a space to state
- **WHEN** `cmd_space_create testspace` is called
- **THEN** the state file SHALL contain `.spaces.testspace.sessions` as an empty object

#### Scenario: Session data persists correctly
- **WHEN** a session is written to state with host, ports, status, and pid
- **THEN** reading the state back SHALL return the same values

### Requirement: Port conflict detection tests

The test suite SHALL include tests for `find_port_conflicts()`.

#### Scenario: No conflict when ports are unique
- **WHEN** existing sessions use ports 3000/3001
- **AND** `find_port_conflicts` is called with ports 4000/4001
- **THEN** the result SHALL be empty (no conflict)

#### Scenario: Conflict detected on client port overlap
- **WHEN** a live session uses local client port 3000
- **AND** `find_port_conflicts` is called with client port 3000
- **THEN** the result SHALL return the conflicting session identifier

#### Scenario: Dormant sessions do not trigger conflicts
- **WHEN** a dormant session uses local client port 3000
- **AND** `find_port_conflicts` is called with client port 3000
- **THEN** the result SHALL be empty (dormant sessions are not checked)
