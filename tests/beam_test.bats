#!/usr/bin/env bats
# beam_test.bats - Automated tests for the beam CLI
#
# Run with: bats tests/beam_test.bats
# Requires: bats-core (brew install bats-core)
#
# Tests use temporary state files and mock SSH/lsof/pgrep commands.
# No real SSH connections are made.

load test_helper

# =============================================================================
# 1. Compose Port Discovery Tests
# =============================================================================

@test "parse_compose_ports extracts variable ports with defaults" {
    local result
    result=$(parse_compose_ports "$SAMPLE_COMPOSE")
    echo "$result" | grep -q "db|DB_PORT|5432"
}

@test "parse_compose_ports extracts multiple ports from one service" {
    local result
    result=$(parse_compose_ports "$SAMPLE_COMPOSE")
    local wasp_count
    wasp_count=$(echo "$result" | grep -c "^wasp|")
    [ "$wasp_count" -eq 2 ]
}

@test "parse_compose_ports extracts literal ports" {
    local result
    result=$(parse_compose_ports "$SAMPLE_COMPOSE")
    echo "$result" | grep -q "api||8080"
}

@test "parse_compose_ports skips services without ports" {
    local result
    result=$(parse_compose_ports "$SAMPLE_COMPOSE")
    ! echo "$result" | grep -q "^worker|"
}

@test "parse_compose_ports warns on unrecognized port format" {
    local compose_with_bad_port='services:
  web:
    ports:
      - "host.docker.internal:8080:8080"
'
    local stderr_output
    stderr_output=$(parse_compose_ports "$compose_with_bad_port" 2>&1 >/dev/null || true)
    echo "$stderr_output" | grep -q "unrecognized port format"
}

@test "parse_compose_ports returns all expected entries from sample" {
    local result
    result=$(parse_compose_ports "$SAMPLE_COMPOSE")
    local count
    count=$(echo "$result" | wc -l | tr -d ' ')
    [ "$count" -eq 5 ]
}

# =============================================================================
# 2. Port Resolution Tests
# =============================================================================

@test "resolve_ports resolves variable from .env" {
    local parsed="db|DB_PORT|5432"
    local env_content="DB_PORT=15432"
    local result
    result=$(resolve_ports "$parsed" "$env_content")
    local local_port remote_port
    local_port=$(echo "$result" | jq -r '.[0].local')
    remote_port=$(echo "$result" | jq -r '.[0].remote')
    [ "$local_port" = "5432" ]
    [ "$remote_port" = "15432" ]
}

@test "resolve_ports uses default when variable absent from .env" {
    local parsed="db|DB_PORT|5432"
    local env_content="OTHER_VAR=123"
    local result
    result=$(resolve_ports "$parsed" "$env_content")
    local remote_port
    remote_port=$(echo "$result" | jq -r '.[0].remote')
    [ "$remote_port" = "5432" ]
}

@test "resolve_ports handles literal ports (no variable)" {
    local parsed="api||8080"
    local result
    result=$(resolve_ports "$parsed" "")
    local local_port remote_port
    local_port=$(echo "$result" | jq -r '.[0].local')
    remote_port=$(echo "$result" | jq -r '.[0].remote')
    [ "$local_port" = "8080" ]
    [ "$remote_port" = "8080" ]
}

@test "resolve_ports uses all defaults when .env is empty" {
    local parsed="db|DB_PORT|5432
wasp|WASP_CLIENT_PORT|3000"
    local result
    result=$(resolve_ports "$parsed" "")
    local count
    count=$(echo "$result" | jq 'length')
    [ "$count" = "2" ]
    local r1 r2
    r1=$(echo "$result" | jq -r '.[0].remote')
    r2=$(echo "$result" | jq -r '.[1].remote')
    [ "$r1" = "5432" ]
    [ "$r2" = "3000" ]
}

@test "resolve_ports includes service name in output" {
    local parsed="redis|REDIS_PORT|6381"
    local result
    result=$(resolve_ports "$parsed" "REDIS_PORT=16381")
    local service
    service=$(echo "$result" | jq -r '.[0].service')
    [ "$service" = "redis" ]
}

# =============================================================================
# 3. State Management Tests
# =============================================================================

@test "init_state creates STATE_FILE with empty spaces when file does not exist" {
    rm -f "$STATE_FILE"
    init_state
    [ -f "$STATE_FILE" ]
    local content
    content=$(cat "$STATE_FILE")
    [ "$content" = '{"spaces": {}}' ]
}

