## Why

When running `beam <space> create`, users hit a hard error — `Session '<name>' already exists in space '<space>'` — even when the intent is to reconnect to the same host/worktree combination. The current behavior offers no recovery path: the user must manually `beam <space> rm <session>` and re-create from scratch, losing any saved port configuration. Additionally, the SSH scanning steps during `beam <space> create` reuse an existing SSH `ControlMaster` connection that has stale port-forwarding configuration, causing `bind: Address already in use` errors to pollute the interactive TUI. There are also zero automated tests in the codebase, making regressions undetectable.

## What Changes

- **Detect and offer to replace existing sessions**: When `cmd_session_create()` finds a session with the same name already exists, instead of hard-failing, prompt the user: "Session already exists. Replace it? (y/n)". If yes, tear down the old tunnel and overwrite the session state.
- **Suppress SSH port-forwarding noise during scans**: The `ssh` commands used for scanning (`ls`, `cat .env`, `grep`) inherit port-forwarding options from `~/.ssh/config` (e.g., `ControlMaster`, `RemoteForward`). Add `-o ClearAllForwardings=yes` to scan-only SSH calls to prevent `bind: Address already in use` warnings from leaking into the TUI.
- **Add a test harness with automated tests**: Introduce a `bats` (Bash Automated Testing System) test suite covering session lifecycle, existence checks, port conflict detection, and state management to prevent regressions.

## Capabilities

### New Capabilities
- `session-replace`: Handle the case where a session already exists during create — offer to replace instead of hard-failing
- `clean-ssh-scans`: Suppress port-forwarding noise from SSH commands used for remote scanning
- `test-harness`: Automated test suite for beam CLI using bats

### Modified Capabilities

## Impact

- **`beam` script**: Changes to `cmd_session_create()` (existence check logic), and all scan-phase `ssh` invocations (lines 574, 643, 677)
- **New files**: `tests/` directory with bats test files and helpers
- **Dependencies**: `bats` test framework (dev-only, not required for runtime)
- **User-facing**: Smoother create flow (no more hard-fail on existing sessions), cleaner TUI (no SSH forwarding warnings during scans)
