-- Uitvoeren via de Studio MCP: execute_luau, datamodel "Edit".
-- 1) Bouwt het level opnieuw met verse kopieën van de servermodules (geen require-cache).
--    MapService:Init() bouwt de standaard-heist (src/server/Map/Registry); zet HEIST voor een andere heist.
-- 2) Stuurt alle zichtbare parts, lichten en de AI-meshes (met kleuren uit hun textuur)
--    naar tools/preview/receiver.py op 127.0.0.1:35001. HttpEnabled staat alleen even aan.
local HEIST: string? = nil -- bv. "GoldenWheel"; nil = de standaard-heist

local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")

local server = game:GetService("ServerScriptService").Server
local tmp = server:Clone()
for _, d in tmp:GetDescendants() do
	if d:IsA("Script") then
		d:Destroy()
	end
end
tmp.Parent = ServerStorage
local okB, errB = pcall(function()
	local MapService = require(tmp.Services.MapService)
	MapService:Init()
	if HEIST then
		MapService:Build(HEIST)
	end
end)
tmp:Destroy()
if not okB then
	return "build faalde: " .. tostring(errB)
end
local level = workspace.Level

local function r(n)
	return math.floor(n * 1000 + 0.5) / 1000
end
local parts, lights, meshInfo = {}, {}, {}
local partCount = 0
for _, d in level:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
	if d:IsA("BasePart") and d.Transparency < 0.98 then
		local kind = "Block"
		if d:IsA("MeshPart") then
			kind = "mesh"
			if not meshInfo[d.MeshId] then
				meshInfo[d.MeshId] = { tex = d.TextureID, size = { d.MeshSize.X, d.MeshSize.Y, d.MeshSize.Z } }
			end
		elseif d:IsA("WedgePart") then
			kind = "Wedge"
		elseif d:IsA("Part") then
			kind = d.Shape.Name
		end
		local c = { d.CFrame:GetComponents() }
		for i, v in c do
			c[i] = r(v)
		end
		table.insert(parts, {
			k = kind,
			id = if kind == "mesh" then (d :: MeshPart).MeshId else nil,
			cf = c,
			s = { r(d.Size.X), r(d.Size.Y), r(d.Size.Z) },
			c = d.Color:ToHex(),
			m = d.Material.Name,
			t = r(d.Transparency),
			n = d.Name,
		})
	elseif (d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight")) and d.Parent and d.Parent:IsA("BasePart") then
		local p = d.Parent :: BasePart
		local dir = nil
		if not d:IsA("PointLight") then
			local w = p.CFrame:VectorToWorldSpace(Vector3.FromNormalId((d :: any).Face))
			dir = { r(w.X), r(w.Y), r(w.Z) }
		end
		table.insert(lights, {
			type = d.ClassName,
			p = { r(p.Position.X), r(p.Position.Y), r(p.Position.Z) },
			dir = dir,
			range = d.Range,
			b = d.Brightness,
			c = d.Color:ToHex(),
			on = d.Enabled,
			angle = if d:IsA("PointLight") then nil else (d :: any).Angle,
		})
	end
end

local posts = { { name = "level.json", body = HttpService:JSONEncode({ parts = parts, lights = lights }) } }
local errors = {}
local mi = 0
for meshId, info in meshInfo do
	mi += 1
	local ok, err = pcall(function()
		local em = AssetService:CreateEditableMeshAsync(Content.fromUri(meshId))
		local img, imgSize, pixels
		if info.tex and info.tex ~= "" then
			img = AssetService:CreateEditableImageAsync(Content.fromUri(info.tex))
			imgSize = img.Size
			pixels = img:ReadPixelsBuffer(Vector2.zero, imgSize)
		end
		local index, verts, n = {}, {}, 0
		for _, vid in em:GetVertices() do
			index[vid] = n
			n += 1
			local p = em:GetPosition(vid)
			table.insert(verts, r(p.X))
			table.insert(verts, r(p.Y))
			table.insert(verts, r(p.Z))
		end
		local faces, cols = {}, {}
		for _, fid in em:GetFaces() do
			local fv = em:GetFaceVertices(fid)
			local fuv = if pixels then em:GetFaceUVs(fid) else nil
			for i = 1, 3 do
				table.insert(faces, index[fv[i]])
				if pixels and fuv then
					local uv = em:GetUV(fuv[i])
					local x = math.clamp(math.floor(uv.X * imgSize.X), 0, imgSize.X - 1)
					local y = math.clamp(math.floor(uv.Y * imgSize.Y), 0, imgSize.Y - 1)
					local o = (y * imgSize.X + x) * 4
					table.insert(
						cols,
						string.format("%02x%02x%02x", buffer.readu8(pixels, o), buffer.readu8(pixels, o + 1), buffer.readu8(pixels, o + 2))
					)
				end
			end
		end
		table.insert(posts, {
			name = "mesh" .. mi .. ".json",
			body = HttpService:JSONEncode({ id = meshId, v = verts, f = faces, col = cols, size = info.size }),
		})
		em:Destroy()
		if img then
			img:Destroy()
		end
	end)
	if not ok then
		table.insert(errors, meshId .. ": " .. tostring(err))
	end
end

local wasEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local failed = {}
for _, p in posts do
	local ok, res = pcall(function()
		return HttpService:PostAsync("http://127.0.0.1:35001/" .. p.name, p.body, Enum.HttpContentType.ApplicationJson)
	end)
	if not ok then
		table.insert(failed, p.name .. ": " .. tostring(res))
	end
end
HttpService.HttpEnabled = wasEnabled
return string.format(
	"parts=%d (zichtbaar %d) lights=%d meshes=%d posts=%d mislukt=[%s] fouten=[%s] Http=%s",
	partCount,
	#parts,
	#lights,
	mi,
	#posts,
	table.concat(failed, " | "),
	table.concat(errors, " | "),
	tostring(HttpService.HttpEnabled)
)
