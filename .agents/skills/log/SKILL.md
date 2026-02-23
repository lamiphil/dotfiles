---
name: log
description: Add a timestamped log entry to notes. Summarizes recent work and adds it to either an issue note (if work relates to a specific Linear issue) or the daily journal note. Use when the user invokes /log or wants to log progress, document decisions, or capture what was accomplished.
---

# Log Entry Skill

Add timestamped log entries summarizing recent work to the appropriate note file.

## Timestamp Format

Always start log entries with a bold timestamp:

```
**YYYY-MM-DD | HH:MM**
```

## Note Locations

- **Daily notes:** `notes/Journal/<year>/<MM - Month>/YYYY-MM-DD.md`
  - Example: `notes/Journal/2026/02 - February/2026-02-23.md`
- **Issue notes:** `notes/Issues/<ID> - <Title>.md`
  - Example: `notes/Issues/CR-50 - Clean Grafana alerts.md`

## Decision: Which Note to Use

1. **Issue note** — If the conversation clearly relates to a specific Linear issue (CR-*, etc.)
2. **Daily note** — If work is general (exploration, meetings, setup, cross-cutting tasks)
3. **Ask the user** — If uncertain which note is appropriate

## Log Entry Format

- Start with bold timestamp on its own line
- Add a blank line before any bullet list (required for Markdown rendering)
- Use **bullet points** when listing discrete items accomplished
- Use **paragraphs** when explaining decisions, context, or reasoning
- Combine both styles when appropriate

Example:

```markdown
**2026-02-23 | 14:30**
Restructured the workspace to better organize repos, notes, and issue files.

- Created `repos/`, `notes/`, `issues/` folder structure
- Moved all git repositories into `repos/`
- Moved Obsidian vault into `notes/`
- Updated CLAUDE.md to reflect new structure
```

## Placement

- **Daily notes:** Append under the `## Logs` section
- **Issue notes:** Append at the end of the `# Logs` section

## Creating Missing Files

If today's daily note doesn't exist, create it with this template:

```markdown
---
date: YYYY-MM-DD
tags:
  - journal
---
# YYYY-MM-DD
## Todos

## Logs

### Meetings
\```dataview
LIST
FROM "Meetings"
WHERE date = this.file.day
\```

### Issues
\```dataview
LIST
FROM "Issues"
WHERE file.mday = this.file.day
\```
```

Also create the month folder if it doesn't exist (format: `MM - Month`).

## Process

1. Determine current timestamp
2. Review conversation context to summarize recent work
3. Decide which note to use (issue vs daily)
4. Read the target note file (or create if daily note doesn't exist)
5. Append the log entry with proper formatting
6. Confirm to user what was logged and where
