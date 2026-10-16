--!nocheck
-- Shared checks for the map specs: budgets, tags, anchor/hide-spot contracts, sign rules and walking lanes.
local roblox = require("@lune/roblox")
local Geometry = require("./Geometry")
local Mock = require("./MockRoblox")

local Vector3 = roblox.Vector3

local Checks = {}

-- Parts, lights and shadow-casting lights under root (beta-spec-maps §12 budgets).
function Checks.counts(root)
	local parts, lights, shadowed = 0, 0, 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("Light") then
			lights += 1
			if d.Shadows then
				shadowed += 1
			end
		end
	end
	return { parts = parts, lights = lights, shadowed = shadowed }
end

function Checks.tagged(root, tag)
	local out = {}
	if root:HasTag(tag) then
		table.insert(out, root)
	end
	for _, d in root:GetDescendants() do
		if d:HasTag(tag) then
			table.insert(out, d)
		end
	end
	return out
end

local CLASSES = { Small = true, Medium = true, Heavy = true, Main = true }

-- LootAnchor contract (beta-spec §2.6): invisible, anchored, non-colliding, non-query part with the attributes.
function Checks.anchorContract(t, anchor)
	local name = anchor:GetFullName()
	t.ok(anchor:IsA("BasePart"), name .. " is a part")
	t.eq(anchor.Anchored, true, name .. " Anchored")
	t.eq(anchor.Transparency, 1, name .. " invisible")
	t.eq(anchor.CanCollide, false, name .. " CanCollide")
	t.eq(anchor.CanQuery, false, name .. " CanQuery")
	t.eq(anchor.CanTouch, false, name .. " CanTouch")
	t.ok(CLASSES[anchor:GetAttribute("AnchorClass")], name .. " AnchorClass")
	local id = anchor:GetAttribute("AnchorId")
	t.ok(type(id) == "string" and #id > 0, name .. " AnchorId")
	t.ok(type(anchor:GetAttribute("Zone")) == "string", name .. " Zone")
end

function Checks.uniqueAnchorIds(t, anchors)
	local seen = {}
	for _, anchor in anchors do
		local id = anchor:GetAttribute("AnchorId")
		t.ok(not seen[id], "duplicate AnchorId " .. tostring(id))
		seen[id] = true
	end
end

-- HideSpot contract (beta-spec §4.1): Model, HideKind, PrimaryPart with Attachments Inside and Exit; the visual
-- encloses a standing character (≥ 4 tall, advisor decision) and the exit is outside the prop.
function Checks.hideSpotContract(t, model)
	local name = model:GetFullName()
	t.ok(model:IsA("Model"), name .. " is a Model")
	t.ok(type(model:GetAttribute("HideKind")) == "string", name .. " HideKind")
	local primary = model.PrimaryPart
	t.ok(primary and primary:IsDescendantOf(model), name .. " PrimaryPart")
	local inside = primary:FindFirstChild("Inside")
	local exit = primary:FindFirstChild("Exit")
	t.ok(inside and inside:IsA("Attachment"), name .. " Inside attachment")
	t.ok(exit and exit:IsA("Attachment"), name .. " Exit attachment")
	local _, size = model:GetBoundingBox()
	t.ok(size.Y >= 4, name .. " at least 4 studs tall")
	t.ok(Geometry.pointInside(inside.WorldPosition, primary, 0), name .. " Inside is inside the spot")
	t.ok(not Geometry.pointInside(exit.WorldPosition, primary, -0.5), name .. " Exit is outside the spot")
end

-- Axis-aligned overlap of two parts (both unrotated or nearly so).
function Checks.overlaps(a, b)
	local function box(p)
		local minV, maxV
		for _, c in Mock.partCorners(p) do
			minV = if minV then minV:Min(c) else c
			maxV = if maxV then maxV:Max(c) else c
		end
		return minV, maxV
	end
	local amin, amax = box(a)
	local bmin, bmax = box(b)
	return amin.X < bmax.X
		and bmin.X < amax.X
		and amin.Y < bmax.Y
		and bmin.Y < amax.Y
		and amin.Z < bmax.Z
		and bmin.Z < amax.Z
end

local function signText(board)
	local gui = board:FindFirstChild("SignText")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	return label and label.Text
end

function Checks.signTexts(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if d.Name == "Sign" and d:IsA("BasePart") then
			local text = signText(d)
			if text then
				out[text] = d
			end
		end
	end
	return out
end

-- Sign rules (beta-spec-maps §2): ALL CAPS, ≤ 2 lines of ≤ 16 characters, a ViewFrom attribute, board height ≥
-- viewing distance ÷ 12 per line, width ≥ 0.5 × characters × line height, and a clear line of sight.
function Checks.signProblems(root)
	local problems = {}
	local blockers = Geometry.visibleParts(root)
	for text, board in Checks.signTexts(root) do
		local label = string.gsub(text, "\n", " / ")
		if string.upper(text) ~= text then
			table.insert(problems, label .. ": not all caps")
		end
		local lines = string.split(text, "\n")
		local longest = 0
		for _, line in lines do
			longest = math.max(longest, #line)
		end
		if #lines > 2 or longest > 16 then
			table.insert(problems, label .. ": too many lines or characters")
		end
		local from = board:GetAttribute("ViewFrom")
		if typeof(from) ~= "Vector3" then
			table.insert(problems, label .. ": no ViewFrom")
			continue
		end
		local lineHeight = board.Size.Y / #lines
		local distance = (board.Position - from).Magnitude
		if lineHeight < distance / 12 - 1e-6 then
			table.insert(
				problems,
				string.format("%s: %.2f high per line, needs %.2f", label, lineHeight, distance / 12)
			)
		end
		if board.Size.X < 0.5 * longest * lineHeight - 1e-6 then
			table.insert(problems, label .. ": board too narrow for its text")
		end
		for _, problem in Geometry.signProblems(board, blockers) do
			table.insert(problems, label .. ": " .. problem)
		end
	end
	return problems
end

-- Walking lanes (local points + origin): no solid part inside, and the Reach station's prompt part within the
-- prompt distance (8) of a character at the lane's end.
function Checks.lanes(root, origin, lanes)
	local problems = {}
	local solids = Geometry.solidParts(root)
	for _, lane in lanes do
		local points = {}
		for _, p in lane.Points do
			table.insert(points, origin + p)
		end
		for _, hit in Geometry.laneBlockers(points, lane.Width, 6, solids) do
			table.insert(problems, lane.Name .. " blocked by " .. hit)
		end
		if lane.Reach then
			local stations = Checks.tagged(root, lane.Reach)
			local station = stations[1]
			if not station then
				table.insert(problems, lane.Name .. ": no " .. lane.Reach)
			else
				local part = if station:IsA("Model") then station.PrimaryPart else station
				local stand = points[#points] + Vector3.new(0, 3, 0)
				local reach = (part.Position - stand).Magnitude
				if reach > 8 then
					table.insert(
						problems,
						string.format("%s: %s prompt %.1f studs away", lane.Name, lane.Reach, reach)
					)
				end
			end
		end
	end
	return problems
end

return Checks
