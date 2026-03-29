## ADDED Requirements

### Requirement: Replace existing session on create

When `cmd_session_create()` detects that a session with the same name already exists in the target space, the system SHALL prompt the user with `"Session '<name>' already exists. Replace it? (y/n)"` instead of exiting with an error.

#### Scenario: User confirms replacement of a live session
- **WHEN** a session named `host1:proj.wt` exists in space `myspace` with status `live` and pid `12345`
- **AND** the user runs `beam myspace create` and selects the same host/worktree combination
- **AND** the user responds `y` to the replace prompt
- **THEN** the system SHALL kill the existing tunnel (pid `12345`)
- **AND** the system SHALL wait for the tunnel ports to be released
- **AND** the system SHALL delete the old session from state
- **AND** the system SHALL proceed to create the new session with the user-specified ports
- **AND** the system SHALL activate the new tunnel

#### Scenario: User confirms replacement of a dormant session
- **WHEN** a session named `host1:proj.wt` exists in space `myspace` with status `dormant`
- **AND** the user runs `beam myspace create` and selects the same host/worktree combination
- **AND** the user responds `y` to the replace prompt
- **THEN** the system SHALL delete the old session from state
- **AND** the system SHALL proceed to create the new session with the user-specified ports

#### Scenario: User declines replacement
- **WHEN** a session named `host1:proj.wt` exists in space `myspace`
- **AND** the user runs `beam myspace create` and selects the same host/worktree combination
- **AND** the user responds `n` to the replace prompt
- **THEN** the system SHALL exit gracefully with a cancellation hint
- **AND** the system SHALL NOT modify the existing session

#### Scenario: Session does not exist
- **WHEN** no session named `host1:proj.wt` exists in space `myspace`
- **AND** the user runs `beam myspace create` and selects that host/worktree
- **THEN** the system SHALL create the session without any replace prompt (existing behavior unchanged)
