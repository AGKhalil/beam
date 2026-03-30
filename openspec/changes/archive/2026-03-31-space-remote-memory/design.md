## Context

Session creation currently has a raw text prompt: `SSH host (e.g. ag@hetzner1):`. Users retype the same hosts repeatedly. The state file already stores the host per session, but there's no aggregated list at the space level.

## Goals / Non-Goals

**Goals:**
- Remember SSH hosts per space automatically
- Present previously-used hosts as selectable options during session creation
- Allow entering new hosts alongside the selection
- Clean up hosts when a space is removed

**Non-Goals:**
- Host validation or connectivity checking at storage time
- Sharing hosts across spaces
- Editing or manually managing the hosts list (it's automatic)

## Decisions

### 1. Store hosts as an array on the space object

**Decision**: Add a `hosts` array to the space object in state:
```json
{
  "spaces": {
    "proteinea": {
      "hosts": ["proteinea-gpu-0", "proteinea-gpu-1"],
      "sessions": { ... }
    }
  }
}
```

**Rationale**: Hosts naturally belong to spaces. When a space is deleted (`jq "del(.spaces[name])"`), its hosts disappear automatically — no extra cleanup. Backward compatible: missing `hosts` key is treated as `[]`.

**Alternatives considered**:
- Derive from sessions on the fly — loses hosts when all sessions for that host are removed
- Top-level `hosts` object — survives space deletion (undesirable per requirements)

### 2. Auto-append on first use, no duplicates

**Decision**: When a session is created with a host not in the space's `hosts` array, append it. Use `jq` with `unique` to prevent duplicates.

**Rationale**: Zero-friction. User never has to manage the list. Hosts accumulate naturally through usage.

### 3. Selection UX: arrow_select with "new host" option

**Decision**: When the space has known hosts, present them using the existing `arrow_select` component with an additional "+ Enter a new host..." option at the end. Selecting it falls through to the raw text prompt. If the space has no known hosts, show the raw prompt directly (same as current behavior).

**Rationale**: Reuses existing UI component. The "new host" option keeps the escape hatch visible. Single-host spaces auto-select (consistent with project/worktree auto-selection pattern).

## Risks / Trade-offs

- **[Stale hosts]** → A host that's no longer reachable stays in the list forever. Acceptable — user just picks a different one. Could add pruning later if needed.
- **[Backward compatibility]** → Old state files won't have `hosts`. Handled by defaulting to `[]` — first session creation populates it.
