---
name: issues
description: Breaks a plan, spec, or parent issue into independently grabbable Linear issues using vertical slices. Use when converting plans into tickets or creating issue tracker work items.
---

# Issues

Break a plan into independently grabbable Linear issues using vertical slices (tracer bullets).

## When to Use This Skill

- The user wants to convert a plan, spec, or parent issue into implementation issues.
- The user wants tickets that can be picked up independently.
- The user asks to split work into vertical slices rather than layer-by-layer tasks.

## Core Rules

- Each issue should deliver a narrow but complete path through all required layers.
- A completed slice must be demoable or verifiable on its own.
- Prefer many thin slices over a few thick ones.
- Use the project's domain glossary vocabulary.
- Carry forward relevant assets from the source plan or conversation into each issue.
- Do not close or modify the parent issue.

## Workflow

1. Gather context from the conversation or the referenced issue, URL, file, or plan.
2. Identify source assets such as screenshots, diagrams, or URLs.
3. Explore the codebase when needed to understand current state, domain vocabulary, and constraints.
4. Draft vertical slices with title, type, blockers, covered user stories, and relevant assets.
5. Create issues in Linear using `linctl` in dependency order — blockers first, so later issues can reference real issue IDs.
6. The user will review the output directly. Do not ask for validation before publishing.

## Creating Linear Issues

Use `linctl` to create issues. Determine the team from context or ask the user.

```bash
# Create an issue
linctl issue create --team <TEAM> --title "Title" --description "Description" --label "label"

# Create with a parent issue
linctl issue create --team <TEAM> --title "Title" --description "Description" --parent <PARENT-ID>

# List teams (if unsure)
linctl team list
```

## Vertical Slice Examples

A vertical slice delivers one user-visible behavior end to end. A horizontal slice completes one technical layer but cannot be verified as a complete behavior on its own.

**Good:**

```md
Title: Let customers reset their password by email
What to build: Customers can request a reset link, receive an email, open the link, set a new password, and sign in with it.
Acceptance criteria:

- [ ] A customer can request a password reset from the sign-in screen
- [ ] The reset link expires after the configured window
- [ ] A customer can sign in with the new password after reset
```

**Bad:**

```md
Title: Add password reset database fields
What to build: Add reset token and reset timestamp columns to users.
Acceptance criteria:

- [ ] User model exposes reset fields
```

The bad example is horizontal: it may be necessary work, but by itself no user can complete a password reset.

## Issue Template

```md
## Parent

A reference to the parent issue on Linear, if the source was an existing issue. Otherwise omit this section.

## What to build

A concise description of this vertical slice. Describe end-to-end behavior, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Assets

Links or attachments from the source plan or conversation needed to implement this slice. Omit if no assets are relevant.

## Blocked by

- A reference to the blocking ticket, if any

Or: None - can start immediately
```
