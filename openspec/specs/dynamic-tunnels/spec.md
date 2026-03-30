## ADDED Requirements

### Requirement: Build SSH tunnel with N port forwards
The system SHALL construct a single `ssh -fN` command with one `-L local:localhost:remote` flag per port pair from the resolved ports list.

#### Scenario: Tunnel with 6 port pairs
- **WHEN** the resolved ports list contains 6 entries (e.g., db, wasp client, wasp server, redis, qdrant, api)
- **THEN** the system SHALL issue one SSH command with 6 `-L` flags

#### Scenario: Tunnel with 1 port pair
- **WHEN** the resolved ports list contains a single entry
- **THEN** the system SHALL issue one SSH command with 1 `-L` flag

### Requirement: Store ports array in session state
The system SHALL store the complete ports list in the session's state as a JSON array with `local`, `remote`, and `service` fields per entry.

#### Scenario: State after session creation
- **WHEN** a session is created with 6 port mappings
- **THEN** the session object in state.json SHALL contain a `ports` array with 6 objects, each having `local`, `remote`, and `service` keys

### Requirement: Display all port mappings
The system SHALL display all port mappings when showing session details, with service name labels.

#### Scenario: Print ports for a session
- **WHEN** displaying port info for a session with 6 port mappings
- **THEN** the system SHALL print one line per mapping showing `localhost:LOCAL -> host:REMOTE (service)`
