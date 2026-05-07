---
name: commit
description: Commit staged changes using a tight conventional-commits format with only chore/feat/fix types. With arguments, uses them as the full commit message verbatim. Without arguments, analyzes staged changes and generates a short message.
tools: Read, Bash
allowedBashCommands: git status, git diff, git log, git commit
model: haiku
---

# /commit

Always commits the **already staged** changes. Never stages anything.

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

If the user passes text after `/commit`, treat the entire text as the **final commit message** and use it verbatim. Do not edit it. Do not add a type if missing. Just run:

```
git commit -m "<the user's text>"
```

## Without arguments

1. Run `git status --porcelain` to see what's staged.
2. If **nothing is staged**, stop and tell the user: "Nothing staged. Run `git add` first." Do not stage anything yourself.
3. Run `git diff --cached` to read the changes.
4. **Check that the staged set is one logical change.** See "Logical commits"
   below. If it isn't, stop and tell the user how to split it.
5. Pick exactly one of `chore` / `feat` / `fix` based on the diff:
   - Adding new functionality the user can use → `feat`
   - Correcting incorrect behavior → `fix`
   - Anything else (config, docs, refactor, deps, dotfiles, CI) → `chore`
6. Pick a scope when one is obvious from the paths (e.g., `auth`, `ci`, `nvim`, `aws-guard`). If multiple unrelated areas changed, omit the scope.
7. Write the description. Imperative mood ("add", not "added"). Keep it under ~50 chars.
8. Run `git commit -m "<message>"`.
9. Print the resulting commit subject and short hash.

Only run `git status`, `git diff`, `git log`, and `git commit`. Never `git add`, `git push`, `git rebase`, or anything else.

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

If the staged set is too broad, **do not commit**. Stop and report back with
a suggested split (file groupings + one-line message per group). Tell the
user to:

```
git reset                         # unstage everything
git add <files for first commit>  # then re-run /commit
```

Never try to split commits with `git add -p` or `git restore --staged`
yourself — the user controls staging.
