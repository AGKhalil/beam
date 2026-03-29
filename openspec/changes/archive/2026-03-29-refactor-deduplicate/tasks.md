## 1. Add Shared Helper Functions

- [x] 1.1 Add `require_space "$state" "$space"` helper after the state read/write section — checks `.spaces["$space"]`, exits 1 with error if missing, returns 0 if found
- [x] 1.2 Add `require_session "$state" "$space" "$session"` helper — checks `.spaces["$space"].sessions["$session"]`, exits 1 with error if missing, returns 0 if found
- [x] 1.3 Add `read_session "$state" "$space" "$session"` helper — single jq call returning `host\tstatus\tpid\tlocal_client_port\tremote_client_port\tlocal_server_port\tremote_server_port\tproject\tworktree` via `@tsv`
- [x] 1.4 Add `sleep_session "$space" "$session"` helper — reads session state, calls `kill_tunnel` if live, updates state to dormant/pid=null
- [x] 1.5 Add `check_and_resolve_conflicts "$lc" "$ls" "$space" "$session"` helper — calls `find_port_conflicts`, parses result, calls `resolve_conflict`, returns 0 on resolved or no conflict, 1 on user cancel
- [x] 1.6 Add `activate_and_report "$space" "$session" "$host" "$lc" "$rc" "$ls" "$rs" "$success_msg"` helper — calls `activate_session`, prints success/failure message with port mappings
- [x] 1.7 Run tests — all 24 existing tests must pass (helpers added, no consumers changed yet)

## 2. Update Consumer Functions — Existence Checks

- [x] 2.1 Replace inline space-exists checks in `cmd_session_create` with `require_space`
- [x] 2.2 Replace inline space-exists checks in `cmd_session_ls` with `require_space`
- [x] 2.3 Replace inline space/session-exists checks in `cmd_session_up` with `require_space` + `require_session`
- [x] 2.4 Replace inline space/session-exists checks in `cmd_session_down` with `require_space` + `require_session`
- [x] 2.5 Replace inline space/session-exists checks in `cmd_session_rm` with `require_space` + `require_session`
- [x] 2.6 Replace inline space/session-exists checks in `cmd_session_switch` with `require_space` + `require_session`
- [x] 2.7 Replace inline space-exists check in `cmd_space_rm` with `require_space`
- [x] 2.8 Run tests — all 24 must pass

## 3. Update Consumer Functions — Batch Session Reads

- [x] 3.1 Replace individual jq field reads in `cmd_session_up` with `read_session` + IFS destructuring
- [x] 3.2 Replace individual jq field reads in `cmd_session_down` with `read_session` + IFS destructuring
- [x] 3.3 Replace individual jq field reads in `cmd_session_rm` with `read_session` + IFS destructuring
- [x] 3.4 Replace individual jq field reads in `cmd_session_switch` with `read_session` + IFS destructuring
- [x] 3.5 Replace individual jq field reads in `cmd_session_ls` with `read_session` + IFS destructuring (per-session loop)
- [x] 3.6 Replace individual jq field reads in `cmd_dashboard` with `read_session` + IFS destructuring (per-session loop)
- [x] 3.7 Replace individual jq field reads in `cmd_hydrate` with `read_session` + IFS destructuring
- [x] 3.8 Replace individual jq field reads in `select_session` with `read_session` + IFS destructuring
- [x] 3.9 Replace individual jq field reads in `resolve_conflict` with `read_session` + IFS destructuring
- [x] 3.10 Replace individual jq field reads in `cmd_space_rm` session loop with `read_session` + IFS destructuring
- [x] 3.11 Replace individual jq field reads in `cmd_session_create` replace path with `read_session` + IFS destructuring
- [x] 3.12 Run tests — all 24 must pass

## 4. Update Consumer Functions — Sleep, Conflicts, Activate

- [x] 4.1 Replace inline kill+dormant logic in `cmd_session_down` with `sleep_session`
- [x] 4.2 Replace inline kill+dormant logic in `resolve_conflict` with `sleep_session`
- [x] 4.3 Replace inline kill+delete logic in `cmd_session_create` replace path with `sleep_session` followed by delete
- [x] 4.4 Replace inline port-conflict check+resolve in `cmd_session_create` with `check_and_resolve_conflicts`
- [x] 4.5 Replace inline port-conflict check+resolve in `cmd_session_up` with `check_and_resolve_conflicts`
- [x] 4.6 Replace inline port-conflict check+resolve in `cmd_session_switch` with `check_and_resolve_conflicts`
- [x] 4.7 Replace inline activate+print in `cmd_session_create` with `activate_and_report`
- [x] 4.8 Replace inline activate+print in `cmd_session_up` with `activate_and_report`
- [x] 4.9 Replace inline activate+print in `cmd_session_switch` with `activate_and_report`
- [x] 4.10 Run tests — all 24 must pass

## 5. Consolidate up/switch and Hydrate

- [x] 5.1 Extract shared body of `cmd_session_up` and `cmd_session_switch` into `cmd_session_activate "$space" "$session" "$success_msg" "$selector_label"`
- [x] 5.2 Make `cmd_session_up` a thin wrapper calling `cmd_session_activate "$space" "$session" "is live" "Activate session"`
- [x] 5.3 Make `cmd_session_switch` a thin wrapper calling `cmd_session_activate "$space" "$session" "Switched to" "Switch session"`
- [x] 5.4 Replace `cmd_hydrate` inline tunnel reconnection with a call to `activate_session`
- [x] 5.5 Standardize cancellation handling: all conflict resolution cancellations use `exit 0`
- [x] 5.6 Run tests — all 24 must pass

## 6. Tests for New Helpers

- [x] 6.1 Test `require_space` returns 0 for existing space and exits 1 for missing space
- [x] 6.2 Test `require_session` returns 0 for existing session and exits 1 for missing session
- [x] 6.3 Test `read_session` returns correct tab-separated fields and handles null pid
- [x] 6.4 Test `sleep_session` kills tunnel and marks state dormant for live session, no-ops for dormant
- [x] 6.5 Test `check_and_resolve_conflicts` returns 0 when no conflict exists
- [x] 6.6 Test no individual session-field jq calls remain outside `read_session` (grep the script)
- [x] 6.7 Run full test suite — all tests (old + new) must pass

## 7. Final Verification

- [x] 7.1 Verify line count reduction (target: ~200+ lines removed from ~1326)
- [x] 7.2 Verify no duplicate "space exists" or "session exists" checks remain outside helpers (grep)
- [x] 7.3 Run full test suite one final time
