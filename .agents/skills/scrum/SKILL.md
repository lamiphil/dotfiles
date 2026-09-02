---
name: scrum
description: Generate Philippe's daily standup (scrum) message. Reads the previous workday's entries from every `notes/Customers/*/_log.md` and today's daily journal note to produce three sections — "Hier:", "Aujourd'hui:", "Bloquant:" — each line formatted as `- <client>: <task> <summary>`. Use when the user invokes /scrum or asks for their scrum / standup / daily text.
---

# Scrum message generator

Produce Philippe's daily standup, ready to copy. Output ONLY the formatted text
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

Also include non-customer work: training, personal projects, etc., pulled
from the previous workday's daily journal note only if no customer log
covers it (see below).

### Today (`Aujourd'hui:`)

Read today's daily journal note:
`notes/Journal/<YYYY>/<MM> - <Month>/<YYYY-MM-DD>.md`.

- The `## Todos` section's **unchecked** items are today's plan. They already
  carry a `tag:` prefix — rewrite each as `- <tag>: <task> <summary>`.
- **`### Prochaine étape` blocks** in the previous workday's log entries are
  harvested as `Aujourd'hui:` candidates. For each such block, emit one bullet
  per next-step line, formatted as `- <client>: <task> <next-step>`. Deduplicate
  against unchecked todos from the daily journal note (todos win on wording).

### Blocking (`Bloquant:`)

- Anything flagged as blocking (`⛔`, `bloqué`, `blocker`, `blocking`,
  `blocked`) in yesterday's logs or today's todos.
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
