## ADDED Requirements

### Requirement: Display full dashboard
The system SHALL display a dashboard of all spaces, sessions, and tunnel health when the user runs `beam` with no arguments.

#### Scenario: Multiple spaces with mixed sessions
- **WHEN** the user runs `beam` and spaces contain live and dormant sessions
- **THEN** the system displays each space as a header, each session underneath with: a live indicator (● for live, blank for dormant), session name, host, local→remote port mappings for live sessions, "(dormant)" for dormant sessions, and health status ("healthy" or "DEAD") for live sessions

#### Scenario: No spaces exist
- **WHEN** the user runs `beam` and no spaces exist
- **THEN** the system displays a message indicating no spaces have been created and suggests `beam space create <name>`

#### Scenario: Dead tunnel detected in dashboard
- **WHEN** the user runs `beam` and a live session has a dead tunnel
- **THEN** the system displays the session as "DEAD" and includes a footer message suggesting `beam hydrate`

### Requirement: Dashboard is read-only
The system SHALL NOT modify any state or tunnels when displaying the dashboard.

#### Scenario: Dashboard does not reconnect
- **WHEN** the user runs `beam` and dead tunnels are detected
- **THEN** the system only reports the dead tunnels and does not attempt to reconnect them
