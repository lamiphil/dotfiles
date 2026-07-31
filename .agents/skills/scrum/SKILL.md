---
name: scrum
description: Generate Philippe's daily standup (scrum) message in his exact format. Use when the user invokes /scrum or asks for their scrum / standup / daily text. Reads the Obsidian daily journal notes (previous workday + today) and the SOM work log to produce three sections — "Hier:" (yesterday's accomplishments), "Aujourd'hui:" (today's plan), "Bloquant:" — each line tagged by project (e.g. "som:", "az-104:").
---

# Scrum message generator

Produce Philippe's daily standup message, ready to copy. Output ONLY the formatted text (in one code block), with no preamble or commentary.

## Output format (exact)

```
Hier:

<tag>: <ce qui a été accompli>
<tag>: <...>

Aujourd'hui:

<tag>: <ce qui est prévu>
<tag>: <...>

Bloquant:

<blocage, ou "all good">
```

- One line per item, prefixed by a project tag then `: ` (e.g. `som:`, `az-104:`).
- Concise, factual, French. No bullets or dashes — just `tag: text` lines.
- Short: the whole message fits in a standup.

## Where to read

The Obsidian vault lives under the vooban workspace at `notes/`. Use the Read tool on:

1. **Daily notes** — `notes/Journal/<YYYY>/<MM> - <Month>/<YYYY-MM-DD>.md` (e.g. `notes/Journal/2026/07 - July/2026-07-31.md`), where `<Month>` is the English month name.
   - **today's** note → unchecked `## Todos` = today's plan; `## Logs` = context.
   - the **previous workday's** note → checked (`- [x]`) todos and `## Logs` = what was done.
2. **SOM work log** — `notes/Customers/SOM/_log.md`. Reverse-chronological (newest first), entries dated `## YYYY-MM-DD`. The entry(ies) dated the previous workday = SOM accomplishments; the newest entry's "Prochaine couche / étape" line = a candidate for today.

Compute the "previous workday" from today's date, skipping weekends (on Monday, yesterday = Friday). If unsure of today's date, run `date +%F`.

## Building each section

- **Hier:** merge the previous workday's completed todos + `## Logs` + the SOM `_log.md` entry(ies) for that date. Summarize into `tag: ...` lines. Infer the tag from the todo prefix or the topic (SOM work → `som:`, training → `az-104:`).
- **Aujourd'hui:** take today's note's **unchecked** todos (they already carry `tag:` prefixes) + the "prochaine étape / couche" from the SOM log. Keep the same tags.
- **Bloquant:** anything flagged as blocking in the notes; otherwise `all good`.

## Scope

- Include **professional / project** items only: `som:`, `az-104:` (formation), other client/work tags.
- **Exclude** purely personal errands (`perso:`, `beneva:`, …) and timesheet admin (`harvest:`) unless the user asks otherwise.

## Rules

- Output the message and nothing else (a single code block).
- Always print the three headers; use `all good` for an empty Bloquant.
- Do not invent work — only summarize what the notes actually contain. If the previous workday's notes are empty, say so briefly inside the message rather than fabricating.
- If the user passes arguments (a different date, extra items to add, or "no som"), honor them.
