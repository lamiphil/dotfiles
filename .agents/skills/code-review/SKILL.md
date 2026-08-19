---
name: code-review
description: Review the latest code changes by delegating a read-only investigation to one deep subagent. Use when the user invokes /code-review or asks to review a working tree, staged changes, current branch or pushed changes, GitHub PR, GitLab MR, commit, or commit range against requirements and tests, with prioritized findings and improvement recommendations.
---

# Code Review

Delegate the substantive review to exactly one foreground subagent. Keep the entire workflow read-only: never edit source files, update snapshots, commit, push, or post comments/reviews to a remote.

## Inputs

Accept an optional target:

- no target: auto-detect the latest meaningful changes
- `working-tree`: staged, unstaged, and untracked changes against `HEAD`
- `staged`: index changes against `HEAD`
- `commit [ref]`: one commit; default to `HEAD`
- `range <base>..<head>`: an explicit commit range
- `branch`: current local branch from its merge-base with the default branch
- `push`: current upstream branch from its merge-base with the remote default branch
- `pr <number-or-url>`: GitHub pull request
- `mr <number-or-url>`: GitLab merge request

Resolve a bare PR/MR URL as remote-review scope. Resolve a bare SHA or ref as a commit, range, or branch scope rather than allowing auto-detection to override it. Treat only non-resolvable prose and stated acceptance criteria as supplemental review context. Ask only when the target remains ambiguous or cannot be resolved safely.

## Resolve the scope

For no target, use this precedence:

1. If tracked or untracked working-tree changes exist, review all changes against `HEAD`, including untracked files.
2. Otherwise, use the open PR/MR associated with the current branch when one exists.
3. Otherwise, review the current branch from its merge-base with the default branch when it has unique commits.
4. Otherwise, review `HEAD^..HEAD`.

Detect GitHub versus GitLab from the remote. Use `gh` or `glab` only for read operations. For a PR/MR, collect its title, description, base/head refs, linked issue context when available, diff, and CI/check status. Do not switch branches or fetch destructively. State when remote metadata is unavailable.

Resolve branch bases through the current branch's upstream remote, falling back to `origin`. Determine that remote's default branch from provider metadata or its symbolic `HEAD`. Ask rather than guess if the remote or base remains ambiguous.

For `push`, review the remote-tracking upstream branch, not unpushed local changes. Explain this interpretation in the final scope.

Before running tests, capture `git status --short`. Skip commands that could overwrite any pre-existing path or mutate tracked files. Never stash, reset, clean, switch, restore, discard, or overwrite user changes.

## Delegate the investigation

Invoke exactly one synchronous foreground `subagent` with `thinking: high`; do not invoke additional subagents. Give it the resolved target, repository root, available PR/MR or user context, and the following mandate:

```text
Act as a rigorous senior code reviewer. Perform a read-only review of the specified change scope.

1. Read applicable repository instructions first.
2. Establish the exact diff and inspect every changed file, including untracked files in scope.
3. Trace affected callers, callees, schemas, configuration, and tests beyond the diff as needed.
4. Derive expected behavior from, in priority order: user acceptance criteria; PR/MR description and linked issues; referenced plans/specs; repository documentation; existing tests and public behavior. Do not treat the implementation itself as the specification.
5. Check relevant correctness, edge cases, error handling, security/privacy, compatibility, state/concurrency, migrations, performance/resources, observability, maintainability, and documentation. Focus only on dimensions relevant to this change.
6. Run local validation only when the checkout faithfully represents the resolved scope. Staged-only, remote PR/MR, push, commit, and range targets may differ from the checkout; in that case use target CI evidence or report local validation as unavailable. Run the smallest relevant commands: targeted tests first, then broader tests, type checks, linters, or builds when justified. Skip any command that may overwrite pre-existing paths or mutate tracked files. Do not run formatters in write mode, update snapshots, install dependencies, stash, reset, clean, switch, restore, or otherwise modify the checkout. Distinguish failures caused by the change from environment or pre-existing failures.
7. Re-check each candidate finding against surrounding code and the reviewed diff. Report only issues introduced by or exposed by this change that are concrete, actionable, and supported by evidence. Do not report subjective style preferences as defects.
8. Check git status after validation. Report any test side effects; do not clean or revert them.

Use severities:
- P0: immediate catastrophic impact; must block
- P1: serious correctness/security/data-loss/regression risk; should block
- P2: real defect or important requirement/test gap; fix before merge when practical
- P3: low-impact issue or worthwhile hardening

Return this structure:
## Verdict
One concise sentence: block, needs changes, or ready, with confidence.

## Findings
Findings ordered P0 to P3. For each:
### [P#] Imperative, specific title — path/to/file:line
Explain the triggering scenario, evidence, impact, and smallest sound recommendation. Cite exact paths and lines. If there are none, write `No actionable findings.`

## Spec and validation
List requirements checked, commands actually run with pass/fail results, and meaningful untested gaps. Never imply a command ran when it did not.

## Improvement opportunities
List only non-blocking, evidence-based improvements. Omit this section if empty.

## Scope and confidence
State the diff/range reviewed, important assumptions or unavailable context, pre-existing failures, test side effects, and confidence.
```

Do not ask the subagent to edit or fix anything. Never launch a second reviewer.

## Present the result

Sanity-check that each finding identifies a changed behavior, precise location, realistic trigger, and impact. Remove unsupported speculation, duplicate findings, and irrelevant pre-existing problems. Preserve uncertainty rather than inventing evidence.

Return the review report directly. Do not apply fixes. If validation could not run, make the limitation prominent rather than treating it as success.
