"""Keeps the Roblox place file and the src/ script tree in sync.

The place holds only services, folders and scripts (the stadium is built at runtime), so src/
is the source of truth and the .rbxlx is generated from it. Layout follows Rojo conventions:
  Folder/           -> Folder (service names map to their service class)
  Name.lua          -> ModuleScript
  Name.server.lua   -> Script
  Name.client.lua   -> LocalScript
  Name/init*.lua    -> the script itself, with the folder's other entries as its children

Usage:
  python3 tools/place.py export <place.rbxlx>   # place -> src/ (overwrites src/)
  python3 tools/place.py build [<place.rbxlx>]  # src/ -> place (default place/NewFootballStar.rbxlx)
  python3 tools/place.py sourcemap              # src/ -> sourcemap.json for luau-lsp
"""

import json
import os
import shutil
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
DEFAULT_PLACE = os.path.join(ROOT, "place", "NewFootballStar.rbxlx")

SERVICE_CLASSES = {
    "ReplicatedStorage": "ReplicatedStorage",
    "ServerScriptService": "ServerScriptService",
    "StarterPlayer": "StarterPlayer",
    "StarterPlayerScripts": "StarterPlayerScripts",
}
SUFFIX_CLASSES = [(".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")]
CLASS_SUFFIX = {"Script": ".server.lua", "LocalScript": ".client.lua", "ModuleScript": ".lua"}
SCRIPT_CLASSES = set(CLASS_SUFFIX)


def split_script(filename):
    for suffix, cls in SUFFIX_CLASSES:
        if filename.endswith(suffix):
            return filename[: -len(suffix)], cls
    return None, None


# ---------------------------------------------------------------- src tree -> nodes

def read_dir(path, name):
    """Returns a node {name, class, source, file, children} for a folder in src/."""
    node = {"name": name, "class": SERVICE_CLASSES.get(name, "Folder"), "source": None, "file": None, "children": []}
    entries = sorted(os.listdir(path))
    for entry in entries:
        full = os.path.join(path, entry)
        if os.path.isfile(full) and entry.startswith("init"):
            _, cls = split_script(entry)
            if cls:
                node["class"] = cls
                node["file"] = full
                with open(full, encoding="utf-8") as f:
                    node["source"] = f.read()
    for entry in entries:
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            node["children"].append(read_dir(full, entry))
        elif not entry.startswith("init"):
            child_name, cls = split_script(entry)
            if cls:
                with open(full, encoding="utf-8") as f:
                    node["children"].append({"name": child_name, "class": cls, "source": f.read(), "file": full, "children": []})
    return node


def read_src():
    return [read_dir(os.path.join(SRC, d), d) for d in sorted(os.listdir(SRC)) if os.path.isdir(os.path.join(SRC, d))]


# ---------------------------------------------------------------- nodes -> rbxlx

def write_place(nodes, out_path):
    lines = ['<roblox version="4">']
    counter = [0]

    def emit(node, depth):
        pad = "  " * depth
        lines.append(f'{pad}<Item class="{node["class"]}" referent="{counter[0]}">')
        counter[0] += 1
        lines.append(f"{pad}  <Properties>")
        lines.append(f'{pad}    <string name="Name">{escape(node["name"])}</string>')
        if node["class"] == "Script":
            lines.append(f'{pad}    <token name="RunContext">0</token>')
        if node["class"] in SCRIPT_CLASSES:
            source = node["source"] or ""
            if "]]>" in source:
                raise SystemExit(f"{node['file']}: ']]>' cannot be stored in CDATA")
            lines.append(f'{pad}    <string name="Source"><![CDATA[{source}]]></string>')
        lines.append(f"{pad}  </Properties>")
        for child in node["children"]:
            emit(child, depth + 1)
        lines.append(f"{pad}</Item>")

    for node in nodes:
        emit(node, 1)
    lines.append("</roblox>")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    ET.parse(out_path)  # must stay well-formed


# ---------------------------------------------------------------- rbxlx -> src tree

def export(place_path):
    tree = ET.parse(place_path)

    def prop(item, key):
        props = item.find("Properties")
        for c in props if props is not None else []:
            if c.get("name") == key:
                return c.text or ""
        return None

    def write_item(item, folder):
        cls = item.get("class")
        name = prop(item, "Name")
        children = item.findall("Item")
        if cls in SCRIPT_CLASSES:
            source = prop(item, "Source") or ""
            if children:
                path = os.path.join(folder, name)
                os.makedirs(path, exist_ok=True)
                target = os.path.join(path, "init" + CLASS_SUFFIX[cls])
                for child in children:
                    write_item(child, path)
            else:
                target = os.path.join(folder, name + CLASS_SUFFIX[cls])
            with open(target, "w", encoding="utf-8", newline="\n") as f:
                f.write(source)
        elif cls == "Folder" or cls in SERVICE_CLASSES.values():
            path = os.path.join(folder, name)
            os.makedirs(path, exist_ok=True)
            for child in children:
                write_item(child, path)
        else:
            raise SystemExit(f"unsupported class {cls} ({name}); extend tools/place.py")

    if os.path.isdir(SRC):
        shutil.rmtree(SRC)
    os.makedirs(SRC)
    for item in tree.getroot().findall("Item"):
        write_item(item, SRC)


# ---------------------------------------------------------------- sourcemap for luau-lsp

def sourcemap(nodes):
    def convert(node):
        out = {"name": node["name"], "className": node["class"]}
        if node["file"]:
            out["filePaths"] = [os.path.relpath(node["file"], ROOT)]
        if node["children"]:
            out["children"] = [convert(c) for c in node["children"]]
        return out

    data = {"name": "Game", "className": "DataModel", "children": [convert(n) for n in nodes]}
    with open(os.path.join(ROOT, "sourcemap.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    cmd = sys.argv[1]
    if cmd == "export":
        export(sys.argv[2])
    elif cmd == "build":
        out = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_PLACE
        write_place(read_src(), out)
        print("wrote", os.path.relpath(out, ROOT))
    elif cmd == "sourcemap":
        sourcemap(read_src())
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
