-- Run via the Studio MCP: execute_luau, datamodel "Edit".
-- Rebuilds ServerStorage.Props from the mesh and texture IDs in tools/props.json
-- (for example if the place was ever saved without props). Existing props are left in place.
local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")

local PROPS = {
	{ name = "AuctionClock", mesh = "rbxassetid://122132521072981", texture = "rbxassetid://111814495828114", size = Vector3.new(15.818, 16.001, 6.493) },
	{ name = "Barge", mesh = "rbxassetid://134830253999465", texture = "rbxassetid://99200225121351", size = Vector3.new(11.381, 9.043, 18) },
	{ name = "Barrel", mesh = "rbxassetid://91962339967938", texture = "rbxassetid://102390238810600", size = Vector3.new(2.6, 2.41, 2.12) },
	{ name = "BasketTarget", mesh = "rbxassetid://106267843448072", texture = "rbxassetid://109088735716538", size = Vector3.new(4.013, 5, 3.375) },
	{ name = "Bicycle", mesh = "rbxassetid://97519321111170", texture = "rbxassetid://134261933980295", size = Vector3.new(3.52, 4.062, 5.519) },
	{ name = "BigMixer", mesh = "rbxassetid://88875206015434", texture = "rbxassetid://117335720652606", size = Vector3.new(4.871, 8, 3.282) },
	{ name = "BlackTulipPot", mesh = "rbxassetid://130119083061333", texture = "rbxassetid://97686124967851", size = Vector3.new(2.78, 5, 2.78) },
	{ name = "BulbBag", mesh = "rbxassetid://74317477546469", texture = "rbxassetid://113870597879323", size = Vector3.new(1.049, 1.2, 0.983) },
	{ name = "BulbBarrel", mesh = "rbxassetid://121536748472007", texture = "rbxassetid://140481508771680", size = Vector3.new(2.251, 3, 2.255) },
	{ name = "CakeStand", mesh = "rbxassetid://87289623178198", texture = "rbxassetid://116059425246311", size = Vector3.new(2.758, 4, 2.782) },
	{ name = "CardboardGuard", mesh = "rbxassetid://114280437371620", texture = "rbxassetid://75651972028814", size = Vector3.new(3.553, 6, 2.551) },
	{ name = "CashDrawer", mesh = "rbxassetid://81138726534898", texture = "rbxassetid://119636170959679", size = Vector3.new(1.471, 1.495, 2) },
	{ name = "Chandelier", mesh = "rbxassetid://119291566008939", texture = "rbxassetid://73681875157875", size = Vector3.new(2.689, 3, 2.71) },
	{ name = "CheeseCube", mesh = "rbxassetid://96212946497285", texture = "rbxassetid://81880244806693", size = Vector3.new(1.69, 1.2, 1.901) },
	{ name = "CheeseGrater", mesh = "rbxassetid://71004717720510", texture = "rbxassetid://119912570495384", size = Vector3.new(2.238, 2.5, 2.201) },
	{ name = "CheesePress", mesh = "rbxassetid://128056277975677", texture = "rbxassetid://93820357537164", size = Vector3.new(3.839, 6, 3.513) },
	{ name = "CheeseWheel", mesh = "rbxassetid://73172573620854", texture = "rbxassetid://70554462180714", size = Vector3.new(2.999, 0.885, 3) },
	{ name = "CheeseWheelTall", mesh = "rbxassetid://76143093444819", texture = "rbxassetid://140049270952905", size = Vector3.new(1.117, 1.6, 1.125) },
	{ name = "ChocolateFountain", mesh = "rbxassetid://100494300190835", texture = "rbxassetid://136223807416183", size = Vector3.new(4.289, 6, 4.312) },
	{ name = "ChocolateSlab", mesh = "rbxassetid://133508277229354", texture = "rbxassetid://119921798014929", size = Vector3.new(2.996, 1.118, 3) },
	{ name = "CocoaSackPile", mesh = "rbxassetid://121119151553813", texture = "rbxassetid://101089031737511", size = Vector3.new(9.081, 5.6, 9.016) },
	{ name = "Crate", mesh = "rbxassetid://95004689267588", texture = "rbxassetid://100986554474392", size = Vector3.new(4, 3.821, 3.987) },
	{ name = "CrtTv", mesh = "rbxassetid://122892866806043", texture = "rbxassetid://104888568793758", size = Vector3.new(2.151, 3.6, 2.054) },
	{ name = "DelftVase", mesh = "rbxassetid://126904061091540", texture = "rbxassetid://120144915919137", size = Vector3.new(2.179, 3, 2.097) },
	{ name = "DisplayCounter", mesh = "rbxassetid://124607370569079", texture = "rbxassetid://94795454855240", size = Vector3.new(2.869, 4, 2.647) },
	{ name = "Dumpster", mesh = "rbxassetid://93507946135186", texture = "rbxassetid://128728270861952", size = Vector3.new(3.181, 5.6, 3.216) },
	{ name = "FlowerTrolley", mesh = "rbxassetid://130035516795868", texture = "rbxassetid://114765645765922", size = Vector3.new(5.102, 6.5, 5.307) },
	{ name = "FlowerTruck", mesh = "rbxassetid://89974711435134", texture = "rbxassetid://105737249634088", size = Vector3.new(8.863, 10.358, 16) },
	{ name = "Forklift", mesh = "rbxassetid://94517248461468", texture = "rbxassetid://130828442981700", size = Vector3.new(4, 5.539, 6.731) },
	{ name = "GoldenGouda", mesh = "rbxassetid://111314658249106", texture = "rbxassetid://80663204516216", size = Vector3.new(4, 1.989, 3.99) },
	{ name = "GoldenPraline", mesh = "rbxassetid://98709620607455", texture = "rbxassetid://138765703786587", size = Vector3.new(2.173, 2.5, 2.19) },
	{ name = "Kennel", mesh = "rbxassetid://87501583784307", texture = "rbxassetid://103121969772012", size = Vector3.new(3.931, 4.83, 5) },
	{ name = "Keycard", mesh = "rbxassetid://109186404230771", texture = "rbxassetid://102336384191545", size = Vector3.new(0.465, 1.2, 0.184) },
	{ name = "Locker", mesh = "rbxassetid://72613639391362", texture = "rbxassetid://132858889987218", size = Vector3.new(4.328, 7, 4.005) },
	{ name = "MarketStall", mesh = "rbxassetid://70759551412887", texture = "rbxassetid://107651151064927", size = Vector3.new(7.017, 7, 4.802) },
	{ name = "PendantLamp", mesh = "rbxassetid://108475747796097", texture = "rbxassetid://108984570272205", size = Vector3.new(2.067, 3.52, 2.061) },
	{ name = "PralineBox", mesh = "rbxassetid://70724607722243", texture = "rbxassetid://125617181335887", size = Vector3.new(1.126, 1.4, 1.117) },
	{ name = "PralineTower", mesh = "rbxassetid://89654865956678", texture = "rbxassetid://79247187576223", size = Vector3.new(3.17, 6, 3.198) },
	{ name = "RailBox", mesh = "rbxassetid://97186781215166", texture = "rbxassetid://121241336531092", size = Vector3.new(1.529, 3, 1.535) },
	{ name = "Safe", mesh = "rbxassetid://109461565656222", texture = "rbxassetid://77570571987636", size = Vector3.new(2.25, 3.2, 2.521) },
	{ name = "Sofa", mesh = "rbxassetid://115954015275582", texture = "rbxassetid://86046544237923", size = Vector3.new(5.77, 3.5, 3.514) },
	{ name = "StandMirror", mesh = "rbxassetid://136054623014599", texture = "rbxassetid://86440467412903", size = Vector3.new(3.272, 7, 1.57) },
	{ name = "StreetLamp", mesh = "rbxassetid://86016392691368", texture = "rbxassetid://122891292769432", size = Vector3.new(2.289, 13, 2.278) },
	{ name = "TallCask", mesh = "rbxassetid://94645672587003", texture = "rbxassetid://125783934323922", size = Vector3.new(4.761, 6, 4.736) },
	{ name = "TipJar", mesh = "rbxassetid://134304820072708", texture = "rbxassetid://122408759067254", size = Vector3.new(1.307, 1.4, 1.308) },
	{ name = "TowTractor", mesh = "rbxassetid://79973342355202", texture = "rbxassetid://99995296620510", size = Vector3.new(2.742, 4, 4.057) },
	{ name = "TulipBalloon", mesh = "rbxassetid://112567389751761", texture = "rbxassetid://113661053257657", size = Vector3.new(30.121, 36, 24.42) },
	{ name = "TulipBox", mesh = "rbxassetid://82644917325670", texture = "rbxassetid://102385372595353", size = Vector3.new(4.375, 2.582, 2.4) },
	{ name = "TulipBoxTall", mesh = "rbxassetid://96479653119468", texture = "rbxassetid://88217394823765", size = Vector3.new(2.517, 3, 1.853) },
	{ name = "TulipBucket", mesh = "rbxassetid://98204057688826", texture = "rbxassetid://104893753931086", size = Vector3.new(1.634, 2.4, 1.607) },
	{ name = "Van", mesh = "rbxassetid://125916443324999", texture = "rbxassetid://132077415574363", size = Vector3.new(8.125, 8.381, 13.046) },
	{ name = "Windmill", mesh = "rbxassetid://110508762115216", texture = "rbxassetid://90499324716316", size = Vector3.new(27.358, 40, 24.281) },
	{ name = "Workbench", mesh = "rbxassetid://118334368327731", texture = "rbxassetid://72902017017167", size = Vector3.new(7.233, 4, 4.104) },
	{ name = "WrappingMachine", mesh = "rbxassetid://97407265834077", texture = "rbxassetid://110574372781288", size = Vector3.new(3.775, 6, 6.086) },
}

local folder = ServerStorage:FindFirstChild("Props") or Instance.new("Folder")
folder.Name = "Props"
folder.Parent = ServerStorage
local made, kept, failed = 0, 0, {}
for _, spec in PROPS do
	if folder:FindFirstChild(spec.name) then
		kept += 1
		continue
	end
	local ok, err = pcall(function()
		local part = AssetService:CreateMeshPartAsync(Content.fromUri(spec.mesh))
		part.Name = "body_geom"
		part.TextureID = spec.texture
		part.Size = spec.size
		part.Anchored = true
		local model = Instance.new("Model")
		model.Name = spec.name
		part.Parent = model
		model.PrimaryPart = part
		model.Parent = folder
	end)
	if ok then
		made += 1
	else
		table.insert(failed, spec.name .. ": " .. tostring(err))
	end
end
return `Props: {made} created, {kept} already existed, failed: {table.concat(failed, " | ")}`
