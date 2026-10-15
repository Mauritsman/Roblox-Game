#!/usr/bin/env python3
"""Pastes the shared test helpers (lib/prelude.luau) in front of a Studio test scenario.

The output is one piece of Luau that you run with the Studio MCP tool `execute_luau`, in the datamodel named at
the top of the scenario (`-- datamodel: Client`). The scenario returns a text with PASS/FAIL per step and a final
line `RESULT: x/y`.

Usage:
  python3 tools/studio_tests/bundle.py --list          # all scenarios with datamodel and goal
  python3 tools/studio_tests/bundle.py 10_spawn        # bundle on stdout (name may omit .luau)
  python3 tools/studio_tests/bundle.py 10 -o /path.lua # bundle to a file (e.g. in your scratchpad)
  python3 tools/studio_tests/bundle.py 10 --compact    # without comment and blank lines (less to paste)

Nothing is sent to Studio: this script deliberately does not start its own StudioMCP process (see CLAUDE.md).
"""
import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCENARIOS = os.path.join(HERE, "scenarios")
PRELUDE = os.path.join(HERE, "lib", "prelude.luau")
HEADER_KEYS = ("datamodel", "play", "goal")
DATAMODELS = ("Edit", "Server", "Client")


def read_header(path):
    """Reads the header lines `-- key: value` at the top of a scenario."""
    header = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"^--\s*(\w+)\s*:\s*(.+?)\s*$", line)
            if not m:
                break
            header[m.group(1).lower()] = m.group(2)
    return header


def scenario_files():
    return sorted(f for f in os.listdir(SCENARIOS) if f.endswith(".luau"))


def find(name):
    files = scenario_files()
    base = name[:-5] if name.endswith(".luau") else name
    exact = [f for f in files if f[:-5] == base]
    if exact:
        return os.path.join(SCENARIOS, exact[0])
    prefix = [f for f in files if f.startswith(base)]
    if len(prefix) == 1:
        return os.path.join(SCENARIOS, prefix[0])
    raise SystemExit(f"Scenario '{name}' not found (or ambiguous). Choose from: {', '.join(files)}")


def check(path):
    header = read_header(path)
    missing = [k for k in HEADER_KEYS if k not in header]
    if missing:
        raise SystemExit(f"{os.path.basename(path)}: missing header line(s): {', '.join(missing)}")
    if not all(d in DATAMODELS for d in header["datamodel"].split("/")):
        raise SystemExit(f"{os.path.basename(path)}: datamodel must be Edit, Server, Client or e.g. Server/Client")
    return header


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("scenario", nargs="?", help="file name or number prefix, e.g. 10_spawn or 10")
    parser.add_argument("--list", action="store_true", help="list all scenarios")
    parser.add_argument("-o", "--out", help="write the bundle to this file instead of stdout")
    parser.add_argument("--compact", action="store_true", help="drop comment and blank lines")
    args = parser.parse_args()

    if args.list or not args.scenario:
        print(f"{'scenario':<24} {'datamodel':<14} {'play':<5} goal")
        for f in scenario_files():
            h = check(os.path.join(SCENARIOS, f))
            print(f"{f[:-5]:<24} {h['datamodel']:<14} {h['play']:<5} {h['goal']}")
        return

    path = find(args.scenario)
    header = check(path)
    with open(PRELUDE, encoding="utf-8") as fh:
        prelude = fh.read()
    with open(path, encoding="utf-8") as fh:
        body = fh.read()
    bundle = f"-- BUNDLE: {os.path.basename(path)} | datamodel: {header['datamodel']}\n{prelude}\n{body}"
    if args.compact:
        # Only whole comment lines (our files contain no --[[ blocks) and blank lines.
        lines = bundle.splitlines()
        bundle = "\n".join([lines[0]] + [l for l in lines[1:] if l.strip() and not l.lstrip().startswith("--")])
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(bundle)
        print(f"{args.out}: {len(bundle.splitlines())} lines, datamodel {header['datamodel']}", file=sys.stderr)
    else:
        sys.stdout.write(bundle)


if __name__ == "__main__":
    main()
