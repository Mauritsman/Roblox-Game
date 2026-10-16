--!nocheck
-- Prints a heist's budgets and markers without Studio: `lune run tests/map/report GoldenWheel`.
local process = require("@lune/process")

local Harness = require("./MapHarness")

local heistId = process.args[1] or "GoldenWheel"
local world = Harness.buildHeist(heistId, { allowMathRandom = process.args[2] == "--loose" })
local level = world.level

local parts, lights, shadows = 0, 0, 0
local byFolder = {}
for _, d in level:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		local top = d
		while top.Parent and top.Parent ~= level do
			top = top.Parent
		end
		byFolder[top.Name] = (byFolder[top.Name] or 0) + 1
	elseif d:IsA("Light") then
		lights += 1
		if d.Shadows then
			shadows += 1
		end
	end
end
print(string.format("%s: %d parts, %d lights (%d with shadows)", heistId, parts, lights, shadows))
local names = {}
for name in byFolder do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	print(string.format("  %-14s %5d parts", name, byFolder[name]))
end

local classes = {}
for _, anchor in Harness.tagged(level, "LootAnchor") do
	local key = anchor:GetAttribute("AnchorClass")
		.. (if anchor:GetAttribute("Group") then "/" .. anchor:GetAttribute("Group") else "")
	classes[key] = (classes[key] or 0) + 1
end
local keys = {}
for key in classes do
	table.insert(keys, key)
end
table.sort(keys)
for _, key in keys do
	print(string.format("  LootAnchor %-18s %d", key, classes[key]))
end
for _, tag in
	{
		"HideSpot",
		"Entrance",
		"Exit",
		"BankZone",
		"CellSpot",
		"HazardAnchor",
		"SecurityCamera",
		"Lamp",
		"StaffZone",
		"SecureZone",
		"Ride",
		"Pryable",
		"SeeThrough",
	}
do
	print(string.format("  %-14s %d", tag, #Harness.tagged(level, tag)))
end
for _, w in world.warnings do
	print("  warn: " .. w)
end
