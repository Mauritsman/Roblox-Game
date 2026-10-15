#!/bin/sh
# Controleert alle Luau-code: typecheck (luau-lsp), lint (selene), opmaak (stylua) en unit-tests (Lune).
# Gebruik: sh tools/check.sh   (vanuit de projectmap)
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
echo "== opmaak"
stylua --check src tests
echo "== unit-tests"
lune run tests/run
echo "Alles in orde."
