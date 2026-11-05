---
name: todo
description: Manage Philippe's todos in the single Vooban todo list (Customers/_todo.md) and its archive (Customers/_archive.md). Use whenever he asks to add, note, remember, track or save a todo/task/action item, marks one done/completed, asks to archive or clean up todos, or invokes /todo.
---

# Todo

One list for everything, one archive. Never write todos anywhere else
(not the daily note, not per-customer files).

- List: `/Users/philippe.lamy/workspaces/vooban/notes/Customers/_todo.md`
- Archive: `/Users/philippe.lamy/workspaces/vooban/notes/Customers/_archive.md`

## File format

Both files share the same shape: one `## <Section>` per customer, then `## Personal`.

```markdown
## Blais Industries
- [ ] 1 - BLS-298: Destroy the old hub from the pre-csp tag
- [ ] 2 - Test S2S from a Blais workstation (TCP 443 to 10.200.1.4)

## SOM
- [ ] 3 - Add a cert-expiry alert for ia-mcp.som.ca

## Personal
- [ ] 4 - Renew passport
```

- **Numbers are global**, 1..N top to bottom across all sections (so « tick 3 » is never ambiguous).
  They are positional, not IDs: after every change, renumber the whole file so it is 1..N with no gaps.

- Customer sections are alphabetical; `## Personal` is always last.
- A customer section exists only if `Customers/<Name>/` exists; use the folder name verbatim.
  Create the section lazily (first todo for that customer). Never create customer folders.
- `## Personal` holds everything that is not a customer: internal Vooban work
  (marketplace, inner tooling), the perso workspace, life admin.
- **Newest first** in both files: insert directly under the section heading.
- Archive lines: `- [x] <text without the number> (YYYY-MM-DD - HH:MM)`, local time of the move.
  The archive is not numbered.
- Nothing else in the files: no frontmatter, no prose, no sub-headings, no nesting.
  If a file is missing, create it with just the sections you need.

## Choosing the section

1. Named by Philippe ("for SOM", "personal") → that section.
2. Otherwise infer, in order:
   - what the session is about (customer repo, ticket prefix like `BLS-`/`TPA-`, customer named in recent messages);
   - the cwd: `~/workspaces/vooban/customers/<slug>/…` → the `Customers/` folder whose name matches
     the slug case- and space-insensitively, or by prefix (`blais` → `Blais Industries`, `top-aces` → `Top Aces`);
   - `~/workspaces/perso/…` or `~/workspaces/vooban/inner/…` → `Personal`.
3. Still unclear, or the slug matches no folder (e.g. `naitre-grandir`) → ask with `ask_user_question`,
   options = existing sections + Personal. Never guess silently.

## Writing the todo

- English, one line, imperative verb first, as short as it can be while still actionable cold.
- Prefix the ticket ID when known: `BLS-298: …`, `TPA-129: …`.
- When Philippe writes little, add only the missing *what/where* from the session
  (resource name, repo, MR number, person). No explanations, no "because", no trailing period.
- Keep technical names, commands and IDs exactly; wrap them in backticks.
- Several todos in one message → one line each.
- Skip exact or near duplicates of an open item in the same section; say so.

Examples:

| Philippe says | Line |
|---|---|
| « todo check the spot quota » (in a Blais session on BLS-298) | `- [ ] 1 - BLS-298: Check the Spot quota request (12 vCPU)` |
| « remind me to ping José about the RUNNER_TAG » (Top Aces cwd) | `- [ ] 7 - Tell José to use RUNNER_TAG=topaces-dev` |
| « todo passport » | `- [ ] 12 - Renew passport` (Personal) |

## Completing and archiving

Every run of this skill starts with a **sweep**: move every `- [x]` line in `_todo.md`
to the top of the matching section in `_archive.md`, stamped with the current time.
(Philippe may tick items in Obsidian; the stamp is the sweep time.)

When Philippe says an item is done ("tick 3", "tick 1, 4", "done: Meraki"):

1. Numbers refer to the file **as it is before this run** (before the sweep and any add):
   resolve them to lines first. Text references: match against open items
   (the inferred section helps disambiguate).
2. One clear match → move it to the archive as `[x]` with the stamp. Several, none, or a
   number out of range → ask.
3. Never archive or tick anything he did not say is done, except the sweep of already-ticked lines.

## Procedure

1. Read both files (they may not exist yet). Resolve any numbers in the request to lines now.
2. Sweep ticked items.
3. Apply the add/complete request. New items go first in their section.
4. Write both files, preserving every other line's text exactly. New items may be written
   without a number; archived items without their number.
5. **Always** run `python3 ~/.agents/skills/todo/scripts/renumber.py` last. It renumbers
   `_todo.md` 1..N (fixing hand edits and unnumbered lines) and strips numbers from
   `_archive.md`. Never renumber by hand.
6. Reply in one line per change: section and text, e.g. `+ Blais Industries: BLS-298: Check the Spot quota request (12 vCPU)`
   or `✓ archived SOM: Add a cert-expiry alert …`. Mention swept items as a count.
7. If the request ends with `[via /todo: show the file]`, finish with the whole `_todo.md`
   as it is now, verbatim, in one ```markdown block (re-read it after writing).

Do not add a log entry, touch daily notes, or edit per-customer files unless asked.
