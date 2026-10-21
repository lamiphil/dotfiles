---
name: mr
description: Interact with GitLab merge requests using the `glab` CLI. Covers creating MRs with the enforced title format, viewing status, checking CI pipelines, reviewing, and merging. Use when the user invokes /mr or asks to create/view/review/merge a GitLab merge request.
---

# GitLab MR Skill

Use the `glab` CLI to interact with GitLab merge requests. Always resolve the target project explicitly (`--repo group/subgroup/project`) when not run from inside the corresponding checkout.

## Create an MR

**Always title MRs with this exact format:**

```
<type>(<scope>): <description>
```

- `<type>` — exactly one of: `feat`, `fix`, `chore`, `refactor`
- `<scope>` — lowercase, the affected component or area; in parentheses; required when obvious
- `<description>` — short, imperative, lowercase first letter, no trailing period
- Preserve acronyms and proper nouns in their original casing
- Total title ≤ 72 characters when possible

Examples:

```
feat(ci): add deployment in dev
chore(docs): add docs for ci
fix(auth): redirect after expired session
refactor(api): extract user lookup into helper
```

Commands:

```bash
# Explicit title (preferred)
glab mr create \
  --title "feat(ci): add deployment in dev" \
  --description "Body of the MR"

# Auto-fill from commits — only OK when the first commit follows the format above
glab mr create --fill

# Push and create against the default target branch in one go
glab mr create --fill --push --yes
```

Draft MRs get a `Draft: ` prefix from GitLab automatically; the underlying title still must follow the format:

```bash
glab mr create --draft --title "feat(ci): add deployment in dev"
```

## View / list MRs

```bash
# One MR (defaults to the current branch's MR)
glab mr view <MR_IID>
glab mr view <MR_IID> --output json | jq '{iid, title, state, source_branch, web_url}'

# MRs assigned to me across every project
glab api 'merge_requests?scope=assigned_to_me&state=opened&per_page=100'

# MRs where I am a reviewer
glab api 'merge_requests?scope=all&reviewer_username=@me&state=opened&per_page=100'
```

## CI status on an MR

```bash
# Latest pipeline for the MR
glab mr view <MR_IID> --output json | jq '.head_pipeline // .pipeline | {id, status, web_url}'

# All pipelines attached to the MR
glab api "projects/:fullpath/merge_requests/<MR_IID>/pipelines"

# Wait for the current pipeline to finish
glab ci status --live
```

## Review an MR

```bash
glab mr view <MR_IID>
glab mr diff <MR_IID>
glab mr approve <MR_IID>
glab mr note <MR_IID> --message "Feedback text"
```

## Merge an MR

```bash
# Merge when pipeline succeeds (recommended)
glab mr merge <MR_IID> --when-pipeline-succeeds --squash --remove-source-branch --yes

# Immediate merge (only if pipeline is already green or skipped)
glab mr merge <MR_IID> --squash --remove-source-branch --yes
```

## Discussions and threads

```bash
# List discussions
glab api "projects/:fullpath/merge_requests/<MR_IID>/discussions?per_page=100"

# Resolve a discussion thread
glab api --method PUT \
  "projects/:fullpath/merge_requests/<MR_IID>/discussions/<DISCUSSION_ID>" \
  --field resolved=true
```

## JSON queries

Most `glab` commands support `--output json`. Prefer piping to `jq`:

```bash
glab mr list --output json | jq '.[] | "\(.iid): \(.title) [\(.state)]"'
```

## Notes

- Do not push straight to protected branches; always route work through an MR.
- When the current repo has a GitLab remote, `glab` resolves the project automatically. Otherwise pass `--repo group/subgroup/project`.
- For automated CI iteration on Greptile reviews, see the `greploop` skill.
