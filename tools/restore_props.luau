-- Run via the Studio MCP: execute_luau, datamodel "Edit".
-- Rebuilds ServerStorage.Props from the mesh and texture IDs in tools/props.json
-- (for example if the place was ever saved without props). Existing props are left in place.
local AssetService = game:GetService("AssetService")
local ServerStorage = game:GetService("ServerStorage")

local PROPS = {
	{ name = "Barrel", mesh = "rbxassetid://91962339967938", texture = "rbxassetid://102390238810600", size = Vector3.new(2.6, 2.41, 2.12) },
	{ name = "Bicycle", mesh = "rbxassetid://97519321111170", texture = "rbxassetid://134261933980295", size = Vector3.new(3.52, 4.062, 5.519) },
	{ name = "CheeseWheel", mesh = "rbxassetid://73172573620854", texture = "rbxassetid://70554462180714", size = Vector3.new(2.999, 0.885, 3) },
	{ name = "Crate", mesh = "rbxassetid://95004689267588", texture = "rbxassetid://100986554474392", size = Vector3.new(4, 3.821, 3.987) },
	{ name = "Forklift", mesh = "rbxassetid://94517248461468", texture = "rbxassetid://130828442981700", size = Vector3.new(4, 5.539, 6.731) },
	{ name = "GoldenGouda", mesh = "rbxassetid://111314658249106", texture = "rbxassetid://80663204516216", size = Vector3.new(4, 1.989, 3.99) },
	{ name = "Kennel", mesh = "rbxassetid://87501583784307", texture = "rbxassetid://103121969772012", size = Vector3.new(3.931, 4.83, 5) },
	{ name = "PendantLamp", mesh = "rbxassetid://108475747796097", texture = "rbxassetid://108984570272205", size = Vector3.new(2.067, 3.52, 2.061) },
	{ name = "StreetLamp", mesh = "rbxassetid://86016392691368", texture = "rbxassetid://122891292769432", size = Vector3.new(2.289, 13, 2.278) },
	{ name = "TulipBox", mesh = "rbxassetid://82644917325670", texture = "rbxassetid://102385372595353", size = Vector3.new(4.375, 2.582, 2.4) },
	{ name = "TulipBoxTall", mesh = "rbxassetid://96479653119468", texture = "rbxassetid://88217394823765", size = Vector3.new(2.517, 3, 1.853) },
	{ name = "Van", mesh = "rbxassetid://125916443324999", texture = "rbxassetid://132077415574363", size = Vector3.new(8.125, 8.381, 13.046) },
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
