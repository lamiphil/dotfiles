---
name: log
description: Add a timestamped log entry to the current customer's _log.md work journal. Summarizes recent work and appends it under the correct date heading. Use when the user invokes /log or wants to log progress, document decisions, or capture what was accomplished.
---

# Log Entry Skill

Add timestamped log entries summarizing recent work to the current customer's `_log.md`.

## Language and Style

- Write in **French** (Québec), concise, first person (`Je...`, `J'ai...`, `Je vais...`).
- Keep technical terms in English when they are tool names or clearer as-is (`API`, `Docker`, `TUI`, etc.).
- Avoid overly formal or generic summaries.

## Timestamp Format

Always start log entries with a bold timestamp:

```
**YYYY-MM-DD | HH:MM**
```

## Resolve the Customer

1. Look for `notes/Customers/` in the current workspace and its ancestors.
   Otherwise try `$HOME/workspaces/vooban/notes/Customers/`.
2. Infer the customer from the current session context: prior discussion, repository names,
   project terminology, or cwd path.
3. Match customer names case-insensitively, tolerating spaces, hyphens, and slug forms.
4. If no unique match exists, **ask the user** to select or name the customer. Never guess.
5. Target file: `Customers/{CUSTOMER}/_log.md`.

## Log File Structure

The `_log.md` file uses **date headings newest-first**, with timestamped entries beneath each
date. A short topic summary follows each date heading.

Example structure:

```markdown
---
customer: som
type: log
tags: [som, log, infra]
---
# SOM - Journal de travail

## 2026-08-19 - Code dbt non versionne

**2026-08-19 | 14:21**
Description of work done...

- Bullet point details
- More details

## 2026-08-18 - Integration MCP

**2026-08-18 | 08:37**
Earlier entry...
```

## Log Entry Format

1. **Line 1:** bold timestamp `**YYYY-MM-DD | HH:MM**`.
2. **Line 2:** blank.
3. **Line 3 (required):** a **very concise one-line French summary** of what was
   done in this log instance. Under ~15 words. No lead-in. Verb-first phrasing
   (`Ajouté...`, `Corrigé...`, `Validé...`, `Investigué...`, `Écrit...`).
   This line is the source of truth used by `/scrum`; treat it as a headline.
4. **Optional details** below: paragraphs and/or bullet points expanding the
   summary. Add a blank line before any bullet list (Markdown rendering).
5. **Optional `## Prochaine étape` sub-section** (recommended when relevant): a
   short next-step block placed **immediately after the entry's details**. It is
   harvested by `/scrum` as a candidate line for `Aujourd'hui:`. Use a level-3
   heading so it stays scoped to the entry:

   ```markdown
   ### Prochaine étape

   - <verb-first action, ≤ 15 words>
   ```

   One or two bullets max. Same French, verb-first, condensed style as the
   headline.
6. **Date heading topic:** include a short topic in `## YYYY-MM-DD - Topic`.

Example:

```markdown
**2026-08-19 | 14:21**

Investigué le code dbt manquant du sandbox SOM.

- Le repo `som-data` ne contient aucun `dbt_project.yml`.
- Message envoyé au collègue pour clarifier où se trouve le code.

### Prochaine étape

- Reconstruire le projet dbt à partir des colonnes de `exp_projets`.
```

## Placement Rules

1. **Same date exists:** Insert the new entry at the **end** of the existing date section
   (before the next `## YYYY-MM-DD` heading or end of file).
2. **New date (today):** Create a new `## YYYY-MM-DD - Topic` heading and insert it
   **above** all existing date headings (newest-first order), but below the frontmatter
   and top-level `#` title.
3. Never reorder or modify existing entries.

## Creating a Missing `_log.md`

If `_log.md` does not exist for the resolved customer, create it with:

```markdown
---
customer: <slug>
type: log
tags: [<slug>, log]
---
# <Customer Name> - Journal de travail

## YYYY-MM-DD - Topic

**YYYY-MM-DD | HH:MM**
<entry content>
```

The `<slug>` is the lowercased, hyphenated customer name.

## Process

1. Determine current timestamp
2. Review conversation context to summarize recent work
3. Resolve the customer (see above)
4. Read `Customers/{CUSTOMER}/_log.md` (or create if missing)
5. Append the log entry under the correct date heading
6. Confirm to user what was logged and where
