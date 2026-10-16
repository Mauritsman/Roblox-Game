--!nocheck
-- Prints a heist's walk map without Studio: `lune run tests/map/walkmap GoldenWheel [floorY] [radius] [startX startZ]`.
-- Rows = x (north = -X at the top), columns = z (left = -Z), 1 stud per character, using tests/map/MapHarness.
--   "." reached from the spawn (floor 0) or from the cellar door (other floors) by an agent of `radius`
--   "," room for the agent but not reached · " " too tight for the agent · "#" blocked
-- Pryable doors count as pried (except LoudOnly); entrance blockers are removed (all entrances open).
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Harness = require("./MapHarness")

local V = roblox.Vector3
local heistId = process.args[1] or "GoldenWheel"
local floorY = tonumber(process.args[2]) or 0
local radius = tonumber(process.args[3]) or 2.25
local world = Harness.buildHeist(heistId)
local x0, x1, z0, z1 = -56, 67, -60, 48
local pry = {}
for _, p in Harness.tagged(world.level, "Pryable") do
	pry[p] = true
end
local raster = Harness.rasterize(world.level, {
	minX = x0,
	maxX = x1,
	minZ = z0,
	maxZ = z1,
	floorY = floorY,
	skip = function(p)
		if pry[p] and not p:GetAttribute("LoudOnly") then
			return true
		end
		return p:FindFirstAncestor("LockedBlocker") ~= nil
	end,
})
local start = if process.args[4]
	then V.new(tonumber(process.args[4]), floorY, tonumber(process.args[5]))
	elseif floorY == 0 then world.heist.Points.Spawn
	else V.new(-3, floorY, -43)
local reach = Harness.flood(raster, start, radius)
for x = x0, x1 do
	local row = string.format("%4d ", x)
	for z = z0, z1 do
		local p = V.new(x, floorY, z)
		local ch = "#"
		if reach.at(p, 0) then
			ch = "."
		elseif Harness.freeAt(raster, p, radius) then
			ch = ","
		elseif Harness.freeAt(raster, p, 0.01) then
			ch = " "
		end
		row ..= ch
	end
	print(row)
end