@test "read_state resets corrupted state file to defaults" {
    echo "corrupted garbage" > "$STATE_FILE"
    local result
    result=$(read_state 2>/dev/null)
    local spaces
    spaces=$(echo "$result" | jq -r '.spaces | keys | length')
    [ "$spaces" = "0" ]
    local on_disk
    on_disk=$(cat "$STATE_FILE")
    echo "$on_disk" | jq empty 2>/dev/null
}

@test "read_state resets empty/newline-only state file to defaults" {
    printf '\n' > "$STATE_FILE"
    local result
    result=$(read_state 2>/dev/null)
    local spaces
    spaces=$(echo "$result" | jq -r '.spaces | keys | length')
    [ "$spaces" = "0" ]
}

@test "write_state rejects invalid JSON" {
    init_state
    local result=0
    write_state "not valid json" 2>/dev/null || result=$?
    [ "$result" -eq 1 ]
    local content
    content=$(cat "$STATE_FILE")
    echo "$content" | jq empty 2>/dev/null
}

@test "read_state returns current contents of STATE_FILE" {
    echo '{"spaces": {"myspace": {"sessions": {}}}}' > "$STATE_FILE"
    local result
    result=$(read_state)
    local space_val
    space_val=$(echo "$result" | jq -r '.spaces.myspace.sessions')
    [ "$space_val" = "{}" ]
}

@test "write_state overwrites STATE_FILE with new content" {
    init_state
    local new_state='{"spaces": {"newspace": {"sessions": {}}}}'
    write_state "$new_state"
    local content
    content=$(cat "$STATE_FILE")
    local val
    val=$(echo "$content" | jq -r '.spaces.newspace.sessions')
    [ "$val" = "{}" ]
}

@test "cmd_space_create adds a space with empty sessions object to state" {
    init_state
    cmd_space_create "testspace" > /dev/null 2>&1
    local state
    state=$(read_state)
    local sessions
    sessions=$(echo "$state" | jq -r '.spaces.testspace.sessions')
    [ "$sessions" = "{}" ]
}

@test "cmd_space_create initializes empty hosts array" {
    init_state
    cmd_space_create "testspace" > /dev/null 2>&1
    local state
    state=$(read_state)
    local hosts_count
    hosts_count=$(echo "$state" | jq '.spaces.testspace.hosts | length')
    [ "$hosts_count" = "0" ]
    # Verify it's an array, not null
    local hosts_type
    hosts_type=$(echo "$state" | jq -r '.spaces.testspace.hosts | type')
    [ "$hosts_type" = "array" ]
}

@test "get_space_hosts returns empty array for spaces without hosts field" {
    init_state
    # Manually create a space without hosts (old format)
    local state
    state=$(read_state)
    state=$(echo "$state" | jq '.spaces.oldspace = {"sessions": {}}')
    write_state "$state"

    local result
    result=$(get_space_hosts "$state" "oldspace")
    local count
    count=$(echo "$result" | jq 'length')
    [ "$count" = "0" ]
}

@test "get_space_hosts returns hosts for space with hosts" {
    init_state
    local state='{"spaces": {"myspace": {"hosts": ["host1", "host2"], "sessions": {}}}}'
    write_state "$state"

    local result
    result=$(get_space_hosts "$state" "myspace")
    local count
    count=$(echo "$result" | jq 'length')
    [ "$count" = "2" ]
    local first
    first=$(echo "$result" | jq -r '.[0]')
    [ "$first" = "host1" ]
}

@test "add_space_host appends new host" {
    init_state
    cmd_space_create "testspace" > /dev/null 2>&1

    add_space_host "testspace" "ag@hetzner1"

    local state
    state=$(read_state)
    local count
    count=$(echo "$state" | jq '.spaces.testspace.hosts | length')
    [ "$count" = "1" ]
    local host
    host=$(echo "$state" | jq -r '.spaces.testspace.hosts[0]')
    [ "$host" = "ag@hetzner1" ]
}

@test "add_space_host prevents duplicates" {
    init_state
    cmd_space_create "testspace" > /dev/null 2>&1

    add_space_host "testspace" "ag@hetzner1"
    add_space_host "testspace" "ag@hetzner1"

    local state
    state=$(read_state)
    local count
    count=$(echo "$state" | jq '.spaces.testspace.hosts | length')
    [ "$count" = "1" ]
}

@test "add_space_host accumulates multiple hosts" {
    init_state
    cmd_space_create "testspace" > /dev/null 2>&1

    add_space_host "testspace" "hostA"
    add_space_host "testspace" "hostB"

    local state
    state=$(read_state)
    local count
    count=$(echo "$state" | jq '.spaces.testspace.hosts | length')
    [ "$count" = "2" ]
}

