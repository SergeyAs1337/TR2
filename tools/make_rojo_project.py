#!/usr/bin/env python3
"""Собирает default.project.json для Rojo так, чтобы синхронизация не сломала карту.

Почему не «просто подключить src/»:
  * если Rojo считает, что объект другого класса (магазин — Part, а Rojo думает Folder),
    он УДАЛЯЕТ объект и создаёт пустой. Поэтому классы всех родителей скрипта берутся
    из файла места (.rbxlx), а не угадываются;
  * Rojo удаляет «лишние» объекты в синхронизируемых папках. Здесь у каждого узла стоит
    $ignoreUnknownInstances = true: модели, детали, звуки и другие скрипты не трогаются;
  * по умолчанию синхронизируются только скрипты, ИЗМЕНЁННЫЕ или ДОБАВЛЕННЫЕ в репозитории
    после выгрузки из Studio. Остальные в репозитории могут быть старше, чем в Studio;
  * если скрипт с тем же именем у одного родителя встречается дважды, Rojo не может понять,
    какой из них обновлять: такие скрипты пропускаются.

Запуск из корня репозитория:
  python3 tools/make_rojo_project.py                     # без файла места: только скрипты прямо в сервисах
  python3 tools/make_rojo_project.py --place TR2.rbxlx   # все изменённые скрипты, классы из места
  python3 tools/make_rojo_project.py --place TR2.rbxlx --all   # вообще все скрипты из src/

Файл места: в Studio File -> Save to File As... -> .rbxlx (свежая копия перед синхронизацией).
"""
import argparse
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Коммит, в котором скрипты были выгружены из Studio: с ним сравниваем «изменён ли скрипт»
EXTRACT_COMMIT = "5c9498e"

SUFFIX_CLASS = [(".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")]
SERVICES = {
    "Workspace", "ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage",
    "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService", "Teams", "Chat",
    "TextChatService",
}
# Классы, которые известны без файла места
KNOWN = {("StarterPlayer", "StarterPlayerScripts"): "StarterPlayerScripts",
         ("StarterPlayer", "StarterCharacterScripts"): "StarterCharacterScripts"}


def safe_name(value):  # как в extract_rbxlx.py
    value = (value or "Unnamed").strip()
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", value)
    value = value.rstrip(". ")
    return value or "Unnamed"


def script_class(path):
    for suffix, cls in SUFFIX_CLASS:
        if path.name.endswith(suffix):
            return cls, path.name[: -len(suffix)]
    return None, None


def git(*args):
    try:
        return subprocess.run(["git", *args], capture_output=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError):
        return None


def original_source(rel_dir, stem):
    """Текст скрипта на момент выгрузки (тогда файлы были просто .lua) или None."""
    old = (Path("src") / rel_dir / (stem + ".lua")).as_posix()
    data = git("show", f"{EXTRACT_COMMIT}:{old}")
    return None if data is None else data.decode("utf-8", errors="replace")


def child_items(item):
    """Дочерние объекты: в .rbxlx они лежат прямо внутри <Item> (иногда — в <Children>)."""
    items = list(item.findall("Item"))
    wrapper = item.find("Children")
    if wrapper is not None:
        items += wrapper.findall("Item")
    return items


def prop_text(item, name):
    props = item.find("Properties")
    if props is None:
        return None
    for node in props:
        if node.attrib.get("name") == name:
            return "".join(node.itertext())
    return None


