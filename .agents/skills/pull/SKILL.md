---
name: pull
description: Pull latest changes for all repos. Use when the user invokes /pull. Goes into each subdirectory of the ./repos/ folder in the current working directory, switches to the default branch (master or main), and pulls the latest changes.
tools: Bash
---

# Pull All Repos

Switch to the default branch and pull latest changes for every git repository in `./repos/`.

## Process

1. List all subdirectories in `./repos/` (relative to the current working directory)
2. For each subdirectory:
   - Skip if it is not a git repository (no `.git` directory)
   - Run `git status --porcelain` to check for uncommitted changes
   - If dirty: skip the repo, record status as **skipped (dirty working tree)**
   - If clean: run `git checkout master`; if that fails, run `git checkout main`; if both fail, record status as **error (no master/main branch)**
   - Run `git pull`; record success or failure
3. Print a summary table listing every repo and its result

## Rules

- Do NOT modify any files beyond what `git checkout` and `git pull` do
- Do NOT push anything
- Do NOT stash or discard uncommitted changes — skip dirty repos
- Silently skip subdirectories that are not git repos
- Run each repo's git commands using the `workdir` parameter pointed at the repo directory — do NOT use `cd`

## Output Format

Print a summary after processing all repos:

```
Repo            Status
----            ------
repo-a          pulled (master)
repo-b          pulled (main)
repo-c          skipped (dirty working tree)
repo-d          error (no master/main branch)
```

Include the branch name that was pulled when successful.