@test "space removal deletes hosts with the space" {
    init_state
    cmd_space_create "testspace" > /dev/null 2>&1
    add_space_host "testspace" "ag@hetzner1"

    cmd_space_rm "testspace" > /dev/null 2>&1

    local state
    state=$(read_state)
    local exists
    exists=$(echo "$state" | jq -r '.spaces.testspace // "null"')
    [ "$exists" = "null" ]
}

# =============================================================================
# 4. Session Lifecycle Tests (ports array format)
# =============================================================================

@test "session data is written to state with ports array" {
    init_state
    helper_create_space "myspace"
    local ports='[{"local":5432,"remote":15432,"service":"db"},{"local":3000,"remote":17331,"service":"wasp"}]'
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null" "$ports"

    local state
    state=$(read_state)

    local host status port_count first_local first_remote
    host=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].host')
    status=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].status')
    port_count=$(echo "$state" | jq '.spaces.myspace.sessions["host1:proj.wt"].ports | length')
    first_local=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].ports[0].local')
    first_remote=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].ports[0].remote')

    [ "$host" = "user@host1" ]
    [ "$status" = "dormant" ]
    [ "$port_count" = "2" ]
    [ "$first_local" = "5432" ]
    [ "$first_remote" = "15432" ]
}

@test "cmd_session_rm removes a session from state" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null"

    local state
    state=$(read_state)
    local exists
    exists=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"] // "null"')
    [ "$exists" != "null" ]

    cmd_session_rm "myspace" "host1:proj.wt" > /dev/null 2>&1

    state=$(read_state)
    exists=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"] // "null"')
    [ "$exists" = "null" ]
}

@test "cmd_session_rm kills tunnel of live session before removing" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "99999"

    cat > "${MOCK_BIN}/kill" << MOCK_KILL
#!/bin/bash
echo "\$@" >> "${TEST_TMPDIR}/kill_log"
if [[ "\$1" == "-0" ]]; then
    exit 1
fi
exit 0
MOCK_KILL
    chmod +x "${MOCK_BIN}/kill"

    cmd_session_rm "myspace" "host1:proj.wt" > /dev/null 2>&1

    local state
    state=$(read_state)
    local exists
    exists=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"] // "null"')
    [ "$exists" = "null" ]
}

# =============================================================================
# 5. Port Conflict Detection Tests (N-port model)
# =============================================================================

@test "find_port_conflicts returns empty when no ports overlap" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345"

    local target='[{"local":4000,"remote":14000,"service":"test"},{"local":4001,"remote":14001,"service":"test"}]'
    local result
    result=$(find_port_conflicts "$target" "" "")
    [ -z "$result" ]
}

@test "find_port_conflicts detects overlap on single port" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345"

    # Default ports include local:3000 — target also wants 3000
    local target='[{"local":3000,"remote":17331,"service":"wasp"},{"local":4001,"remote":14001,"service":"test"}]'
    local result
    result=$(find_port_conflicts "$target" "" "")
    [ "$result" = "myspace:host1:proj.wt" ]
}

@test "find_port_conflicts skips dormant sessions" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null"

    local target='[{"local":3000,"remote":17331,"service":"wasp"}]'
    local result
    result=$(find_port_conflicts "$target" "" "")
    [ -z "$result" ]
}

@test "find_port_conflicts skips the excluded space/session pair" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345"

    local target='[{"local":3000,"remote":17331,"service":"wasp"}]'
    local result
    result=$(find_port_conflicts "$target" "myspace" "host1:proj.wt")
    [ -z "$result" ]
}

@test "find_port_conflicts detects overlap across many ports" {
    init_state
    helper_create_space "myspace"
    local ports='[{"local":5432,"remote":15432,"service":"db"},{"local":6381,"remote":16381,"service":"redis"}]'
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "$ports"

    # Target wants 6381 which overlaps with existing redis
    local target='[{"local":3000,"remote":17331,"service":"wasp"},{"local":6381,"remote":26381,"service":"redis"}]'
    local result
    result=$(find_port_conflicts "$target" "" "")
    [ "$result" = "myspace:host1:proj.wt" ]
}

# =============================================================================
# 6. Tunnel & PID Sanitization Tests
# =============================================================================

