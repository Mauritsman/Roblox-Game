--!nocheck
-- A small mock of the Roblox engine for map tests in Lune (no Studio needed).
-- - Instances are plain tables, but every property write is checked against Roblox's reflection database
--   (unknown property, read-only property or wrong datatype → error), so typos fail here instead of in Studio.
-- - The script tree is read from src/ like Rojo does (folder + init.luau = ModuleScript with children), so
--   `require(script.Parent.X)` works without a sourcemap.
-- - Terrain records FillBlock/Clear calls; CollectionService, PhysicsService and friends are stubs.
-- Usage: local world = Mock.world({ props = true? }); local MapService = world.require(world.server.Services.MapService)

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local db = roblox.getReflectionDatabase()

local Mock = {}

---------------------------------------------------------------- reflection helpers

local chainCache = {}
local function chain(className)
	local cached = chainCache[className]
	if cached then
		return cached
	end
	local list = {}
	local def = db:GetClass(className)
	assert(def, "unknown class " .. tostring(className))
	while def do
		table.insert(list, def)
		def = if def.Superclass then db:GetClass(def.Superclass) else nil
	end
	chainCache[className] = list
	return list
end

local function isA(className, wanted)
	for _, def in chain(className) do
		if def.Name == wanted then
			return true
		end
	end
	return false
end

local function propDef(className, prop)
	for _, def in chain(className) do
		local p = def.Properties[prop]
		if p then
			return p
		end
	end
	return nil
end

local function defaultOf(className, prop)
	for _, def in chain(className) do
		local d = def.DefaultProperties and def.DefaultProperties[prop]
		if d ~= nil then
			return d
		end
	end
	return nil
end

local NUMBER = { Float32 = true, Float64 = true, Int32 = true, Int64 = true }
local SAME = {
	Vector3 = true,
	CFrame = true,
	Color3 = true,
	UDim2 = true,
	UDim = true,
	Vector2 = true,
	BrickColor = true,
	NumberSequence = true,
	ColorSequence = true,
	NumberRange = true,
}

local function checkValue(className, prop, def, value)
	local dt = def.Datatype
	local ok = true
	if value == nil then
		ok = dt == "Ref"
	elseif dt == "Bool" then
		ok = type(value) == "boolean"
	elseif NUMBER[dt] then
		ok = type(value) == "number"
	elseif dt == "String" or dt == "Content" or dt == "ContentId" then
		ok = type(value) == "string"
	elseif dt == "Ref" then
		ok = Mock.isInstance(value)
	elseif string.sub(dt, 1, 5) == "Enum." then
		ok = typeof(value) == "EnumItem"
			and string.match(tostring(value), "^Enum%.([%w_]+)%.") == string.sub(dt, 6)
	elseif dt == "Color3uint8" then
		ok = typeof(value) == "Color3"
	elseif SAME[dt] then
		ok = typeof(value) == dt
	end
	if not ok then
		error(string.format("%s.%s expects %s, got %s", className, prop, dt, typeof(value)), 4)
	end
end

local ATTRIBUTE_TYPES = {
	string = true,
	number = true,
	boolean = true,
	Vector3 = true,
	Vector2 = true,
	CFrame = true,
	Color3 = true,
	UDim = true,
	UDim2 = true,
	BrickColor = true,
	NumberRange = true,
	NumberSequence = true,
	ColorSequence = true,
}

---------------------------------------------------------------- instances

local methods = {}
local meta = {}
local tagged = {} -- tag → { [inst] = true }

function Mock.isInstance(v)
	return type(v) == "table" and getmetatable(v) == meta
end

function Mock.new(className)
	assert(db:GetClass(className), "Instance.new: unknown class " .. tostring(className))
	return setmetatable({
		__class = className,
		__props = { Name = className },
		__children = {},
		__attrs = {},
		__tags = {},
	}, meta)
end

