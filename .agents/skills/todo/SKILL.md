---
name: todo
description: Manage Philippe's todos in the todo list declared for the current workspace (a `## Todo` section in its AGENTS.md) and its archive. Use whenever he asks to add, note, remember, track or save a todo/task/action item, marks one done/completed, asks to archive or clean up todos, or invokes /todo.
---

# Todo

Each workspace has one todo list and one archive, declared in its `AGENTS.md`. Never write
todos anywhere else (not the daily note, not per-customer files).

## Find the list

Run `python3 ~/.agents/skills/todo/scripts/resolve.py` from the session cwd. It prints JSON
with `list`, `archive`, `sync`, `sections` and `declared_in` (the nearest `## Todo`
declaration wins). Use only these paths.

- Exit 1 (no declaration): reply with its one line (`No todo list declared for <dir>`) and
  stop. Never guess a list.
- Lists never mix. The cwd's list is the only one you touch. If an item clearly belongs to
  another workspace (for example a customer item in a personal session), still write it here
  only if Philippe insists; otherwise say in one line that it looks like another workspace's
  todo and that he should add it from a session there.
- `sync` is `git`: before reading, run `git pull --ff-only` in the list's folder; if it fails,
  stop and report the error. After the formatter (last procedure step), commit **only** the
  list and the archive (`git commit -m "todo: <first reply line>" -- <list> <archive>`, after
  `git add` of both), then `git push`. Never stage or commit any other file. Report a failed
  push in one line.

## File format

Both files share the same `## <Section>` headings. The declaration's `sections` text says
which sections exist (see Choosing the section).

List lines are `<status> <number>: <text>`, no `- [ ]`:

```markdown
## Client A
!!  1: ACME-298: Destroy the old hub from the pre-csp tag
 !  2: Test S2S from a workstation (TCP 443 to 10.0.0.4)
    3: Check the Spot quota request (12 vCPU)
 X  4: Rotate the VPN PSK (waiting on: client network team)

### ACME-301: Prod hub
 !  5: Create the prod tfvars
    6: Plan the prod network

## Internal
    7: Update the shared CI runner image
```

- **Status** (one per item): `!!` top priority, `!` priority, blank = normal,
  `X` blocked. A blocked item ends with `(waiting on: <short reason>)`; blocking
  a priority item drops its priority, unblocking makes it normal.
- **Main tasks** group related items: a `### <title>` heading inside a section
  (ticket ID first when known, e.g. `### PROJ-129: Prod environment`). The heading has no
  number and no status; its items are its subtasks. A section is: standalone items first,
  then its main tasks, newest first.
- **Order inside each block** (standalone items, or one main task): `!!`, `!`, normal, `X`.
  The formatter sorts this (stable) and never reorders main tasks.
- **Numbers are global**, 1..N top to bottom across all sections (so « tick 3 » is never ambiguous).
  They are positional, not IDs.
- **Alignment** (status padded to 2 chars, numbers right-aligned) and numbering are done
  only by the formatter script. Never align or renumber by hand.

- Sections are alphabetical, except a section the declaration puts last (for example
  `## Internal`). Create a section lazily (first todo for it), following the declaration.
- **Newest first**: any line you add *or change the status of* goes directly under its
  heading (`##` for standalone, `###` for a subtask); the stable sort then puts it first in
  its status group (so a newly prioritised item lands at the top of its block's priorities).
  A new main task goes right after the section's standalone items (before older main tasks).
- Archive lines keep the old shape: `- [x] <text> (YYYY-MM-DD - HH:MM)`, local time of the move,
  newest first. No status, no number, no `(waiting on: …)` suffix. A subtask is archived as
  `- [x] <main task title> › <subtask text> (stamp)`. The archive has no `###` headings.
- Nothing else in the files: no frontmatter, no prose, no nesting beyond `###` main tasks.
  If a file is missing, create it with just the sections you need.

## Choosing the section

The declaration's `sections` text is the rule (for example "one per `notes/Customers/`
folder, then `## Internal`", or "only sections Philippe names").

1. Named by Philippe ("for Client A", "internal") → that section, if the rule allows it.
2. Otherwise infer from what the session is about (repo, ticket prefix, customer or project
   named in recent messages) and the cwd, matching existing section names case- and
   space-insensitively. A rule based on folders allows only existing folder names, verbatim.
3. Still unclear, or no allowed section matches → ask with `ask_user_question`,
   options = the allowed or existing sections. When the rule says sections are created only
   on request, never invent one: ask, and let Philippe type a new name. Never guess silently.

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
| « todo passport » (personal workspace) | `0: Renew passport` |

Write new lines with any number (`0:` is fine); the formatter fixes it.

## Main tasks

Plain language: « new main task CORP-129 prod environment », « add X and Y under prod env »,
« move 4 under CORP-129 », « make 6 standalone », « rename prod env to … ».

- Title: short noun phrase, ticket ID first when known. Subtasks follow the normal todo
  rules but drop the ticket prefix already in the heading.
- An item goes into a main task when Philippe names it (by ticket, title or a clear
  paraphrase). If he does not, but the new item's ticket ID matches exactly one main task
  in that section, put it there and show it in the reply. Otherwise it stays standalone.
- Referring to a main task that does not exist → offer to create it (`ask_user_question`).
- A new main task can start empty; an empty heading is kept until it is closed.
- Closing: when its **last subtask** is archived, remove the heading and add
  `- [x] <main task title> (stamp)` to the archive. « <main task> is done » with open
  subtasks → ask first, then archive every subtask, then the main task line.

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

1. Find the list (and pull when `sync` is `git`). Read both files (they may not exist yet).
   Resolve any numbers in the request to lines now.
2. Apply the add / status / complete request.
3. Write both files, preserving every other line's text exactly.
4. **Always** run `python3 ~/.agents/skills/todo/scripts/renumber.py <list> <archive>` last
   (then commit and push when `sync` is `git`). It sorts each
   block by status, keeps `###` main tasks after the standalone items, renumbers the list 1..N, aligns it, and strips numbers from
   the archive. It also converts old `- [ ] N - text` lines.
5. Reply in one line per change: section and text, e.g. `+ Client A: ACME-298: Check the Spot quota request (12 vCPU)`,
   `! Client B: Tighten GitLab rules`, `X Client C: Rotate the PSK (waiting on: Client C IT)`
   or `✓ archived Client C: Add a cert-expiry alert …`. For subtasks, show the main task:
   `+ Client B › CORP-129: Prod environment: Create prod KV`, `✓ closed main task CORP-129: Prod environment`.
6. If the request ends with `[via /todo: show the file]`, finish with the whole list
   as it is now, verbatim, in one ```markdown block (re-read it after writing).

Do not add a log entry, touch daily notes, or edit per-customer files unless asked.
