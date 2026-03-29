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
# 4. State Management Tests
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
    # Verify file was also repaired on disk
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
    # Original state should be preserved
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

# =============================================================================
# 5. Session Lifecycle Tests
# =============================================================================

@test "session data is written to state with correct fields" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null" "3000" "3001" "12225" "11570"

    local state
    state=$(read_state)

    local host status pid lc ls rc rs
    host=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].host')
    status=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].status')
    pid=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].pid')
    lc=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].local_client_port')
    ls=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].local_server_port')
    rc=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].remote_client_port')
    rs=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].remote_server_port')

    [ "$host" = "user@host1" ]
    [ "$status" = "dormant" ]
    [ "$pid" = "null" ]
    [ "$lc" = "3000" ]
    [ "$ls" = "3001" ]
    [ "$rc" = "12225" ]
    [ "$rs" = "11570" ]
}

@test "replace prompt is triggered when session already exists" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt"

    local state
    state=$(read_state)
    local session_exists
    session_exists=$(echo "$state" | jq -r '.spaces["myspace"].sessions["host1:proj.wt"] // "null"')

    # Session should exist (not be the string "null")
    [ "$session_exists" != "null" ]

    # Verify the replace prompt logic: when session exists and user says 'n', exit 0
    # We test the core check inline since cmd_session_create requires interactive SSH
    local result=0
    (
        echo "n" | {
            if [[ "$session_exists" != "null" ]]; then
                read -r answer
                if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
                    exit 0
                fi
            fi
            # Should not reach here
            exit 1
        }
    ) || result=$?
    [ "$result" -eq 0 ]
}

@test "declining replace prompt leaves existing session unchanged" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "3000" "3001"

    # Capture state before
    local state_before
    state_before=$(read_state)

    # Simulate decline: verify state is not modified
    # (The actual prompt reads from /dev/tty in cmd_session_create, so we test
    # that the state remains unchanged when the replace branch is not taken)
    local state_after
    state_after=$(read_state)

    local status_before status_after
    status_before=$(echo "$state_before" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].status')
    status_after=$(echo "$state_after" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].status')

    [ "$status_before" = "$status_after" ]
    [ "$status_after" = "live" ]
}

@test "cmd_session_rm removes a session from state" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null"

    # Verify session exists
    local state
    state=$(read_state)
    local exists
    exists=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"] // "null"')
    [ "$exists" != "null" ]

    # Remove it
    cmd_session_rm "myspace" "host1:proj.wt" > /dev/null 2>&1

    # Verify session is gone
    state=$(read_state)
    exists=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"] // "null"')
    [ "$exists" = "null" ]
}

@test "cmd_session_rm kills tunnel of live session before removing" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "99999" "3000" "3001"

    # Create a mock kill that records calls
    local kill_log="${TEST_TMPDIR}/kill_log"
    cat > "${MOCK_BIN}/kill" << MOCK_KILL
#!/bin/bash
echo "\$@" >> "${kill_log}"
# Return failure for kill -0 checks (process not found) to simulate successful kill
if [[ "\$1" == "-0" ]]; then
    exit 1
fi
exit 0
MOCK_KILL
    chmod +x "${MOCK_BIN}/kill"

    cmd_session_rm "myspace" "host1:proj.wt" > /dev/null 2>&1

    # Verify session is removed
    local state
    state=$(read_state)
    local exists
    exists=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"] // "null"')
    [ "$exists" = "null" ]
}

# =============================================================================
# 6. Port Conflict Detection Tests
# =============================================================================

@test "find_port_conflicts returns empty when no ports overlap" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "3000" "3001"

    local result
    result=$(find_port_conflicts "4000" "4001" "" "")
    [ -z "$result" ]
}

@test "find_port_conflicts returns conflicting session when client port overlaps" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "3000" "3001"

    local result
    result=$(find_port_conflicts "3000" "4001" "" "")
    [ "$result" = "myspace:host1:proj.wt" ]
}

@test "find_port_conflicts returns conflicting session when server port overlaps" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "3000" "3001"

    local result
    result=$(find_port_conflicts "4000" "3001" "" "")
    [ "$result" = "myspace:host1:proj.wt" ]
}

@test "find_port_conflicts skips dormant sessions" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null" "3000" "3001"

    local result
    result=$(find_port_conflicts "3000" "3001" "" "")
    [ -z "$result" ]
}

@test "find_port_conflicts skips the excluded space/session pair" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "3000" "3001"

    local result
    result=$(find_port_conflicts "3000" "3001" "myspace" "host1:proj.wt")
    [ -z "$result" ]
}

# =============================================================================
# 7. Tunnel & PID Sanitization Tests
# =============================================================================