meta.__index = function(self, k)
	if k == "Parent" then
		return rawget(self, "__parent")
	elseif k == "ClassName" then
		return rawget(self, "__class")
	end
	local m = methods[k]
	if m then
		return m
	end
	local props = rawget(self, "__props")
	local value = props[k]
	if value ~= nil then
		return value
	end
	local className = rawget(self, "__class")
	if k == "Position" and isA(className, "BasePart") then
		return (props.CFrame or CFrame.new()).Position
	end
	if k == "WorldPosition" and className == "Attachment" then
		local parent = rawget(self, "__parent")
		return parent.CFrame * (props.Position or Vector3.zero)
	end
	-- An unset property vs a child with that name: the child wins (e.g. a module called "Tags", while
	-- Instance.Tags is not visible to scripts).
	for _, child in rawget(self, "__children") do
		if child.Name == k then
			return child
		end
	end
	if propDef(className, k) then
		return defaultOf(className, k)
	end
	error(tostring(k) .. " is not a valid member of " .. className .. " " .. tostring(props.Name), 2)
end

meta.__newindex = function(self, k, v)
	local className = rawget(self, "__class")
	if k == "Parent" then
		assert(v == nil or Mock.isInstance(v), "Parent must be an Instance")
		local old = rawget(self, "__parent")
		if old then
			local list = rawget(old, "__children")
			local index = table.find(list, self)
			if index then
				table.remove(list, index)
			end
		end
		rawset(self, "__parent", v)
		if v then
			table.insert(rawget(v, "__children"), self)
		end
		return
	end
	local def = propDef(className, k)
	if not def then
		error(tostring(k) .. " is not a valid member of " .. className, 2)
	end
	if def.Scriptability == "None" or def.Scriptability == "Read" then
		error(className .. "." .. k .. " cannot be assigned to", 2)
	end
	checkValue(className, k, def, v)
	local props = rawget(self, "__props")
	if k == "Position" and isA(className, "BasePart") then
		local cf = props.CFrame or CFrame.new()
		props.CFrame = cf - cf.Position + v
		return
	end
	props[k] = v
end

meta.__tostring = function(self)
	return rawget(self, "__class") .. " " .. tostring(rawget(self, "__props").Name)
end

function methods:IsA(className)
	return isA(rawget(self, "__class"), className)
end

function methods:GetFullName()
	local parts = {}
	local node = self
	while node do
		table.insert(parts, 1, node.Name)
		node = rawget(node, "__parent")
	end
	return table.concat(parts, ".")
end

function methods:FindFirstChild(name, recursive)
	for _, child in rawget(self, "__children") do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in rawget(self, "__children") do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function methods:WaitForChild(name)
	local child = self:FindFirstChild(name)
	assert(child, "WaitForChild would wait forever for " .. tostring(name) .. " in " .. self:GetFullName())
	return child
end

function methods:FindFirstChildOfClass(className)
	for _, child in rawget(self, "__children") do
		if rawget(child, "__class") == className then
			return child
		end
	end
	return nil
end

function methods:FindFirstChildWhichIsA(className, recursive)
	for _, child in (if recursive then self:GetDescendants() else rawget(self, "__children")) do
		if child:IsA(className) then
			return child
		end
	end
	return nil
end

function methods:FindFirstAncestorWhichIsA(className)
	local node = rawget(self, "__parent")
	while node do
		if node:IsA(className) then
			return node
		end
		node = rawget(node, "__parent")
	end
	return nil
end

function methods:FindFirstAncestorOfClass(className)
	local node = rawget(self, "__parent")
	while node do
		if rawget(node, "__class") == className then
			return node
		end
		node = rawget(node, "__parent")
	end
	return nil
end

function methods:IsDescendantOf(other)
	local node = rawget(self, "__parent")
	while node do
		if node == other then
			return true
		end
		node = rawget(node, "__parent")
	end
	return false
end

function methods:GetChildren()
	return table.clone(rawget(self, "__children"))
end

function methods:GetDescendants()
	local out = {}
	local function walk(node)
		for _, child in rawget(node, "__children") do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function methods:SetAttribute(key, value)
	assert(type(key) == "string", "attribute name must be a string")
	assert(
		value == nil or ATTRIBUTE_TYPES[typeof(value)],
		"attribute " .. key .. ": unsupported type " .. typeof(value)
	)
	rawget(self, "__attrs")[key] = value
end

function methods:GetAttribute(key)
	return rawget(self, "__attrs")[key]
end

function methods:GetAttributes()
	return table.clone(rawget(self, "__attrs"))
end

function methods:AddTag(tag)
	rawget(self, "__tags")[tag] = true
	tagged[tag] = tagged[tag] or setmetatable({}, { __mode = "k" })
	tagged[tag][self] = true
