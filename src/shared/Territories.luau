--!strict
-- THE territory settings file: names, positions, flag counts and rewards, all in one place.
-- A territory has one or more FLAGS. Each flag is captured by standing near it (the normal capture bar, one per
-- flag). A faction owns a territory only when it holds ALL of that territory's flags.
-- Positions are in studs on War Island's ground plane (x east, z south, 0,0 is the middle). A flag's `y` is the
-- height of the ground it stands on (the top of a cliff or lighthouse). `route` lists waypoints bots walk through
-- (ramps) to reach a raised flag. Everything here is placeholder layout: move things by editing this file.
--
-- Rewards by tier (for everyone who helped capture a territory):
--   aura     aura points for the capturing helpers (10 aura = 1 second on a treadmill; more aura = more aura power)
--   value    pool multiplier for Mog Points and the tier of the box (Gold 1, Diamond 2, Ultra 3)
--   trickle  aura every minute, for every member of a faction that holds the territory (harder tiers pay more)

export type Waypoint = { x: number, z: number, y: number }

export type Flag = {
	name: string,
	x: number,
	z: number,
	y: number,
	size: number,
	route: { Waypoint }?,
}

export type Territory = {
	id: string,
	name: string,
	tier: string,
	x: number, -- middle of the territory, for scenery and its sign
	z: number,
	sign: { x: number, z: number },
	flags: { Flag },
}

export type Tier = { label: string, value: number, aura: number, trickle: number, box: string }

local Territories = {}

Territories.trickleSeconds = 60

Territories.tiers = {
	gold = { label = "Gold", value = 1, aura = 100, trickle = 10, box = "gold" },
	diamond = { label = "Diamond", value = 2, aura = 300, trickle = 20, box = "diamond" },
	ultra = { label = "Ultra", value = 3, aura = 1000, trickle = 50, box = "ultra" },
} :: { [string]: Tier }

Territories.list = {
	{
		id = "gigachad_gate",
		name = "Gigachad Gate",
		tier = "ultra",
		x = 0,
		z = 0,
		sign = { x = 0, z = 52 },
		flags = {
			{ name = "Left Tower", x = -30, z = 0, y = 0, size = 18 },
			{ name = "Right Tower", x = 30, z = 0, y = 0, size = 18 },
			{ name = "The Gate", x = 0, z = 26, y = 0, size = 18 },
		},
	},
	{
		id = "rizz_ravine",
		name = "Rizz Ravine",
		tier = "diamond",
		x = 85,
		z = -15,
		sign = { x = 120, z = -15 },
		flags = {
			{ name = "North Cliff", x = 85, z = -37, y = 5, size = 18, route = { { x = 85, z = -68, y = 3 }, { x = 85, z = -52, y = 8 } } },
			{ name = "South Cliff", x = 85, z = 7, y = 5, size = 18, route = { { x = 85, z = 41, y = 3 }, { x = 85, z = 22, y = 8 } } },
		},
	},
	{
		id = "locked_in_lighthouse",
		name = "Locked-In Lighthouse",
		tier = "diamond",
		x = -85,
		z = 10,
		sign = { x = -120, z = 28 },
		flags = {
			{ name = "Lighthouse Base", x = -85, z = 40, y = 0, size = 18 },
			{
				name = "Lighthouse Top",
				x = -85,
				z = 10,
				y = 28,
				size = 20,
				route = { { x = -150, z = 10, y = 3 }, { x = -100, z = 10, y = 31 } },
			},
		},
	},
	{
		id = "npc_village",
		name = "NPC Village",
		tier = "gold",
		x = 0,
		z = -105,
		sign = { x = -34, z = -100 },
		flags = { { name = "Village Square", x = 0, z = -105, y = 0, size = 24 } },
	},
	{
		id = "brainrot_bog",
		name = "Brainrot Bog",
		tier = "gold",
		x = -105,
		z = 70,
		sign = { x = -80, z = 96 },
		flags = { { name = "Bog Centre", x = -105, z = 70, y = 0, size = 24 } },
	},
	{
		id = "cooked_canyon",
		name = "Cooked Canyon",
		tier = "gold",
		x = 105,
		z = 70,
		sign = { x = 78, z = 96 },
		flags = { { name = "Canyon Floor", x = 105, z = 70, y = 0, size = 24 } },
	},
} :: { Territory }

local byId: { [string]: Territory } = {}
for _, territory in Territories.list do
	assert(byId[territory.id] == nil, "duplicate territory id: " .. territory.id)
	assert(Territories.tiers[territory.tier] ~= nil, "unknown tier for " .. territory.id)
	assert(#territory.flags >= 1, "a territory needs at least one flag: " .. territory.id)
	byId[territory.id] = territory
end
Territories.byId = byId

-- Every flag as a flat list, with the territory it belongs to and its 1-based index in that territory.
function Territories.allFlags(): { { territory: Territory, flag: Flag, index: number } }
	local result = {}
	for _, territory in Territories.list do
		for index, flag in territory.flags do
			table.insert(result, { territory = territory, flag = flag, index = index })
		end
	end
	return result
end

-- The name a flag's zone part is given in the world.
function Territories.partName(territory: Territory, index: number): string
	return "Flag_" .. territory.id .. "_" .. index
end

return Territories
