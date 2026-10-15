--!strict
-- Namen van CollectionService-tags en attributen, zodat server en client dezelfde spelling gebruiken.
-- (Een tag is een label dat je aan een object hangt, zodat code alle objecten met dat label kan vinden.)

return table.freeze({
	-- Tags
	Electronic = "Electronic", -- valt uit door een EMP (camera's, lampen, drones)
	SecurityCamera = "SecurityCamera",
	Lamp = "Lamp",
	Guard = "Guard",
	Pryable = "Pryable", -- kan open met de Crowbar
	GadgetPedestal = "GadgetPedestal",
	Goal = "Goal",
	Drone = "Drone",
	Spottable = "Spottable",

	-- Attributen
	Disabled = "Disabled", -- boolean op Electronic-objecten
	GuardState = "GuardState",
	Crouching = "Crouching",
	Operating = "Operating", -- speler bestuurt drone of kijkt naar camerabeelden
	Gadgets = "Gadgets", -- komma-lijst van gadgetnamen op de speler
	Slots = "Slots",
	Charges = "Charges_", -- prefix: Charges_EMP enz.
	Owner = "Owner", -- UserId van de eigenaar (drone)
	SpotKind = "SpotKind", -- soort ping-icoon voor dit object
})
