--!strict
-- The Garage (beta-spec-ux §1.2, beta-spec-meta §5): Cash / Rank / Rep bar, contracts chip, the
-- "LEAVING IN 12" countdown, station prompts that open screens (heist board, gadget rack, workbench,
-- mirror, trophy wall), your trophies on the wall, and refusal toasts from meta (`MetaResult`).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Lib = script.Parent.Parent.Lib
local Audio = require(Lib.Audio)
local CharState = require(Lib.CharState)
local Hud = require(Lib.Hud)
local Juice = require(Lib.Juice)
local Profile = require(Lib.Profile)
local RoundState = require(Lib.RoundState)
local Screens = require(Lib.Screens)
local Theme = require(Lib.Theme)
local UiText = require(Lib.UiText)

local ScreensFolder = script.Parent.Parent.Screens
local Contracts = require(ScreensFolder.Contracts)
local GadgetRack = require(ScreensFolder.GadgetRack)
local HeistBoard = require(ScreensFolder.HeistBoard)
local Mirror = require(ScreensFolder.Mirror)
local PerkTree = require(ScreensFolder.PerkTree)
local SettingsScreen = require(ScreensFolder.SettingsScreen)
local TrophyWall = require(ScreensFolder.TrophyWall)

local OnboardingController = require(script.Parent.OnboardingController)

local GarageController = {}

local player = Players.LocalPlayer
local C = Theme.Colors

-- Station tag (meta block in Tags.luau) or prompt attribute "Screen" → screen name.
local STATION_SCREENS: { [string]: string } = {
	JobBoard = "HeistBoard",
	GadgetRack = "GadgetRack",
	Workbench = "PerkTree",
	Mirror = "Mirror",
	TrophyWall = "TrophyWall",
	CollectionBook = "Collection",
}

-- Meta's `OpenScreen(screen)` names (MetaConfig.Lobby.Stations) → ux screens.
local OPEN_SCREEN: { [string]: string } = {
	JobBoard = "HeistBoard",
	Gadgets = "GadgetRack",
	Perks = "PerkTree",
	Mirror = "Mirror",
	Collection = "Collection",
	Trophies = "TrophyWall",
}

local pendingInvite: { from: string, endsAt: number }? = nil
local garageBar: Frame
local cashLabel: TextLabel
local rankLabel: TextLabel
local repFill: Frame
local contractsChip: TextButton
local departLabel: TextLabel
local lastCash: number? = nil

local function screenFor(prompt: ProximityPrompt): string?
	local named = prompt:GetAttribute("Screen")
	if typeof(named) == "string" and named ~= "" then
		return named
	end
	local current: Instance? = prompt
	while current and current ~= workspace do
		for tag, screen in STATION_SCREENS do
			if CollectionService:HasTag(current, tag) then
				return screen
			end
		end
		current = current.Parent
	end
	return nil
end

local lastOpened: string? = nil
local lastOpenedAt = -math.huge

-- The station prompt opens the screen at once on this client; meta's OpenScreen then arrives too, so the
-- same screen within a second is not opened twice.
local function openScreen(name: string)
	if Screens.current() == name and lastOpened == name and os.clock() - lastOpenedAt < 1.5 then
		return
	end
	lastOpened = name
	lastOpenedAt = os.clock()
	Profile.request()
	Screens.open(name)
end

local function refreshBar()
	local mode = RoundState.statusMode()
	garageBar.Visible = mode == "Garage"
	if mode ~= "Garage" then
		departLabel.Visible = false
		return
	end
	local cash = Profile.number("cash", "Cash")
	cashLabel.Text = `● {Hud.formatNumber(cash)}`
	if lastCash and cash > lastCash then
		Juice.pop(cashLabel, 1.2)
	end
	lastCash = cash
	local rank = Profile.number("rank", "Rank")
	rankLabel.Text = `RANK {math.max(rank, 1)}`
	local into = Profile.number("repIntoRank", "RepIntoRank")
	local need = Profile.number("repForNext", "RepForNext")
	repFill.Size = UDim2.fromScale(if into and need and need > 0 then math.clamp(into / need, 0, 1) else 0, 1)
	local list = Contracts.list()
	local done = 0
	for _, contract in list do
		if contract.done == true then
			done += 1
		end
	end
	contractsChip.Visible = #list > 0
	contractsChip.Text = `CONTRACTS {done}/{#list}`
end

