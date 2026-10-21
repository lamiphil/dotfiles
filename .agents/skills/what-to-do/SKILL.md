---
name: what-to-do
description: >-
  Aggregate configured Jira items, open GitLab merge requests, and unresolved todos in today's Obsidian daily note, then return a grouped, ranked plan in chat. Use when the user invokes /what-to-do or asks "what should I work on", "what's on my plate", "quel est mon backlog", or similar prompts.
---

# What To Do

Aggregate all outstanding work assigned to the current user from Jira, GitLab, and today's Obsidian daily note. Rank the results, then respond in chat with a grouped list and a short "next 3 things" recommendation. Do not write any files.

## Sources

1. **Jira** — items in `$ATLASSIAN_PROJECTS` that are assigned to the current user or carry the `DevOps` / `devops` label.
2. **GitLab merge requests** — MRs assigned to the current user or requesting their review, across every project on `gitlab.com`.
3. **Today's daily journal** — unresolved `- [ ]` checkboxes in today's daily note only.

Skip any source that fails, but report the failure in the output.

## 1. Jira

Configuration comes from ignored `.env.local` variables:

- `$ATLASSIAN_BASE_URL`
- `$ATLASSIAN_EMAIL`
- `$ATLASSIAN_PROJECTS` — comma-separated Jira project keys
- `$ATLASSIAN_TOKEN`

If any variable is unset or empty, skip Jira and report which variable is missing.

Query the configured projects in a single JQL call via the Jira Cloud search API:

```bash
curl -s -u "$ATLASSIAN_EMAIL:$ATLASSIAN_TOKEN" \
  -G "$ATLASSIAN_BASE_URL/rest/api/3/search/jql" \
  --data-urlencode "jql=project in ($ATLASSIAN_PROJECTS) AND statusCategory != Done AND (assignee = currentUser() OR labels in (DevOps, devops)) ORDER BY priority DESC, updated DESC" \
  --data-urlencode 'fields=summary,status,priority,duedate,issuetype,updated,project,labels' \
  --data-urlencode 'maxResults=100'
```

Parse `issues[]` with `jq`. For each issue capture:

- `key` (e.g. `PROJ-123`)
- `fields.project.key` (used to group output)
- `fields.summary`
- `fields.status.name`
- `fields.priority.name` (default `Medium` if missing)
- `fields.duedate` (may be null)
- `fields.issuetype.name` (Story / Task / Bug / …)
- `fields.updated`
- browse URL: `$ATLASSIAN_BASE_URL/browse/<key>`
- match reason:
  - `assigned` if `fields.assignee.emailAddress == "$ATLASSIAN_EMAIL"`
  - `devops` if the label matched but assignee did not
  - `both` if both are true

Group the output by project in `$ATLASSIAN_PROJECTS` order. Within each project, list `assigned`/`both` items before `devops`-only items.

## 2. GitLab merge requests

Use the authenticated `glab` CLI on `gitlab.com`. Run both queries in parallel; deduplicate on `web_url`.

```bash
# MRs assigned to the current user
glab api 'merge_requests?scope=assigned_to_me&state=opened&per_page=100'

# MRs awaiting the current user's review
glab api 'merge_requests?scope=all&reviewer_username=@me&state=opened&per_page=100'
```

`@me` resolves through the token; if it fails, fall back to `glab api user | jq -r .username` and substitute.

For each MR capture:

- `references.full` (e.g. `group/project!42`)
- `title`
- `web_url`
- `draft` (boolean)
- `updated_at`
- role: `assignee` or `reviewer` (record both if applicable)

Group in output as `Assigned to me` and `Awaiting my review`.

## 3. Today's daily journal

Vault root: `$NOTES_ROOT`. If unset, skip this source and report the missing variable.

Read exactly one file: today's daily note.

- Path: `Journal/<YYYY>/<MM - Month>/<YYYY-MM-DD>.md`
- Month folder format: two-digit month, ` - `, English month name (e.g. `09 - September`).
- If the file does not exist, skip this source and report:
  `Today's daily note not found: <path>`. Do not create it.

Extract unresolved todos with ripgrep:

```bash
rg --no-heading --line-number '^- \[ \] ' "$TODAY_NOTE"
```

For each hit capture:

- line number
- task text (strip the `- [ ] ` prefix)

Never scan any other file. Do not read past daily notes. Do not read `_TODOS.md` files.

## Ranking

Rank inside each group before printing.

**Jira** — sort by:

1. Overdue (`duedate` before today) first
2. Priority: `Highest` > `High` > `Medium` > `Low` > `Lowest`
3. Most recently updated

**GitLab** — sort by:

1. Non-draft before draft
2. Reviewer requests before assignee items (review unblocks others)
3. Oldest `updated_at` first (stale MRs are the pain)

**Today's todos** — preserve document order.

## Output format

Respond in chat, in the language of the invoking prompt (default French). Use this shape:

```markdown
## What to do — YYYY-MM-DD HH:MM

### Jira (N)
- **PROJ** (N)
  - `PROJ-123` 👤 **Highest** [In Progress] Story — Summary (due 2026-08-20)
  - `PROJ-124` 🏷️ **Medium** [To Do] Task — Summary

Mark each item with 👤 (assigned to me), 🏷️ (DevOps label only), or both.

### GitLab MRs (N)
- **Assigned to me** (N)
  - `group/project!42` — Title (updated 3d ago)
- **Awaiting my review** (N)
  - `group/project!17` — Title _(draft)_

### Today's todos (N)
- L8: Task text
- L12: Task text

### Next 3

1. `PROJ-123` — <one-line reason>
2. `group/project!17` — <one-line reason>
3. Today L8 — <one-line reason>
```

- Show total counts in each heading, e.g. `### Jira (12)`.
- Omit any section whose source failed; list the failure below the top heading as `_Skipped: <source> — <reason>_`.
- The "Next 3" recommendation combines all sources. Prefer overdue Jira → reviewer MRs → high-priority Jira → stale reviewer MRs → today's todos. Add a one-line justification per pick.
- Never include more than the three top items in "Next 3"; the full list is above.

## Constraints

- Read-only. Do not write, edit, or create files.
- Do not print credentials or full API responses; only the parsed fields listed above.
- Cap each section at the top 20 items after ranking; report `+N more` if truncated.
- If the user asks for a specific source only (e.g. "just show my Jira"), run only that source and return the same shape without empty sections.

## Process

1. Determine today's date (local timezone) and resolve today's daily-note path.
2. Run the three source queries in parallel where possible.
3. Rank each group per the rules above.
4. Build the output in the invoking language.
5. Emit the "Next 3" recommendation.
