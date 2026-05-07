---
name: push
description: Smart push — commits staged changes (using /commit rules) before pushing, just pushes when there are already unpushed commits, and says nothing to do when up to date. Sets the upstream automatically when the branch has none. Use `/push force` to also stage unstaged changes (asks for confirmation before pushing).
tools: Read, Bash
allowedBashCommands: git status, git diff, git log, git commit, git push, git rev-parse, git symbolic-ref, git branch, git remote, git add
model: haiku
---

# /push

Decide what to do based on the working tree and the branch's state vs its
upstream.

## `/push force` mode

When the user invokes `/push force` (the literal word `force` is the only
argument), use this flow instead of the default decision tree:

1. Run `git status --porcelain`. If the working tree is clean **and** there
   are no commits ahead of upstream, fall back to the normal flow's case C
   (`Nothing to do`).
2. Stage all tracked-modified, deleted, and untracked files:
   ```
   git add -A
   ```
   Respect `.gitignore`. Do not stage anything else by hand.
3. Run the **`/commit`** workflow. Use the user's text verbatim if they passed
   any text **after** `force` (e.g. `/push force feat(api): add login`),
   otherwise auto-generate the message per the `/commit` skill (chore | feat
   | fix only).
4. **Stop and ask the user for explicit authorization** before pushing.
   Print the new commit's subject + short hash, the branch name, and the
   target (`origin/<branch>` or `origin <branch>` for an unset upstream).
   Ask, literally:
   ```
   Push this commit to <target>? (yes/no)
   ```
   Wait for the user's reply. Only proceed if they answer with `y`, `yes`,
   `Y`, or `YES`. Anything else → stop. Do not amend, do not reset, do not
   undo the commit. Tell the user how to push later: `/push` (no args) will
   send it the next time they invoke it.
5. On approval, push using the same logic as step 5 of the default flow
   (set upstream automatically if the branch has none).
6. Print a summary line: commit subject + short hash, then
   `pushed to origin/<branch>`.

Never combine `force` with `--force` / `-f`. The `force` keyword in this
skill only authorizes staging — it never authorizes a force-push, rebase,
or history rewrite.

---

## Default mode (no args, or any text other than `force`)

Follow this decision tree.

1. Run `git status --porcelain` to inspect the working tree.
2. Run `git rev-parse --abbrev-ref HEAD` to get the current branch name.
3. Determine whether the branch has an upstream:
   ```
   git rev-parse --abbrev-ref --symbolic-full-name @{u}
   ```
   Exit code 0 ⇒ upstream exists. Non-zero ⇒ no upstream.

4. Choose **exactly one** of the following branches:

   ### A — Something is staged
   Run the **`/commit`** workflow first. Use the user's text verbatim if they
   passed any after `/push`; otherwise auto-generate the message per the
   `/commit` skill (chore | feat | fix only). Then continue to step 5.

   ### B — Nothing staged, but there are local commits ahead of the upstream
   Skip committing. Continue to step 5.

   You can verify with:
   ```
   git log @{u}..HEAD --oneline    # only meaningful when upstream exists
   ```

   ### C — Nothing staged, no commits ahead, and there is an upstream
   Say: **"Nothing to do — working tree clean and up to date with `<upstream>`."**
   Stop. Do not push.

   ### D — Nothing staged, no upstream yet, but the branch has commits
   Treat the same as B (push and set upstream in step 5).

5. **Push**. Two cases:

   - Upstream exists → `git push`.
   - No upstream → `git push --set-upstream origin <branch>` using the branch
     name from step 2.

6. Print one summary line:
   - When you committed: the commit subject + short hash, then `pushed to origin/<branch>`.
   - When you only pushed: list the subjects + short hashes that were pushed
     (`git log @{u}@{1}..@{u} --oneline` after the push, or capture before pushing).
   - When skipped: just the "Nothing to do" line.

## Rules

- Never `git add` anything. The user controls staging.
- Never amend, rebase, force-push, or rewrite history.
- Never push a different branch than the current one.
- If `git push` is rejected (non-fast-forward, etc.), stop and show the error.
  Do not run `git pull`, `--force`, or any recovery on your own.

## Allowed commands

`git status`, `git diff`, `git log`, `git commit`, `git push`,
`git rev-parse`, `git symbolic-ref`, `git branch`, `git remote`. Nothing else.
