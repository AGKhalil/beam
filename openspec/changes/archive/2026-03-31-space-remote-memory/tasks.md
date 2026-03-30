## 1. State & Space Management

- [x] 1.1 Update `cmd_space_create` to initialize `hosts` as an empty array on new spaces
- [x] 1.2 Create `get_space_hosts` helper to read hosts array from state (returns `[]` if missing for backward compat)
- [x] 1.3 Create `add_space_host` helper to append a host to a space's hosts array (no-op if duplicate)

## 2. Host Selection UX

- [x] 2.1 Update `cmd_session_create` host input step: if space has known hosts, present arrow_select with hosts + "+ Enter a new host..." option
- [x] 2.2 Handle auto-select when space has exactly one known host
- [x] 2.3 Handle fallback to raw text prompt when space has no known hosts or user picks "new host"
- [x] 2.4 After successful session creation, call `add_space_host` to remember the host

## 3. Tests

- [x] 3.1 Test `cmd_space_create` initializes empty hosts array
- [x] 3.2 Test `get_space_hosts` returns empty array for spaces without hosts field
- [x] 3.3 Test `add_space_host` appends new host and prevents duplicates
- [x] 3.4 Test that space removal deletes hosts with the space
- [x] 3.5 Update session creation tests to verify host is remembered after creation
