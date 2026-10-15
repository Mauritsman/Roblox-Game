--!nocheck
-- Mini-testrunner voor pure logica (Lune). Gebruik: `lune run tests/run` (of via tools/check.sh).
-- Zoekt alle bestanden tests/**/*.spec.luau. Een spec geeft een functie terug die `t` krijgt:
--   return function(t) t.test("naam", function() t.eq(1 + 1, 2) end) end
local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0
local failures = {}

local function fmt(v)
	if type(v) == "table" then
		local parts = {}
		for k, x in v do
			table.insert(parts, tostring(k) .. "=" .. tostring(x))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local t = {}
local currentFile = ""
function t.eq(actual, expected, msg)
	if actual ~= expected then
		error(
			string.format("%sverwacht %s, kreeg %s", msg and (msg .. ": ") or "", fmt(expected), fmt(actual)),
			2
		)
	end
end
function t.near(actual, expected, eps, msg)
	if math.abs(actual - expected) > (eps or 1e-6) then
		error(
			string.format(
				"%sverwacht ~%s, kreeg %s",
				msg and (msg .. ": ") or "",
				tostring(expected),
				tostring(actual)
			),
			2
		)
	end
end
function t.ok(cond, msg)
	if not cond then
		error(msg or "voorwaarde niet waar", 2)
	end
end
function t.test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		table.insert(failures, currentFile .. " › " .. name .. ": " .. tostring(err))
	end
end

local function walk(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -10) == ".spec.luau" then
			currentFile = path
			local spec = require("./" .. string.sub(path, 7, -6)) -- pad relatief aan tests/
			spec(t)
		end
	end
end

walk("tests")
print(string.format("Tests: %d geslaagd, %d mislukt", passed, failed))
for _, f in failures do
	print("  ✗ " .. f)
end
process.exit(if failed > 0 then 1 else 0)
