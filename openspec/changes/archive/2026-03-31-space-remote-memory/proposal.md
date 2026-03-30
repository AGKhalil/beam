## Why

When creating a new beam session, the user must type the full SSH host every time (e.g. `proteinea-gpu-0`). Spaces tend to be associated with a small set of remotes — the "proteinea" space always connects to proteinea machines. Beam should remember which hosts have been used in a space and offer them as choices, while still allowing new hosts.

## What Changes

- **Store a `hosts` array on each space** in state, tracking SSH hosts that have been used to create sessions in that space
- **Auto-remember new hosts** — when a session is created with a host not yet in the space's list, append it automatically
- **Present known hosts as a selection** during `beam <space> create` — the user picks from previous hosts or enters a new one via an "Enter a new host..." option
- **Remove hosts with the space** — when `beam space rm` deletes a space, its hosts list is deleted with it (it's part of the space object)

## Capabilities

### New Capabilities
- `space-host-memory`: Track and present previously-used SSH hosts per space during session creation

### Modified Capabilities
- `session-lifecycle`: Session creation presents a host selector instead of a raw text prompt when the space has known hosts

## Impact

- **`beam` script**: Changes to `cmd_session_create` (host input step) and `cmd_space_create` (initialize empty hosts array)
- **State file**: Adds `hosts` array to each space object — backward compatible (missing `hosts` treated as empty)
- **Tests**: New tests for host memory, updated session creation tests
- **No breaking changes**: Spaces without `hosts` just show the raw prompt as before
