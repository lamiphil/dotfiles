#!/usr/bin/env python3
"""Find the todo list declared for a folder. Prints JSON, exits 1 when none.

Walks up from <dir> (default: cwd) to $HOME. In each folder it reads the first of
AGENTS.md / CLAUDE.md that exists and looks for a `## Todo` section with:

    - **List**: `notes/_todo.md`
    - **Archive**: `notes/_archive.md`
    - **Sections**: <free text for the agent>
    - **Sync**: none | git

The nearest declaration wins. Paths are relative to the declaring folder.

    {"list": "/abs/_todo.md", "archive": "/abs/_archive.md",
     "sync": "git", "sections": "...", "declared_in": "/abs/AGENTS.md"}
"""
import json
import re
import sys
from pathlib import Path

FIELD = re.compile(r"^\s*-\s*\*\*(List|Archive|Sections|Sync)\*\*:\s*(.+?)\s*$")


def declaration(text):
    m = re.search(r"^## Todo\s*$(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not m:
        return None
    fields = {}
    for line in m[1].splitlines():
        f = FIELD.match(line)
        if f:
            fields[f[1].lower()] = f[2]
    return fields


def path(value, base):
    m = re.search(r"`([^`]+)`", value or "")
    return str((base / Path(m[1]).expanduser()).resolve()) if m else None


def resolve(start):
    home = Path.home().resolve()
    d = start.resolve()
    while True:
        for name in ("AGENTS.md", "CLAUDE.md"):
            f = d / name
            if f.exists():
                fields = declaration(f.read_text())
                if fields is not None:
                    lst, arc = path(fields.get("list"), d), path(fields.get("archive"), d)
                    if not lst or not arc:
                        sys.exit(f"Bad ## Todo declaration in {f}: List and Archive need a `path`")
                    sync = re.sub(r"[`*]", "", fields.get("sync", "none")).strip().lower()
                    return {"list": lst, "archive": arc, "sync": sync,
                            "sections": fields.get("sections", ""), "declared_in": str(f)}
                break  # only the first file per folder counts
        if d == home or d.parent == d:
            return None
        d = d.parent


if __name__ == "__main__":
    found = resolve(Path(sys.argv[1] if len(sys.argv) > 1 else "."))
    if not found:
        print(f"No todo list declared for {Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve()}")
        sys.exit(1)
    print(json.dumps(found))
