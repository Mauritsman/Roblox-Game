#!/usr/bin/env python3
"""Genereert Luau-code die alle scripts uit de Rojo-sourcemap in de open Studio-place zet.

Waarom: Rojo's live-sync vraagt een klik op "Connect" in Studio. Via de Studio MCP
(execute_luau) kan Claude de code zelf in Studio zetten, zonder klik.

Gebruik:
  python3 tools/gen_studio_sync.py            # schrijft build/studio_sync.luau
  python3 tools/gen_studio_sync.py --print    # print de code

De gegenereerde code:
  * maakt ontbrekende mappen/scripts aan op het juiste pad (volgens default.project.json)
  * zet de Source van elk script
  * verwijdert scripts onder de beheerde containers die niet meer in de repo staan
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
MANAGED_ROOTS = [
    ["ReplicatedStorage", "Shared"],
    ["ServerScriptService", "Server"],
    ["StarterPlayer", "StarterPlayerScripts", "Client"],
]


def sourcemap():
    env = dict(os.environ)
    env["PATH"] = os.path.expanduser("~/.rokit/bin") + ":" + env.get("PATH", "")
    out = os.path.join(ROOT, "sourcemap.json")
    subprocess.run(
        ["rojo", "sourcemap", "default.project.json", "-o", out],
        cwd=ROOT, env=env, check=True, capture_output=True,
    )
    with open(out) as f:
        return json.load(f)


def collect(node, path, entries):
    for child in node.get("children", []):
        child_path = path + [child["name"]]
        cls = child["className"]
        files = [p for p in child.get("filePaths", []) if p.endswith((".luau", ".lua"))]
        entries.append({"path": child_path, "className": cls, "file": files[0] if files else None})
        collect(child, child_path, entries)


def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{text}]{eq}]"


def luau_path(path):
    return "{" + ", ".join(json.dumps(p) for p in path) + "}"


def generate():
    sm = sourcemap()
    entries = []
    collect(sm, [], entries)
    lines = [
        "-- Gegenereerd door tools/gen_studio_sync.py. Niet met de hand aanpassen.",
        "local function resolve(path, classes)",
        "\tlocal current = game",
        "\tfor index, name in path do",
        "\t\tlocal child = current:FindFirstChild(name)",
        "\t\tlocal wanted = classes[index]",
        "\t\tif child and wanted and child.ClassName ~= wanted and index > 1 then",
        "\t\t\tchild:Destroy()",
        "\t\t\tchild = nil",
        "\t\tend",
        "\t\tif not child then",
        "\t\t\tif index == 1 then",
        "\t\t\t\tchild = game:GetService(name)",
        "\t\t\telse",
        "\t\t\t\tchild = Instance.new(wanted or 'Folder')",
        "\t\t\t\tchild.Name = name",
        "\t\t\t\tchild.Parent = current",
        "\t\t\tend",
        "\t\tend",
        "\t\tcurrent = child",
        "\tend",
        "\treturn current",
        "end",
        "local keep = {}",
        "local updated = 0",
    ]
    class_by_path = {tuple(e["path"]): e["className"] for e in entries}
    for e in entries:
        if not any(e["path"][: len(r)] == r for r in MANAGED_ROOTS):
            continue
        classes = [class_by_path.get(tuple(e["path"][: i + 1]), None) for i in range(len(e["path"]))]
        classes_luau = "{" + ", ".join("nil" if c is None else json.dumps(c) for c in classes) + "}"
        if e["className"] in SCRIPT_CLASSES and e["file"]:
            with open(os.path.join(ROOT, e["file"])) as f:
                source = f.read()
            lines.append("do")
            lines.append(f"\tlocal inst = resolve({luau_path(e['path'])}, {classes_luau})")
            lines.append(f"\tlocal src = {long_string(source)}")
            lines.append("\tif inst.Source ~= src then inst.Source = src; updated += 1 end")
            lines.append("\tkeep[inst] = true")
            lines.append("end")
        else:
            lines.append(f"keep[resolve({luau_path(e['path'])}, {classes_luau})] = true")
    roots = ", ".join(luau_path(r) for r in MANAGED_ROOTS)
    lines += [
        f"local removed = 0",
        f"for _, rootPath in {{{roots}}} do",
        "\tlocal root = game",
        "\tfor _, name in rootPath do root = root and root:FindFirstChild(name) end",
        "\tif root then",
        "\t\tfor _, d in root:GetDescendants() do",
        "\t\t\tif d:IsA('LuaSourceContainer') and not keep[d] then d:Destroy(); removed += 1 end",
        "\t\tend",
        "\tend",
        "end",
        "print(`[studio_sync] {updated} bijgewerkt, {removed} verwijderd`)",
        "return `{updated} updated, {removed} removed`",
    ]
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    code = generate()
    if "--print" in sys.argv:
        print(code)
    else:
        out = os.path.join(ROOT, "build", "studio_sync.luau")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w") as f:
            f.write(code)
        print(f"{out} ({len(code)} tekens)")
