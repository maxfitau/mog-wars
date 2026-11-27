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

export type Flag = {
	name: string,
	x: number,
	z: number,
	y: number, -- height of the ground the flag circle sits on
	size: number, -- diameter of the capture circle
	pole: number?, -- flag pole height (shorter indoors)
	beam: number?, -- height of the thin beam shown while the flag is neutral or contested
	noSpawn: boolean?, -- true if players must never be spawned beside this flag (for example inside a hollow brain)
}

export type Territory = {
	id: string,
	name: string,
	tier: string,
	x: number, -- middle of the territory
	z: number,
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
		-- A giant stone face with sunglasses. Its mouth is a tunnel you walk through; inside the head is the throne room
		-- (reached from the two spiral-staircase towers by covered corridors). One flag on top of each tower, one in the
		-- throne room.
		flags = {
			{ name = "Left Tower", x = -75, z = 0, y = 60, size = 14, pole = 9, beam = 22 },
			{ name = "Right Tower", x = 75, z = 0, y = 60, size = 14, pole = 9, beam = 22 },
			{ name = "Throne Room", x = 0, z = 0, y = 26, size = 22, pole = 10, beam = 14 },
		},
	},
	{
		id = "rizz_ravine",
		name = "Rizz Ravine",
		tier = "diamond",
		x = 215,
		z = -70,
		-- A deep pink-rock ravine with a rope bridge; a flag on top of each cliff; a hollow heart on the bridge.
		flags = {
			{ name = "North Cliff", x = 215, z = -112, y = 24, size = 20, pole = 14, beam = 30 },
			{ name = "South Cliff", x = 215, z = -28, y = 24, size = 20, pole = 14, beam = 30 },
		},
	},
	{
		id = "locked_in_lighthouse",
		name = "Locked-In Lighthouse",
		tier = "diamond",
		x = -185,
		z = 45,
		-- A striped lighthouse on a rocky island, spiral stairs inside, and a giant golden padlock for a lamp room.
		flags = {
			{ name = "Lighthouse Base", x = -148, z = 45, y = 12, size = 16, pole = 12, beam = 30 },
			{ name = "Lighthouse Top", x = -165, z = 45, y = 84, size = 14, pole = 9, beam = 16 },
		},
	},
	{
		id = "npc_village",
		name = "NPC Village",
		tier = "gold",
		x = -100,
		z = -170,
		-- A blocky village of enterable houses and a giant grey NPC statue climbed by scaffolding. Flag on its head.
		flags = {
			{ name = "Statue Head", x = -100, z = -190, y = 84, size = 14, pole = 9, beam = 20 },
		},
	},
	{
		id = "brainrot_bog",
		name = "Brainrot Bog",
		tier = "gold",
		x = -110,
		z = 190,
		-- A foggy green swamp and a giant HOLLOW pink brain. Flag in the middle of its fleshy tunnels.
		flags = {
			{ name = "Brain Core", x = -110, z = 190, y = 0, size = 18, pole = 9, beam = 12, noSpawn = true },
		},
	},
	{
		id = "cooked_canyon",
		name = "Cooked Canyon",
		tier = "gold",
		x = 120,
		z = 190,
		-- A red canyon with a lava river, rock jumps up to a giant frying pan, and the flag in the yolk.
		flags = {
			{ name = "The Yolk", x = 120, z = 190, y = 18, size = 22, pole = 12, beam = 26 },
		},
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
