---
name: linear
description: Interact with Linear issues via the linctl CLI. Use when the user references a Linear issue (e.g. "CR-50"), wants to list/search/create/update issues, manage comments, or check issue status. Covers all linctl capabilities including issue CRUD, comments, assignments, state transitions, and searches.
---

# Linear

Manage Linear issues using the `linctl` CLI. Always pass `-p` (plaintext) for readable output, or `-j` (JSON) when structured data is needed for further processing.

## Common commands

```bash
# Fetch issue details
linctl issue get CR-50 -p

# List my in-progress issues
linctl issue list -a me -s "In Progress" -t CR -p

# Search issues
linctl issue search "query" -t CR -p

# Create issue
linctl issue create --title "Title" -t CR -d "Description" --assign-me

# Update issue state
linctl issue update CR-50 -s "In Progress"

# Update issue fields
linctl issue update CR-50 --title "New title" --priority 2 --labels bug,urgent

# Assign to me
linctl issue assign CR-50

# Add comment
linctl comment create CR-50 --body "Comment text"

# List comments
linctl comment list CR-50 -p
```

## Workflow guidelines

- When the user references an issue ID (e.g. "CR-50", "LIN-123"), fetch it with `linctl issue get` first to load context.
- Use `-p` for human-readable output, `-j` when parsing results programmatically.
- Default team filter: use the team prefix from the issue ID when available (e.g. CR → `-t CR`).
- When creating issues, always include `--title` and `-t` (team). Add `--assign-me` unless told otherwise.
- State names are case-sensitive: `Todo`, `In Progress`, `In Review`, `Done`, `Canceled`.
- Priority values: 0=None, 1=Urgent, 2=High, 3=Normal, 4=Low.
- Use `--cycle current` to filter by the active sprint/cycle.
- For issue notes in the workspace, check `notes/Issues/` for existing context before fetching from Linear.
