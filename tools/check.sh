#!/bin/sh
# Checks all Luau code: typecheck (luau-lsp), lint (selene), formatting (stylua) and unit tests (Lune).
# Usage: sh tools/check.sh   (from the project folder)
set -e
export PATH="$HOME/.rokit/bin:$PATH"
cd "$(dirname "$0")/.."
if [ ! -f tools/defs/globalTypes.d.luau ]; then
	mkdir -p tools/defs
	curl -sSfL -o tools/defs/globalTypes.d.luau \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
rojo sourcemap default.project.json -o sourcemap.json >/dev/null
echo "== typecheck"
luau-lsp analyze --platform roblox --sourcemap sourcemap.json \
	--definitions @roblox=tools/defs/globalTypes.d.luau src
echo "== lint"
selene src
echo "== formatting"
stylua --check src tests
echo "== unit tests"
lune run tests/run
echo "All good."
