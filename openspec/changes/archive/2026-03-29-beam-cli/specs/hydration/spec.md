## ADDED Requirements

### Requirement: Hydrate all live sessions
The system SHALL reconnect all sessions marked as live when the user runs `beam hydrate`.

#### Scenario: All live sessions need reconnection
- **WHEN** the user runs `beam hydrate` and all live sessions have dead tunnels
- **THEN** the system re-establishes a background SSH tunnel for each session marked as live, updates PIDs in state, and reports results per session

#### Scenario: Some sessions already healthy
- **WHEN** the user runs `beam hydrate` and some live sessions still have healthy tunnels
- **THEN** the system skips healthy sessions and only reconnects dead ones, reporting status for each

#### Scenario: No live sessions
- **WHEN** the user runs `beam hydrate` and no sessions are marked as live
- **THEN** the system displays a message indicating there are no live sessions to hydrate

#### Scenario: Port conflict during hydration
- **WHEN** the user runs `beam hydrate` and two live sessions share the same local ports (corrupted state)
- **THEN** the system hydrates the first session found, skips the conflicting one with an error, and advises the user to resolve manually

#### Scenario: Reconnection failure
- **WHEN** `beam hydrate` attempts to reconnect a session and the SSH connection fails (e.g., server unreachable)
- **THEN** the system reports the failure for that session, leaves it marked as live, and continues hydrating remaining sessions
