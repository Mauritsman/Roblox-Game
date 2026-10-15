#!/usr/bin/env python3
"""Zet de code uit de repo in de open Studio-place, zonder Rojo-klik.

1. Bouwt build/studio_payload.json (alle scripts volgens de Rojo-sourcemap).
2. Zorgt dat een lokale webserver (alleen 127.0.0.1:34999) dat bestand aanbiedt.
3. Daarna voert Claude tools/studio_sync_apply.luau uit via de Studio MCP (execute_luau, Edit).
   Dat script zet HttpEnabled heel even aan, haalt de code op en zet HttpEnabled terug.

Gebruik: python3 tools/studio_sync.py
"""
import json
import os
import socket
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = 34999
ROOTS = [["ReplicatedStorage", "Shared"], ["ServerScriptService", "Server"],
         ["StarterPlayer", "StarterPlayerScripts", "Client"]]
SCRIPTS = ("Script", "LocalScript", "ModuleScript")


def build_payload():
    env = dict(os.environ)
    env["PATH"] = os.path.expanduser("~/.rokit/bin") + ":" + env.get("PATH", "")
    subprocess.run(["rojo", "sourcemap", "default.project.json", "-o", "sourcemap.json"],
                   cwd=ROOT, env=env, check=True, capture_output=True)
    with open(os.path.join(ROOT, "sourcemap.json")) as f:
        sm = json.load(f)
    items = []

    def walk(node, path, classes):
        for child in node.get("children", []):
            p = path + [child["name"]]
            c = classes + [child["className"]]
            files = [x for x in child.get("filePaths", []) if x.endswith((".luau", ".lua"))]
            if any(p[: len(r)] == r for r in ROOTS):
                source = None
                if files and child["className"] in SCRIPTS:
                    with open(os.path.join(ROOT, files[0])) as fh:
                        source = fh.read()
                items.append({"path": p, "classes": c, "source": source})
            walk(child, p, c)

    walk(sm, [], [])
    out = os.path.join(ROOT, "build", "studio_payload.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        json.dump(items, f)
    return out, len(items)


def ensure_server():
    with socket.socket() as s:
        if s.connect_ex(("127.0.0.1", PORT)) == 0:
            return "draaide al"
    subprocess.Popen([sys.executable, "-m", "http.server", str(PORT), "--bind", "127.0.0.1"],
                     cwd=os.path.join(ROOT, "build"), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    return "gestart"


if __name__ == "__main__":
    path, count = build_payload()
    state = ensure_server()
    print(f"{count} items in {path}; server op 127.0.0.1:{PORT} {state}")
    print("Voer nu tools/studio_sync_apply.luau uit met execute_luau (datamodel Edit).")
