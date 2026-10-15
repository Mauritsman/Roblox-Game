--!nocheck
-- Mini test runner for pure logic (Lune). Usage: `lune run tests/run` (or via tools/check.sh).
-- Finds all files tests/**/*.spec.luau. A spec returns a function that receives `t`:
--   return function(t) t.test("name", function() t.eq(1 + 1, 2) end) end
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
			string.format("%sexpected %s, got %s", msg and (msg .. ": ") or "", fmt(expected), fmt(actual)),
			2
		)
	end
end
function t.near(actual, expected, eps, msg)
	if math.abs(actual - expected) > (eps or 1e-6) then
		error(
			string.format(
				"%sexpected ~%s, got %s",
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
		error(msg or "condition not true", 2)
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
			local spec = require("./" .. string.sub(path, 7, -6)) -- path relative to tests/
			spec(t)
		end
	end
end

walk("tests")
print(string.format("Tests: %d passed, %d failed", passed, failed))
for _, f in failures do
	print("  ✗ " .. f)
end
process.exit(if failed > 0 then 1 else 0)
