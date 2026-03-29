## ADDED Requirements

### Requirement: require_space validates space existence

The system SHALL provide a `require_space` helper that checks whether a space exists in state and exits with an error if it does not. All command functions that need a space to exist MUST use this helper instead of inline checks.

#### Scenario: Space exists
- **WHEN** `require_space "$state" "myspace"` is called
- **AND** `myspace` exists in `.spaces`
- **THEN** the function SHALL return 0 (success) with no output

#### Scenario: Space does not exist
- **WHEN** `require_space "$state" "nonexistent"` is called
- **AND** `nonexistent` does not exist in `.spaces`
- **THEN** the function SHALL print `"Space 'nonexistent' does not exist."` to stderr
- **AND** the function SHALL exit with code 1

### Requirement: require_session validates session existence

The system SHALL provide a `require_session` helper that checks whether a session exists within a space and exits with an error if it does not. All command functions that need a session to exist MUST use this helper instead of inline checks.

#### Scenario: Session exists
- **WHEN** `require_session "$state" "myspace" "host1:proj.wt"` is called
- **AND** the session exists in `.spaces.myspace.sessions`
- **THEN** the function SHALL return 0 with no output

#### Scenario: Session does not exist
- **WHEN** `require_session "$state" "myspace" "nosession"` is called
- **AND** the session does not exist
- **THEN** the function SHALL print `"Session 'nosession' does not exist in space 'myspace'."` to stderr
- **AND** the function SHALL exit with code 1

### Requirement: sleep_session tears down a live tunnel and marks it dormant

The system SHALL provide a `sleep_session` helper that kills a session's tunnel and updates the state to dormant. `cmd_session_down`, `resolve_conflict`, and the replace logic in `cmd_session_create` MUST use this helper instead of inline kill-and-update patterns.

#### Scenario: Sleep a live session
- **WHEN** `sleep_session "$space" "$session"` is called
- **AND** the session has status `live` with a valid pid
- **THEN** the tunnel process SHALL be killed
- **AND** the state SHALL be updated to status `dormant` and pid `null`

#### Scenario: Sleep an already dormant session
- **WHEN** `sleep_session "$space" "$session"` is called
- **AND** the session has status `dormant`
- **THEN** the state SHALL remain unchanged
- **AND** the function SHALL return 0

### Requirement: check_and_resolve_conflicts wraps port conflict detection and resolution

The system SHALL provide a `check_and_resolve_conflicts` helper that calls `find_port_conflicts`, parses the result, and invokes `resolve_conflict` if needed. `cmd_session_create`, `cmd_session_up`, and `cmd_session_switch` MUST use this helper instead of inline conflict-check patterns.

#### Scenario: No conflict exists
- **WHEN** `check_and_resolve_conflicts "$lc" "$ls" "$space" "$session"` is called
- **AND** no port conflicts are found
- **THEN** the function SHALL return 0 with no output

#### Scenario: Conflict exists and user resolves it
- **WHEN** a port conflict is found
- **AND** the user confirms resolution
- **THEN** the conflicting session SHALL be slept
- **AND** the function SHALL return 0

#### Scenario: Conflict exists and user cancels
- **WHEN** a port conflict is found
- **AND** the user declines resolution
- **THEN** the function SHALL return 1

### Requirement: activate_and_report connects a tunnel and prints the result

The system SHALL provide an `activate_and_report` helper that calls `activate_session`, prints the success/failure message, and prints port mappings on success. `cmd_session_create`, `cmd_session_up`, and `cmd_session_switch` MUST use this helper instead of inline activate-and-print patterns.

#### Scenario: Tunnel activation succeeds
- **WHEN** `activate_and_report "$space" "$session" "$host" "$lc" "$rc" "$ls" "$rs" "$success_msg"` is called
- **AND** `activate_session` returns 0
- **THEN** the success message SHALL be printed with a green checkmark
- **AND** port mappings SHALL be printed via `print_ports`

#### Scenario: Tunnel activation fails
- **WHEN** `activate_and_report` is called
- **AND** `activate_session` returns 1
- **THEN** an error message SHALL be printed indicating tunnel failure

### Requirement: cmd_hydrate uses activate_session

`cmd_hydrate` SHALL call `activate_session()` for tunnel reconnection instead of inlining its own start_tunnel + PID capture + state update logic. This ensures bug fixes to `activate_session` propagate to hydration.

#### Scenario: Hydrate reconnects a dead session
- **WHEN** `cmd_hydrate` finds a live session with a dead tunnel
- **AND** it calls `activate_session` to reconnect
- **THEN** the session SHALL be reconnected with proper PID sanitization
- **AND** the state SHALL be updated via `activate_session`'s logic
