--!strict
-- One pair of RemoteEvents for all network traffic.
-- (A RemoteEvent is the Roblox channel through which client and server exchange messages.)
--
-- Client → server: Net.request(name, ...)  (the server re-checks everything)
-- Server → client: Net.send(player, name, ...) / Net.broadcast(name, ...)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local IS_SERVER = RunService:IsServer()

local remotesFolder: Folder
if IS_SERVER then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		remotesFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		remotesFolder = folder
	end
else
	remotesFolder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function getRemote(name: string): RemoteEvent
	local found = remotesFolder:FindFirstChild(name)
	if found and found:IsA("RemoteEvent") then
		return found
	end
	if IS_SERVER then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
		return remote
	end
	return remotesFolder:WaitForChild(name) :: RemoteEvent
end

local toServer = getRemote("ToServer")
local toClient = getRemote("ToClient")

type Handler = (...any) -> ()

local serverHandlers: { [string]: (player: Player, ...any) -> () } = {}
local clientHandlers: { [string]: { Handler } } = {}

if IS_SERVER then
	toServer.OnServerEvent:Connect(function(player: Player, name: any, ...: any)
		if typeof(name) ~= "string" then
			return
		end
		local handler = serverHandlers[name]
		if handler then
			local ok, err = pcall(handler :: any, player, ...)
			if not ok then
				warn(`[Net] error in handler {name}: {err}`)
			end
		end
	end)
else
	toClient.OnClientEvent:Connect(function(name: string, ...: any)
		local list = clientHandlers[name]
		if list then
			for _, handler in list do
				task.spawn(handler, ...)
			end
		end
	end)
end

-- Server: register a handler for requests from clients.
function Net.onRequest(name: string, handler: (player: Player, ...any) -> ())
	assert(IS_SERVER, "Net.onRequest only on the server")
	serverHandlers[name] = handler
end

-- Client: send a request to the server.
function Net.request(name: string, ...: any)
	assert(not IS_SERVER, "Net.request only on the client")
	toServer:FireServer(name, ...)
end

-- Server: send a message to one player.
function Net.send(player: Player, name: string, ...: any)
	toClient:FireClient(player, name, ...)
end

-- Server: send a message to all players.
function Net.broadcast(name: string, ...: any)
	toClient:FireAllClients(name, ...)
end

-- Client: listen for messages from the server.
function Net.on(name: string, handler: Handler)
	assert(not IS_SERVER, "Net.on only on the client")
	local list = clientHandlers[name]
	if not list then
		list = {}
		clientHandlers[name] = list
	end
	table.insert(list, handler)
end

return Net
