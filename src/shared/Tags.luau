--!strict
-- Names of CollectionService tags and attributes, so server and client use the same spelling.
-- (A tag is a label you attach to an object, so code can find all objects with that label.)

return table.freeze({
	-- Tags
	Electronic = "Electronic", -- knocked out by an EMP (cameras, lamps, drones)
	SecurityCamera = "SecurityCamera",
	Lamp = "Lamp",
	Guard = "Guard",
	Pryable = "Pryable", -- can be opened with the Crowbar
	GadgetPedestal = "GadgetPedestal",
	Goal = "Goal",
	Drone = "Drone",
	Spottable = "Spottable",

	-- Attributes
	Disabled = "Disabled", -- boolean on Electronic objects
	GuardState = "GuardState",
	Crouching = "Crouching",
	Operating = "Operating", -- player is flying a drone or watching camera feeds
	Gadgets = "Gadgets", -- comma-separated list of gadget names on the player
	Slots = "Slots",
	Charges = "Charges_", -- prefix: Charges_EMP etc.
	Owner = "Owner", -- UserId of the owner (drone)
	SpotKind = "SpotKind", -- kind of ping icon for this object
})