end

function methods:RemoveTag(tag)
	rawget(self, "__tags")[tag] = nil
	if tagged[tag] then
		tagged[tag][self] = nil
	end
end

function methods:HasTag(tag)
	return rawget(self, "__tags")[tag] == true
end

function methods:GetTags()
	local out = {}
	for tag in rawget(self, "__tags") do
		table.insert(out, tag)
	end
	table.sort(out)
	return out
end

function methods:Destroy()
	for _, child in self:GetChildren() do
		child:Destroy()
	end
	self.Parent = nil
	rawset(self, "__destroyed", true)
end

function methods:ClearAllChildren()
	for _, child in self:GetChildren() do
		child:Destroy()
	end
end

function methods:Clone()
	local map = {}
	local function copy(node)
		local c = setmetatable({
			__class = rawget(node, "__class"),
			__props = table.clone(rawget(node, "__props")),
			__children = {},
			__attrs = table.clone(rawget(node, "__attrs")),
			__tags = {},
			__file = rawget(node, "__file"),
		}, meta)
		map[node] = c
		for tag in rawget(node, "__tags") do
			c:AddTag(tag)
		end
		for _, child in rawget(node, "__children") do
			copy(child).Parent = c
		end
		return c
	end
	local root = copy(self)
	for original, c in map do
		for key, value in rawget(original, "__props") do
			if Mock.isInstance(value) and map[value] then
				rawget(c, "__props")[key] = map[value]
			end
		end
	end
	return root
end

local function partCorners(part)
	local half = part.Size / 2
	local out = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, part.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
			end
		end
	end
	return out
end
Mock.partCorners = partCorners

function methods:GetBoundingBox()
	local minV, maxV
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			for _, corner in partCorners(d) do
				minV = if minV then minV:Min(corner) else corner
				maxV = if maxV then maxV:Max(corner) else corner
			end
		end
	end
	if not minV then
		return CFrame.new(), Vector3.zero
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end

function methods:GetPivot()
	if self:IsA("BasePart") then
		return self.CFrame
	end
	local primary = rawget(self, "__props").PrimaryPart
	if primary then
		return primary.CFrame
	end
	return (self:GetBoundingBox())
end

function methods:PivotTo(target)
	if self:IsA("BasePart") then
		self.CFrame = target
		return
	end
	local delta = target * self:GetPivot():Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end

function methods:GetScale()
	return rawget(self, "__scale") or 1
end

function methods:ScaleTo(scale)
	local factor = scale / self:GetScale()
	local pivot = self:GetPivot()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			d.Size *= factor
			d.CFrame = pivot * (rel - rel.Position + rel.Position * factor)
		end
	end
	rawset(self, "__scale", scale)
end

---------------------------------------------------------------- deterministic Random

local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = math.floor(seed or 1) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return setmetatable({ state = state }, Random)
end
function Random:_next()
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function Random:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function Random:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end
Mock.Random = Random

---------------------------------------------------------------- script tree from src/

local function loadTree(path, name)
	local node
	if fs.isDir(path) then
		local entries = fs.readDir(path)
		table.sort(entries)
		local init = nil
		for _, entry in entries do
			if entry == "init.luau" or entry == "init.lua" then
				init = path .. "/" .. entry
			end
		end
		node = Mock.new(if init then "ModuleScript" else "Folder")
		node.Name = name
		if init then
			rawset(node, "__file", init)
		end
		for _, entry in entries do
			local full = path .. "/" .. entry
			if fs.isDir(full) then
				loadTree(full, entry).Parent = node
			elseif entry ~= "init.luau" and entry ~= "init.lua" then
				local base = string.match(entry, "^(.-)%.luau?$")
				if base and not string.match(base, "%.server$") and not string.match(base, "%.client$") then
					local module = Mock.new("ModuleScript")
					module.Name = base
					rawset(module, "__file", full)
					module.Parent = node
				end
			end
		end
	end
	return node
end
Mock.loadTree = loadTree

---------------------------------------------------------------- the world

