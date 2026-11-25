---
name: refresh-memory
description: Refreshes the current expert session with the latest project knowledge from its declared log target (a customer work log or a project _log.md). Use when the user asks to refresh memory, update project context, catch up on recent work, absorb the latest project logs, or prepare the expert session before cloning it for another task.
---

# Refresh Memory

Refresh the current session's project understanding from its log. Remain strictly read-only.

## Locate the project log

1. Find the log target exactly as the `log` skill does ("Find the log target"): the `## Log` declaration in the nearest `AGENTS.md` / `CLAUDE.md`, an overriding outer declaration first. Never guess from paths or environment variables.
2. When the rule needs a choice (for example which customer), infer it from the session context: prior discussion, repository names, project terminology. Match names case-insensitively, tolerating spaces, hyphens and slug forms.
3. If no declaration exists or no unique match exists, ask the user. Never guess between plausible targets.
4. Require the target file to exist. If missing, stop and report the resolved path.

Do not treat the cwd's basename as the project.

## Determine the refresh boundary

Search the current session context for the newest stable marker:

`Memory refreshed through: YYYY-MM-DD | HH:MM`

- If a marker exists, treat its timestamp as the last absorbed log entry.
- If no marker or other unambiguous last-known timestamp exists, read the entire log in manageable chunks to establish the baseline.
- If the marker timestamp does not exist in the current log, warn that the log may have been rewritten and read the entire log rather than risk missing updates.

Logs group entries under date headings and may contain multiple `**YYYY-MM-DD | HH:MM**` entries per date. Date sections are newest-first, while entries within one date may be appended in ascending time order. Therefore:

- Compare entry timestamps; do not merely stop at the marker's line.
- Absorb every timestamped entry newer than the marker.
- Read through the complete section for the marker's date so later same-day entries are not missed.
- Stop only after reaching a date older than the marker date.
- Exclude entries at or before the marker timestamp from the delta.

Use bounded `read` calls and continue with offsets when a file exceeds tool output limits.

## Follow relevant local links

From newly absorbed entries, follow a directly referenced local note only when it is needed to understand a decision, status change, blocker, or next step.

- Support Obsidian wikilinks and relative Markdown note links.
- Resolve at most one hop from the log.
- Do not recursively traverse links.
- Do not open unrelated notes, external URLs, repositories, issue trackers, or web sources.
- Treat the log file as the primary authority; linked notes only clarify it.

## Reconcile knowledge

- Treat newer timestamped log information as authoritative over older session assumptions.
- Explicitly identify material facts, decisions, or next steps that the new log supersedes.
- Preserve exact identifiers such as issue numbers, merge requests, commit hashes, environments, and resource names.
- Distinguish completed work, current state, unresolved blockers, and proposed next steps.
- Do not invent context that is absent from the sources.

## Respond

Match the language of the current session. Return a concise structured delta with only relevant, non-empty sections:

- **Progress**
- **Decisions / changed assumptions**
- **Current state**
- **Blockers / open questions**
- **Next steps**

End with exactly one checkpoint line using the greatest timestamp actually absorbed from the log:

`Memory refreshed through: YYYY-MM-DD | HH:MM`

If there are no newer entries, say that the expert context is already current and repeat the existing marker unchanged.

## Safety

Do not modify project notes, Pi session files, repositories, issue trackers, or external systems. Do not create a checkpoint file. The response marker is the only persisted checkpoint and is intended to survive session cloning and compaction.
