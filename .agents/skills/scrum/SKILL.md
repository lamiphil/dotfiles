---
name: scrum
description: >-
  Generate the user's daily standup (scrum) message. Reads the previous workday's entries from every `notes/Customers/*/_log.md`, the todo archive and the todo list (`notes/Customers/_archive.md`, `_todo.md`) to produce three sections (Hier, Aujourd'hui, Bloquant), each line formatted as `- <client>: <task> <summary>`. Use when the user invokes /scrum or asks for their scrum / standup / daily text.
---

# Scrum message generator

Produce the user's daily standup, ready to copy. Output ONLY the formatted text
(in one code block), with no preamble or commentary.

## Output format (exact)

```
Hier:

- <client>: <tâche> <résumé condensé>
- <client>: <tâche> <résumé condensé>

Aujourd'hui:

- <client>: <tâche> <résumé condensé>
- <client>: <tâche> <résumé condensé>

Bloquant:

- <blocage, ou "all good">
```

### Line structure

Every bullet follows: `- <client>: <task> <summary>`.

- `<client>` — lowercase project slug from the customer folder name or
  frontmatter (`som`, `maheu-maheu`, `humaco`, …). For training/personal work
  keep the existing tag (`az-104`, `formation`, …).
- `<task>` — a short label (2–4 words) identifying the topic. Prefer the log
  entry's date-heading topic (`## YYYY-MM-DD - Topic`).
- `<summary>` — condense the log entry's own one-line French summary even
  further. Aim for ≤ 10 words. Verb-first, no lead-in, no MR numbers, SHAs,
  IDs, or file paths.

Example:

```
- som: MCP OAuth clarifié le flux LemonLDAP + Entra ID
- az-104: labs terminé les modules réseau
```

## Sources

### Yesterday (`Hier:`)

Read **every** `notes/Customers/*/_log.md` file. For each file:

1. Find entries whose date heading matches the previous workday
   (`## YYYY-MM-DD - ...`). On Monday, the previous workday is Friday.
2. For each timestamped entry under that date, take the **first non-empty
   French line** below the `**YYYY-MM-DD | HH:MM**` timestamp — this is the
   log's own one-line summary and is authoritative.
3. Extract the customer slug from the folder name (case-insensitively; keep
   `som`, `humaco`, `maheu-maheu`, etc.).
4. Compose the bullet: `- <slug>: <topic-condensed> <summary-condensed>`.

If several entries share the same date + client + task, merge them into one
bullet.

Also read `notes/Customers/_archive.md` (format owned by the `todo` skill):
every `- [x] <text> (YYYY-MM-DD - HH:MM)` stamped on the previous workday is
work done. Add it under its section's slug unless a log bullet already covers
it (logs win on wording). `## Personal` items count only if professional
(see Scope).

### Today (`Aujourd'hui:`)

Read `notes/Customers/_todo.md` (newest first in each `## <Section>`).

- For each customer that has a log entry on the previous workday, take its
  newest 1–2 open items as today's plan: `- <slug>: <task> <summary>`, in French.
  The user edits the list before sending, so stay short rather than exhaustive.
- **`### Prochaine étape` blocks** in the previous workday's log entries are
  also `Aujourd'hui:` candidates: one bullet per next-step line,
  `- <client>: <task> <next-step>`. Deduplicate against the todo items (todos win on wording).
- Do not read daily journal notes.

### Blocking (`Bloquant:`)

- Anything flagged as blocking (`⛔`, `bloqué`, `blocker`, `blocking`,
  `blocked`) in yesterday's logs or in open items of `_todo.md`.
- Otherwise print `all good`.

## Date logic

Compute the previous workday from today, skipping weekends. If unsure of
today's date, run `date +%F`.

## Scope

- Include **professional / project** items only.
- **Exclude** purely personal errands (`perso:`, `beneva:`, …) and timesheet
  admin (`harvest:`) unless the user asks otherwise.

## Rules

- Output the message and nothing else — a single fenced code block.
- Always print the three headers; use `all good` for an empty Bloquant.
- Never invent work. If yesterday's logs are empty, say so briefly inside
  the message rather than fabricating.
- If the user passes arguments (a different date, extra items to add, or
  `no som`), honor them.
- Keep the entire message short enough to fit in a standup slack message.
