--!strict
-- Player data (owner: meta). One DataStore key per player ("u_<UserId>") holding a record with a session lock.
-- docs/beta-spec-meta.md §1–2:
--   * every write is UpdateAsync with a pure lock transform (Logic/SessionLock): two servers never both write;
--   * retries with exponential backoff, ≥ 7 s between writes per key, autosave every 120 s, BindToClose;
--   * version + ordered migrations (Logic/DataSchema); newer data → kick; corrupt data → backup + fresh profile;
--   * Studio without API access (or an unpublished place) → memory only, nothing is saved.
-- It never errors the server: every DataStore call is wrapped in pcall. Other services change data ONLY through
-- DataService:Update (the callback must not yield).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local MetaTags = require(ReplicatedStorage.Shared.MetaTags)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Backoff = require(ReplicatedStorage.Shared.Logic.Backoff)
local DataSchema = require(ReplicatedStorage.Shared.Logic.DataSchema)
local SessionLock = require(ReplicatedStorage.Shared.Logic.SessionLock)

local Meta = script.Parent.Parent.Meta
local Clock = require(Meta.Clock)
local ProfileView = require(Meta.ProfileView)
local RequestGuard = require(Meta.RequestGuard)

export type PlayerData = DataSchema.PlayerData

local D = MetaConfig.Data

local MSG_LOAD_FAILED = "We couldn't open your crew file. Please rejoin in a minute."
local MSG_NEWER = "Crowbar Crew was updated. Please rejoin to keep your progress."
local MSG_LOST = "Your save was opened in another server."

local DataService = {}

-- Fired once a player's data is ready (attributes are set before it fires).
DataService.Loaded = Signal.new() :: Signal.Signal<Player, PlayerData>
-- Fired after every successful Update (player, reason).
DataService.Changed = Signal.new() :: Signal.Signal<Player, string>
-- Data events for analytics (name, player?, value?): DataLockStolen, DataLoadFailed, DataCorruptReset.
DataService.Logged = Signal.new() :: Signal.Signal<string, Player?, number>
-- Fired when a player leaves with a loaded profile (player, sessionSeconds).
DataService.Leaving = Signal.new() :: Signal.Signal<Player, number>

type Backend = {
	kind: string, -- "DataStore" | "Memory"
	update: (key: string, userId: number, transform: (any) -> any) -> any,
	get: (key: string) -> any,
	backup: (key: string, value: any) -> (),
}

type Session = {
	player: Player,
	userId: number,
	key: string,
	sessionId: string,
	data: PlayerData,
	changes: number,
	savedChanges: number,
	lastWrite: number,
	failures: number,
	saving: boolean,
	releasing: boolean,
	released: boolean,
	ended: boolean,
	startedAt: number,
	status: string,
	syncQueued: boolean,
	lastSync: number,
}

local backend: Backend? = nil
local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local loadFailed: { [Player]: boolean } = {}
local releasingUsers: { [number]: boolean } = {}
local hooks: { () -> () } = {}
local shuttingDown = false
local hooksFinished = false
local mock = { FailRate = D.Mock.FailRate, LatencySeconds = D.Mock.LatencySeconds }

local function starter(): DataSchema.Starter
	return { equipped = Catalog.DefaultEquipped, loadout = Catalog.DefaultLoadout }
end

local function defaults(): PlayerData
	return DataSchema.defaults(Clock.now(), starter())
end

-- Backends ---------------------------------------------------------------------------------------------------

local function injectFaults()
	if not RunService:IsStudio() then
		return
	end
	if mock.LatencySeconds > 0 then
		task.wait(mock.LatencySeconds)
	end
	if mock.FailRate > 0 and math.random() < mock.FailRate then
		error("[Mock] simulated DataStore failure")
	end
end

local function memoryBackend(): Backend
	local values: { [string]: any } = {}
	return {
		kind = "Memory",
		update = function(key: string, _userId: number, transform: (any) -> any): any
			injectFaults()
			local new = transform(DataSchema.deepCopy(values[key]))
			if new ~= nil then
				values[key] = DataSchema.deepCopy(new)
			end
			return DataSchema.deepCopy(new)
		end,
		get = function(key: string): any
			injectFaults()
			return DataSchema.deepCopy(values[key])
		end,
		backup = function(key: string, value: any)
			print(`[Data] (memory) corrupt value of {key} backed up: {tostring(value)}`)
		end,
	}
