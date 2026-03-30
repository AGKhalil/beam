## ADDED Requirements

### Requirement: Space stores a list of known hosts
Each space SHALL maintain a `hosts` array in state containing SSH host strings that have been used to create sessions in that space.

#### Scenario: New space has empty hosts
- **WHEN** a new space is created
- **THEN** its state SHALL contain an empty `hosts` array

#### Scenario: Backward compatibility with existing spaces
- **WHEN** a space exists in state without a `hosts` field
- **THEN** the system SHALL treat it as having an empty hosts list

### Requirement: Hosts are auto-remembered on session creation
When a session is created with a host not already in the space's `hosts` array, the system SHALL append that host to the array.

#### Scenario: First session with a new host
- **WHEN** a session is created in space "work" with host "ag@hetzner1" and the space has no known hosts
- **THEN** the space's `hosts` array SHALL become `["ag@hetzner1"]`

#### Scenario: Session with already-known host
- **WHEN** a session is created with host "ag@hetzner1" and that host is already in the space's `hosts` array
- **THEN** the `hosts` array SHALL remain unchanged (no duplicates)

#### Scenario: Multiple hosts accumulate
- **WHEN** sessions are created with hosts "hostA" and "hostB" in the same space
- **THEN** the space's `hosts` array SHALL contain both `["hostA", "hostB"]`

### Requirement: Hosts are removed with the space
When a space is deleted, its `hosts` array SHALL be deleted as part of the space object removal.

#### Scenario: Space removal
- **WHEN** `beam space rm myspace --force` is executed
- **THEN** the hosts associated with "myspace" SHALL no longer exist in state
