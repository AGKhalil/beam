## 1. Fix Session Exists Hard-Fail (session-replace)

- [x] 1.1 In `cmd_session_create()` (line 704-709), replace the hard `exit 1` on existing session with a replace prompt: print a warning that the session exists, prompt `"Replace it? (y/n)"`, read from `/dev/tty`
- [x] 1.2 On user confirming replace (`y`): if the existing session is `live`, call `kill_tunnel` with its pid/ports and wait for port release; then delete the session from state via `jq del()`; re-read state before proceeding to create the new session
- [x] 1.3 On user declining replace (`n`): print a cancellation hint and `exit 0` (graceful exit, not error)
- [x] 1.4 Verify the replace flow works end-to-end: existing live session is torn down, new session is created and activated with new port configuration

## 2. Suppress SSH Scan Noise (clean-ssh-scans)

- [x] 2.1 Add `-o ClearAllForwardings=yes` to the project-scanning SSH call at line 574 (`ssh -o ConnectTimeout=10 "$host" 'ls -1d ~/codebases/*/...'`)
- [x] 2.2 Add `-o ClearAllForwardings=yes` to the worktree-port-reading SSH call at line 643 (`ssh -o ConnectTimeout=10 "$host" "$grep_cmd"`)
- [x] 2.3 Add `-o ClearAllForwardings=yes` to the `.env`-reading SSH call at line 677 (`ssh -o ConnectTimeout=10 "$host" "cat ~/codebases/$worktree/.env..."`)
- [x] 2.4 Verify that `beam <space> create` no longer shows `bind: Address already in use` or `cannot listen to port` warnings during the scanning/selection phase

## 3. Test Harness Setup

- [x] 3.1 Create `tests/` directory and add a `tests/test_helper.bash` file with: temporary state directory setup/teardown, helper to source beam functions, mock SSH command that returns canned responses
- [x] 3.2 Create `tests/beam_test.bats` as the main test file with bats shebang and helper load
- [x] 3.3 Document test running instructions in a comment at the top of the test file (or in README)

## 4. State Management Tests

- [x] 4.1 Test `init_state` creates `STATE_FILE` with `{"spaces": {}}` when file does not exist
- [x] 4.2 Test `read_state` returns the current contents of `STATE_FILE`
- [x] 4.3 Test `write_state` overwrites `STATE_FILE` with new content
- [x] 4.4 Test `cmd_space_create` adds a space with empty sessions object to state

## 5. Session Lifecycle Tests

- [x] 5.1 Test that creating a session adds it to the state file with correct host, ports, worktree, status=dormant, pid=null
- [x] 5.2 Test that the replace prompt is triggered when a session with the same name already exists
- [x] 5.3 Test that declining the replace prompt leaves the existing session unchanged
- [x] 5.4 Test `cmd_session_rm` removes a session from state and kills its tunnel if live

## 6. Port Conflict Detection Tests

- [x] 6.1 Test `find_port_conflicts` returns empty when no ports overlap
- [x] 6.2 Test `find_port_conflicts` returns the conflicting session when client port overlaps
- [x] 6.3 Test `find_port_conflicts` returns the conflicting session when server port overlaps
- [x] 6.4 Test `find_port_conflicts` skips dormant sessions (only checks live sessions)
- [x] 6.5 Test `find_port_conflicts` skips the excluded space/session pair

## 7. Verification

- [x] 7.1 Run full bats test suite and confirm all tests pass
- [x] 7.2 Manual smoke test: `beam <space> create` with an already-existing session shows replace prompt and works on confirmation
