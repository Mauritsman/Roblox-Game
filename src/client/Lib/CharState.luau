--!strict
-- Read-only view of the local player and character attributes (beta-spec §9.3), with one Changed signal
-- that survives respawns. Also computes the control mode (ClientState.mode) the touch cluster follows:
--   Explore | Carry | Drone | Hidden | Cell | Carried | Van | Spectate

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local ClientState = require(script.Parent.ClientState)

local CharState = {}

local player = Players.LocalPlayer

CharState.Changed = Signal.new() :: Signal.Signal<string>

function CharState.character(): Model?
	return player.Character
end

function CharState.root(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function CharState.get(name: string): any
	local character = player.Character
	return if character then character:GetAttribute(name) else nil
end

function CharState.playerAttr(name: string): any
	return player:GetAttribute(name)
end

-- Carry: "Medium" | "Heavy" | nil, plus the role ("Lead" | "Help").
function CharState.carry(): (string?, string)
	local class = CharState.get("CarryClass")
	if typeof(class) ~= "string" or class == "" or class == "Small" then
		return nil, "Lead"
	end
	local role = CharState.get("CarryRole")
	local r = if role == "Help" then "Help" else "Lead"
	if class == "Heavy" or class == "Main" then
		return "Heavy", r
	end
	return "Medium", r
end

function CharState.captured(): string?
	local value = CharState.get("Captured")
	if value == "Cell" or value == "Carried" then
		return value
	end
	if CharState.get("Caught") == true then
		return "Carried"
	end
	return nil
end

function CharState.pockets(): number
	local value = CharState.get("Pockets")
	return if typeof(value) == "number" then value else 0
end

function CharState.mode(): string
	local captured = CharState.captured()
	if captured == "Cell" then
		return "Cell"
	elseif captured == "Carried" then
		return "Carried"
	end
	if ClientState.spectating then
		return "Spectate"
	end
	if ClientState.drone ~= nil then
		return "Drone"
	end
	if CharState.get("Hidden") == true then
		return "Hidden"
	end
	if CharState.carry() ~= nil then
		return "Carry"
	end
	if CharState.get("InVan") == true then
		return "Van"
	end
	return "Explore"
end

local function refreshMode()
	local mode = CharState.mode()
	if ClientState.mode ~= mode then
		ClientState.set("mode", mode)
	end
end

local started = false
local characterConnection: RBXScriptConnection? = nil
function CharState.init()
	if started then
		return
	end
	started = true
	local function watch(character: Model)
		if characterConnection then
			characterConnection:Disconnect()
		end
		characterConnection = character.AttributeChanged:Connect(function(name)
			refreshMode()
			CharState.Changed:Fire(name)
		end)
		refreshMode()
		CharState.Changed:Fire("Character")
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
	player.AttributeChanged:Connect(function(name)
		CharState.Changed:Fire("Player:" .. name)
	end)
	ClientState.Changed:Connect(function(key)
		if key == "drone" or key == "spectating" then
			refreshMode()
		end
	end)
end

return CharState
