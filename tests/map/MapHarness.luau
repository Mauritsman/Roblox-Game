--!nocheck
-- Builds a heist without Roblox Studio, in Lune (map package A, 16 Oct 2026).
--
-- Instances and datatypes are the real ones from `@lune/roblox` (property names and types are checked like in
-- Roblox: a typo in a property name is an error here too). The engine pieces Lune does not have are filled in:
-- Terrain:FillBlock/Clear (logged), Model:GetBoundingBox, and a CollectionService that stores tags on the
-- instances. `math.random` is blocked: map code must use the build's `rng`. Props are never found (no
-- ServerStorage.Props), so every `Builder.prop` takes its fallback.
--
-- The script tree follows default.project.json: src/shared → ReplicatedStorage.Shared, src/server →
-- ServerScriptService.Server (folders with an init.luau become a ModuleScript with children).
--
-- Usage (from the project folder): `local Harness = require("./MapHarness")` then `Harness.buildHeist("GoldenWheel")`.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local Harness = {}

---------------------------------------------------------------- engine gaps
local function corners(cf, size)
	local h = size / 2
	local out = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
			end
		end
	end
	return out
end
Harness.corners = corners

-- World-axis bounding box of a part (min, max).
function Harness.aabb(part)
	local minV, maxV
	for _, c in corners(part.CFrame, part.Size) do
		minV = if minV then minV:Min(c) else c
		maxV = if maxV then maxV:Max(c) else c
	end
	return minV, maxV
end

local implemented = false
local terrainLog = {}
local function implementEngine()
	if implemented then
		return
	end
	implemented = true
	roblox.implementMethod("Terrain", "FillBlock", function(_, cf, size, material)
		table.insert(terrainLog, { cframe = cf, size = size, material = material })
	end)
	roblox.implementMethod("Terrain", "Clear", function()
		table.insert(terrainLog, { clear = true })
	end)
	roblox.implementMethod("Model", "GetBoundingBox", function(self)
		local minV, maxV
		for _, d in self:GetDescendants() do
			if d:IsA("BasePart") then
				local a, b = Harness.aabb(d)
				minV = if minV then minV:Min(a) else a
				maxV = if maxV then maxV:Max(b) else b
			end
		end
		if not minV then
			return CFrame.new(), Vector3.zero
		end
		return CFrame.new((minV + maxV) / 2), maxV - minV
	end)
end

