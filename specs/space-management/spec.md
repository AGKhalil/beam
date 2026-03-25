## ADDED Requirements

### Requirement: List spaces
The system SHALL display all existing spaces when the user runs `beam space ls`.

#### Scenario: Spaces exist
- **WHEN** the user runs `beam space ls` and spaces exist in state
- **THEN** the system displays each space name, one per line

#### Scenario: No spaces exist
- **WHEN** the user runs `beam space ls` and no spaces exist
- **THEN** the system displays a message indicating no spaces have been created

### Requirement: Create a space
The system SHALL create a new named space when the user runs `beam space create <name>`.

#### Scenario: Create new space
- **WHEN** the user runs `beam space create proteinea`
- **THEN** the system creates a space named "proteinea" in the state file and confirms creation

#### Scenario: Space already exists
- **WHEN** the user runs `beam space create proteinea` and a space named "proteinea" already exists
- **THEN** the system displays an error indicating the space already exists

### Requirement: Remove a space
The system SHALL remove a space when the user runs `beam space rm <name>`, subject to safety constraints.

#### Scenario: Remove empty space
- **WHEN** the user runs `beam space rm proteinea` and the space has no sessions
- **THEN** the system removes the space from state and confirms removal

#### Scenario: Remove space with sessions without force flag
- **WHEN** the user runs `beam space rm proteinea` and the space contains sessions and `--force` is not provided
- **THEN** the system displays an error indicating the space is not empty and suggests using `--force`

#### Scenario: Force remove space with sessions
- **WHEN** the user runs `beam space rm proteinea --force` and the space contains sessions
- **THEN** the system kills any live tunnels in the space, removes all sessions, removes the space, and confirms removal

#### Scenario: Remove nonexistent space
- **WHEN** the user runs `beam space rm nonexistent` and no space with that name exists
- **THEN** the system displays an error indicating the space does not exist
