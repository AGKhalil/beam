## ADDED Requirements

### Requirement: Scan-only SSH calls suppress port forwarding

All SSH commands used for remote scanning (listing projects, reading `.env` files, reading port values) SHALL include `-o ClearAllForwardings=yes` to prevent `LocalForward`, `RemoteForward`, and `DynamicForward` directives from `~/.ssh/config` from executing during scan operations.

#### Scenario: Scanning projects does not trigger port forwarding
- **WHEN** the user runs `beam <space> create` and enters an SSH host
- **AND** the host has `RemoteForward` or `LocalForward` directives in `~/.ssh/config`
- **THEN** the project listing SSH call SHALL NOT attempt to forward any ports
- **AND** no `bind: Address already in use` or `cannot listen to port` warnings SHALL appear in the output

#### Scenario: Reading worktree ports does not trigger port forwarding
- **WHEN** the system SSHes to the remote host to read `WASP_CLIENT_PORT` from worktree `.env` files
- **AND** the host has forwarding directives in `~/.ssh/config`
- **THEN** the port-reading SSH call SHALL NOT attempt to forward any ports

#### Scenario: Reading remote .env does not trigger port forwarding
- **WHEN** the system SSHes to the remote host to `cat` the full `.env` file for port extraction
- **AND** the host has forwarding directives in `~/.ssh/config`
- **THEN** the .env-reading SSH call SHALL NOT attempt to forward any ports

#### Scenario: SSH config host aliases and identity files are preserved
- **WHEN** scan-only SSH calls use `-o ClearAllForwardings=yes`
- **THEN** host aliases, identity files, proxy jumps, and other non-forwarding SSH config directives SHALL continue to work