@test "activate_session sanitizes pid with SSH warnings mixed into stdout" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null"

    start_tunnel() {
        echo "Warning: remote port forwarding failed for listen port 8090"
        echo "12345"
    }

    local ports_json
    ports_json=$(read_session_ports "$(read_state)" "myspace" "host1:proj.wt")
    activate_session "myspace" "host1:proj.wt" "user@host1" "$ports_json"

    local state
    state=$(read_state)
    local pid status
    pid=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].pid')
    status=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].status')

    [ "$pid" = "12345" ]
    [ "$status" = "live" ]
}

@test "activate_session handles clean pid output correctly" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null"

    start_tunnel() {
        echo "67890"
    }

    local ports_json
    ports_json=$(read_session_ports "$(read_state)" "myspace" "host1:proj.wt")
    activate_session "myspace" "host1:proj.wt" "user@host1" "$ports_json"

    local state
    state=$(read_state)
    local pid
    pid=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].pid')

    [ "$pid" = "67890" ]
}

@test "activate_session returns failure when start_tunnel produces no pid" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null"

    start_tunnel() {
        echo "Warning: remote port forwarding failed for listen port 8090"
    }

    local ports_json
    ports_json=$(read_session_ports "$(read_state)" "myspace" "host1:proj.wt")
    local result=0
    activate_session "myspace" "host1:proj.wt" "user@host1" "$ports_json" || result=$?

    [ "$result" -eq 1 ]
}

@test "command routing accepts both 'space' and 'spaces' as subcommand" {
    grep -q 'space|spaces)' "$BEAM_SCRIPT"
}

@test "cmd_hydrate uses activate_session instead of inline start_tunnel" {
    local hydrate_section
    hydrate_section=$(sed -n '/^cmd_hydrate()/,/^}/p' "$BEAM_SCRIPT")
    if echo "$hydrate_section" | grep -q 'start_tunnel'; then
        echo "cmd_hydrate still calls start_tunnel directly"
        return 1
    fi
    echo "$hydrate_section" | grep -q 'activate_session'
}

@test "start_tunnel ssh command does NOT use ClearAllForwardings" {
    local func_body
    func_body=$(type start_tunnel)
    if echo "$func_body" | grep -q "ClearAllForwardings"; then
        echo "start_tunnel must not use ClearAllForwardings (it clears -L flags)"
        return 1
    fi
}

@test "scan ssh calls include ClearAllForwardings and stderr redirect" {
    local func_body
    func_body=$(type cmd_session_create)
    local count
    count=$(echo "$func_body" | grep -c "ClearAllForwardings=yes" || true)
    [ "$count" -ge 3 ]
}

# =============================================================================
# 7. Shared Helper Tests
# =============================================================================

@test "require_space returns 0 for existing space" {
    init_state
    helper_create_space "myspace"
    local state
    state=$(read_state)
    require_space "$state" "myspace"
}

@test "require_space exits 1 for missing space" {
    init_state
    local state
    state=$(read_state)
    local result=0
    (require_space "$state" "nonexistent" 2>/dev/null) || result=$?
    [ "$result" -eq 1 ]
}

@test "require_session returns 0 for existing session" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt"
    local state
    state=$(read_state)
    require_session "$state" "myspace" "host1:proj.wt"
}

@test "require_session exits 1 for missing session" {
    init_state
    helper_create_space "myspace"
    local state
    state=$(read_state)
    local result=0
    (require_session "$state" "myspace" "nosession" 2>/dev/null) || result=$?
    [ "$result" -eq 1 ]
}

@test "read_session returns correct tab-separated fields (new format)" {
    init_state
    helper_create_space "myspace"
    local ports='[{"local":3000,"remote":12225,"service":"wasp"},{"local":3001,"remote":11570,"service":"wasp"}]'
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "$ports"
    local state
    state=$(read_state)

    local s_host s_status s_pid s_project s_worktree
    IFS=$'\t' read -r s_host s_status s_pid s_project s_worktree <<< "$(read_session "$state" "myspace" "host1:proj.wt")"

    [ "$s_host" = "user@host1" ]
    [ "$s_status" = "live" ]
    [ "$s_pid" = "12345" ]
    [ "$s_project" = "testproj" ]
    [ "$s_worktree" = "testproj.wt" ]
}

@test "read_session_ports returns ports JSON array" {
    init_state
    helper_create_space "myspace"
    local ports='[{"local":5432,"remote":15432,"service":"db"}]'
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "$ports"
    local state
    state=$(read_state)

    local result
    result=$(read_session_ports "$state" "myspace" "host1:proj.wt")
    local count local_port
    count=$(echo "$result" | jq 'length')
    local_port=$(echo "$result" | jq -r '.[0].local')

    [ "$count" = "1" ]
    [ "$local_port" = "5432" ]
}

