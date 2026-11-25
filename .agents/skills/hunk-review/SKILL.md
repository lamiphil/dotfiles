---
name: hunk-review
description: Reads and answers the user's notes in a live Hunk diff review session, and steers the Hunk view, through the `hunk session` CLI. Use when the user has a Hunk session running, mentions Hunk or "my comments" on a diff, or asks for a Hunk walkthrough.
---

# Hunk Review

Hunk is a terminal diff viewer. The user reviews in the Hunk window and writes notes with `c`. You control the window through `hunk session *` commands only. Never run `hunk diff`, `hunk show` or other interactive commands yourself. If no session exists, ask the user to open one.

## Command reference

Run `hunk skill show hunk-review` once per session before you use a command you are not sure of. It prints the reference that matches the installed Hunk version. These house rules override it.

## House rules

1. **Select the session by id.** Run `hunk session list --json`, pick the session whose `repoRoot` is the repo in question, and pass its `sessionId` to every command. Do not use `--repo .`: sessions often start outside the repo. If several sessions match, ask the user which one.
2. **Read the user's notes first.** The default task is to answer them:
   ```bash
   hunk session comment list <id> --type user --json
   ```
   - `comment list` without `--type` shows only agent comments.
   - The `comments: N` line in `session list` counts only agent comments.
   - So neither one can tell you that the user has no notes. Use `--type user` (or `--type all` to see threads).
3. **Do not add comments unless asked.** Answer each user note with one reply:
   ```bash
   hunk session comment add <id> --reply-to <noteId> --summary "<answer>" [--rationale "<detail>"] --focus
   ```
   Agent notes start hidden; `--focus` on the first reply turns them on. Write new root comments (`comment add --file`, `comment apply`) only when the user asks for comments, a review or a walkthrough. A bare `/skill:hunk-review` or "look at my comments" is not such a request.
4. **Do not remove the user's notes.** Remove only agent comments you added in this conversation, and only when the user asks.
5. **After you change code**, reload the session (`hunk session reload <id> -- diff` or `-- show <ref>`), then re-read the user notes, because a reload can move them.

## Walkthrough (only when asked)

Navigate before commenting so the user sees the code. Comment only what the user would not spot: intent, risks, follow-ups. Prefer one `comment apply` batch, and keep it short.
