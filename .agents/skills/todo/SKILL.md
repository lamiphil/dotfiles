---
name: todo
description: Manage Philippe's todos in the single work todo list (Customers/_todo.md) and its archive (Customers/_archive.md). Use whenever he asks to add, note, remember, track or save a todo/task/action item, marks one done/completed, asks to archive or clean up todos, or invokes /todo.
---

# Todo

One list for everything, one archive. Never write todos anywhere else
(not the daily note, not per-customer files).

- List: `$NOTES_ROOT/Customers/_todo.md` (fallback: `$HOME/notes/Customers/_todo.md`)
- Archive: `$NOTES_ROOT/Customers/_archive.md`

## File format

Both files share the same sections: one `## <Section>` per customer, then `## Personal`.

`_todo.md` lines are `<status> <number>: <text>`, no `- [ ]`:

```markdown
## Client A
!!  1: ACME-298: Destroy the old hub from the pre-csp tag
 !  2: Test S2S from a workstation (TCP 443 to 10.0.0.4)
    3: Check the Spot quota request (12 vCPU)
 X  4: Rotate the VPN PSK (waiting on: client network team)

## Personal
    5: Renew passport
```

- **Status** (one per item): `!!` top priority, `!` priority, blank = normal,
  `X` blocked. A blocked item ends with `(waiting on: <short reason>)`; blocking
  a priority item drops its priority, unblocking makes it normal.
- **Order inside a section**: `!!`, `!`, normal, `X`. The formatter sorts this (stable).
- **Numbers are global**, 1..N top to bottom across all sections (so « tick 3 » is never ambiguous).
  They are positional, not IDs.
- **Alignment** (status padded to 2 chars, numbers right-aligned) and numbering are done
  only by the formatter script. Never align or renumber by hand.

- Customer sections are alphabetical; `## Personal` is always last.
- A customer section exists only if `Customers/<Name>/` exists; use the folder name verbatim.
  Create the section lazily (first todo for that customer). Never create customer folders.
- `## Personal` holds everything that is not a customer: internal work
  (shared tooling), the personal workspace, life admin.
- **Newest first**: any line you add *or change the status of* goes directly under its
  section heading; the stable sort then puts it first in its status group (so a newly
  prioritised item lands at the top of the section's priorities).
- Archive lines keep the old shape: `- [x] <text> (YYYY-MM-DD - HH:MM)`, local time of the move,
  newest first. No status, no number, no `(waiting on: …)` suffix.
- Nothing else in the files: no frontmatter, no prose, no sub-headings, no nesting.
  If a file is missing, create it with just the sections you need.

## Choosing the section

1. Named by Philippe ("for Client A", "personal") → that section.
2. Otherwise infer, in order:
   - what the session is about (customer repo, ticket prefix, customer named in recent messages);
   - the cwd: a `customers/<slug>/…` path → the `Customers/` folder whose name matches
     the slug case- and space-insensitively, or by prefix;
   - a personal workspace path, or a shared/internal tooling path → `Personal`.
3. Still unclear, or the slug matches no folder → ask with `ask_user_question`,
   options = existing sections + Personal. Never guess silently.

## Writing the todo

- English, one line, imperative verb first, as short as it can be while still actionable cold.
- Prefix the ticket ID when known: `ACME-298: …`, `CORP-129: …`.
- When Philippe writes little, add only the missing *what/where* from the session
  (resource name, repo, MR number, person). No explanations, no "because", no trailing period.
- Keep technical names, commands and IDs exactly; wrap them in backticks.
- Several todos in one message → one line each.
- Skip exact or near duplicates of an open item in the same section; say so.

Examples:

| Philippe says | Line |
|---|---|
| « todo check the spot quota » (in a Client A session on ACME-298) | `0: ACME-298: Check the Spot quota request (12 vCPU)` |
| « urgent: ping Alex about the RUNNER_TAG » (Client B cwd) | `! 0: Tell Alex to use RUNNER_TAG=clientb-dev` |
| « todo passport » | `0: Renew passport` (Personal) |

Write new lines with any number (`0:` is fine); the formatter fixes it.

## Changing a status

Philippe asks in plain language: « 3 is urgent », « make 5 top priority »,
« 7 is blocked until the client sends the IDs », « 7 is unblocked », « 3 is no longer urgent ».
Map urgent/important/priority → `!`, top/most urgent/critical → `!!`. If unsure between
`!` and `!!`, ask. Blocking without a reason → ask for it. Change the status, move the
line directly under its heading, and keep its text otherwise unchanged.

## Completing and archiving

Items are done only when Philippe says so (there is no checkbox to tick in Obsidian,
and no sweep). A line he deletes by hand is just gone.

When Philippe says an item is done ("tick 3", "tick 1, 4", "done: Meraki"):

1. Numbers refer to the file **as it is before this run** (before any add or re-sort):
   resolve them to lines first. Text references: match against open items
   (the inferred section helps disambiguate).
2. One clear match → move it to the archive (stamped, without status, number or
   waiting-on suffix). Several, none, or a number out of range → ask.
3. Never archive anything he did not say is done.

## Procedure

1. Read both files (they may not exist yet). Resolve any numbers in the request to lines now.
2. Apply the add / status / complete request.
3. Write both files, preserving every other line's text exactly.
4. **Always** run `python3 ~/.agents/skills/todo/scripts/renumber.py` last. It sorts each
   section by status, renumbers `_todo.md` 1..N, aligns it, and strips numbers from
   `_archive.md`. It also converts old `- [ ] N - text` lines.
5. Reply in one line per change: section and text, e.g. `+ Client A: ACME-298: Check the Spot quota request (12 vCPU)`,
   `! Client B: Tighten GitLab rules`, `X Client C: Rotate the PSK (waiting on: Client C IT)`
   or `✓ archived Client C: Add a cert-expiry alert …`.
6. If the request ends with `[via /todo: show the file]`, finish with the whole `_todo.md`
   as it is now, verbatim, in one ```markdown block (re-read it after writing).

Do not add a log entry, touch daily notes, or edit per-customer files unless asked.
