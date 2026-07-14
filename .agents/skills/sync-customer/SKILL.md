---
name: sync-customer
description: Sync all GitLab repos for a customer/project. Use when the user invokes /sync-customer <name> or asks to sync/pull all repos for a given customer. Discovers every project under the customer's GitLab group (vooban/customers/.../<name>) via the glab CLI, clones any that are missing under ~/workspaces/vooban/customers/<name>/, and pulls the default branch for repos already checked out.
tools: Bash
---

# Sync Customer Repos

Given a customer/project name (e.g. `maheu-maheu`), sync every GitLab repo belonging to that customer's group into `~/workspaces/vooban/customers/<name>/`. GitLab is the source of truth for which repos exist — do not rely on a local config file or on whatever folders already happen to be checked out.

## Requirements

- `glab` CLI, already authenticated to gitlab.com
- `jq` for JSON parsing

## Process

1. **Resolve the customer's GitLab group.**

   ```
   glab api "groups?search=<name>" | jq -r '.[] | select(.path == "<name>") | select(.full_path | startswith("vooban/customers/")) | "\(.id)\t\(.full_path)"'
   ```

   - No result: stop, report "no GitLab group found for customer '<name>'".
   - More than one result: stop, list the matches, ask the user to disambiguate.
   - Exactly one result: capture `group_id` and `group_full_path`.

2. **List every project under the group, including subgroups.**

   Paginate until a page returns `[]`:

   ```
   glab api "groups/<group_id>/projects?include_subgroups=true&per_page=100&page=<N>"
   ```

   Concatenate all pages into one JSON array.

3. **Filter to the customer's own namespace.**

   Keep only projects whose `path_with_namespace` starts with `<group_full_path>/`. This drops projects that are merely shared with the group but don't actually belong to this customer (e.g. someone's personal repo shared for access).

4. **For each remaining project**, extract `path` (repo folder name), `ssh_url_to_repo`, and `default_branch`. Target directory: `~/workspaces/vooban/customers/<name>/<path>`.

   - Directory doesn't exist: `git clone <ssh_url_to_repo> <target_dir>`. Record **cloned**.
   - Directory exists but has no `.git`: record **error (not a git repo)**, don't touch it.
   - Directory exists and is a git repo:
     - Run `git status --porcelain` (use the `workdir` parameter — do not `cd`).
     - Dirty: record **skipped (dirty working tree)**.
     - Clean: `git checkout <default_branch>`, then `git pull`. Record **pulled (<default_branch>)**, or **error** if either command fails.

5. Print a summary table of every repo and its result:

   ```
   Repo               Status
   ----               ------
   maheu-specs        cloned
   infra              pulled (main)
   igeyser            skipped (dirty working tree)
   projectconductor   error (checkout failed)
   ```

## Rules

- Never push, never stash or discard uncommitted changes, never force anything.
- Don't modify files beyond what `git clone`/`checkout`/`pull` do.
- Don't create `~/workspaces/vooban/customers/<name>/` if the group lookup fails — only ever created as a side effect of a successful `git clone`.
- Silently skip nothing without recording it in the summary — every project found in step 3 must appear in the final table.