---------------------------------------------------------------- deterministic Random (not Roblox's PCG)
local HRandom = {}
HRandom.__index = HRandom
function HRandom.new(seed)
	local state = math.floor(seed or 1) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return setmetatable({ state = state }, HRandom)
end
function HRandom:_next()
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function HRandom:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function HRandom:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end
Harness.Random = HRandom

---------------------------------------------------------------- script tree
local function addTree(parent, dir, name)
	local entries = fs.readDir(dir)
	table.sort(entries)
	local node
	if table.find(entries, "init.luau") then
		node = Instance.new("ModuleScript")
		node:SetAttribute("HarnessSource", dir .. "/init.luau")
	else
		node = Instance.new("Folder")
	end
	node.Name = name
	node.Parent = parent
	for _, entry in entries do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			addTree(node, path, entry)
		elseif entry ~= "init.luau" and string.sub(entry, -5) == ".luau" then
			local base = string.sub(entry, 1, -6)
			if not string.find(base, "%.") then -- skip .server/.client scripts
				local module = Instance.new("ModuleScript")
				module.Name = base
				module:SetAttribute("HarnessSource", path)
				module.Parent = node
			end
		end
	end
	return node
end

-- A fresh world: DataModel with the script tree, Workspace with Terrain, and a `game` proxy for the map code.
function Harness.newWorld(opts)
	implementEngine()
	local dm = Instance.new("DataModel")
	local workspace = dm:GetService("Workspace")
	local terrain = Instance.new("Terrain")
	terrain.Name = "Terrain"
	terrain.Parent = workspace
	addTree(dm:GetService("ReplicatedStorage"), "src/shared", "Shared")
	addTree(dm:GetService("ServerScriptService"), "src/server", "Server")

	local collection = {}
	function collection:AddTag(inst, tag)
		inst:AddTag(tag)
	end
	function collection:RemoveTag(inst, tag)
		inst:RemoveTag(tag)
	end
	function collection:HasTag(inst, tag)
		return inst:HasTag(tag)
	end
	function collection:GetTagged(tag)
		local out = {}
		for _, d in dm:GetDescendants() do
			if d:HasTag(tag) then
				table.insert(out, d)
			end
		end
		return out
	end
	local game = {}
	function game:GetService(name)
		if name == "CollectionService" then
			return collection
		end
		return dm:GetService(name)
	end

	local world = { dm = dm, game = game, workspace = workspace, terrain = terrain, terrainLog = terrainLog }
	local cache = {}
	local strictMath = table.clone(math)
	if not (opts and opts.allowMathRandom) then
		strictMath.random = function()
			error("math.random is not allowed in map code: use the build's rng", 2)
		end
	end
	local baseEnv = {
		game = game,
		workspace = workspace,
		Random = HRandom,
		math = strictMath,
		warn = function(...)
			table.insert(world.warnings, table.concat({ ... }, " "))
		end,
	}
	for key, value in roblox do
		if type(key) == "string" and string.match(key, "^%u") then
			baseEnv[key] = value
		end
	end
	world.warnings = {}

	local function req(module)
		local path = module:GetAttribute("HarnessSource")
		assert(path, "not a ModuleScript from src: " .. module:GetFullName())
		if cache[path] ~= nil then
			return cache[path]
		end
		local env = table.clone(baseEnv)
		env.script = module
		env.require = req
		local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
		local result = chunk()
		cache[path] = result
		return result
	end
	baseEnv.require = req
	world.require = req
	return world
end

-- Builds one heist like MapService:Build does (without the atmosphere) and returns the world plus the heist.
function Harness.buildHeist(heistId, opts)
	local world = Harness.newWorld(opts)
	table.clear(terrainLog)
	local server = world.dm:GetService("ServerScriptService").Server
	local Registry = world.require(server.Map.Registry)
	local heist = Registry.get(heistId)
	assert(heist, "unknown heist " .. tostring(heistId))
	local level = Instance.new("Folder")
	level.Name = "Level"
	heist.Build(level, HRandom.new(heist.Seed))
	level.Parent = world.workspace
	world.level = level
	world.heist = heist
	world.Tags = world.require(world.dm:GetService("ReplicatedStorage").Shared.Tags)
	world.Config = world.require(world.dm:GetService("ReplicatedStorage").Shared.Config)
	return world
end

---------------------------------------------------------------- queries
function Harness.tagged(root, tag)
	local out = {}
	for _, d in root:GetDescendants() do
		if d:HasTag(tag) then
			table.insert(out, d)
		end
	end
	return out
end

function Harness.ofClass(root, className)
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA(className) then
			table.insert(out, d)
		end
	end
	return out
end

-- World position of an Attachment (Lune does not derive WorldPosition).
function Harness.attachmentWorld(att)
	return (att.Parent.CFrame * att.CFrame).Position
end

-- Is a world point inside a (possibly rotated) block part?
function Harness.inside(part, point)
	local p = part.CFrame:PointToObjectSpace(point)
	local h = part.Size / 2
	local inBox = math.abs(p.X) <= h.X + 1e-3 and math.abs(p.Y) <= h.Y + 1e-3 and math.abs(p.Z) <= h.Z + 1e-3
	if inBox and part.ClassName == "WedgePart" then
		-- A wedge is solid below its slope, which rises from the bottom at local -Z to the top at local +Z.
		return (p.Y + h.Y) / (2 * h.Y) <= (p.Z + h.Z) / (2 * h.Z) + 1e-3
	end
	return inBox
end

-- Ray (origin → target) against a block part's oriented box: true if it crosses the box strictly between the ends.
function Harness.rayHitsBox(part, origin, target)
	local o = part.CFrame:PointToObjectSpace(origin)
	local d = part.CFrame:PointToObjectSpace(target) - o
	local h = part.Size / 2
	local tMin, tMax = 0.001, 0.999
	for _, axis in { "X", "Y", "Z" } do
		local oa, da, ha = o[axis], d[axis], h[axis]
		if math.abs(da) < 1e-9 then
			if oa < -ha or oa > ha then
				return false
			end
		else
			local t1, t2 = (-ha - oa) / da, (ha - oa) / da
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin = math.max(tMin, t1)
			tMax = math.min(tMax, t2)
			if tMin > tMax then
				return false
			end
		end
	end
	return true
end

---------------------------------------------------------------- walk grid (a rough stand-in for pathfinding)
-- `Harness.rasterize` marks every collidable part that intersects the height band [floorY + 0.6, floorY + 8] in a 2D
-- grid (cell = `step` studs); `skip(part)` → true leaves a part out (doors that get pried, entrance blockers).
-- `Harness.flood` then floods from `start` with an agent radius, with optional extra parts (the blockers of locked
-- entrances) rasterised on top. Roblox's own pathfinder uses 4-stud voxels, so this check is necessary, not
-- sufficient: keep doorways ≥ 6 studs.
local function rasterPart(raster, part, into)
	local step, minX, minZ, nx, nz = raster.step, raster.minX, raster.minZ, raster.nx, raster.nz
	local a, b = Harness.aabb(part)
	if b.Y <= raster.bandLow or a.Y >= raster.bandHigh then
		return
	end
	if b.X < minX or a.X > raster.maxX or b.Z < minZ or a.Z > raster.maxZ then
		return
	end
	local i0 = math.max(0, math.floor((a.X - minX) / step))
	local i1 = math.min(nx - 1, math.ceil((b.X - minX) / step))
	local k0 = math.max(0, math.floor((a.Z - minZ) / step))
	local k1 = math.min(nz - 1, math.ceil((b.Z - minZ) / step))
	local exact = part.ClassName ~= "Part" or part.Shape == roblox.Enum.PartType.Block
	local y = math.clamp((a.Y + b.Y) / 2, raster.bandLow, raster.bandHigh)
	if part.ClassName == "WedgePart" then
		-- A ramp blocks only where its slope rises into the band: test at the band's middle.
		y = (raster.bandLow + raster.bandHigh) / 2
	end
	for i = i0, i1 do
		for k = k0, k1 do
			if not exact or Harness.inside(part, Vector3.new(minX + i * step, y, minZ + k * step)) then
				into[i * nz + k] = true
			end
		end
	end
end

function Harness.rasterize(level, opts)
	local step = opts.step or 0.5
	local raster = {
		step = step,
		minX = opts.minX,
		maxX = opts.maxX,
		minZ = opts.minZ,
		maxZ = opts.maxZ,
		nx = math.floor((opts.maxX - opts.minX) / step) + 1,
		nz = math.floor((opts.maxZ - opts.minZ) / step) + 1,
		bandLow = (opts.floorY or 0) + 0.6,
		bandHigh = (opts.floorY or 0) + 8,
		blocked = {},
	}
	for _, part in level:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide and not (opts.skip and opts.skip(part)) then
			rasterPart(raster, part, raster.blocked)
		end
	end
	return raster
end

-- Is there room for an agent of `radius` at `p` (no blocked cell within the radius)?
function Harness.freeAt(raster, p, radius)
	local step, nz = raster.step, raster.nz
	local ci = math.floor((p.X - raster.minX) / step + 0.5)
	local ck = math.floor((p.Z - raster.minZ) / step + 0.5)
	local r = math.ceil(radius / step)
	for di = -r, r do
		for dk = -r, r do
			if (di * step) ^ 2 + (dk * step) ^ 2 <= radius * radius then
				local i, k = ci + di, ck + dk
				if i >= 0 and k >= 0 and i < raster.nx and k < nz and raster.blocked[i * nz + k] then
					return false
				end
			end
		end
	end
	return true
end

-- Floods the raster from `start`; returns `reach`: reach(point, slack) → true when a free cell within `slack`
-- studs of the point was reached (anchors sit on furniture; the agent stands next to it).
function Harness.flood(raster, start, radius, extraParts)
	local step, minX, minZ, nx, nz = raster.step, raster.minX, raster.minZ, raster.nx, raster.nz
	local base = raster.blocked
	local extra = {}
	for _, part in extraParts or {} do
		rasterPart(raster, part, extra)
	end
	local r = math.ceil(radius / step)
	local offsets = {}
	for di = -r, r do
		for dk = -r, r do
			if (di * step) ^ 2 + (dk * step) ^ 2 <= radius * radius then
				table.insert(offsets, di)
				table.insert(offsets, dk)
			end
		end
	end
	local freeCache = {}
	local function free(i, k)
		if i < 0 or k < 0 or i >= nx or k >= nz then
			return false
		end
		local key = i * nz + k
		local cached = freeCache[key]
		if cached ~= nil then
			return cached
		end
		local ok = true
		for o = 1, #offsets, 2 do
			local ii, kk = i + offsets[o], k + offsets[o + 1]
			if ii >= 0 and ii < nx and kk >= 0 and kk < nz then
				local other = ii * nz + kk
				if base[other] or extra[other] then
					ok = false
					break
				end
			end
		end
		freeCache[key] = ok
		return ok
	end
	local function cellOf(p)
		return math.floor((p.X - minX) / step + 0.5), math.floor((p.Z - minZ) / step + 0.5)
	end
	local seen = {}
	local si, sk = cellOf(start)
	local queue = {}
	if free(si, sk) then
		seen[si * nz + sk] = true
		table.insert(queue, si * nz + sk)
	end
	local head = 1
	while head <= #queue do
		local key = queue[head]
		head += 1
		local i, k = key // nz, key % nz
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ii, kk = i + d[1], k + d[2]
			local nkey = ii * nz + kk
			if not seen[nkey] and free(ii, kk) then
				seen[nkey] = true
				table.insert(queue, nkey)
			end
		end
	end
	local reach = {}
	reach.startFree = #queue > 0
	reach.cells = #queue
	function reach.at(p, slack)
		local ci, ck = cellOf(p)
		local s = math.ceil((slack or 0) / step)
		for di = -s, s do
			for dk = -s, s do
				local ii, kk = ci + di, ck + dk
				if ii >= 0 and kk >= 0 and ii < nx and kk < nz and seen[ii * nz + kk] then
					return true
				end
			end
		end
		return false
	end
	return reach
end

return Harness