@test "read_session_ports returns empty array for session without ports field" {
    init_state
    helper_create_space "myspace"
    # Manually create old-format session (no ports field)
    local state
    state=$(read_state)
    state=$(echo "$state" | jq '.spaces.myspace.sessions["old:session"] = {
        "host": "testhost",
        "project": "proj",
        "worktree": "proj.wt",
        "local_client_port": 3000,
        "remote_client_port": 12225,
        "local_server_port": 3001,
        "remote_server_port": 11570,
        "status": "dormant",
        "pid": null
    }')
    write_state "$state"

    local result
    result=$(read_session_ports "$state" "myspace" "old:session")
    local count
    count=$(echo "$result" | jq 'length')
    [ "$count" = "0" ]
}

@test "read_session returns 'null' string for null pid" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null"
    local state
    state=$(read_state)

    local s_host s_status s_pid s_project s_worktree
    IFS=$'\t' read -r s_host s_status s_pid s_project s_worktree <<< "$(read_session "$state" "myspace" "host1:proj.wt")"

    [ "$s_pid" = "null" ]
}

@test "sleep_session marks live session as dormant" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "99999"

    sleep_session "myspace" "host1:proj.wt"

    local state
    state=$(read_state)
    local status pid
    status=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].status')
    pid=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].pid')
    [ "$status" = "dormant" ]
    [ "$pid" = "null" ]
}

@test "sleep_session no-ops for dormant session" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null"

    sleep_session "myspace" "host1:proj.wt"

    local state
    state=$(read_state)
    local status
    status=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].status')
    [ "$status" = "dormant" ]
}

@test "check_and_resolve_conflicts returns 0 when no conflict" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345"

    local target='[{"local":4000,"remote":14000,"service":"test"},{"local":4001,"remote":14001,"service":"test"}]'
    check_and_resolve_conflicts "$target" "myspace" "other:session"
}

# =============================================================================
# 8. Start Tunnel Tests (dynamic -L flags)
# =============================================================================

@test "start_tunnel builds ssh command with N -L flags" {
    # Override ssh mock to capture the command
    cat > "${MOCK_BIN}/ssh" << 'MOCK_SSH'
#!/bin/bash
echo "$@" > /tmp/beam_test_ssh_args
echo "55555"
exit 0
MOCK_SSH
    chmod +x "${MOCK_BIN}/ssh"

    # Override lsof to say ports are listening
    cat > "${MOCK_BIN}/lsof" << 'MOCK_LSOF'
#!/bin/bash
exit 0
MOCK_LSOF
    chmod +x "${MOCK_BIN}/lsof"

    local ports='[{"local":5432,"remote":15432,"service":"db"},{"local":3000,"remote":17331,"service":"wasp"},{"local":3001,"remote":17332,"service":"wasp"}]'
    local result
    result=$(start_tunnel "user@host1" "$ports")

    # Check the ssh args file for -L flags
    local ssh_args
    ssh_args=$(cat /tmp/beam_test_ssh_args)

    echo "$ssh_args" | grep -q "\-L 5432:localhost:15432"
    echo "$ssh_args" | grep -q "\-L 3000:localhost:17331"
    echo "$ssh_args" | grep -q "\-L 3001:localhost:17332"

    rm -f /tmp/beam_test_ssh_args
}

@test "start_tunnel returns pid on success" {
    cat > "${MOCK_BIN}/ssh" << 'MOCK_SSH'
#!/bin/bash
exit 0
MOCK_SSH
    chmod +x "${MOCK_BIN}/ssh"
    cat > "${MOCK_BIN}/lsof" << 'MOCK_LSOF'
#!/bin/bash
exit 0
MOCK_LSOF
    chmod +x "${MOCK_BIN}/lsof"
    cat > "${MOCK_BIN}/pgrep" << 'MOCK_PGREP'
#!/bin/bash
echo "12345"
MOCK_PGREP
    chmod +x "${MOCK_BIN}/pgrep"

    local ports='[{"local":3000,"remote":17331,"service":"wasp"}]'
    local result
    result=$(start_tunnel "user@host1" "$ports")
    [ "$result" = "12345" ]
}

@test "no individual session-field jq reads remain outside read_session" {
    local count
    count=$(grep -c 'jq -r.*\.sessions\[.*\]\.\(host\|status\|pid\|local_client_port\|remote_client_port\|local_server_port\|remote_server_port\)' "$BEAM_SCRIPT" || true)
    [ "$count" -le 1 ]
}