end

local function dataStoreBackend(store: DataStore?, corrupt: DataStore?): Backend
	return {
		kind = "DataStore",
		update = function(key: string, userId: number, transform: (any) -> any): any
			injectFaults()
			if not store then
				error("DataStore unavailable")
			end
			return (store :: DataStore):UpdateAsync(key, function(old: any)
				local new = transform(old)
				if new == nil then
					return nil
				end
				return new, { userId } -- GDPR: tie the key to this user
			end)
		end,
		get = function(key: string): any
			injectFaults()
			if not store then
				error("DataStore unavailable")
			end
			return (store :: DataStore):GetAsync(key)
		end,
		backup = function(key: string, value: any)
			if corrupt then
				local ok, err = pcall(function()
					(corrupt :: DataStore):SetAsync(`{key}_{os.time()}`, value)
				end)
				if not ok then
					warn(`[Data] could not back up corrupt data of {key}: {err}`)
				end
			end
		end,
	}
end

local function chooseBackend(): Backend
	local setting = D.UseMemoryInStudio
	local isStudio = RunService:IsStudio()
	local suffix = if isStudio then D.StudioSuffix else ""
	if isStudio and (setting == true or game.PlaceId == 0) then
		print("[Data] Studio without API access: memory only, nothing is saved.")
		return memoryBackend()
	end
	local okStore, store = pcall(function()
		return DataStoreService:GetDataStore(D.StoreName .. suffix)
	end)
	local okCorrupt, corrupt = pcall(function()
		return DataStoreService:GetDataStore(D.CorruptStoreName .. suffix)
	end)
	if isStudio and setting ~= false then
		local probeOk = okStore and pcall(function()
			(store :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			print("[Data] Studio without API access: memory only, nothing is saved.")
			return memoryBackend()
		end
	end
	if not okStore then
		warn(`[Data] GetDataStore failed: {store}`)
	end
	return dataStoreBackend(if okStore then store else nil, if okCorrupt then corrupt else nil)
end

local function waitForBackend(): Backend
	while not backend do
		task.wait(0.1)
	end
	return backend :: Backend
end

-- Attributes and client sync ----------------------------------------------------------------------------------

local function ensureLeaderstats(player: Player): IntValue
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "leaderstats"
		created.Parent = player
		folder = created
	end
	local rank = (folder :: Instance):FindFirstChild("Rank")
	if not rank or not rank:IsA("IntValue") then
		local created = Instance.new("IntValue")
		created.Name = "Rank"
		created.Parent = folder
		return created
	end
	return rank
end

local function publish(session: Session)
	local player = session.player
	for name, value in ProfileView.attributes(session.data) do
		player:SetAttribute(name, value)
	end
	player:SetAttribute(MetaTags.SaveStatus, session.status)
	player:SetAttribute(MetaTags.DataLoaded, true)
	ensureLeaderstats(player).Value = player:GetAttribute(MetaTags.Rank) :: number
end

local function sendSync(session: Session)
	session.syncQueued = false
	session.lastSync = os.clock()
	if session.player.Parent and not session.ended then
		Net.send(session.player, "ProfileSync", ProfileView.build(session.data, session.status))
	end
end

local function queueSync(session: Session)
	if session.syncQueued then
		return
	end
	session.syncQueued = true
	local wait = math.max(0, 1 / D.SyncPerSecond - (os.clock() - session.lastSync))
	task.delay(wait, sendSync, session)
end

local function setStatus(session: Session, status: string)
	if session.status ~= status then
		session.status = status
		session.player:SetAttribute(MetaTags.SaveStatus, status)
		Net.send(session.player, "SaveStatus", status)
	end
end

local function kick(player: Player, message: string)
	if player.Parent then
		pcall(function()
			player:Kick(message)
		end)
	end
end

-- Saving -----------------------------------------------------------------------------------------------------

local function endSession(session: Session, message: string?)
	session.ended = true
	if sessions[session.player] == session then
		sessions[session.player] = nil
	end
	if message then
		warn(`[Data] session of {session.player.Name} ended: {message}`)
		kick(session.player, message)
	end
end

-- One UpdateAsync write (with retries). Returns true when the record was written.
local function writeAsync(session: Session, release: boolean): boolean
	while session.saving do
		task.wait(0.05)
	end
	if session.released or (session.ended and not release) then
		return session.released
	end
	local store = waitForBackend()
	session.saving = true
	local changesAtStart = session.changes
	local outcome: string = "error"
	local ok, err = Backoff.retry(
		function()
			return store.update(session.key, session.userId, function(raw: any): any
				local record, result = SessionLock.save(raw, {
					session = session.sessionId,
					now = os.time(),
					data = session.data,
					release = release,
				})
				outcome = result
				return record
			end)
		end,
		D.RetryAttempts,
		D.RetryMaxSeconds,
		function(seconds: number)
			task.wait(seconds)
		end,
		math.random
	)
	session.saving = false
	session.lastWrite = os.clock()
	if not ok then
		session.failures += 1
		warn(`[Data] save of {session.player.Name} failed ({session.failures}x): {err}`)
		if session.failures >= D.TroubleAfterFailures and backend and backend.kind ~= "Memory" then
			setStatus(session, "Trouble")
		end
		return false
	end
	if outcome == "lost" or outcome == "missing" then
		endSession(session, MSG_LOST)
		return false
	end
	session.failures = 0
	session.savedChanges = math.max(session.savedChanges, changesAtStart)
	if session.status == "Trouble" then
		setStatus(session, "Ok")
	end
	if release then
		session.released = true
	end
	return true
end

local function minSpacing(): number
	return if backend and backend.kind == "Memory" then 0.5 else D.MinSecondsBetweenWrites
end

-- Loading ----------------------------------------------------------------------------------------------------

local LOAD_OK = { created = true, taken = true, stale = true, stolen = true, reset = true }

local function startSession(player: Player, key: string, sessionId: string, data: PlayerData)
	local store = waitForBackend()
	local session: Session = {
		player = player,
		userId = player.UserId,
		key = key,
		sessionId = sessionId,
		data = data,
		changes = 0,
		savedChanges = 0,
		lastWrite = os.clock(),
		failures = 0,
		saving = false,
		releasing = false,
		released = false,
		ended = false,
		startedAt = os.clock(),
		status = if store.kind == "Memory" then "Memory" else "Ok",
		syncQueued = false,
		lastSync = 0,
	}
	data.stats.sessions = (data.stats.sessions or 0) + 1
	data.lastSeen = Clock.now()
	sessions[player] = session
	publish(session)
	DataService.Loaded:Fire(player, data)
	Net.send(player, "SaveStatus", session.status)
	queueSync(session)
end

local function loadPlayer(player: Player)
	local store = waitForBackend()
	if shuttingDown or sessions[player] or loading[player] then
		return
	end
	loading[player] = true
	local userId = player.UserId
	local deadline = os.clock() + D.RejoinWaitSeconds
	while releasingUsers[userId] and os.clock() < deadline do
		task.wait(0.25)
	end
	local key = D.KeyPrefix .. userId
	local sessionId = HttpService:GenerateGUID(false)
	local resetCorrupt = false
	for attempt = 1, D.LoadAttempts do
		if not player.Parent or shuttingDown then
			loading[player] = nil
			return
		end
		local outcome: string = "error"
		local rawSeen: any = nil
		local ok, result = pcall(store.update, key, userId, function(raw: any): any
			rawSeen = raw
			local record, loadOutcome = SessionLock.load(raw, {
				session = sessionId,
				job = game.JobId,
				place = game.PlaceId,
				now = os.time(),
				staleSeconds = D.StaleLockSeconds,
				steal = attempt >= D.StealAfterAttempts,
				currentVersion = DataSchema.CURRENT,
				makeDefaults = defaults,
				resetCorrupt = resetCorrupt,
			})
			outcome = loadOutcome
			return record
		end)
		local retryNow = false
		if ok and LOAD_OK[outcome] and type(result) == "table" then
			if outcome == "stolen" then
				DataService.Logged:Fire("DataLockStolen", player, 1)
			end
			local status, data = DataSchema.prepare(result.data, Clock.now(), starter())
			if status ~= "ok" or not data then
				-- Valid wrapper but unusable data: keep a copy, start fresh (we hold the lock now).
				store.backup(key, result.data)
				DataService.Logged:Fire("DataCorruptReset", player, 1)
				data = defaults()
			end
			loading[player] = nil
			local fresh = data :: PlayerData
			if not player.Parent then
				local temp: Session = {
					player = player,
					userId = userId,
					key = key,
					sessionId = sessionId,
					data = fresh,
					changes = 0,
					savedChanges = 0,
					lastWrite = 0,
					failures = 0,
					saving = false,
					releasing = true,
					released = false,
					ended = false,
					startedAt = os.clock(),
					status = "Ok",
					syncQueued = false,
					lastSync = 0,
				}
				writeAsync(temp, true)
				return
			end
			startSession(player, key, sessionId, fresh)
			return
		elseif ok and outcome == "newer" then
			loading[player] = nil
			kick(player, MSG_NEWER)
			return
		elseif ok and outcome == "corrupt" then
			store.backup(key, rawSeen)
			DataService.Logged:Fire("DataCorruptReset", player, 1)
			resetCorrupt = true
			retryNow = true
		elseif not ok then
			warn(`[Data] load attempt {attempt} for {player.Name} failed: {result}`)
		end
		if attempt < D.LoadAttempts and not retryNow then
			task.wait(D.LoadRetrySeconds)
		end
	end
	loading[player] = nil
	loadFailed[player] = true
	DataService.Logged:Fire("DataLoadFailed", player, 1)
	kick(player, MSG_LOAD_FAILED)
end

-- Public API -------------------------------------------------------------------------------------------------

-- Yields until the player's data is loaded. nil if loading failed, the player left or the timeout passed.
function DataService:WaitForData(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while not sessions[player] and player.Parent and not loadFailed[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	local session = sessions[player]
	return if session then session.data else nil
end

-- The live data table. READ ONLY by convention: change it with Update.
function DataService:Get(player: Player): PlayerData?
	local session = sessions[player]
	return if session then session.data else nil
end

function DataService:IsLoaded(player: Player): boolean
	return sessions[player] ~= nil
end

-- The only way to change data. `fn` gets a copy and must not yield; on error nothing changes.
-- Returns false when the data is not loaded, being released (leaving/teleporting) or fn errored.
function DataService:Update(player: Player, reason: string, fn: (PlayerData) -> ()): boolean
	local session = sessions[player]
	if not session or session.ended or session.releasing or session.released then
		return false
	end
	if player:GetAttribute(MetaTags.Teleporting) == true then
		return false
	end
	local copy = DataSchema.deepCopy(session.data)
	local ok, err = pcall(fn :: any, copy)
	if not ok then
		warn(`[Data] update "{reason}" failed for {player.Name}: {err}`)
		return false
	end
	DataSchema.sanitize(copy)
	local live = session.data :: any
	for key in live do
		if (copy :: any)[key] == nil then
			live[key] = nil
		end
	end
	for key, value in copy :: any do
		live[key] = value
	end
	session.changes += 1
	publish(session)
	queueSync(session)
	DataService.Changed:Fire(player, reason)
	return true
end

-- Saves now (yields). Use after payouts, purchases and receipts. Requests within 7 s merge into one write.
function DataService:SaveNowAsync(player: Player, reason: string): boolean
	local session = sessions[player]
	if not session then
		return false
	end
	if shuttingDown then
		return true -- the shutdown release writes everything
	end
	local wanted = session.changes
	while session.saving or os.clock() - session.lastWrite < minSpacing() do
		if session.savedChanges >= wanted and not session.saving then
			return true
		end
		if session.ended or session.released then
			return session.released
		end
		task.wait(0.2)
	end
	if session.savedChanges >= wanted and wanted > 0 then
		return true
	end
	local ok = writeAsync(session, false)
	if not ok then
		warn(`[Data] SaveNowAsync ({reason}) failed for {player.Name}`)
	end
	return ok
end

-- Saves and unlocks the profile (leaving, teleporting). Idempotent.
function DataService:ReleaseAsync(player: Player): boolean
	local session = sessions[player]
	if not session then
		return true
	end
	if session.releasing then
		while not session.released and not session.ended do
			task.wait(0.1)
		end
		return session.released
	end
	session.releasing = true
	releasingUsers[session.userId] = true
	local ok = writeAsync(session, true)
	if not ok then
		-- Retry once more after the backoff; the lock goes stale (or is stolen) if this fails too.
		ok = writeAsync(session, true)
	end
	session.ended = true
	if sessions[player] == session then
		sessions[player] = nil
	end
	releasingUsers[session.userId] = nil
	return ok
end

-- Runs (max ShutdownHookSeconds) before the final saves, e.g. RoundService settling the running round.
function DataService:OnBeforeShutdown(fn: () -> ())
	table.insert(hooks, fn)
end

-- Game calendar time (os.time() plus the Studio test offset).
function DataService:Now(): number
	return Clock.now()
end

function DataService:IsMemory(): boolean
	return backend ~= nil and (backend :: Backend).kind == "Memory"
end

-- Sends the full ProfileSync now (throttled).
function DataService:Sync(player: Player)
	local session = sessions[player]
	if session then
		queueSync(session)
	end
end

-- Private Crew: release the profile before a teleport; Update returns false from now on.
function DataService:PrepareTeleportAsync(player: Player): boolean
	player:SetAttribute(MetaTags.Teleporting, true)
	return self:ReleaseAsync(player)
end

-- After TeleportInitFailed: load the profile again.
function DataService:CancelTeleport(player: Player)
	player:SetAttribute(MetaTags.Teleporting, nil)
	if not sessions[player] and player.Parent then
		task.spawn(loadPlayer, player)
	end
end

-- Studio test helpers (MetaDevService) ---------------------------------------------------------------------------

function DataService:DevSetMock(failRate: number, latencySeconds: number)
	if RunService:IsStudio() then
		mock.FailRate = math.clamp(failRate, 0, 1)
		mock.LatencySeconds = math.clamp(latencySeconds, 0, 10)
		print(`[Data] mock: FailRate {mock.FailRate}, LatencySeconds {mock.LatencySeconds}`)
	end
end

-- Runs a raw transform on a stored record (e.g. write a foreign lock). Studio only.
function DataService:DevUpdateRecord(userId: number, transform: (any) -> any): (boolean, any)
	if not RunService:IsStudio() then
		return false, "Studio only"
	end
	local store = waitForBackend()
	return pcall(store.update, D.KeyPrefix .. userId, userId, transform)
end

-- Replaces the profile with fresh defaults (keeps the session and lock). Studio only.
function DataService:DevResetAsync(player: Player): boolean
	if not RunService:IsStudio() then
		return false
	end
	local ok = self:Update(player, "DevReset", function(data)
		local fresh = defaults() :: any
		local live = data :: any
		for key in live do
			live[key] = nil
		end
		for key, value in fresh do
			live[key] = value
		end
	end)
	if ok then
		self:SaveNowAsync(player, "DevReset")
	end
	return ok
end

-- Releases the session, lets `transform` rewrite the stored record, then loads again. Studio only.
function DataService:DevReloadAsync(player: Player, transform: ((any) -> any)?): boolean
	if not RunService:IsStudio() then
		return false
	end
	self:ReleaseAsync(player)
	if transform then
		self:DevUpdateRecord(player.UserId, transform)
	end
	loadFailed[player] = nil
	task.spawn(loadPlayer, player)
	return self:WaitForData(player, 40) ~= nil
end

-- Lifecycle --------------------------------------------------------------------------------------------------

local SETTINGS = D.SettingsKeys

local function onSaveSettings(player: Player, values: any)
	if type(values) ~= "table" then
		return
	end
	local clean: { [string]: any } = {}
	for key, value in values do
		local spec = if type(key) == "string" then SETTINGS[key] else nil
		if spec then
			if spec.Kind == "boolean" and type(value) == "boolean" then
				clean[key] = value
			elseif spec.Kind == "number" and type(value) == "number" and value == value then
				clean[key] = math.clamp(value, spec.Min, spec.Max)
			end
		end
	end
	if next(clean) then
		DataService:Update(player, "Settings", function(data)
			for key, value in clean do
				data.settings[key] = value
			end
		end)
	end
end

local function onTipSeen(player: Player, tipId: any)
	local id = RequestGuard.id(tipId)
	if not id or not table.find(D.TipIds, id) then
		return
	end
	DataService:Update(player, "TipSeen", function(data)
		data.seenTips[id] = math.min((data.seenTips[id] or 0) + 1, D.MaxTipShows)
	end)
end

function DataService:Start()
	task.spawn(function()
		backend = chooseBackend()
	end)

	RequestGuard.on("ProfileRequest", function(player: Player)
		local session = sessions[player]
		if session then
			queueSync(session)
		end
	end, { burst = 1, perSecond = 0.5 })
	RequestGuard.on("SaveSettings", onSaveSettings, { burst = 2, perSecond = 0.5 })
	RequestGuard.on("TipSeen", onTipSeen)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		loadFailed[player] = nil
		local session = sessions[player]
		if not session then
			return
		end
		local seconds = math.floor(os.clock() - session.startedAt)
		DataService:Update(player, "Leave", function(data)
			data.stats.playSeconds = (data.stats.playSeconds or 0) + seconds
			data.lastSeen = Clock.now()
		end)
		DataService.Leaving:Fire(player, seconds)
		task.spawn(function()
			-- During a shutdown the round is settled first (OnBeforeShutdown hooks).
			local waitUntil = os.clock() + D.ShutdownHookSeconds
			while shuttingDown and not hooksFinished and os.clock() < waitUntil do
				task.wait(0.1)
			end
			DataService:ReleaseAsync(player)
		end)
	end)

	-- Autosave: every session once per interval, spread out; always writes (refreshes the lock time).
	task.spawn(function()
		while not shuttingDown do
			local list: { Session } = {}
			for _, session in sessions do
				table.insert(list, session)
			end
			if #list == 0 then
				task.wait(D.AutosaveSeconds)
			else
				local step = D.AutosaveSeconds / #list
				for _, session in list do
					task.wait(step)
					if shuttingDown then
						break
					end
					if sessions[session.player] == session and not session.releasing then
						local budgetOk = true
						if backend and (backend :: Backend).kind == "DataStore" then
							local okBudget, budget = pcall(function()
								return DataStoreService:GetRequestBudgetForRequestType(
									Enum.DataStoreRequestType.UpdateAsync
								)
							end)
							budgetOk = not okBudget or budget >= 2 * #Players:GetPlayers()
						end
						if budgetOk then
							task.spawn(writeAsync, session, false)
						end
					end
				end
			end
		end
	end)

	game:BindToClose(function()
		shuttingDown = true
		local started = os.clock()
		local hooksDone = 0
		for _, fn in hooks do
			task.spawn(function()
				local ok, err = pcall(fn :: any)
				if not ok then
					warn(`[Data] shutdown hook failed: {err}`)
				end
				hooksDone += 1
			end)
		end
		while hooksDone < #hooks and os.clock() - started < D.ShutdownHookSeconds do
			task.wait(0.1)
		end
		hooksFinished = true
		local total, done, saved = 0, 0, 0
		for player in sessions do
			total += 1
			task.spawn(function()
				if DataService:ReleaseAsync(player) then
					saved += 1
				end
				done += 1
			end)
		end
		while
			(done < total or next(releasingUsers) ~= nil)
			and os.clock() - started < D.ShutdownTimeoutSeconds
		do
			task.wait(0.1)
		end
		print(`[Data] released {saved}/{total} in {string.format("%.1f", os.clock() - started)} s`)
	end)
end

return DataService
