--!strict
-- Catalog (owner: meta): every cosmetic and gadget a player can own. Pure data (no Roblox APIs), readable on the
-- client (mirror, gadget rack) and in Lune tests. Source: docs/beta-spec-meta.md §3.1 and §5.4.
--
-- Kind:   "Mask" | "Hat" | "Van" | "Gadget"
-- Source: "Starter" | "Rank" | "Shop" | "MostWanted" | "Collection" | "Mastery" | "Stars"
-- Free:   owned automatically once Rank >= MinRank (starter and rank items). Everything else lives in `owned`.
-- Price:  only Shop items have one (Cash). Robux items arrive at launch (kept apart in `robuxOwned`).
-- Colors are {r, g, b} 0–255; Fallback is the code-built look used until a model exists in
-- ReplicatedStorage.Cosmetics.<Id> (offset is relative to the face/hat attachment, in studs).
-- A Gadget only appears in the game when mechanics defines Config.Gadgets[<Id>].

export type Fallback = {
	Shape: string, -- "Block" | "Ball" | "Cylinder" | "Wedge"
	Size: { number },
	Color: { number },
	Offset: { number },
	Material: string?,
}

export type Item = {
	Id: string,
	Kind: string,
	Name: string,
	Price: number?,
	MinRank: number,
	Source: string,
	Free: boolean?,
	Color: { number }?, -- vans: paint colour
	Material: string?, -- vans: paint material (Enum.Material name)
	Fallback: Fallback?,
	Blurb: string?,
}

local function mask(
	id: string,
	name: string,
	price: number?,
	minRank: number,
	source: string,
	fb: Fallback
): Item
	return {
		Id = id,
		Kind = "Mask",
		Name = name,
		Price = price,
		MinRank = minRank,
		Source = source,
		Fallback = fb,
	}
end

local function hat(
	id: string,
	name: string,
	price: number?,
	minRank: number,
	source: string,
	fb: Fallback
): Item
	return {
		Id = id,
		Kind = "Hat",
		Name = name,
		Price = price,
		MinRank = minRank,
		Source = source,
		Fallback = fb,
	}
end

local function van(
	id: string,
	name: string,
	price: number?,
	minRank: number,
	source: string,
	color: { number }
): Item
	return {
		Id = id,
		Kind = "Van",
		Name = name,
		Price = price,
		MinRank = minRank,
		Source = source,
		Color = color,
		Material = "SmoothPlastic",
	}
end

local function face(shape: string, size: { number }, color: { number }, material: string?): Fallback
	return { Shape = shape, Size = size, Color = color, Offset = { 0, 0, -0.15 }, Material = material }
end

local function top(shape: string, size: { number }, color: { number }, material: string?): Fallback
	return { Shape = shape, Size = size, Color = color, Offset = { 0, 0.35, 0 }, Material = material }
end

