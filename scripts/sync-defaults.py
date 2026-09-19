#!/usr/bin/env python3
"""Generate the README shortcut table and the landing page layout list from
Config.standard, so the defaults are defined once in Swift.

Usage:
    python3 scripts/sync-defaults.py           # rewrite the generated blocks
    python3 scripts/sync-defaults.py --check   # fail if they are out of date
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BINARY = ROOT / "build" / "print-defaults"


def defaults() -> list[dict]:
    """Compiles and runs the Swift printer so Config.swift stays the source."""
    BINARY.parent.mkdir(exist_ok=True)
    sources = sorted((ROOT / "Sources" / "SnapItKit").glob("*.swift"))
    subprocess.run(
        ["swiftc", "-swift-version", "5", "-o", str(BINARY),
         *map(str, sources), str(ROOT / "scripts" / "print-defaults" / "main.swift")],
        check=True, capture_output=True,
    )
    return json.loads(subprocess.run([str(BINARY)], check=True, capture_output=True).stdout)


def replace_block(text: str, start: str, end: str, body: str) -> str:
    head, _, rest = text.partition(start)
    _, _, tail = rest.partition(end)
    if not rest or not tail:
        raise SystemExit(f"marker {start!r} not found")
    return f"{head}{start}\n{body}\n{end}{tail}"


def readme_table(rows: list[dict]) -> str:
    lines = ["| Layout | Shortcut | Region |", "|---|---|---|"]
    for row in rows:
        region = f"{round(row['width'] * 100)}% x {round(row['height'] * 100)}%"
        lines.append(f"| {row['name']} | `{row['display'] or '-'}` | {region} |")
    return "\n".join(lines)


def demo_array(rows: list[dict]) -> str:
    entries = []
    for row in rows:
        entries.append(
            '    { name: "%s", key: "%s", x: %s, y: %s, w: %s, h: %s }'
            % (row["name"], row["display"] or "",
               round(row["x"], 6), round(row["y"], 6),
               round(row["width"], 6), round(row["height"], 6))
        )
    return "  var LAYOUTS = [\n" + ",\n".join(entries) + "\n  ];"


def main() -> None:
    check = "--check" in sys.argv
    rows = defaults()

    targets = [
        (ROOT / "README.md", "<!-- defaults:start -->", "<!-- defaults:end -->", readme_table(rows)),
        (ROOT / "web" / "demo.js", "/* defaults:start */", "/* defaults:end */", demo_array(rows)),
        (ROOT / "web" / "index.html", "<!-- count:start -->", "<!-- count:end -->", str(len(rows))),
    ]

    stale = []
    for path, start, end, body in targets:
        current = path.read_text(encoding="utf-8")
        updated = replace_block(current, start, end, body)
        if updated == current:
            continue
        if check:
            stale.append(path.relative_to(ROOT))
        else:
            path.write_text(updated, encoding="utf-8")
            print(f"updated {path.relative_to(ROOT)}")

    if check and stale:
        joined = ", ".join(str(p) for p in stale)
        raise SystemExit(f"out of date, run make sync-defaults: {joined}")
    print(f"{len(rows)} layouts, {'in sync' if check else 'written'}")


if __name__ == "__main__":
    main()
