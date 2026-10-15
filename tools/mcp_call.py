#!/usr/bin/env python3
"""Minimal MCP stdio client, used to talk to Roblox Studio's built-in MCP server
(and other stdio MCP servers) from the terminal, without restarting Claude Code.

Usage:
  python3 tools/mcp_call.py list
  python3 tools/mcp_call.py call <tool_name> '<json arguments>'
  python3 tools/mcp_call.py --server "<command ...>" list

Default server: Roblox Studio's StudioMCP binary.
"""
import json
import os
import shlex
import subprocess
import sys
import threading
import queue

DEFAULT_SERVER = "/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP"
PROTOCOL = "2025-06-18"


class Client:
    def __init__(self, cmd, timeout):
        self.timeout = timeout
        self.proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self.q = queue.Queue()
        self.next_id = 1
        threading.Thread(target=self._reader, daemon=True).start()
        threading.Thread(target=self._stderr, daemon=True).start()
        self.stderr_lines = []

    def _reader(self):
        for line in self.proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                self.q.put(json.loads(line))
            except json.JSONDecodeError:
                pass

    def _stderr(self):
        for line in self.proc.stderr:
            self.stderr_lines.append(line.rstrip())

    def send(self, msg):
        self.proc.stdin.write(json.dumps(msg) + "\n")
        self.proc.stdin.flush()

    def request(self, method, params=None):
        rid = self.next_id
        self.next_id += 1
        msg = {"jsonrpc": "2.0", "id": rid, "method": method}
        if params is not None:
            msg["params"] = params
        self.send(msg)
        while True:
            try:
                resp = self.q.get(timeout=self.timeout)
            except queue.Empty:
                raise TimeoutError(f"timeout waiting for {method}; stderr: {self.stderr_lines[-5:]}")
            if resp.get("id") == rid:
                return resp
            # ignore notifications / other messages

    def initialize(self):
        r = self.request(
            "initialize",
            {
                "protocolVersion": PROTOCOL,
                "capabilities": {},
                "clientInfo": {"name": "roblox-game-cli", "version": "0.1"},
            },
        )
        self.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
        return r

    def close(self):
        try:
            self.proc.stdin.close()
            self.proc.terminate()
        except Exception:
            pass


def main():
    args = sys.argv[1:]
    server = DEFAULT_SERVER
    timeout = float(os.environ.get("MCP_TIMEOUT", "120"))
    if args and args[0] == "--server":
        server = args[1]
        args = args[2:]
    cmd = shlex.split(server)
    c = Client(cmd, timeout)
    try:
        init = c.initialize()
        if "error" in init:
            print(json.dumps(init, indent=2))
            sys.exit(1)
        if not args or args[0] == "list":
            r = c.request("tools/list", {})
            tools = r.get("result", {}).get("tools", [])
            for t in tools:
                desc = (t.get("description") or "").split("\n")[0][:110]
                print(f"{t['name']}: {desc}")
            if not tools:
                print(json.dumps(r, indent=2))
        elif args[0] == "schema":
            r = c.request("tools/list", {})
            for t in r.get("result", {}).get("tools", []):
                if t["name"] == args[1]:
                    print(json.dumps(t, indent=2))
        elif args[0] == "call":
            name = args[1]
            arguments = json.loads(args[2]) if len(args) > 2 else {}
            r = c.request("tools/call", {"name": name, "arguments": arguments})
            res = r.get("result")
            if res is None:
                print(json.dumps(r, indent=2))
                sys.exit(1)
            for item in res.get("content", []):
                if item.get("type") == "text":
                    print(item["text"])
                elif item.get("type") == "image":
                    out = os.environ.get("MCP_IMAGE_OUT", "/tmp/mcp_image.png")
                    import base64
                    with open(out, "wb") as f:
                        f.write(base64.b64decode(item["data"]))
                    print(f"[image saved to {out}]")
                else:
                    print(json.dumps(item)[:2000])
            if res.get("isError"):
                sys.exit(2)
    finally:
        c.close()


if __name__ == "__main__":
    main()
