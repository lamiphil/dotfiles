---
name: log
description: Add a timestamped log entry for recent work to the log target declared in AGENTS.md (a work log in a notes vault, or a project _log.md in a repo). Use when the user invokes /log or wants to log progress, document decisions, or capture what was accomplished.
---

# Log

Write a short, timestamped entry about recent work into each **log target** the work belongs to.
Logs are for the user, not for the repository's users.

## Find the log target

The log target comes only from a **log declaration** in an `AGENTS.md` (or `CLAUDE.md`). Never
guess it from paths, folder names or environment variables.

1. List the folders the work happened in: the session cwd and every repository or folder that
   tools read or changed in this session.
2. For each folder, read the `AGENTS.md` / `CLAUDE.md` files from that folder up to `$HOME`
   (use the copies already in context, including `<repo_instructions>` blocks; read the others).
3. Find each file's `## Log` section. The **nearest** declaration wins, unless an outer one says
   it overrides inner files: then the outer one wins for everything below it.
4. A declaration gives:
   - **target**: a path (relative to the declaring folder) or a rule (for example "the customer's
     `Customers/{CUSTOMER}/_log.md`");
   - **language**;
   - **visibility**: `private` or `public`. When the visibility is missing, treat it as `public`.
5. Group the work by log target. Write **one entry per target**, holding only the work done for
   that target. Never put work from one target into another.
6. When the rule needs a choice (for example which customer), infer it from the session: earlier
   discussion, repository names, project terms. Match names case-insensitively, tolerating spaces,
   hyphens and slug forms. If no unique match exists, ask. Never guess.
7. **No declaration** covers the work: ask the user where to log. If the request says the run is
   unattended, do not ask: write nothing and reply `No log target declared; nothing logged.`
   The same applies when a choice in step 6 is ambiguous in an unattended run.

## Public logs

A public log is readable by anyone. Before writing to a target with visibility `public`, check
the entry and remove:

- names of employers, customers, colleagues or any other person or company tied to them;
- non-public identifiers: IDs, hostnames, IPs, emails, internal URLs, tenant or account
  numbers, and absolute home paths (`/Users/...`, `/home/...`, `~/...` outside the repo);
- secrets, tokens and credentials;
- private life: health, money, feelings, relationships.

Keep only the technical what and why. Refer to things by their role ("the work notes vault",
"a customer repository"). Re-check the final text once more before writing. Private targets
skip this section.

## Entry format

All targets use the same format, written in the target's language.

```markdown
**YYYY-MM-DD | HH:MM**

One-line headline, verb-first, under ~15 words.

- Optional detail
- Optional detail

### <Next step heading>

- Verb-first action, under ~15 words.
```

- Line 1: bold local timestamp. Line 2: blank. Line 3: the headline, with no lead-in.
- Details are optional; put a blank line before any bullet list.
- The next-step block is optional, one or two bullets, directly after the entry's details.
  Heading by language: French `### Prochaine étape`, English `### Next step`.
- Keep tool and technical names as they are (`API`, `Docker`, `TUI`).
- French: Québec French, first person (`J'ai...`), verbs like `Ajouté`, `Corrigé`, `Validé`.
- English: first person, past tense, verbs like `Added`, `Fixed`, `Checked`.

## File structure

Date sections are **newest first**. Each date heading has a short topic:

```markdown
# <Title>

## 2026-08-19 - <Topic>

**2026-08-19 | 14:21**
...

## 2026-08-18 - <Topic>
...
```

Placement:

1. Today's date heading exists: add the entry at the **end** of that date section (before the
   next `## YYYY-MM-DD` heading or the end of the file).
2. No heading for today: add `## YYYY-MM-DD - <Topic>` **above** all date headings, below any
   frontmatter and the `#` title.
3. Never reorder or change existing entries.

Missing file: create it with a `#` title and the first entry. Title: French `# <Name> - Journal de
travail`, English `# <Name> - Log`. Add frontmatter only when the declaration asks for it.

## Process

1. Get the current local timestamp (`date '+%Y-%m-%d | %H:%M'`).
2. Summarize the session's recent work.
3. Find the log targets (see above).
4. For each target: read the file, write the entry with the edit or write tool (so the change is
   tracked), applying the public rules when needed.
5. Never commit. Reply with one line per target: the path and the headline.
