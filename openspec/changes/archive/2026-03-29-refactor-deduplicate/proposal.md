## Why

The beam script (1326 lines) has extensive code duplication that has directly caused bugs — the hydrate jq crash existed because `cmd_hydrate()` inlined its own tunnel reconnection instead of calling `activate_session()`, so the fix to `activate_session()` didn't propagate. The same "space exists" check is copy-pasted 8 times, "session exists" 5 times, session field reads use ~60+ individual jq subprocess calls instead of batching, and `cmd_session_up` vs `cmd_session_switch` are ~95% identical (~68 lines each). This duplication makes every bug fix a game of grep-and-hope, and every new feature requires updating the same pattern in 5+ places.

## What Changes

- **Extract shared helpers**: `require_space()`, `require_session()`, `read_session()`, `sleep_session()`, `check_and_resolve_conflicts()`, `activate_and_report()`
- **Batch jq reads**: Replace ~60+ individual `echo "$state" | jq -r "...field"` calls with a single `read_session()` that reads all fields at once via `@tsv`
- **Eliminate `cmd_hydrate` inline reconnection**: Replace with a call to `activate_session()`
- **Merge `cmd_session_up` and `cmd_session_switch`**: They differ only in the success message; consolidate into one function with a parameter
- **Standardize error handling**: Consistent use of `exit 1` vs `return` for the same failure scenarios across all commands
- **Update tests**: Adapt existing bats tests to the refactored helpers and add tests for the new shared functions

## Capabilities

### New Capabilities
- `shared-helpers`: Extraction of duplicated patterns into reusable helper functions (require_space, require_session, read_session, sleep_session, check_and_resolve_conflicts, activate_and_report)
- `batch-jq-reads`: Replace individual jq field reads with batched single-call reads
- `consolidated-commands`: Merge near-identical command functions (up/switch)

### Modified Capabilities

## Impact

- **`beam` script**: Internal refactor only — all existing CLI commands, arguments, output formats, and state file format remain unchanged. No user-facing behavior changes.
- **Tests**: Existing tests in `tests/beam_test.bats` will need updates to account for renamed/extracted helper functions and to add coverage for new helpers.
- **Risk**: Pure refactor with no behavior changes. Tests provide a safety net. If any test breaks, the refactor introduced a regression.