local items: { Item } = {
	-- Masks (the key cosmetic: auto Mask Up)
	mask("PaperBag", "Paper Bag", nil, 1, "Starter", face("Block", { 1.3, 1.4, 1.3 }, { 196, 160, 110 })),
	mask(
		"DisguiseGlasses",
		"Disguise Glasses",
		500,
		1,
		"Shop",
		face("Block", { 1.2, 0.5, 0.3 }, { 30, 30, 30 })
	),
	mask(
		"CheeseWedgeMask",
		"Cheese Wedge Mask",
		750,
		1,
		"Shop",
		face("Wedge", { 1.2, 1.2, 0.5 }, { 255, 204, 64 })
	),
	mask(
		"RubberDuckMask",
		"Rubber Duck Mask",
		1000,
		1,
		"Shop",
		face("Ball", { 1.3, 1.3, 1.3 }, { 255, 221, 0 })
	),
	mask("TulipMask", "Tulip Mask", 1500, 1, "Shop", face("Ball", { 1.2, 1.4, 0.6 }, { 230, 60, 80 })),
	mask(
		"KlompMask",
		"Klomp Mask",
		2000,
		1,
		"Shop",
		face("Block", { 1.0, 0.8, 1.6 }, { 214, 170, 100 }, "Wood")
	),
	mask("KarelMask", "Karel Mask", 2500, 1, "Shop", face("Block", { 1.2, 1.2, 0.4 }, { 120, 140, 160 })),
	mask(
		"GoldenGoudaMask",
		"Golden Gouda Mask",
		3000,
		7,
		"Shop",
		face("Cylinder", { 0.4, 1.3, 1.3 }, { 255, 190, 30 }, "Metal")
	),
	mask("BoefSnout", "Boef Snout", nil, 1, "MostWanted", face("Ball", { 0.8, 0.6, 0.8 }, { 90, 60, 40 })),
	mask(
		"NightShiftGoggles",
		"Night Shift Goggles",
		nil,
		1,
		"MostWanted",
		face("Block", { 1.2, 0.5, 0.4 }, { 40, 120, 60 })
	),
	mask(
		"CheeseMonocle",
		"Cheese Monocle",
		nil,
		1,
		"Collection",
		face("Cylinder", { 0.1, 0.5, 0.5 }, { 255, 210, 80 })
	),
	mask(
		"GoudaVisor",
		"Gouda Visor",
		nil,
		1,
		"Mastery",
		face("Block", { 1.3, 0.6, 0.4 }, { 255, 180, 0 }, "Neon")
	),
	mask("PralineMask", "Praline Mask", nil, 1, "Mastery", face("Ball", { 1.3, 1.3, 0.6 }, { 110, 60, 30 })),
	mask("BulbHelmet", "Bulb Helmet", nil, 1, "Mastery", face("Ball", { 1.5, 1.6, 1.5 }, { 160, 200, 120 })),
	mask(
		"StarShades",
		"Star Shades",
		nil,
		1,
		"Stars",
		face("Block", { 1.3, 0.5, 0.3 }, { 255, 230, 60 }, "Neon")
	),
	mask(
		"AllStarMask",
		"All-Star Mask",
		nil,
		1,
		"Stars",
		face("Block", { 1.3, 1.3, 0.4 }, { 255, 240, 120 }, "Neon")
	),

	-- Hats
	hat("FlatCap", "Flat Cap", nil, 2, "Rank", top("Cylinder", { 0.3, 1.4, 1.4 }, { 80, 70, 60 })),
	hat("RedBeanie", "Red Beanie", 500, 2, "Shop", top("Ball", { 1.3, 0.8, 1.3 }, { 200, 40, 40 })),
	hat("ChefToque", "Chef's Toque", 1000, 2, "Shop", top("Cylinder", { 1.2, 1.1, 1.1 }, { 245, 245, 245 })),
	hat(
		"CheeseWheelHat",
		"Cheese Wheel Hat",
		1500,
		2,
		"Shop",
		top("Cylinder", { 0.5, 1.5, 1.5 }, { 255, 204, 64 })
	),
	hat(
		"CheeseCrown",
		"Cheese Crown",
		3000,
		7,
		"Shop",
		top("Cylinder", { 0.6, 1.3, 1.3 }, { 255, 190, 30 }, "Metal")
	),
	hat(
		"KarelsBucket",
		"Karel's Bucket",
		nil,
		1,
		"MostWanted",
		top("Cylinder", { 1.0, 1.2, 1.2 }, { 150, 150, 160 })
	),
	hat(
		"SirenHat",
		"Siren Hat",
		nil,
		1,
		"MostWanted",
		top("Ball", { 0.8, 0.8, 0.8 }, { 40, 90, 255 }, "Neon")
	),

	-- Van colours
	van("GetawayWhite", "Getaway White", nil, 1, "Starter", { 235, 235, 230 }),
	van("CheddarOrange", "Cheddar Orange", 5000, 4, "Shop", { 240, 140, 30 }),
	van("CanalBlue", "Canal Blue", 5000, 4, "Shop", { 40, 90, 160 }),
	van("TulipRed", "Tulip Red", 5000, 4, "Shop", { 200, 40, 60 }),
	van("GoudaGold", "Gouda Gold", nil, 15, "Rank", { 255, 190, 30 }),

	-- Gadgets (the Crowbar is always carried and is not in the catalog)
	{
		Id = "Drone",
		Kind = "Gadget",
		Name = "Drone",
		MinRank = 1,
		Source = "Starter",
		Blurb = "Fly and spot guards",
	},
	{
		Id = "Noisemaker",
		Kind = "Gadget",
		Name = "Noisemaker",
		MinRank = 1,
		Source = "Starter",
		Blurb = "Lures one guard away",
	},
	{
		Id = "EMP",
		Kind = "Gadget",
		Name = "EMP",
		MinRank = 1,
		Source = "Starter",
		Blurb = "Kills cameras and lamps",
	},
	{
		Id = "BubbleBlaster",
		Kind = "Gadget",
		Name = "Bubble Blaster",
		MinRank = 1,
		Source = "Starter",
		Blurb = "Bubbles a guard 8 s",
	},
	{ Id = "Periscope", Kind = "Gadget", Name = "Periscope", Price = 2000, MinRank = 2, Source = "Shop" },
	{
		Id = "LockpickSet",
		Kind = "Gadget",
		Name = "Lockpick Set",
		Price = 3000,
		MinRank = 5,
		Source = "Shop",
	},
	{
		Id = "FakeDelivery",
		Kind = "Gadget",
		Name = "Fake Delivery",
		Price = 4000,
		MinRank = 8,
		Source = "Shop",
	},
}

local byId: { [string]: Item } = {}
for _, item in items do
	if item.Source == "Starter" or item.Source == "Rank" then
		item.Free = true
	end
	byId[item.Id] = item
end

local Catalog = {
	List = items,
	ById = byId,
	-- Starter equipment (every new profile).
	DefaultEquipped = { Mask = "PaperBag", Van = "GetawayWhite" } :: { [string]: string },
	DefaultLoadout = { "Noisemaker", "BubbleBlaster" },
	AlwaysCarried = "Crowbar",
	Slots = { "Mask", "Hat", "Van" },
}

function Catalog.get(id: string): Item?
	return byId[id]
end

return Catalog
