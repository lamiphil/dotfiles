---
name: push
description: Commit then push. Same rules as /commit, plus a `git push` afterward. Sets upstream automatically when the branch has none.
tools: Read, Bash
allowedBashCommands: git status, git diff, git log, git commit, git push, git rev-parse, git symbolic-ref, git branch
model: haiku
---

# /push

Run the **/commit** workflow first (see that skill for the format and rules), then push.

## Steps

1. Do everything `/commit` does — including refusing to run when nothing is staged, and using any user-supplied text verbatim.
2. After the commit succeeds, push:

   ```
   git push
   ```

3. If `git push` fails because the current branch has no upstream, get the branch name and set the upstream, then retry:

   ```
   git rev-parse --abbrev-ref HEAD          # current branch
   git push --set-upstream origin <branch>
   ```

4. Print the commit subject + short hash, then a single line confirming the push (`pushed to origin/<branch>`).

## Allowed commands

`git status`, `git diff`, `git log`, `git commit`, `git push`, `git rev-parse`, `git symbolic-ref`, `git branch`. Nothing else.
