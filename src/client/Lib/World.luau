--!strict
-- Finding tagged places in the world (map/mechanics tags, beta-spec §9.4) for markers and arrows.
-- With StreamingEnabled some of them may not be streamed in yet: every function can return nil.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local World = {}

function World.position(inst: Instance?): Vector3?
	if not inst or not inst.Parent then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	elseif inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	return nil
end

local function myRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Nearest instance with a tag (optionally filtered).
function World.nearest(tag: string, filter: ((Instance) -> boolean)?): Instance?
	local root = myRoot()
	local best: Instance? = nil
	local bestDistance = math.huge
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(workspace) and (not filter or filter(inst)) then
			local pos = World.position(inst)
			if pos then
				local d = if root then (pos - root.Position).Magnitude else 0
				if d < bestDistance then
					bestDistance = d
					best = inst
				end
			end
		end
	end
	return best
end

local function session(inst: Instance): string?
	local value = inst:GetAttribute("Session")
	if typeof(value) == "string" then
		return value
	end
	local parent = inst.Parent
	if parent then
		local fromParent = parent:GetAttribute("Session")
		if typeof(fromParent) == "string" then
			return fromParent
		end
	end
	return nil
end

-- The van (bank zone) of the round you are in: Crew, Tutorial1/2... Falls back to any Exit / BankZone.
function World.vanPosition(): Vector3?
	local activity = Players.LocalPlayer:GetAttribute("Activity")
	local wanted = if activity == "Tutorial" then "Tutorial" else "Crew"
	local zone = World.nearest("BankZone", function(inst)
		local s = session(inst)
		return s == nil or string.sub(s, 1, #wanted) == wanted
	end)
	if zone then
		return World.position(zone)
	end
	local exit = World.nearest("Exit")
	if exit then
		return World.position(exit)
	end
	return nil
end

function World.goudaPosition(): Vector3?
	local main = World.nearest("MainLoot")
	if main then
		return World.position(main)
	end
	local loot = World.nearest("Loot", function(inst)
		return inst:GetAttribute("LootClass") == "Main"
	end)
	return World.position(loot)
end

function World.cellPosition(): Vector3?
	return World.position(World.nearest("CellDoor") or World.nearest("Cell"))
end

function World.tagged(tag: string): Instance?
	return World.nearest(tag)
end

return World
