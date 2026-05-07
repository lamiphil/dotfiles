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
4. Pick exactly one of `chore` / `feat` / `fix` based on the diff:
   - Adding new functionality the user can use → `feat`
   - Correcting incorrect behavior → `fix`
   - Anything else (config, docs, refactor, deps, dotfiles, CI) → `chore`
5. Pick a scope when one is obvious from the paths (e.g., `auth`, `ci`, `nvim`, `aws-guard`). If multiple unrelated areas changed, omit the scope.
6. Write the description. Imperative mood ("add", not "added"). Keep it under ~50 chars.
7. Run `git commit -m "<message>"`.
8. Print the resulting commit subject and short hash.

Only run `git status`, `git diff`, `git log`, and `git commit`. Never `git add`, `git push`, `git rebase`, or anything else.
