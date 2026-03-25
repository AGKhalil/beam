## ADDED Requirements

### Requirement: Start a background SSH tunnel
The system SHALL establish a background SSH tunnel using `ssh -fN` with local port forwarding for both client and server ports.

#### Scenario: Tunnel starts successfully
- **WHEN** a session is activated
- **THEN** the system runs `ssh -fN -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -L <local_client>:localhost:<remote_client> -L <local_server>:localhost:<remote_server> <host>`, stores the resulting PID in the session state, and marks the session as live

#### Scenario: Tunnel fails to start (port already bound)
- **WHEN** a session is activated and the local port is already bound by a non-beam process
- **THEN** the system displays an error indicating the port is in use and does not mark the session as live

### Requirement: Kill a tunnel
The system SHALL kill a running tunnel by sending SIGTERM to the stored PID.

#### Scenario: Kill a running tunnel
- **WHEN** a live session is being slept or removed
- **THEN** the system sends SIGTERM to the stored PID, verifies the process has exited, clears the PID from state, and marks the session as dormant

#### Scenario: PID no longer running
- **WHEN** a session is being slept but the stored PID is no longer a running process
- **THEN** the system clears the PID from state and marks the session as dormant without error

### Requirement: Health check a tunnel
The system SHALL verify tunnel health by checking that the stored PID is running and local ports are bound.

#### Scenario: Tunnel is healthy
- **WHEN** a health check runs on a live session and the PID is running and local ports are bound
- **THEN** the system reports the session as "healthy"

#### Scenario: Tunnel is dead (PID gone)
- **WHEN** a health check runs on a live session and the stored PID is not running
- **THEN** the system reports the session as "dead"

#### Scenario: Tunnel is dead (ports not bound)
- **WHEN** a health check runs on a live session and the PID is running but local ports are not bound
- **THEN** the system reports the session as "dead"

### Requirement: Detect port conflicts
The system SHALL detect when a session's local ports conflict with any other live session across all spaces.

#### Scenario: Conflict detected
- **WHEN** a session is being activated and another live session uses the same local client port or local server port
- **THEN** the system identifies the conflicting session (name and space) and reports the conflict

#### Scenario: No conflict
- **WHEN** a session is being activated and no other live session uses the same local ports
- **THEN** the system proceeds with activation
