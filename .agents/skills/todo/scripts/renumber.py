#!/usr/bin/env python3
"""Format _todo.md and _archive.md. Idempotent.

_todo.md: every non-blank line under a `## ` heading is an open item. Each section is
sorted by status (!! → ! → none → X, stable), then items are numbered 1..N across the
file and aligned: status right-aligned to 2 chars, number right-aligned to the widest.

    !!  1: Fix the prod DNS
     !  2: Tighten GitLab rules
        3: Explore KEDA autoscaling
     X 10: Prepare prod (waiting on: prod subscription)

Accepts the old `- [ ] N - text` shape too. _archive.md: strips numbers from `- [x]` lines.
"""
import os
import re
from pathlib import Path

DIR = Path(os.environ.get("NOTES_ROOT", str(Path.home() / "notes"))) / "Customers"
RANK = {"!!": 0, "!": 1, "": 2, "X": 3}
ITEM = re.compile(
    r"^\s*(?:- \[ \]\s*)?"  # old checkbox prefix
    r"(?:(?P<st>!!|!|X)\s+)?"  # status
    r"(?:\d+\s*(?::|-)\s+)?"  # old/new number
    r"(?P<text>.+?)\s*$"
)


def rewrite(path, fn):
    if not path.exists():
        return
    old = path.read_text()
    text = "\n".join(fn(old.splitlines())).rstrip("\n") + "\n"
    if text != old:
        path.write_text(text)


def todo(lines):
    head, sections = [], []  # sections: [heading, [(status, text)]]
    for line in lines:
        if line.startswith("## "):
            sections.append([line, []])
        elif not line.strip():
            continue
        elif not sections:
            head.append(line)
        else:
            m = ITEM.match(line)
            sections[-1][1].append((m["st"] or "", m["text"]))
    for s in sections:
        s[1].sort(key=lambda it: RANK[it[0]])
    total = sum(len(items) for _, items in sections)
    w = len(str(total))
    out, n = head + ([""] if head else []), 0
    for heading, items in sections:
        out.append(heading)
        for st, text in items:
            n += 1
            out.append(f"{st:>2} {n:>{w}}: {text}")
        out.append("")
    return out


def archive(lines):
    return [re.sub(r"^- \[x\] (\d+\s*-\s*)?", "- [x] ", l) for l in lines]


rewrite(DIR / "_todo.md", todo)
rewrite(DIR / "_archive.md", archive)
