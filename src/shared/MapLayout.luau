--!strict
-- The placeholder map as plain data: one baseplate, one home base per faction (index = faction id) and the
-- capture zones. Positions are in studs on the ground plane; z points south. A real map built in Studio
-- replaces this: tag its zones "Zone", give each a "Value" attribute, and mark each faction's SpawnLocation
-- with a "HomeBase" attribute holding the faction id. tools/pacing.py reads the zone values from here.
-- Two islands share one place: War Island (the baseplate, bases, zones) and Training Island (see below).

export type Base = { x: number, z: number }
export type ZoneSpec = { name: string, x: number, z: number, size: number, value: number }
export type Treadmill = { x: number, z: number, width: number, length: number, push: number }
export type Portal = { x: number, z: number, size: number }
export type Area = { x: number, z: number, width: number, length: number }
export type TrainingIsland = {
	x: number,
	z: number,
	size: number,
	arrival: { x: number, z: number },
	returnPortal: Portal,
	treadmills: { Treadmill },
	shop: Portal,
	reserved: { prestigeAltar: Area, arenaPlots: Area },
}

local MapLayout = {
	baseplateSize = 320,
	baseSize = 16,
	bases = {
		{ x = -130, z = -130 }, -- faction 1, north west
		{ x = 130, z = -130 }, -- faction 2, north east
		{ x = 130, z = 130 }, -- faction 3, south east
		{ x = -130, z = 130 }, -- faction 4, south west
	} :: { Base },
	-- Portals on War Island, one beside each home base. Walking into one sends you to Training Island.
	warPortals = {
		{ x = -130, z = -103, size = 14 },
		{ x = 130, z = -103, size = 14 },
		{ x = 130, z = 103, size = 14 },
		{ x = -130, z = 103, size = 14 },
	} :: { Portal },
	-- Training Island: a second platform in the same place, far from War Island. All positions inside it are
	-- LOCAL to its centre (x east, z south). Everything for training and the shop is grouped here; the two
	-- "reserved" areas are kept empty for the prestige altar (Update 2) and the Mog Arena plots (Update 3).
	trainingIsland = {
		x = 700,
		z = 0,
		size = 260,
		arrival = { x = 0, z = 100 }, -- where you land from War Island
		returnPortal = { x = 0, z = 118, size = 14 }, -- walking into it sends you back to War Island
		treadmills = {
			{ x = -45, z = 40, width = 10, length = 20, push = -10 },
			{ x = -15, z = 40, width = 10, length = 20, push = -10 },
			{ x = 15, z = 40, width = 10, length = 20, push = -10 },
			{ x = 45, z = 40, width = 10, length = 20, push = -10 },
		} :: { Treadmill },
		shop = { x = 90, z = 70, size = 16 },
		reserved = {
			prestigeAltar = { x = 0, z = -20, width = 30, length = 30 },
			arenaPlots = { x = 0, z = -90, width = 240, length = 60 },
		},
	} :: TrainingIsland,
	zones = {
		{ name = "Zone_Centre", x = 0, z = 0, size = 36, value = 2 },
		{ name = "Zone_North", x = 0, z = -60, size = 28, value = 1 },
		{ name = "Zone_East", x = 60, z = 0, size = 28, value = 1 },
		{ name = "Zone_South", x = 0, z = 60, size = 28, value = 1 },
		{ name = "Zone_West", x = -60, z = 0, size = 28, value = 1 },
		{ name = "Zone_NorthWest", x = -95, z = -95, size = 28, value = 1 },
		{ name = "Zone_NorthEast", x = 95, z = -95, size = 28, value = 1 },
		{ name = "Zone_SouthEast", x = 95, z = 95, size = 28, value = 1 },
		{ name = "Zone_SouthWest", x = -95, z = 95, size = 28, value = 1 },
	} :: { ZoneSpec },
}

return MapLayout