-- Makes a fresh game: services, the script tree and a require that loads modules with a Roblox-like environment.
-- opts.props = { [name] = Vector3 size } puts simple MeshPart templates in ServerStorage.Props.
function Mock.world(opts)
	opts = opts or {}
	local log = {}
	local game = Mock.new("DataModel")
	game.Name = "Game"

	local workspace = Mock.new("Workspace")
	workspace.Name = "Workspace"
	workspace.Parent = game
	local terrain = Mock.new("Terrain")
	terrain.Name = "Terrain"
	terrain.Parent = workspace
	rawset(terrain, "FillBlock", function(_, cf, size, material)
		table.insert(log, { kind = "FillBlock", cframe = cf, size = size, material = material })
	end)
	rawset(terrain, "Clear", function()
		table.insert(log, { kind = "Clear" })
	end)
	local baseplate = Mock.new("Part")
	baseplate.Name = "Baseplate"
	baseplate.Size = Vector3.new(512, 20, 512)
	baseplate.CFrame = CFrame.new(0, -10, 0)
	baseplate.Parent = workspace

	local services = {}
	local function service(className)
		local s = Mock.new(className)
		s.Name = className
		s.Parent = game
		services[className] = s
		return s
	end
	service("Lighting")
	local replicated = service("ReplicatedStorage")
	local sss = service("ServerScriptService")
	local serverStorage = service("ServerStorage")
	service("MaterialService")
	service("Players")
	services.Workspace = workspace

	local shared = loadTree("src/shared", "Shared")
	shared.Parent = replicated
	local remotes = Mock.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = replicated
	local server = loadTree("src/server", "Server")
	server.Parent = sss

	if opts.props then
		local props = Mock.new("Folder")
		props.Name = "Props"
		props.Parent = serverStorage
		for name, size in opts.props do
			local part = Mock.new("MeshPart")
			part.Name = name
			part.Size = size
			part.Parent = props
		end
	end

	local function roots()
		return { workspace, services.Lighting, replicated, sss, serverStorage }
	end
	local CollectionService = {
		AddTag = function(_, inst, tag)
			inst:AddTag(tag)
		end,
		RemoveTag = function(_, inst, tag)
			inst:RemoveTag(tag)
		end,
		HasTag = function(_, inst, tag)
			return inst:HasTag(tag)
		end,
		GetTagged = function(_, tag)
			local out = {}
			for inst in tagged[tag] or {} do
				for _, root in roots() do
					if inst:IsDescendantOf(root) then
						table.insert(out, inst)
						break
					end
				end
			end
			return out
		end,
		GetInstanceAddedSignal = function()
			return { Connect = function() end }
		end,
	}
	services.CollectionService = CollectionService
	services.PhysicsService = {
		IsCollisionGroupRegistered = function()
			return false
		end,
		RegisterCollisionGroup = function(_, group)
			table.insert(log, { kind = "RegisterCollisionGroup", group = group })
		end,
		CollisionGroupSetCollidable = function() end,
	}
	services.RunService = {
		IsStudio = function()
			return false
		end,
		IsServer = function()
			return true
		end,
	}

	rawset(game, "GetService", function(_, name)
		local s = services[name]
		assert(s, "mock has no service " .. tostring(name))
		return s
	end)

	local cache = {}
	local env
	local function fakeRequire(node)
		assert(Mock.isInstance(node), "require expects a ModuleScript, got " .. tostring(node))
		if cache[node] ~= nil then
			return cache[node]
		end
		local file = rawget(node, "__file")
		assert(file, "no source file for " .. node:GetFullName())
		local moduleEnv = table.clone(env)
		moduleEnv.script = node
		local chunk = luau.load(fs.readFile(file), { debugName = file, environment = moduleEnv })
		local result = chunk()
		cache[node] = result
		return result
	end

	env = {
		game = game,
		workspace = workspace,
		Instance = { new = Mock.new },
		Random = Random,
		require = fakeRequire,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		BrickColor = roblox.BrickColor,
		Enum = roblox.Enum,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
		NumberRange = roblox.NumberRange,
		task = task,
		warn = function(...)
			table.insert(log, { kind = "warn", text = table.concat({ ... }, " ") })
		end,
		print = function() end,
	}

	return {
		game = game,
		workspace = workspace,
		terrain = terrain,
		lighting = services.Lighting,
		replicated = replicated,
		shared = shared,
		server = server,
		services = services,
		log = log,
		require = fakeRequire,
	}
end

return Mock
