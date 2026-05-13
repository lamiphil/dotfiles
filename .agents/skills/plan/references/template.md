# Plan Template

Save plans under `./plans/` using `YY-MM-DD-<slug>.md`.

Example names:

- `plans/26-05-12-migrate-to-flux-v2.md`
- `plans/26-05-15-refactor-aws-guard.md`

## Required Structure

```markdown
# <Title>

## Goal

<What this achieves and why — 2-3 sentences max>

## Tasks

1. **Step 1**: Description
   - File: `path/to/file`
   - Changes: What to modify and how. Include relevant, non-trivial snippets when useful.
   - Acceptance: How to verify

2. **Step 2**: Description
   - File: `path/to/file`
   - Changes: What to modify and how. Include relevant, non-trivial snippets when useful.
   - Acceptance: How to verify

## Files to Modify

- `path/to/file` - what changes.

## New Files (if any)

- `path/to/new` - purpose

## What We're NOT Doing

<Explicitly scope out related work that is deferred or out of scope.>

## Risks & Edge Cases

<Things that could go wrong or need special handling.>
```

## Writing Rules

- Prefer 2–5 top-level steps.
- Use sub-tasks only when a single top-level step genuinely needs internal sequencing.
- Keep each step small and actionable.
- Prefer concrete file-level changes over abstract architecture prose.
- Each step must include acceptance criteria.
- Avoid long background sections unless they are necessary to explain the step breakdown.

## Validation Checklist

Use this before finishing:

- title is specific
- goal is 2–3 sentences max
- tasks are numbered
- steps are actionable
- file paths are explicit
- acceptance criteria exist for every step
- files-to-modify list is complete
- non-goals are explicit
- risks mention likely failure modes or tricky transitions
