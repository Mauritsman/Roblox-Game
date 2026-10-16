#!/usr/bin/env python3
"""Puts the code from the repo into the open Studio place, without a Rojo click.

1. Builds build/studio_payload.json (all scripts according to the Rojo sourcemap).
2. Makes sure a local web server (127.0.0.1:34999 only) serves that file.
3. Then Claude runs tools/studio_sync_apply.luau via the Studio MCP (execute_luau, Edit).
   That script turns HttpEnabled on very briefly, fetches the code and sets HttpEnabled back.

Usage: python3 tools/studio_sync.py
"""
import json
import os
import socket
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = 34999
ROOTS = [["ReplicatedStorage", "Shared"], ["ServerScriptService", "Server"],
         ["StarterPlayer", "StarterPlayerScripts", "Client"], ["ReplicatedFirst"]]
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
            return "was already running"
    subprocess.Popen([sys.executable, "-m", "http.server", str(PORT), "--bind", "127.0.0.1"],
                     cwd=os.path.join(ROOT, "build"), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
    return "started"


if __name__ == "__main__":
    path, count = build_payload()
    state = ensure_server()
    print(f"{count} items in {path}; server on 127.0.0.1:{PORT} {state}")
    print("Now run tools/studio_sync_apply.luau with execute_luau (datamodel Edit).")
