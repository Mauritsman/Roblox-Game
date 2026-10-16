--!strict
-- M0 STUB (meta): default loadout for everyone.

local ShopService = {}

function ShopService:GetLoadout(_player: Player): { string }
	return { "Crowbar", "Noisemaker", "BubbleBlaster" }
end

return ShopService
