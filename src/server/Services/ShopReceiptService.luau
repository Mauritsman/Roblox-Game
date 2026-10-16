--!strict
-- Robux receipts and game passes (owner: meta). docs/beta-spec-meta.md §7. Monetisation is OFF in the beta
-- (MetaConfig.Monetization.Enabled = false): no prompts anywhere, but the handler is installed and can be tested
-- in Studio with fake receipts (MetaDevService "DevFakeReceipt").
--
-- MarketplaceService.ProcessReceipt is set ONLY here. Each PurchaseId is granted exactly once:
--   player not here / data not loaded → NotProcessedYet (Roblox retries later)
--   receipt already in the profile    → make sure it is saved, PurchaseGranted
--   unknown or disabled product       → NotProcessedYet
--   grant + receipts[PurchaseId] in ONE Update, then SaveNowAsync; save failed → NotProcessedYet (retry lands
--   in "already in the profile").

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local MetaConfig = require(ReplicatedStorage.Shared.MetaConfig)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Ledger = require(ReplicatedStorage.Shared.Logic.Ledger)

local Clock = require(script.Parent.Parent.Meta.Clock)
local AnalyticsTracker = require(script.Parent.AnalyticsTracker)
local DataService = require(script.Parent.DataService)

local M = MetaConfig.Monetization

local ShopReceiptService = {}

-- Fired after a consumable product was granted (player, productKey), e.g. for crew fireworks later.
ShopReceiptService.Granted = Signal.new() :: Signal.Signal<Player, string>

export type Receipt = { PlayerId: number, ProductId: number, PurchaseId: string, CurrencySpent: number? }

local passOwners: { [Player]: { [string]: boolean } } = {}

local function productByKey(
	key: string
): { Id: number, Enabled: boolean, DevOnly: boolean, Kind: string, Item: string }?
	return M.Products[key]
end

local function productById(productId: number): string?
	if productId == 0 then
		return nil
	end
	for key, product in M.Products do
		if product.Id == productId then
			return key
		end
	end
	return nil
end

-- The receipt handler. `devKey` is only used by fake Studio receipts (the product id is 0 there).
function ShopReceiptService:Process(receipt: Receipt, devKey: string?): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local purchaseId = tostring(receipt.PurchaseId)
	local key = if devKey and RunService:IsStudio() then devKey else productById(receipt.ProductId)
	local product = if key then productByKey(key) else nil
	local data = if player then DataService:WaitForData(player, 10) else nil
	local enabled = product ~= nil
		and ((M.Enabled and product.Enabled) or (devKey ~= nil and RunService:IsStudio()))
		and (not product.DevOnly or RunService:IsStudio() or product.Enabled)
	local action = Ledger.decideReceipt({
		playerPresent = player ~= nil,
		dataLoaded = data ~= nil,
		alreadyProcessed = data ~= nil and data.receipts[purchaseId] ~= nil,
		productKnown = product ~= nil,
		productEnabled = enabled,
	})
	if action == "NotProcessedYet" or not player then
		if player and data and not product then
			warn(`[Receipt] unknown or disabled product {receipt.ProductId} ({purchaseId})`)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local buyer = player :: Player
	if action == "AlreadyGranted" then
		if DataService:SaveNowAsync(buyer, "Receipt") then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local def = product :: { Id: number, Enabled: boolean, DevOnly: boolean, Kind: string, Item: string }
	local productKey = key :: string
	local granted = DataService:Update(buyer, "Receipt", function(d)
		if d.receipts[purchaseId] then
			return
		end
		if def.Kind == "Item" and Catalog.get(def.Item) then
			d.robuxOwned[def.Item] = Clock.now() -- Robux items are never removed
		end
		d.purchases[productKey] = (d.purchases[productKey] or 0) + 1
		Ledger.recordReceipt(d.receipts, purchaseId, Clock.now(), MetaConfig.Data.ReceiptHistory)
	end)
	if not granted or not DataService:SaveNowAsync(buyer, "Receipt") then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	AnalyticsTracker:Custom(buyer, "ProductGranted", receipt.CurrencySpent or 0, { productKey })
	ShopReceiptService.Granted:Fire(buyer, productKey)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Game passes: cached ownership (Roblox stores it). Disabled passes and Id 0 are never checked.
function ShopReceiptService:OwnsPass(player: Player, passKey: string): boolean
	local owned = passOwners[player]
	return owned ~= nil and owned[passKey] == true
end

local function loadPasses(player: Player)
	local owned: { [string]: boolean } = {}
	passOwners[player] = owned
	for key, pass in M.Passes do
		if M.Enabled and pass.Enabled and pass.Id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and has then
				owned[key] = true
				player:SetAttribute(`Pass_{key}`, true)
			end
		end
	end
end

function ShopReceiptService:Start()
	MarketplaceService.ProcessReceipt = function(receiptInfo: any): Enum.ProductPurchaseDecision
		local ok, decision = pcall(function()
			return ShopReceiptService:Process(receiptInfo :: Receipt)
		end)
		if not ok then
			warn(`[Receipt] handler error: {decision}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, bought: boolean)
			if not bought then
				return
			end
			for key, pass in M.Passes do
				if pass.Id == passId and pass.Id ~= 0 then
					local owned = passOwners[player] or {}
					passOwners[player] = owned
					owned[key] = true
					player:SetAttribute(`Pass_{key}`, true)
				end
			end
		end
	)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPasses, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		passOwners[player] = nil
	end)
end

return ShopReceiptService
