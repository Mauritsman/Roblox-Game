--!nocheck
-- Geometry checks on mock parts (tests/map/MockRoblox): line of sight for signs and clear walking lanes.
-- Blocks, balls, cylinders and mesh parts count as their box (conservative); a WedgePart is box + slope.

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local Geometry = {}

-- Planes {n, c} (n·p ≤ c inside) in the part's local space.
local function planes(part)
	local h = part.Size / 2
	local list = {
		{ Vector3.new(1, 0, 0), h.X },
		{ Vector3.new(-1, 0, 0), h.X },
		{ Vector3.new(0, 1, 0), h.Y },
		{ Vector3.new(0, -1, 0), h.Y },
		{ Vector3.new(0, 0, 1), h.Z },
		{ Vector3.new(0, 0, -1), h.Z },
	}
	if part.ClassName == "WedgePart" then
		-- Solid below the slope from the bottom-front edge (y −h, z −h) to the top-back edge (y +h, z +h).
		table.insert(list, { Vector3.new(0, 1 / h.Y, -1 / h.Z), 0 })
	end
	return list
end

-- Where the segment a→b first enters the part (t in 0..1), or nil.
function Geometry.segmentHit(a, b, part)
	local la = part.CFrame:PointToObjectSpace(a)
	local lb = part.CFrame:PointToObjectSpace(b)
	local d = lb - la
	local t0, t1 = 0, 1
	for _, plane in planes(part) do
		local n, c = plane[1], plane[2]
		local start = n:Dot(la)
		local speed = n:Dot(d)
		if math.abs(speed) < 1e-9 then
			if start > c then
				return nil
			end
		else
			local t = (c - start) / speed
			if speed > 0 then
				t1 = math.min(t1, t)
			else
				t0 = math.max(t0, t)
			end
			if t0 > t1 then
				return nil
			end
		end
	end
	return t0
end

function Geometry.pointInside(p, part, margin)
	local lp = part.CFrame:PointToObjectSpace(p)
	for _, plane in planes(part) do
		if plane[1]:Dot(lp) > plane[2] - (margin or 0) * plane[1].Magnitude then
			return false
		end
	end
	return true
end

local function radius(part)
	return (part.Size / 2).Magnitude
end

-- Visible blockers: parts players cannot see through.
function Geometry.visibleParts(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.5 then
			table.insert(out, d)
		end
	end
	return out
end

-- Solid parts a character bumps into.
function Geometry.solidParts(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			table.insert(out, d)
		end
	end
	return out
end

-- Line-of-sight test for a Builder.sign board (beta-spec-maps §2): rays from its ViewFrom attribute to the 4
-- corners (inset 5%) and the centre of its front face must reach the board. Returns a list of problems.
function Geometry.signProblems(board, blockers)
	local problems = {}
	local from = board:GetAttribute("ViewFrom")
	if typeof(from) ~= "Vector3" then
		return { "no ViewFrom attribute" }
	end
	local h = board.Size / 2
	local targets = { Vector3.new(0, 0, -h.Z - 0.01) }
	for _, sx in { -0.9, 0.9 } do
		for _, sy in { -0.9, 0.9 } do
			table.insert(targets, Vector3.new(h.X * sx, h.Y * sy, -h.Z - 0.01))
		end
	end
	-- The viewer must be in front of the board.
	if board.CFrame:PointToObjectSpace(from).Z > -h.Z then
		table.insert(problems, "ViewFrom is behind the board")
	end
	for _, localTarget in targets do
		local target = board.CFrame * localTarget
		local mid = (from + target) / 2
		local len = (target - from).Magnitude
		for _, part in blockers do
			if
				part ~= board
				and part.Name ~= "SignFrame"
				and (part.Position - mid).Magnitude <= len / 2 + radius(part)
			then
				local t = Geometry.segmentHit(from, target, part)
				if t and t < 0.995 then
					table.insert(
						problems,
						string.format("view to %s blocked by %s", tostring(localTarget), part.Name)
					)
					break
				end
			end
		end
	end
	return problems
end

-- A walking lane along a polyline (world points at floor height): samples points across `width` and between
-- heights 0.6 and `height` above the floor; returns the names of solid parts found inside (empty = clear).
function Geometry.laneBlockers(points, width, height, solids, ignore)
	local hits = {}
	local seen = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = flat.Magnitude
		local dir = flat.Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local steps = math.max(1, math.ceil(len / 0.75))
		local candidates = {}
		local mid = (a + b) / 2
		for _, part in solids do
			if
				not (ignore and ignore[part])
				and (part.Position - mid).Magnitude <= len / 2 + width + height + radius(part)
			then
				table.insert(candidates, part)
			end
		end
		for s = 0, steps do
			local base = a + (b - a) * (s / steps)
			for w = -width / 2 + 0.1, width / 2 - 0.1 + 1e-6, (width - 0.2) / 6 do
				for y = 0.6, height, 0.9 do
					local p = base + side * w + Vector3.new(0, y, 0)
					for _, part in candidates do
						if not seen[part] and Geometry.pointInside(p, part, 0.02) then
							seen[part] = true
							table.insert(
								hits,
								string.format("%s at %s", part:GetFullName(), tostring(part.Position))
							)
						end
					end
				end
			end
		end
	end
	return hits
end

return Geometry
