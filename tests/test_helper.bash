# test_helper.bash - Setup/teardown for beam tests
#
# Provides:
#   - Temporary STATE_DIR/STATE_FILE per test
#   - Sources beam functions without executing main
#   - Mock ssh command in PATH

BEAM_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/beam"

setup() {
    # Create a temp directory for state isolation
    TEST_TMPDIR="$(mktemp -d)"
    export STATE_DIR="${TEST_TMPDIR}/state"
    export STATE_FILE="${STATE_DIR}/state.json"
    mkdir -p "$STATE_DIR"

    # Create mock bin directory and add to PATH
    MOCK_BIN="${TEST_TMPDIR}/mock_bin"
    mkdir -p "$MOCK_BIN"
    export ORIGINAL_PATH="$PATH"
    export PATH="${MOCK_BIN}:${PATH}"

    # Create default mock ssh that returns empty
    cat > "${MOCK_BIN}/ssh" << 'MOCK_SSH'
#!/bin/bash
# Default mock ssh - returns empty output
# Override per-test by writing a new script to this path
exit 0
MOCK_SSH
    chmod +x "${MOCK_BIN}/ssh"

    # Create mock lsof that always says port is free
    cat > "${MOCK_BIN}/lsof" << 'MOCK_LSOF'
#!/bin/bash
# Default mock lsof - port not in use
exit 1
MOCK_LSOF
    chmod +x "${MOCK_BIN}/lsof"

    # Create mock pgrep that returns a fake PID
    cat > "${MOCK_BIN}/pgrep" << 'MOCK_PGREP'
#!/bin/bash
echo "99999"
MOCK_PGREP
    chmod +x "${MOCK_BIN}/pgrep"

    # Source beam functions (the source guard prevents main execution)
    source "$BEAM_SCRIPT"
}

teardown() {
    # Restore PATH
    export PATH="$ORIGINAL_PATH"
    # Clean up temp directory
    rm -rf "$TEST_TMPDIR"
}

# Helper: create a space in state
helper_create_space() {
    local name="$1"
    init_state
    local state
    state=$(read_state)
    state=$(echo "$state" | jq ".spaces[\"$name\"] = {\"sessions\": {}}")
    write_state "$state"
}

# Helper: add a session to a space in state
helper_add_session() {
    local space="$1"
    local session="$2"
    local host="${3:-testhost}"
    local status="${4:-dormant}"
    local pid="${5:-null}"
    local lc="${6:-3000}"
    local ls="${7:-3001}"
    local rc="${8:-12225}"
    local rs="${9:-11570}"

    local state
    state=$(read_state)
    state=$(echo "$state" | jq ".spaces[\"$space\"].sessions[\"$session\"] = {
        \"host\": \"$host\",
        \"project\": \"testproj\",
        \"worktree\": \"testproj.wt\",
        \"remote_client_port\": $rc,
        \"remote_server_port\": $rs,
        \"local_client_port\": $lc,
        \"local_server_port\": $ls,
        \"status\": \"$status\",
        \"pid\": $pid
    }")
    write_state "$state"
}