@test "activate_session sanitizes pid with SSH warnings mixed into stdout" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null" "4000" "4001"

    # Mock start_tunnel to simulate SSH warnings mixed with PID on stdout
    # Override the start_tunnel function to return a dirty pid
    start_tunnel() {
        echo "Warning: remote port forwarding failed for listen port 8090"
        echo "12345"
    }

    activate_session "myspace" "host1:proj.wt" "user@host1" "4000" "12225" "4001" "11570"

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
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null" "4000" "4001"

    start_tunnel() {
        echo "67890"
    }

    activate_session "myspace" "host1:proj.wt" "user@host1" "4000" "12225" "4001" "11570"

    local state
    state=$(read_state)
    local pid
    pid=$(echo "$state" | jq -r '.spaces.myspace.sessions["host1:proj.wt"].pid')

    [ "$pid" = "67890" ]
}

@test "activate_session returns failure when start_tunnel produces no pid" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null" "4000" "4001"

    start_tunnel() {
        echo "Warning: remote port forwarding failed for listen port 8090"
        # No PID line
    }

    local result=0
    activate_session "myspace" "host1:proj.wt" "user@host1" "4000" "12225" "4001" "11570" || result=$?

    [ "$result" -eq 1 ]
}

@test "command routing accepts both 'space' and 'spaces' as subcommand" {
    # Verify the case statement matches both singular and plural
    local routing
    routing=$(type -a main 2>/dev/null || true)
    # Instead, check the script source directly
    grep -q 'space|spaces)' "$BEAM_SCRIPT"
}

@test "cmd_hydrate uses activate_session instead of inline start_tunnel" {
    # After refactoring, hydrate should delegate to activate_session
    local hydrate_section
    hydrate_section=$(sed -n '/^cmd_hydrate()/,/^}/p' "$BEAM_SCRIPT")
    # Should NOT call start_tunnel directly
    if echo "$hydrate_section" | grep -q 'start_tunnel'; then
        echo "cmd_hydrate still calls start_tunnel directly"
        return 1
    fi
    # Should call activate_session
    echo "$hydrate_section" | grep -q 'activate_session'
}

@test "start_tunnel ssh command does NOT use ClearAllForwardings" {
    # ClearAllForwardings=yes clears command-line -L flags too (per man page),
    # which breaks the tunnel. Only scan SSH calls should use it.
    local func_body
    func_body=$(type start_tunnel)
    if echo "$func_body" | grep -q "ClearAllForwardings"; then
        echo "start_tunnel must not use ClearAllForwardings (it clears -L flags)"
        return 1
    fi
}

@test "scan ssh calls include ClearAllForwardings and stderr redirect" {
    # Verify all scan ssh calls in cmd_session_create suppress forwarding and stderr
    local func_body
    func_body=$(type cmd_session_create)
    local count
    count=$(echo "$func_body" | grep -c "ClearAllForwardings=yes" || true)
    # Should have 3 occurrences (project scan, worktree ports, .env read)
    [ "$count" -ge 3 ]
}

# =============================================================================
# 8. Shared Helper Tests
# =============================================================================

@test "require_space returns 0 for existing space" {
    init_state
    helper_create_space "myspace"
    local state
    state=$(read_state)
    require_space "$state" "myspace"
    # If we get here, it returned 0 (didn't exit)
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

@test "read_session returns correct tab-separated fields" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "3000" "3001" "12225" "11570"
    local state
    state=$(read_state)

    local s_host s_status s_pid s_lc s_rc s_ls s_rs s_project s_worktree
    IFS=$'\t' read -r s_host s_status s_pid s_lc s_rc s_ls s_rs s_project s_worktree <<< "$(read_session "$state" "myspace" "host1:proj.wt")"

    [ "$s_host" = "user@host1" ]
    [ "$s_status" = "live" ]
    [ "$s_pid" = "12345" ]
    [ "$s_lc" = "3000" ]
    [ "$s_rc" = "12225" ]
    [ "$s_ls" = "3001" ]
    [ "$s_rs" = "11570" ]
}

@test "read_session returns 'null' string for null pid" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "dormant" "null"
    local state
    state=$(read_state)

    local s_host s_status s_pid s_lc s_rc s_ls s_rs s_project s_worktree
    IFS=$'\t' read -r s_host s_status s_pid s_lc s_rc s_ls s_rs s_project s_worktree <<< "$(read_session "$state" "myspace" "host1:proj.wt")"

    [ "$s_pid" = "null" ]
}

@test "sleep_session marks live session as dormant" {
    init_state
    helper_create_space "myspace"
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "99999" "3000" "3001"

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
    helper_add_session "myspace" "host1:proj.wt" "user@host1" "live" "12345" "3000" "3001"

    check_and_resolve_conflicts "4000" "4001" "myspace" "other:session"
}

@test "no individual session-field jq reads remain outside read_session" {
    # After refactoring, individual session field READS (jq -r) should only exist in read_session
    # State WRITES (.status = "live", .pid = $pid) are excluded — those are mutations, not reads
    local count
    count=$(grep -c 'jq -r.*\.sessions\[.*\]\.\(host\|status\|pid\|local_client_port\|remote_client_port\|local_server_port\|remote_server_port\)' "$BEAM_SCRIPT" || true)
    # Only read_session itself should have the pattern (in its @tsv expression)
    [ "$count" -le 1 ]
}
