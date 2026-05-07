---
name: commit
description: Stage and commit pending changes using a tight conventional-commits format with only chore/feat/fix types. Auto-stages all working-tree changes when nothing is staged yet; commits just the existing staged set when the user pre-staged a subset. Refuses to commit when the staged set is not one logical change. With arguments, uses them as the full commit message verbatim.
tools: Read, Bash
allowedBashCommands: git status, git diff, git log, git add, git reset, git commit
model: haiku
---

# /commit

Commits pending working-tree changes with a tight conventional-commits format.
**Auto-stages everything when nothing is staged yet**, so you no longer need to
`git add` for the common case. When something **is** already staged, only the
staged set is committed — so manual per-group staging (`git add <subset> && /commit`)
still works as expected.

## Format

```
<type>(<scope>): <description>
```

- `<type>` — exactly one of: `chore`, `feat`, `fix`
- `<scope>` — lowercase, the affected component or area; in parentheses; optional, omit if unclear
- `<description>` — short, imperative, lowercase first letter, no trailing period
- Total subject ≤ 72 characters when possible
- No body, no footer (keep it simple)

### Types

- **chore** — Anything that isn't a new feature or a bug fix. Refactor, formatting, docs, CI, dependency bumps, config tweaks, dotfile changes.
- **feat** — A new feature is added.
- **fix** — A bug is fixed.

### Examples

```
feat(auth): add login page
fix(auth): redirect after expired session
chore(ci): bump actions/checkout to v4
chore: tidy gitignore
```

## With arguments

If the user passes text after `/commit`, treat the entire text as the **final
commit message** and use it verbatim:

1. Run `git status --porcelain`.
2. If anything is **already staged** (first column of porcelain output is
   non-space, e.g. `M `, `A `, `D `, `R`, `C`), commit just that staged set
   — do not auto-stage anything else.
3. Otherwise, if the working tree is clean, stop with: "Nothing to commit —
   working tree clean."
4. Otherwise (tree dirty, nothing staged), `git add -A` to stage everything,
   then commit.
5. `git commit -m "<the user's text>"`

Do not edit the message. Do not add a type if missing. With arguments, the
logical-commit guard is **bypassed** — explicit user intent wins.

## Without arguments

1. Run `git status --porcelain`.
2. **Decide whether to auto-stage**. If the porcelain output contains
   **any line whose first column is non-space** (something is already
   staged), do **not** auto-stage — the user has set up the staged set
   intentionally. If nothing is staged and the working tree is clean,
   stop with: "Nothing to commit — working tree clean." Otherwise
   (working-tree changes exist but nothing is staged), run
   `git add -A` to stage everything (respects `.gitignore`).
   - Remember whether **you** ran `git add -A` (call it `weStaged`).
     This matters for the refusal flow below.
3. Run `git diff --cached` to read the staged changes.
4. **Check that the staged set is one logical change.** See "Logical commits"
   below.
   - If it is **not** one logical change → stop.
     - If `weStaged` is true: run `git reset` to undo the staging you just
       did, so the working tree is back to its pre-`/commit` state.
     - If `weStaged` is false: the user staged this themselves; **leave
       the index intact** so they don't lose their selection.
     Then report a suggested split to the user (see "Refusal flow").
     **Do not commit.**
5. Pick exactly one of `chore` / `feat` / `fix` based on the diff:
   - Adding new functionality the user can use → `feat`
   - Correcting incorrect behavior → `fix`
   - Anything else (config, docs, refactor, deps, dotfiles, CI) → `chore`
6. Pick a scope when one is obvious from the paths (e.g., `auth`, `ci`, `nvim`, `aws-guard`). If multiple unrelated areas changed, omit the scope.
7. Write the description. Imperative mood ("add", not "added"). Keep it under ~50 chars.
8. Run `git commit -m "<message>"`.
9. Print the resulting commit subject and short hash.

Allowed commands: `git status`, `git diff`, `git log`, `git add`, `git reset`,
`git commit`. Never `git push`, `git rebase`, `git checkout`, `git restore`,
`git stash`, or anything else.

## Logical commits

One commit = one logical change. Before committing, look at the staged set
and decide whether it is **one** thing the reviewer would describe with a
single sentence.

Split when you see:

- **Different scopes / areas** — e.g. `nvim` config + `tmux` config + `aws-guard`.
- **Mixed types** — a real bug fix mixed in with unrelated refactor or config tweaks.
- **A new feature plus its supporting unrelated cleanup** — commit each separately.
- **Independent files that don't co-evolve** — if file A keeps working without
  file B (and vice versa), they probably belong in different commits.

Keep together when:

- The changes are required to ship one capability (e.g. a new `/foo` command:
  the extension code + the settings entry that registers it).
- A single refactor touches several files but expresses one idea.
- A test and the production code it covers.

## Refusal flow (when staged set is too broad)

Report back with a suggested split: file groupings + a one-line message per
group. Tell the user how to commit each group:

```
git add <files for first commit>  &&  /commit
git add <files for second commit> &&  /commit
…
```

If you ran `git add -A` yourself this turn (`weStaged` true), also run
`git reset` first so the index is clean and the user's `git add <subset>`
starts from a clean slate. If the user had already curated the staged set
(`weStaged` false), leave it intact so they can adjust it without losing
their work.

The working tree is left intact either way (only the index may be reset).
Never try to split commits with `git add -p` or `git restore --staged`
yourself — once we refuse, the user takes manual control.

## When to bypass the logical-commit guard

If the user really wants one big commit covering everything, they can pass
an explicit message: `/commit chore: assorted dotfile cleanup`. With explicit
arguments, this skill commits verbatim and skips the logical-commit check.
