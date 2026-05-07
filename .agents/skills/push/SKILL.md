---
name: push
description: Smart push — auto-stages and commits pending changes (per /commit rules), then pushes. If something is already staged, only the staged set is committed (manual per-group flow stays intact). Just pushes when there are unpushed commits and a clean tree. Sets the upstream automatically when the branch has none. Use `/push force` to bypass the logical-commit guard and lump everything into one commit (asks for confirmation before pushing).
tools: Read, Bash
allowedBashCommands: git status, git diff, git log, git add, git reset, git commit, git push, git rev-parse, git symbolic-ref, git branch, git remote, find
model: haiku
---

# /push

Decide what to do based on the working tree and the branch's state vs its
upstream.

## Repo resolution

Before any git command, resolve `<repo>`:

1. Run `git rev-parse --show-toplevel` (without `-C`).
   - Exit 0 → the printed path is `<repo>`. Skip to the main flow below.
   - Non-zero → cwd is not inside a git repo. Continue to step 2.
2. Search up to two levels deep for git repos:
   ```
   find . -maxdepth 3 -type d -name .git -prune
   ```
   For each result, the repo path is its parent directory.
3. Decide:
   - **0 found** → stop with: "Not in a git repository, and no nearby repos
     found under `<cwd>`. cd into a repo and re-run."
   - **1 found** → use it. Tell the user `Using <repo>`.
   - **2+ found** → print a numbered list and ask: "Which repo? (1–N, or
     'cancel')". Wait for the reply. Use the matched repo, or stop with
     `Cancelled.` on no match.
4. From this point on, prefix every git command with `git -C <repo>`. This
   includes the calls into the `/commit` workflow (forward `<repo>` to it).

## `/push force` mode

When the user invokes `/push force`, use this flow instead of the default
decision tree. Resolve `<repo>` first (per "Repo resolution"), then:

1. Run `git -C <repo> status --porcelain`. If the working tree is clean
   **and** there are no commits ahead of upstream, fall back to the normal
   flow's case C (`Nothing to do`).
2. Stage everything if needed: if the porcelain output already has staged
   entries (first column non-space), keep that intact — the user has
   curated it. Otherwise run `git -C <repo> add -A` to stage all
   working-tree changes. Respects `.gitignore`.
3. Commit. If the user passed any text **after** `force`
   (e.g. `/push force feat(api): add login`), use it verbatim with
   `git -C <repo> commit -m "<text>"`. Otherwise, **bypass the
   logical-commit guard**: pick a single chore/feat/fix message that
   broadly summarizes the staged set and commit. Force mode is the
   explicit override for the "must be one logical change" rule.
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
skill only authorizes bypassing the logical-commit guard — it never
authorizes a force-push, rebase, or history rewrite.

---

## Default mode (no args, or any text other than `force`)

Resolve `<repo>` per "Repo resolution" first, then follow this decision tree.

1. Run `git -C <repo> status --porcelain` to inspect the working tree.
2. Run `git -C <repo> rev-parse --abbrev-ref HEAD` to get the current branch name.
3. Determine whether the branch has an upstream:
   ```
   git -C <repo> rev-parse --abbrev-ref --symbolic-full-name @{u}
   ```
   Exit code 0 ⇒ upstream exists. Non-zero ⇒ no upstream.

4. Choose **exactly one** of the following branches:

   ### A — There are working-tree changes (staged or unstaged)
   Run the **`/commit`** workflow, which will:
   - **Auto-stage only when nothing is already staged.** If the user has
     hand-staged a subset, that subset is committed as-is and the rest of
     the working tree is left for follow-up `/commit` runs.
   - Run the logical-commit check on the staged set.
   - Either commit, or refuse with a suggested split (and unstage only what
     `/commit` itself just staged — hand-staged sets are preserved).

   If `/commit` refused (broad set), **stop**. Pass through its suggested
   split to the user. Do not push. Tell the user to `git add` the first
   logical group manually and re-run `/push` (or `/push force` if they
   really want one big commit).

   If the commit succeeded, continue to step 5.

   If the user passed text after `/push`, forward it to `/commit` so it's
   used as the verbatim message.

   ### B — Nothing changed in the tree, but there are local commits ahead of the upstream
   Skip committing. Continue to step 5.

   You can verify with:
   ```
   git -C <repo> log @{u}..HEAD --oneline    # only meaningful when upstream exists
   ```

   ### C — Working tree clean, no commits ahead, and there is an upstream
   Say: **"Nothing to do — working tree clean and up to date with `<upstream>`."**
   Stop. Do not push.

   ### D — Working tree clean, no upstream yet, but the branch has commits
   Treat the same as B (push and set upstream in step 5).

5. **Push**. Two cases:

   - Upstream exists → `git -C <repo> push`.
   - No upstream → `git -C <repo> push --set-upstream origin <branch>` using
     the branch name from step 2.

6. Print one summary line:
   - When you committed: the commit subject + short hash, then `pushed to origin/<branch>`.
   - When you only pushed: list the subjects + short hashes that were pushed
     (`git log @{u}@{1}..@{u} --oneline` after the push, or capture before pushing).
   - When skipped: just the "Nothing to do" line.

## Rules

- Never amend, rebase, force-push, or rewrite history.
- Never push a different branch than the current one.
- If `git push` is rejected (non-fast-forward, etc.), stop and show the error.
  Do not run `git pull`, `--force`, or any recovery on your own.

## Allowed commands

`git status`, `git diff`, `git log`, `git add`, `git reset`, `git commit`,
`git push`, `git rev-parse`, `git symbolic-ref`, `git branch`, `git remote`,
`find` (only with the exact form `find . -maxdepth 3 -type d -name .git -prune`
used for repo discovery). Either as plain or `git -C <repo>` form.
Nothing else.
