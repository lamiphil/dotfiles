---
name: todo
description: Add user todos to Philippe's current Obsidian daily note. Use whenever he explicitly asks to create, add, note, remember, track, or save a todo/task/action item, including phrasing that clearly implies a new todo.
---

# Todo

Add the requested task to the current daily note unless Philippe explicitly names another destination.

## Location

Use:

`/Users/philippe.lamy/workspaces/vooban/notes/Journal/<year>/<MM - Month>/<YYYY-MM-DD>.md`

If today’s note does not exist, create it using the journal template from the `log` skill. Preserve existing content.

## Procedure

1. Determine today’s date and locate the daily note.
2. Read the note before editing it.
3. Add a checkbox under `## Todos`, preserving existing todos:
   `- [ ] <concise task>`
4. Keep the task in the user’s language; retain technical names and commands exactly.
5. If the user explicitly requests another note or project log, follow that destination instead of the daily note.
6. Confirm the path and the todo text briefly.

Do not add a log entry unless the user also asks to log the work. Do not mark a todo completed unless explicitly instructed.
