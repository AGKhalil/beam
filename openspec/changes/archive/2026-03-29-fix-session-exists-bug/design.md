## Context

`beam` is a single-file Bash CLI (~1281 lines) that manages persistent SSH tunnels for remote Wasp development projects. State is stored in `~/.local/state/beam/state.json`. The tool has no automated tests.

Two bugs surface during `beam <space> create`:

1. **Session exists hard-fail**: `cmd_session_create()` reads state at line 552, walks the user through an interactive multi-step flow (SSH host, project selection, worktree selection, port prompts — each involving SSH calls), then at line 705 checks if the session already exists. If it does, it `exit 1`s with no recovery. The user must `beam <space> rm <session>` and redo the entire flow.

2. **SSH scan noise**: The three SSH calls at lines 574, 643, and 677 (used to scan projects, read ports, read `.env`) do not suppress port-forwarding. If the user's `~/.ssh/config` includes `RemoteForward` or `LocalForward` directives for the target host, those forwarding rules execute on every SSH connection — producing `bind: Address already in use` / `cannot listen to port` warnings that pollute the TUI.

## Goals / Non-Goals

**Goals:**
- When a session already exists, offer the user a replace option instead of hard-failing
- Eliminate SSH port-forwarding noise from scan-only SSH commands
- Add a bats test suite covering session lifecycle, existence checks, and state management
- Keep changes minimal and surgical — this is a bugfix, not a rewrite

**Non-Goals:**
- Rewriting the SSH tunneling approach (e.g., switching to `autossh` or `mosh`)
- Adding a configuration file system
- Changing the state file format
- Supporting concurrent beam processes (file locking)

## Decisions

### 1. Replace-prompt on session exists (over silent overwrite or force flag)

**Decision**: When the session already exists, prompt `"Session already exists. Replace it? (y/n)"`. On yes, tear down the old tunnel (if live) and delete the old session state before creating the new one.

**Alternatives considered**:
- *Silent overwrite*: Dangerous — could kill an active tunnel the user didn't realize was there.
- *`--force` flag*: Adds CLI complexity, doesn't help the interactive flow where users aren't passing flags.
- *Error + helpful message*: Still requires the user to abort and run a separate command.

**Rationale**: The interactive prompt matches the existing UX pattern (see `resolve_conflict()` at line 395 which already uses a y/n prompt). It gives the user explicit control without requiring them to restart the flow.

### 2. `-o ClearAllForwardings=yes` for scan SSH calls

**Decision**: Add `-o ClearAllForwardings=yes` to the three SSH calls that are scan-only (lines 574, 643, 677). This SSH option disables all `LocalForward`, `RemoteForward`, and `DynamicForward` directives from config for that connection.

**Alternatives considered**:
- *`-F /dev/null`*: Ignores the entire SSH config, which would break things like `Host` aliases, identity files, proxy jumps.
- *Redirecting stderr*: Hides the warnings but also hides legitimate errors (auth failures, timeout).
- *`-o LogLevel=ERROR`*: Would suppress warnings but also suppress useful debug output.

**Rationale**: `ClearAllForwardings=yes` is surgical — it only disables forwarding directives while preserving all other SSH config (host aliases, identity files, proxy settings).

### 3. Bats test framework (over shunit2, shellspec)

**Decision**: Use `bats-core` with `bats-support` and `bats-assert` helper libraries.

**Alternatives considered**:
- *shunit2*: Less expressive syntax, smaller community.
- *shellspec*: BDD-style, heavier, less widespread.
- *Plain bash test scripts*: No structure, no assertions, hard to maintain.

**Rationale**: Bats is the de facto standard for Bash testing, has excellent assertion libraries, and integrates naturally with CI. Tests mock the state file and SSH commands to run without real SSH connections.

### 4. Test architecture: mock SSH and state file

**Decision**: Tests will use a temporary `STATE_DIR`/`STATE_FILE` (overriding the variables) and stub `ssh` with a bash function that returns canned responses. This allows testing all logic without network access.

**Rationale**: The beam script already reads `STATE_DIR` and `STATE_FILE` as variables set at the top of the file — these can be overridden. SSH can be stubbed by prepending a mock directory to `PATH`.

## Risks / Trade-offs

- **[Risk] Replace prompt changes existing behavior** → Mitigation: Only triggered when session already exists (currently a hard error), so no existing successful flow is affected.
- **[Risk] `ClearAllForwardings=yes` may not be supported on very old SSH clients** → Mitigation: This option has been available since OpenSSH 3.1 (2002). Practically universal.
- **[Risk] Bats tests may become stale if beam script changes significantly** → Mitigation: Tests focus on observable behavior (state file contents, exit codes, output) rather than internal implementation.
- **[Trade-off] Mocking SSH in tests means we don't test actual tunnel creation** → Accepted: real SSH testing requires infrastructure. The mock approach covers all logic paths.
