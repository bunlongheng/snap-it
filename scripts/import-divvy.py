#!/usr/bin/env python3
"""Import Divvy's saved shortcuts into a Snap It config.

Divvy keeps its shortcuts as an NSKeyedArchiver blob inside its preference
file. This reads that blob, converts each entry into a Snap It layout, and
writes config.json.

Usage:
    python3 scripts/import-divvy.py            # write the real config
    python3 scripts/import-divvy.py --dry-run  # print it instead
"""

from __future__ import annotations

import argparse
import json
import os
import plistlib
import sys

DIVVY_PLISTS = (
    "~/Library/Preferences/com.mizage.direct.Divvy.plist",
    "~/Library/Preferences/com.mizage.Divvy.plist",
)
CONFIG = "~/Library/Application Support/SnapIt/config.json"

# Cocoa modifier flag bits. The remaining bits (function, numeric pad) describe
# the key itself rather than a modifier, so they are ignored.
MODIFIERS = ((1 << 20, "cmd"), (1 << 18, "ctrl"), (1 << 19, "alt"), (1 << 17, "shift"))

# Virtual key codes Divvy can store, named the way Snap It writes them.
KEY_NAMES = {
    0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
    11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1", 19: "2",
    20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
    29: "0", 30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "return",
    37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "n",
    46: "m", 47: ".", 48: "tab", 49: "space", 50: "`", 51: "delete", 53: "escape",
    96: "f5", 97: "f6", 98: "f7", 99: "f3", 100: "f8", 101: "f9", 103: "f11",
    109: "f10", 111: "f12", 115: "home", 116: "pageup", 117: "forwarddelete",
    118: "f4", 119: "end", 120: "f2", 121: "pagedown", 122: "f1",
    123: "left", 124: "right", 125: "down", 126: "up",
}


def find_plist() -> str:
    for candidate in DIVVY_PLISTS:
        path = os.path.expanduser(candidate)
        if os.path.exists(path):
            return path
    sys.exit("No Divvy preferences found. Is Divvy installed for this user?")


def shortcut_objects(path: str) -> tuple[list[dict], list]:
    """Returns Divvy's shortcut dictionaries and the archive's object table."""
    with open(path, "rb") as handle:
        preferences = plistlib.load(handle)

    blob = preferences.get("shortcuts")
    if not blob:
        sys.exit("Divvy's preferences hold no shortcuts.")

    archive = plistlib.loads(blob)
    objects = archive["$objects"]
    root = objects[archive["$top"]["root"].data]

    entries = []
    for reference in root["NS.objects"]:
        entry = objects[reference.data]
        if isinstance(entry, dict) and "selectionStartColumn" in entry:
            entries.append(entry)
    return entries, objects


def shortcut_string(entry: dict) -> str | None:
    key = KEY_NAMES.get(entry.get("keyComboCode"))
    if key is None:
        return None

    flags = entry.get("keyComboFlags", 0)
    parts = [name for bit, name in MODIFIERS if flags & bit]
    if not any(part in ("cmd", "ctrl", "alt") for part in parts):
        return None
    return "+".join(parts + [key])


def identifier(name: str, taken: set[str]) -> str:
    base = "".join(character if character.isalnum() else "-" for character in name.lower())
    base = "-".join(filter(None, base.split("-"))) or "layout"
    candidate, index = base, 1
    while candidate in taken:
        index += 1
        candidate = f"{base}-{index}"
    taken.add(candidate)
    return candidate


def to_layout(entry: dict, name: str, taken: set[str]) -> dict:
    columns = entry.get("sizeColumns") or 6
    rows = entry.get("sizeRows") or 6
    start_column = entry["selectionStartColumn"]
    start_row = entry["selectionStartRow"]
    width = entry["selectionEndColumn"] - start_column + 1
    height = entry["selectionEndRow"] - start_row + 1

    layout = {
        "id": identifier(name, taken),
        "name": name,
        "frame": {
            "x": round(start_column / columns, 6),
            "y": round(start_row / rows, 6),
            "width": round(width / columns, 6),
            "height": round(height / rows, 6),
        },
    }
    combination = shortcut_string(entry)
    if combination and entry.get("enabled", True):
        layout["shortcut"] = combination
    return layout


def main() -> None:
    parser = argparse.ArgumentParser(description="Import Divvy shortcuts into Snap It.")
    parser.add_argument("--dry-run", action="store_true", help="print the config instead of writing it")
    parser.add_argument("--output", default=CONFIG, help="where to write config.json")
    arguments = parser.parse_args()

    entries, objects = shortcut_objects(find_plist())

    taken: set[str] = set()
    layouts, claimed = [], {}
    for entry in entries:
        name_reference = entry.get("nameKey")
        name = objects[name_reference.data] if name_reference is not None else "Layout"
        layout = to_layout(entry, str(name), taken)

        # Snap It refuses duplicate shortcuts, so the first claim wins and the
        # rest keep their geometry without a shortcut.
        combination = layout.get("shortcut")
        if combination and combination in claimed:
            del layout["shortcut"]
            print(f"note: {name} drops {combination}, already used by {claimed[combination]}")
        elif combination:
            claimed[combination] = name
        layouts.append(layout)

    grid_columns = entries[0].get("sizeColumns", 6) if entries else 6
    grid_rows = entries[0].get("sizeRows", 6) if entries else 6
    config = {
        "gap": 0,
        "grid": {"columns": grid_columns, "rows": grid_rows},
        "layouts": layouts,
    }
    rendered = json.dumps(config, indent=2, sort_keys=True)

    if arguments.dry_run:
        print(rendered)
        return

    destination = os.path.expanduser(arguments.output)
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    if os.path.exists(destination):
        backup = destination + ".backup"
        os.replace(destination, backup)
        print(f"previous config saved to {backup}")
    with open(destination, "w", encoding="utf-8") as handle:
        handle.write(rendered + "\n")
    print(f"imported {len(layouts)} layouts to {destination}")


if __name__ == "__main__":
    main()
