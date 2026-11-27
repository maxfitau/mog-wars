--!strict
-- The placeholder map as plain data: one baseplate, one home base per faction (index = faction id) and the
-- capture zones. Positions are in studs on the ground plane; z points south. A real map built in Studio
-- replaces this: tag its zones "Zone", give each a "Value" attribute, and mark each faction's SpawnLocation
-- with a "HomeBase" attribute holding the faction id. tools/pacing.py reads the zone values from here.

export type Base = { x: number, z: number }
export type ZoneSpec = { name: string, x: number, z: number, size: number, value: number }
export type Treadmill = { x: number, z: number, width: number, length: number, push: number }

local MapLayout = {
	baseplateSize = 320,
	baseSize = 16,
	bases = {
		{ x = -130, z = -130 }, -- faction 1, north west
		{ x = 130, z = -130 }, -- faction 2, north east
		{ x = 130, z = 130 }, -- faction 3, south east
		{ x = -130, z = 130 }, -- faction 4, south west
	} :: { Base },
	-- Training Arena: one treadmill belt just outside each home base. The belt pushes along z (push is in
	-- studs per second, toward the base) and the player has to keep walking against it.
	treadmills = {
		{ x = -130, z = -103, width = 10, length = 20, push = -10 },
		{ x = 130, z = -103, width = 10, length = 20, push = -10 },
		{ x = 130, z = 103, width = 10, length = 20, push = 10 },
		{ x = -130, z = 103, width = 10, length = 20, push = 10 },
	} :: { Treadmill },
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
