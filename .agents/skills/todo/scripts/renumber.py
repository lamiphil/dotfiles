#!/usr/bin/env python3
"""Renumber open todos 1..N in _todo.md and strip numbers from _archive.md. Idempotent."""
import re
from pathlib import Path

DIR = Path.home() / "workspaces/vooban/notes/Customers"
NUM = r"(\d+\s*-\s*)?"


def rewrite(path, fn):
    if not path.exists():
        return
    old = path.read_text()
    new = fn(old.splitlines())
    text = "\n".join(new) + "\n"
    if text != old:
        path.write_text(text)


def todo(lines):
    n = 0
    out = []
    for line in lines:
        if line.startswith("- [ ] "):
            n += 1
            line = re.sub(rf"^- \[ \] {NUM}", f"- [ ] {n} - ", line)
        out.append(line)
    return out


def archive(lines):
    return [re.sub(rf"^- \[x\] {NUM}", "- [x] ", l) for l in lines]


rewrite(DIR / "_todo.md", todo)
rewrite(DIR / "_archive.md", archive)
