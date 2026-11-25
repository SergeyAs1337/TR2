#!/usr/bin/env python3
"""Extract Script, LocalScript and ModuleScript source from a Roblox XML Place (.rbxlx)."""
import argparse
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
# Имена файлов по правилам Rojo: по расширению Rojo понимает класс скрипта
EXTENSIONS = {"Script": ".server.lua", "LocalScript": ".client.lua", "ModuleScript": ".lua"}

def child_items(item):
    """Дочерние объекты: в .rbxlx они лежат прямо внутри <Item> (иногда — в <Children>)."""
    items = list(item.findall("Item"))
    wrapper = item.find("Children")
    if wrapper is not None:
        items += wrapper.findall("Item")
    return items


def prop_text(item, prop_name):
    props = item.find("Properties")
    if props is None:
        return None
    for node in props:
        if node.attrib.get("name") == prop_name:
            return "".join(node.itertext())
    return None

def safe_name(value):
    value = (value or "Unnamed").strip()
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", value)
    value = value.rstrip(". ")
    return value or "Unnamed"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("place", help="Input .rbxlx file")
    parser.add_argument("--output", default="src", help="Output source directory (default: src)")
    args = parser.parse_args()

    source = Path(args.place)
    out = Path(args.output)
    if not source.is_file():
        raise SystemExit(f"File not found: {source}")

    try:
        root = ET.parse(source).getroot()
    except ET.ParseError as exc:
        raise SystemExit(f"Could not parse XML Place. Make sure the file is .rbxlx: {exc}")

    written = []
    counts = {name: 0 for name in sorted(SCRIPT_CLASSES)}

    def walk(item, parents):
        cls = item.attrib.get("class", "Unknown")
        name = safe_name(prop_text(item, "Name") or cls)
        path_parts = parents + [name]

        if cls in SCRIPT_CLASSES:
            code = prop_text(item, "Source")
            if code is None:
                code = ""
            folder = out.joinpath(*[safe_name(x) for x in parents])
            folder.mkdir(parents=True, exist_ok=True)
            ext = EXTENSIONS[cls]
            target = folder / (name + ext)
            if target.exists():
                suffix = 2
                while (folder / f"{name}_{suffix}{ext}").exists():
                    suffix += 1
                target = folder / f"{name}_{suffix}{ext}"
            target.write_text(code, encoding="utf-8")
            counts[cls] += 1
            written.append({
                "class": cls,
                "name": name,
                "path": target.as_posix(),
                "roblox_path": ".".join(path_parts),
            })

        for child in child_items(item):
            walk(child, path_parts)

    for item in root.findall("Item"):
        walk(item, [])

    out.mkdir(parents=True, exist_ok=True)
    manifest = {
        "input": str(source),
        "counts": counts,
        "total": len(written),
        "scripts": written,
        "note": "Scripts are extracted as source files; models, assets, properties and runtime links remain in the original Place file."
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Extracted {len(written)} scripts into {out}")
    for cls, count in counts.items():
        print(f"  {cls}: {count}")
    print(f"Manifest: {out / 'manifest.json'}")

if __name__ == "__main__":
    main()
