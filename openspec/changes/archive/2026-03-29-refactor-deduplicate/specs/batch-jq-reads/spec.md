## ADDED Requirements

### Requirement: read_session returns all session fields in one jq call

The system SHALL provide a `read_session` helper that reads all session fields (host, status, pid, local_client_port, remote_client_port, local_server_port, remote_server_port, project, worktree) in a single jq invocation and returns them as tab-separated values. All functions that read session fields MUST use this helper instead of individual jq calls.

#### Scenario: Read all fields for an existing session
- **WHEN** `read_session "$state" "myspace" "host1:proj.wt"` is called
- **AND** the session exists with known field values
- **THEN** the function SHALL output a single tab-separated line containing: host, status, pid, local_client_port, remote_client_port, local_server_port, remote_server_port, project, worktree

#### Scenario: Caller destructures the output
- **WHEN** the caller uses `IFS=$'\t' read -r s_host s_status s_pid s_lc s_rc s_ls s_rs s_project s_worktree <<< "$(read_session ...)"` 
- **THEN** each variable SHALL contain the correct corresponding field value

#### Scenario: Null pid is returned as the string "null"
- **WHEN** a session has `"pid": null` in state
- **THEN** `read_session` SHALL return the string `null` for the pid field (not empty string)

### Requirement: Elimination of individual jq field reads

After refactoring, no command function SHALL read individual session fields via separate `echo "$state" | jq -r ".spaces[...].sessions[...].<field>"` calls. All session field reads MUST go through `read_session`.

#### Scenario: No individual session field jq calls remain
- **WHEN** the refactoring is complete
- **THEN** searching the beam script for the pattern `jq.*\.sessions\[.*\]\.\(host\|status\|pid\|local_client_port\|remote_client_port\|local_server_port\|remote_server_port\)` SHALL return zero matches outside of `read_session` itself
