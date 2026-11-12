"""Reads and writes art/painted/painted.json, the list of painted art the game
uses. Every entry is optional: when one is missing the game falls back to what
it draws itself, so art can be added one picture at a time."""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
PAINTED = ROOT / "art" / "painted"
SOURCES = ROOT / "art_src"
PREVIEW = pathlib.Path(__file__).resolve().parent / "_preview"
PATH = PAINTED / "painted.json"

# Size of the source painting every coordinate in the manifest refers to.
SOURCE_SIZE = (1124, 1998)
# Where the mock-up sits inside a 1220x2712 gallery screenshot.
MOCKUP_BOX = (48, 349, 1172, 2347)

SECTIONS = ("rooms", "bodies", "expressions", "poses", "stages", "bulbs")


def load():
    data = json.loads(PATH.read_text()) if PATH.exists() else {}
    data.setdefault("source_size", list(SOURCE_SIZE))
    for section in SECTIONS:
        data.setdefault(section, {})
    # Bulbs are stored per room picture; drop the old per-archetype lists.
    data["bulbs"] = {k: v for k, v in data["bulbs"].items() if "." in k}
    return data


def save(data):
    text = json.dumps(data, indent="\t", ensure_ascii=False)
    # Keep short number lists such as [x, y] and boxes on one line.
    text = re.sub(r"\[\s+(-?\d+(?:,\s+-?\d+)*)\s+\]", lambda m: "[" + re.sub(r"\s+", " ", m.group(1)) + "]", text)
    PATH.write_text(text + "\n")


def preview_dir():
    PREVIEW.mkdir(exist_ok=True)
    return PREVIEW
