## Context

The beam CLI is a 1326-line Bash script with no shared helpers beyond tunnel primitives (`start_tunnel`, `kill_tunnel`, `check_health`, `activate_session`). Each command function (`cmd_session_up`, `cmd_session_down`, `cmd_session_rm`, etc.) is self-contained — it reads state, validates existence, reads session fields one at a time via individual jq subprocess calls, performs its operation, and writes state. This has led to:

- ~60+ redundant jq subprocess invocations per run
- 8 copies of the "space exists" check
- 5 copies of the "session exists" check
- `cmd_hydrate` inlining tunnel reconnection instead of using `activate_session()` (caused a production bug)
- `cmd_session_up` and `cmd_session_switch` being ~95% identical (~68 lines each)

The existing 24 bats tests provide a safety net for refactoring.

## Goals / Non-Goals

**Goals:**
- Extract duplicated patterns into shared helpers
- Batch jq reads to eliminate subprocess overhead
- Make `cmd_hydrate` use `activate_session()` so fixes propagate
- Merge `cmd_session_up` and `cmd_session_switch`
- Standardize error handling across commands
- Maintain all existing CLI behavior (commands, arguments, output, state format)
- Keep all 24 existing tests passing, add tests for new helpers

**Non-Goals:**
- Changing any user-facing behavior, output formatting, or CLI interface
- Restructuring the state file format
- Splitting the script into multiple files
- Adding new features or commands
- Changing the SSH tunnel approach

## Decisions

### 1. Helper function signatures use positional args (over associative arrays or globals)

**Decision**: All helpers take explicit positional arguments: `require_space "$state" "$space"`, `read_session "$state" "$space" "$session"`.

**Alternatives considered**:
- *Globals*: Fragile, hard to test, hidden coupling between functions.
- *Associative arrays*: Bash 4+ only; macOS ships Bash 3. While zsh is default on modern macOS, the script uses `#!/bin/bash` and must work with Bash 3.

**Rationale**: Positional args match the existing style, work on all Bash versions, and are explicit about data flow.

### 2. `read_session` returns tab-separated fields via `@tsv` (over JSON output or nameref)

**Decision**: `read_session` runs one jq call with `@tsv` output and the caller destructures via `IFS=$'\t' read -r`:

```bash
read_session() {
    local state="$1" space="$2" session="$3"
    echo "$state" | jq -r ".spaces[\"$space\"].sessions[\"$session\"] |
        [.host, .status, (.pid // \"null\" | tostring), (.local_client_port|tostring), (.remote_client_port|tostring), (.local_server_port|tostring), (.remote_server_port|tostring), .project, .worktree] | @tsv"
}
```

**Alternatives considered**:
- *Return JSON, parse in caller*: Still requires multiple jq calls or complex parsing.
- *Bash nameref (declare -n)*: Bash 4.3+ only.
- *eval-based*: Security risk, fragile quoting.

**Rationale**: TSV is simple, single-subprocess, and the `IFS read` pattern is idiomatic Bash.

### 3. Merge `up` and `switch` into one function with a label parameter (over keeping separate)

**Decision**: Create `cmd_session_activate "$space" "$session" "$label"` where label is "live" or "Switched to". Both `up` and `switch` become thin wrappers that call it.

**Alternatives considered**:
- *Delete `switch` entirely*: Breaking change — users may have muscle memory or scripts using `beam <space> switch`.
- *Have `switch` call `up` directly*: Works but `up` would need to know about "switch" semantics for the message.

**Rationale**: Thin wrappers preserve the CLI interface while eliminating ~60 lines of duplication. The routing at the bottom of the script still maps `switch` and `up` to their respective wrappers.

### 4. Refactor order: helpers first, then consumers, then tests (over incremental per-function)

**Decision**: Add all new helpers in one block after the existing tunnel core section. Then update consumer functions one at a time, running tests after each. Finally add new helper tests.

**Rationale**: Adding all helpers upfront avoids forward-reference issues in Bash (functions must be defined before they're called). Updating consumers one at a time with test runs after each ensures regressions are caught immediately.

## Risks / Trade-offs

- **[Risk] Refactoring introduces subtle behavior differences** → Mitigation: All 24 existing tests must pass after each consumer function is updated. Tests cover state management, session lifecycle, port conflicts, and PID sanitization.
- **[Risk] TSV parsing breaks on field values containing tabs** → Mitigation: None of the session fields (host, ports, status, project, worktree) can contain tabs. Port values are numeric, host/project/worktree are filesystem-safe strings.
- **[Risk] Helper extraction changes function call depth, affecting `set -e` behavior** → Mitigation: Helpers that check existence call `exit 1` directly (same as current inline behavior). `set -e` is already active and all current functions are tested under it.
- **[Trade-off] Slightly less readable for someone unfamiliar with the helper contracts** → Accepted: The helpers are well-named (`require_space`, `read_session`) and the duplication reduction far outweighs the indirection cost.
