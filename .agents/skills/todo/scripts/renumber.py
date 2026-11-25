#!/usr/bin/env python3
"""Format _todo.md and _archive.md. Idempotent.

_todo.md: `## ` customer sections; inside a section, `### ` main-task headings group
subtasks. Every other non-blank line is an open item. Each block (a section's standalone
items, or one main task) is sorted by status (!! → ! → none → X, stable); standalone items
come before main tasks, whose order is kept. Items are numbered 1..N across the file and
aligned: status right-aligned to 2 chars, number right-aligned to the widest.

    ## Client B
    !!  1: Fix the prod DNS
        2: Explore KEDA autoscaling

    ### CORP-129: Prod environment
     !  3: Create prod tfvars
     X 10: Apply prod (waiting on: prod subscription)

Accepts the old `- [ ] N - text` shape too. _archive.md: strips numbers from `- [x]` lines.

Usage: renumber.py <list> <archive>  (paths from resolve.py)
"""
import re
import sys
from pathlib import Path
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
    # sections: [heading, standalone items, [[subheading, items], ...]]
    head, sections = [], []
    for line in lines:
        if line.startswith("## "):
            sections.append([line, [], []])
        elif not line.strip():
            continue
        elif not sections:
            head.append(line)
        elif line.startswith("### "):
            sections[-1][2].append([line, []])
        else:
            m = ITEM.match(line)
            item = (m["st"] or "", m["text"])
            groups = sections[-1][2]
            (groups[-1][1] if groups else sections[-1][1]).append(item)

    blocks = [items for _, items, groups in sections for items in [items] + [g[1] for g in groups]]
    for items in blocks:
        items.sort(key=lambda it: RANK[it[0]])
    w = len(str(sum(len(b) for b in blocks)))

    out, n = head + ([""] if head else []), 0

    def emit(items):
        nonlocal n
        for st, text in items:
            n += 1
            out.append(f"{st:>2} {n:>{w}}: {text}")

    for heading, items, groups in sections:
        out.append(heading)
        emit(items)
        for sub, sub_items in groups:
            out += ["", sub]
            emit(sub_items)
        out.append("")
    return out


def archive(lines):
    return [re.sub(r"^- \[x\] (\d+\s*-\s*)?", "- [x] ", l) for l in lines]


if len(sys.argv) != 3:
    sys.exit("usage: renumber.py <list> <archive>")
rewrite(Path(sys.argv[1]), todo)
rewrite(Path(sys.argv[2]), archive)