def index_place(place_path):
    """(безопасные имена пути) -> список (настоящее имя, класс, исходник)."""
    root = ET.parse(place_path).getroot()
    index = {}

    def walk(item, parents):
        cls = item.attrib.get("class", "Unknown")
        name = prop_text(item, "Name") or cls
        key = parents + (safe_name(name),)
        source = prop_text(item, "Source") if cls in ("Script", "LocalScript", "ModuleScript") else None
        index.setdefault(key, []).append((name, cls, source))
        for child in child_items(item):
            walk(child, key)

    for item in root.findall("Item"):
        walk(item, ())
    return index


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--place", help="свежая копия места в формате .rbxlx")
    parser.add_argument("--all", action="store_true", help="синхронизировать все скрипты, а не только изменённые")
    parser.add_argument("--force", action="store_true", help="включать скрипты, которые в Studio менялись после выгрузки")
    parser.add_argument("--out", default="default.project.json")
    args = parser.parse_args()

    src = Path("src")
    if not src.is_dir():
        sys.exit("Запускай из корня репозитория (нужна папка src/)")

    manifest = {}
    manifest_path = src / "manifest.json"
    if manifest_path.exists():
        for entry in json.loads(manifest_path.read_text(encoding="utf-8")).get("scripts", []):
            manifest[entry["path"]] = entry

    place = index_place(args.place) if args.place else None
    have_git = git("cat-file", "-e", EXTRACT_COMMIT) is not None
    if not args.all and not have_git:
        print("! git или коммит выгрузки недоступен: беру все скрипты (как с --all)")
        args.all = True

    tree = {"$className": "DataModel"}
    included, skipped = [], []

    for path in sorted(src.rglob("*.lua")):
        cls, stem = script_class(path)
        rel = path.relative_to(src)
        parts = list(rel.parent.parts)
        entry = manifest.get(path.as_posix())
        real_name = entry["name"] if entry else stem
        label = "/".join(parts + [real_name])

        current = path.read_text(encoding="utf-8")
        original = original_source(rel.parent, stem) if have_git else None
        changed = original is None or original != current
        if not args.all and not changed:
            continue  # не меняли: в Studio может быть более новая версия

        if entry and real_name != stem:
            skipped.append((label, "у родителя два скрипта с таким именем — Rojo не различит, обнови вручную"))
            continue
        if not parts or parts[0] not in SERVICES:
            skipped.append((label, "не в сервисе Roblox"))
            continue

        # Классы и настоящие имена родителей
        chain = []  # [(имя, класс)]
        ok = True
        for depth in range(len(parts)):
            key = tuple(parts[: depth + 1])
            if depth == 0:
                chain.append((parts[0], parts[0]))
                continue
            if key[:2] in KNOWN and depth == 1:
                chain.append((parts[1], KNOWN[key[:2]]))
                continue
            if place is None:
                ok = False
                skipped.append((label, "родитель не сервис: нужен --place с файлом .rbxlx"))
                break
            found = place.get(key)
            if not found:
                ok = False
                skipped.append((label, f"в месте нет «{'/'.join(key)}»"))
                break
            if len(found) > 1:
                ok = False
                skipped.append((label, f"в месте несколько объектов «{'/'.join(key)}»"))
                break
            chain.append((found[0][0], found[0][1]))
        if not ok:
            continue

        if place is not None:
            existing = place.get(tuple(parts) + (safe_name(real_name),))
            if existing and len(existing) > 1:
                skipped.append((label, "в месте два скрипта с таким именем"))
                continue
            if existing and original is not None and not args.force:
                studio_source = existing[0][2] or ""
                if studio_source.strip() != original.strip() and studio_source.strip() != current.strip():
                    skipped.append((label, "в Studio его меняли после выгрузки — сравни вручную или запусти с --force"))
                    continue
            if existing and existing[0][1] != cls:
                print(f"! {label}: в месте это {existing[0][1]}, в репозитории {cls} — Rojo заменит скрипт")

        node = tree
        for name, klass in chain:
            child = node.get(name)
            if child is None:
                child = {"$className": klass, "$ignoreUnknownInstances": True}
                node[name] = child
            node = child
        if real_name in node:
            skipped.append((label, "имя уже занято в проекте"))
            continue
        node[real_name] = {"$path": path.as_posix()}
        included.append(label)

    project = {"name": "TR2", "tree": tree}
    Path(args.out).write_text(json.dumps(project, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Записан {args.out}: {len(included)} скриптов для синхронизации")
    for label in included:
        print(f"  + {label}")
    if skipped:
        print(f"Пропущено {len(skipped)}:")
        for label, why in skipped:
            print(f"  - {label}: {why}")


if __name__ == "__main__":
    main()
