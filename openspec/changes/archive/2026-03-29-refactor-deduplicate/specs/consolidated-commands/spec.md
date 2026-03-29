## ADDED Requirements

### Requirement: cmd_session_up and cmd_session_switch share implementation

The system SHALL provide a shared internal function `cmd_session_activate` that handles the common logic of both `up` and `switch` commands: validate space/session existence, check status, resolve port conflicts, activate tunnel, and print results. `cmd_session_up` and `cmd_session_switch` SHALL be thin wrappers that call `cmd_session_activate` with different UI labels.

#### Scenario: beam space up activates a dormant session
- **WHEN** a user runs `beam <space> up <session>`
- **AND** the session is dormant
- **THEN** the session SHALL be activated
- **AND** the success message SHALL say `"<session> is live"`

#### Scenario: beam space switch activates a dormant session
- **WHEN** a user runs `beam <space> switch <session>`
- **AND** the session is dormant
- **THEN** the session SHALL be activated
- **AND** the success message SHALL say `"Switched to <session>"`

#### Scenario: Both commands handle already-live sessions identically
- **WHEN** a user runs either `beam <space> up` or `beam <space> switch` on a live session
- **THEN** the system SHALL print `"Already live."` and return without error

#### Scenario: Both commands handle port conflicts identically
- **WHEN** a port conflict is detected during either `up` or `switch`
- **THEN** the conflict resolution prompt SHALL be shown
- **AND** behavior SHALL be identical between the two commands

### Requirement: Consistent error handling across commands

All command functions SHALL use `exit 1` for fatal errors (space not found, session not found) and `return` for non-fatal conditions (already live, already dormant, user cancelled). No command SHALL use `exit 0` for a user cancellation while another uses `return` for the same scenario.

#### Scenario: Space not found exits consistently
- **WHEN** any command receives a non-existent space name
- **THEN** it SHALL call `require_space` which exits with code 1

#### Scenario: User cancellation is consistent
- **WHEN** the user cancels a port conflict resolution in any command
- **THEN** the command SHALL exit with code 0 (graceful cancellation)
