---
name: push
description: Smart push — commits staged changes (using /commit rules) before pushing, just pushes when there are already unpushed commits, and says nothing to do when up to date. Sets the upstream automatically when the branch has none.
tools: Read, Bash
allowedBashCommands: git status, git diff, git log, git commit, git push, git rev-parse, git symbolic-ref, git branch, git remote
model: haiku
---

# /push

Decide what to do based on the working tree and the branch's state vs its
upstream.

## Decision tree

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
