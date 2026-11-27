--!strict
-- The placeholder map as plain data: one baseplate, one home base per faction (index = faction id) in the
-- corners, the portal to Training Island and Training Island itself. The territories and their flags live in
-- src/shared/Territories.luau. Positions are in studs on the ground plane; z points south. A real map built in Studio
-- replaces this: tag each flag's part "Zone" with the Territory, FlagIndex, FlagCount and Value attributes (see
-- Territories.luau), and mark each faction's SpawnLocation with a "HomeBase" attribute holding the faction id.
-- Two islands share one place: War Island (the baseplate, bases, territories) and Training Island (see below).

export type Base = { x: number, z: number }
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
	baseplateSize = 720, -- War Island is about 700 studs across (a round island of terrain; this is its bounding square)
	baseSize = 16,
	bases = {
		{ x = -225, z = -225 }, -- faction 1, north west
		{ x = 225, z = -225 }, -- faction 2, north east
		{ x = 225, z = 225 }, -- faction 3, south east
		{ x = -225, z = 225 }, -- faction 4, south west
	} :: { Base },
	-- The portal on War Island, at the top (north) edge. Walking into it sends you to Training Island.
	warPortals = {
		{ x = 0, z = -312, size = 14 },
	} :: { Portal },
	-- Training Island: a second platform in the same place, far from War Island. All positions inside it are
	-- LOCAL to its centre (x east, z south). Everything for training and the shop is grouped here; the two
	-- "reserved" areas are kept empty for the prestige altar (Update 2) and the Mog Arena plots (Update 3).
	trainingIsland = {
		x = 800,
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
}

return MapLayout