local function refreshDepart()
	local left = RoundState.left("VanDepartAt")
	local show = RoundState.statusMode() == "Garage" and left ~= nil and left > 0
	departLabel.Visible = show
	if show and left then
		departLabel.Text = `LEAVING IN {math.ceil(left)}`
	end
end

-- Your own trophies on the wall's TrophySlot parts (drawn locally).
local function drawTrophies()
	local view = Profile.view
	local trophies = if view and typeof(view.trophies) == "table" then view.trophies else {}
	local slots = {}
	for _, inst in CollectionService:GetTagged("TrophySlot") do
		if inst:IsA("BasePart") then
			table.insert(slots, inst)
		end
	end
	table.sort(slots, function(a, b)
		local ia, ib = a:GetAttribute("Index"), b:GetAttribute("Index")
		if typeof(ia) == "number" and typeof(ib) == "number" then
			return ia < ib
		end
		return a:GetFullName() < b:GetFullName()
	end)
	for index, slot in slots do
		local existing = slot:FindFirstChild("CC_Trophy")
		if existing then
			existing:Destroy()
		end
		local trophy = trophies[#trophies - index + 1]
		if typeof(trophy) == "table" then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "CC_Trophy"
			gui.Face = Enum.NormalId.Front
			gui.LightInfluence = 0
			gui.PixelsPerStud = 40
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.Adornee = slot
			Hud.text({
				Size = UDim2.fromScale(1, 0.6),
				Text = Theme.Loot.Main.glyph,
				TextColor3 = C.Gold,
				Display = true,
				MaxTextSize = 200,
				Stroke = 2,
			}, gui)
			Hud.text({
				Position = UDim2.fromScale(0, 0.6),
				Size = UDim2.fromScale(1, 0.4),
				Text = UiText.heist(trophy.heist).name,
				MaxTextSize = 80,
				Stroke = 2,
			}, gui)
			gui.Parent = player:WaitForChild("PlayerGui")
		end
	end
end

local REASON_FALLBACK = "Can't do that right now"

local function onResult()
	local result = Profile.result
	if not result then
		return
	end
	if result.ok then
		if result.action == "Buy" then
			Hud.toast("Bought!", C.Good, "✓")
			Audio.play("KaChing")
		elseif result.action == "Equip" then
			Hud.toast("Looking sharp", C.Good, "✓")
		elseif result.action == "Loadout" then
			Hud.toast("Gadgets packed", C.Good, "✓")
		end
	else
		local reason = if typeof(result.reason) == "string" then UiText.Reasons[result.reason] else nil
		Hud.toast(reason or REASON_FALLBACK, C.Warn)
		Audio.play("UiBack")
	end
end

function GarageController:Init()
	Screens.register(
		"HeistBoard",
		HeistBoard.create({
			onVote = function()
				OnboardingController.tourProgress(2)
			end,
			openSettings = function()
				Screens.open("Settings")
			end,
		})
	)
	Screens.register(
		"GadgetRack",
		GadgetRack.create({
			onLoadout = function()
				OnboardingController.tourProgress(1)
			end,
		})
	)
	Screens.register("Mirror", Mirror.create())
	Screens.register("TrophyWall", TrophyWall.create())
	Screens.register("Collection", TrophyWall.createCollection())
	Screens.register("PrivateCrew", {
		title = "PRIVATE CREW",
		size = Vector2.new(460, 260),
		build = function(body: Frame): (() -> ())?
			local invite = pendingInvite
			if not invite then
				return nil
			end
			Hud.text({
				Size = UDim2.new(1, 0, 0, 60),
				Text = `{invite.from} asks: play in your own closed server?`,
				MaxTextSize = 20,
			}, body)
			local countdown = Hud.text({
				Position = UDim2.fromOffset(0, 62),
				Size = UDim2.new(1, 0, 0, 24),
				Text = "",
				TextColor3 = C.Muted,
				MaxTextSize = 16,
			}, body)
			local row =
				Hud.frame({ Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 64) }, body)
			Hud.list(
				row,
				Enum.FillDirection.Horizontal,
				12,
				Enum.HorizontalAlignment.Center,
				Enum.VerticalAlignment.Center
			)
			local function answer(yes: boolean)
				pendingInvite = nil
				Net.request("PrivateCrewAnswer", yes)
				Screens.close("PrivateCrew")
			end
			local yes = Hud.button(
				{ Size = UDim2.fromOffset(150, 56), Text = "YES", Kind = "good", LayoutOrder = 1 },
				row
			)
			local no = Hud.button(
				{ Size = UDim2.fromOffset(150, 56), Text = "NO", Kind = "secondary", LayoutOrder = 2 },
				row
			)
			yes.Activated:Connect(function()
				answer(true)
			end)
			no.Activated:Connect(function()
				answer(false)
			end)
			local alive = true
			task.spawn(function()
				while alive do
					local left = invite.endsAt - os.clock()
					if left <= 0 then
						pendingInvite = nil
						Screens.close("PrivateCrew")
						break
					end
					countdown.Text = `{math.ceil(left)} s`
					task.wait(0.25)
				end
			end)
			return function()
				alive = false
			end
		end,
	})
	Screens.register("PerkTree", PerkTree.create())
	Screens.register("Contracts", Contracts.create())
	Screens.register("Settings", SettingsScreen.create())

	garageBar = Hud.panel({
		Name = "GarageBar",
		Size = UDim2.fromOffset(340, 56),
		LayoutOrder = 1,
		Visible = false,
	}, Hud.slot("Status"))
	cashLabel = Hud.text({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.fromOffset(150, 30),
		Text = "● 0",
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Display = true,
		MaxTextSize = 26,
		Stroke = 1.5,
	}, garageBar)
	rankLabel = Hud.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(120, 26),
		Text = "RANK 1",
		TextXAlignment = Enum.TextXAlignment.Right,
		Display = true,
		MaxTextSize = 22,
		Stroke = 1.5,
	}, garageBar)
	local _, fill = Hud.bar(garageBar, {
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 8),
		Radius = 4,
	}, C.Info)
	repFill = fill

	contractsChip = Hud.button({
		Name = "Contracts",
		Size = UDim2.fromOffset(180, 48),
		Text = "CONTRACTS 0/3",
		Kind = "ghost",
		MaxTextSize = 16,
		LayoutOrder = 2,
		Visible = false,
	}, Hud.slot("Status"))
	contractsChip.Activated:Connect(function()
		openScreen("Contracts")
	end)

	departLabel = Hud.text({
		Name = "Depart",
		Size = UDim2.fromOffset(340, 40),
		Text = "",
		TextColor3 = C.Gold,
		Display = true,
		MaxTextSize = 34,
		Stroke = 2,
		LayoutOrder = 5,
		Visible = false,
	}, Hud.slot("Status"))
