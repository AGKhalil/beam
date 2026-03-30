## MODIFIED Requirements

### Requirement: start_tunnel accepts a ports array
`start_tunnel` SHALL accept a host and a ports array (as JSON or positional groups) and create one SSH process with `-L` flags for every port pair.

#### Scenario: Start tunnel with multiple ports
- **WHEN** `start_tunnel` is called with host and 6 port pairs
- **THEN** it SHALL execute `ssh -fN` with 6 `-L local:localhost:remote` flags and return the PID

### Requirement: find_port_conflicts checks N ports
`find_port_conflicts` SHALL accept a list of local ports and check each against all local ports of every live session.

#### Scenario: Overlap on one port
- **WHEN** the new session wants local port 5432 and an existing live session has 5432 in its ports
- **THEN** the function SHALL return the conflicting session identifier

#### Scenario: No overlap
- **WHEN** none of the new session's local ports match any live session's local ports
- **THEN** the function SHALL return empty (no conflict)

### Requirement: print_ports renders N rows with service labels
`print_ports` SHALL iterate the session's ports array and print one line per entry.

#### Scenario: Display 6 port mappings
- **WHEN** a session has 6 port entries with service names
- **THEN** the output SHALL show 6 lines in the format `localhost:LOCAL -> host:REMOTE (service)`

### Requirement: read_session returns ports array
`read_session` SHALL return the session's ports as a JSON array instead of four separate port fields.

#### Scenario: Read session with new state format
- **WHEN** reading a session that has a `ports` array in state
- **THEN** the function SHALL return the ports array accessible for iteration

#### Scenario: Read session with missing ports field
- **WHEN** reading a session from old state format (no `ports` array)
- **THEN** the function SHALL treat it as having zero ports (dead session)
