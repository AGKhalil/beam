## ADDED Requirements

### Requirement: Parse port mappings from docker-compose.dev.yml
The system SHALL read `~/codebases/<worktree>/docker-compose.dev.yml` on the remote host and extract all port mapping entries from every service's `ports:` section.

#### Scenario: Variable port with default
- **WHEN** a compose file contains a port line `"${DB_PORT:-5432}:5432"` under a service named `db`
- **THEN** the system SHALL extract: variable=`DB_PORT`, default=`5432`, service=`db`

#### Scenario: Literal port mapping
- **WHEN** a compose file contains a port line `"8080:8080"` under a service named `web`
- **THEN** the system SHALL extract: variable=none, default=`8080`, service=`web`

#### Scenario: Multiple ports under one service
- **WHEN** a service has multiple port lines (e.g., wasp with client and server ports)
- **THEN** the system SHALL extract each as a separate port entry

#### Scenario: Service with no ports section
- **WHEN** a service (e.g., `worker`) has no `ports:` section
- **THEN** the system SHALL skip that service with no error

#### Scenario: Unrecognized port format
- **WHEN** a port line does not match either `"${VAR:-DEFAULT}:CONTAINER"` or `"HOST:CONTAINER"` patterns
- **THEN** the system SHALL skip it and print a warning

### Requirement: Resolve port variables against .env
The system SHALL read the worktree's `.env` file and resolve each extracted variable to its actual value, producing a final list of local/remote port pairs.

#### Scenario: Variable present in .env
- **WHEN** `DB_PORT=15432` exists in `.env` and the compose default is `5432`
- **THEN** the system SHALL produce local=`5432`, remote=`15432`

#### Scenario: Variable absent from .env
- **WHEN** `DB_PORT` is not defined in `.env` and the compose default is `5432`
- **THEN** the system SHALL produce local=`5432`, remote=`5432`

#### Scenario: Literal port (no variable)
- **WHEN** the port entry has no variable (literal `"8080:8080"`)
- **THEN** the system SHALL produce local=`8080`, remote=`8080`

### Requirement: Missing compose file is a fatal error
The system SHALL abort session creation if `docker-compose.dev.yml` does not exist in the selected worktree.

#### Scenario: No compose file
- **WHEN** the user selects a worktree that has no `docker-compose.dev.yml`
- **THEN** the system SHALL print an error message and exit without creating a session

### Requirement: Missing .env uses all defaults
The system SHALL fall back to compose defaults for all ports if `.env` does not exist.

#### Scenario: No .env file
- **WHEN** the selected worktree has `docker-compose.dev.yml` but no `.env`
- **THEN** the system SHALL use the default value for every variable port and proceed normally