end

function GarageController:Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local screen = screenFor(prompt)
		if screen then
			openScreen(screen)
		end
	end)
	Net.on("OpenScreen", function(name: any)
		if typeof(name) == "string" then
			openScreen(OPEN_SCREEN[name] or name)
		end
	end)
	Net.on("PrivateCrewInvite", function(fromName: any, seconds: any)
		pendingInvite = {
			from = if typeof(fromName) == "string" then fromName else "A crew member",
			endsAt = os.clock() + (if typeof(seconds) == "number" then seconds else 10),
		}
		Audio.play("HintBlip")
		Screens.open("PrivateCrew")
	end)
	Profile.Changed:Connect(function(what)
		if what == "profile" then
			refreshBar()
			drawTrophies()
			for _, name in
				{ "GadgetRack", "Mirror", "TrophyWall", "Collection", "PerkTree", "Contracts", "HeistBoard" }
			do
				Screens.refresh(name)
			end
		elseif what == "board" then
			Screens.refresh("HeistBoard")
		elseif what == "result" then
			onResult()
		end
	end)
	CharState.Changed:Connect(function(name)
		if
			name == "Player:Cash"
			or name == "Player:Rank"
			or name == "Player:Rep"
			or name == "Player:RepIntoRank"
			or name == "Player:Activity"
		then
			refreshBar()
			if name == "Player:Cash" then
				Screens.refresh("Mirror")
			end
		end
	end)
	RoundState.Changed:Connect(function(name)
		if name == "RoundPhase" then
			refreshBar()
			local phase = RoundState.phase()
			if phase == "Briefing" or phase == "Heist" then
				-- Leaving the Garage closes its screens.
				local current = Screens.current()
				if
					current
					and current ~= "Settings"
					and current ~= "Payout"
					and RoundState.activity() == "Crew"
				then
					Screens.close()
				end
			end
		elseif name == "VanDepartAt" then
			refreshDepart()
		end
	end)
	CollectionService:GetInstanceAddedSignal("TrophySlot"):Connect(function()
		task.defer(drawTrophies)
	end)
	refreshBar()
	drawTrophies()
	while true do
		refreshDepart()
		task.wait(0.25)
	end
end

return GarageController
