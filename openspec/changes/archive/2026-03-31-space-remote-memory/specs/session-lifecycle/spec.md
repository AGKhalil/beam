## MODIFIED Requirements

### Requirement: Session creation presents host selector when hosts are known
During session creation, the system SHALL present the space's known hosts as selectable options instead of a raw text prompt, when the space has at least one known host.

#### Scenario: Space has known hosts
- **WHEN** the user runs `beam <space> create` and the space has hosts `["proteinea-gpu-0", "proteinea-gpu-1"]`
- **THEN** the system SHALL display an arrow-select menu with those hosts plus a "+ Enter a new host..." option

#### Scenario: User selects a known host
- **WHEN** the user selects "proteinea-gpu-0" from the host menu
- **THEN** the system SHALL use "proteinea-gpu-0" as the SSH host and proceed to project scanning

#### Scenario: User selects "Enter a new host"
- **WHEN** the user selects "+ Enter a new host..." from the menu
- **THEN** the system SHALL display a raw text prompt for the SSH host

#### Scenario: Space has no known hosts
- **WHEN** the user runs `beam <space> create` and the space has no `hosts` or an empty array
- **THEN** the system SHALL display the raw text prompt directly (current behavior)

#### Scenario: Space has exactly one known host
- **WHEN** the space has exactly one known host
- **THEN** the system SHALL still present the arrow-select menu with that host plus "+ Enter a new host..." (never auto-select hosts)
