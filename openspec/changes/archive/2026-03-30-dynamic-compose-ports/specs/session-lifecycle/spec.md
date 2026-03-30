## MODIFIED Requirements

### Requirement: Session creation reads compose file instead of prompting for ports
Session creation SHALL parse `docker-compose.dev.yml` and resolve ports against `.env` instead of prompting the user for local port numbers. The user is no longer asked for local client or server ports.

#### Scenario: Create session from worktree with compose file
- **WHEN** the user selects a worktree during session creation
- **THEN** the system SHALL read `docker-compose.dev.yml`, resolve ports, and proceed to tunnel creation without any port prompts

### Requirement: Conflict resolution tears down or aborts
When a port conflict is detected, the system SHALL prompt the user to tear down the conflicting session. There is no option to choose alternate local ports.

#### Scenario: Conflict with existing live session
- **WHEN** the resolved ports overlap with a live session's local ports
- **THEN** the system SHALL display which session conflicts and prompt "Tear it down? [y/N]"

#### Scenario: User confirms teardown
- **WHEN** the user answers "y" to the teardown prompt
- **THEN** the system SHALL sleep the conflicting session and proceed with the new session

#### Scenario: User declines teardown
- **WHEN** the user answers "n" or presses Enter
- **THEN** the system SHALL abort session creation

### Requirement: Worktree preview shows service count
During worktree selection, the system SHALL show the number of port-mapped services from each worktree's compose file instead of the client port number.

#### Scenario: Worktree with 6 mapped services
- **WHEN** listing worktrees and a worktree's compose file has 6 services with ports
- **THEN** the display SHALL show the worktree name followed by `6 services`

#### Scenario: Worktree with no compose file
- **WHEN** listing worktrees and a worktree has no `docker-compose.dev.yml`
- **THEN** the display SHALL show the worktree name followed by `no compose`
