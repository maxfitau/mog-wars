--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/Territories.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local BoxRoll = require("../src/shared/BoxRoll")
local Config = require("../src/shared/EconomyConfig")
local MapLayout = require("../src/shared/MapLayout")
local Territories = require("../src/shared/Territories")
local TerritoryRules = require("../src/shared/TerritoryRules")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

-- ---------- the six territories from the design ----------
local byId = Territories.byId
check("six territories", #Territories.list == 6)
check("Gigachad Gate: Ultra, 3 flags", byId.gigachad_gate.tier == "ultra" and #byId.gigachad_gate.flags == 3)
check("Rizz Ravine: Diamond, 2 flags", byId.rizz_ravine.tier == "diamond" and #byId.rizz_ravine.flags == 2)
check("Locked-In Lighthouse: Diamond, 2 flags", byId.locked_in_lighthouse.tier == "diamond" and #byId.locked_in_lighthouse.flags == 2)
check("NPC Village: Gold, 1 flag", byId.npc_village.tier == "gold" and #byId.npc_village.flags == 1)
check("Brainrot Bog: Gold, 1 flag", byId.brainrot_bog.tier == "gold" and #byId.brainrot_bog.flags == 1)
check("Cooked Canyon: Gold, 1 flag", byId.cooked_canyon.tier == "gold" and #byId.cooked_canyon.flags == 1)
check("Gigachad Gate flags: both towers and the top of the head", byId.gigachad_gate.flags[1].name == "Left Tower" and byId.gigachad_gate.flags[2].name == "Right Tower" and byId.gigachad_gate.flags[3].name == "Top of the Head" and byId.gigachad_gate.flags[3].y > 20)
check("NPC Village flag is on the statue's head (raised)", byId.npc_village.flags[1].y > 20)
check("Brainrot Bog flag is in the brain (raised)", byId.brainrot_bog.flags[1].y > 8)
check("Cooked Canyon flag is in the yolk on the pan (raised)", byId.cooked_canyon.flags[1].y > 5)
check("Rizz Ravine has a flag on each cliff", byId.rizz_ravine.flags[1].name == "North Cliff" and byId.rizz_ravine.flags[2].name == "South Cliff")
check("Lighthouse has a base flag and a top flag", byId.locked_in_lighthouse.flags[1].y == 0 and byId.locked_in_lighthouse.flags[2].y > 20)
check("ten flags in all", #Territories.allFlags() == 10)

-- ---------- rewards ----------
check("aura rewards are 100, 300 and 1000", Territories.tiers.gold.aura == 100 and Territories.tiers.diamond.aura == 300 and Territories.tiers.ultra.aura == 1000)
check("harder tiers pay more", Territories.tiers.gold.value < Territories.tiers.diamond.value and Territories.tiers.diamond.value < Territories.tiers.ultra.value)
check("harder tiers trickle more aura", Territories.tiers.gold.trickle < Territories.tiers.diamond.trickle and Territories.tiers.diamond.trickle < Territories.tiers.ultra.trickle)
check("the trickle is small next to a capture", Territories.tiers.ultra.trickle * 5 < Territories.tiers.ultra.aura)
for id, tier in Territories.tiers do
	check("tier " .. id .. " has a real box", Config.boxes.tiers[tier.box] ~= nil)
	check("tier " .. id .. " box matches what its value gives", BoxRoll.tierForValue(tier.value, Config.boxes.tierForValue) == tier.box)
	check("tier " .. id .. " aura is a whole number of strides", tier.aura % Config.training.auraPerStride == 0 and tier.trickle % Config.training.auraPerStride == 0)
end

-- ---------- ownership ----------
check("all flags held by one faction owns it", TerritoryRules.owner({ 2, 2, 2 }) == 2)
check("two of three flags owns nothing", TerritoryRules.owner({ 2, 2, 1 }) == 0)
check("an unowned flag means nobody owns it", TerritoryRules.owner({ 2, 2, 0 }) == 0)
check("a single flag held owns the territory", TerritoryRules.owner({ 3 }) == 3)
check("no flags own nothing", TerritoryRules.owner({}) == 0)
check("flags held counts only that faction", TerritoryRules.flagsHeld({ 2, 2, 1 }, 2) == 2 and TerritoryRules.flagsHeld({ 2, 2, 1 }, 1) == 1 and TerritoryRules.flagsHeld({ 0, 0 }, 0) == 0)
check("completing a territory is a capture", TerritoryRules.justCaptured(0, 2) and TerritoryRules.justCaptured(1, 2))
check("holding it again is not a new capture", not TerritoryRules.justCaptured(2, 2))
check("losing it is not a capture", not TerritoryRules.justCaptured(2, 0))

-- ---------- layout ----------
local plate = MapLayout.baseplateSize / 2
local all = Territories.allFlags()
local layoutOk = true
for _, entry in all do
	local f = entry.flag
	if math.abs(f.x) + f.size / 2 > plate or math.abs(f.z) + f.size / 2 > plate then
		layoutOk = false
		print("flag off the plate: " .. f.name)
	end
	for _, base in MapLayout.bases do
		local gapX = math.abs(f.x - base.x) - (f.size + MapLayout.baseSize) / 2
		local gapZ = math.abs(f.z - base.z) - (f.size + MapLayout.baseSize) / 2
		if math.max(gapX, gapZ) < 20 then
			layoutOk = false
			print("flag too close to a base: " .. f.name)
		end
	end
	for _, portal in MapLayout.warPortals do
		local gapX = math.abs(f.x - portal.x) - (f.size + portal.size) / 2
		local gapZ = math.abs(f.z - portal.z) - (f.size + portal.size) / 2
		if math.max(gapX, gapZ) < 10 then
			layoutOk = false
			print("flag too close to the portal: " .. f.name)
		end
	end
end
check("every flag is on the plate, away from the bases and the portal", layoutOk)

local apart = true
for i = 1, #all do
	for j = i + 1, #all do
		local a, b = all[i].flag, all[j].flag
		if math.abs(a.y - b.y) <= 6 then -- flags at different heights may overlap on the map
			local gapX = math.abs(a.x - b.x) - (a.size + b.size) / 2
			local gapZ = math.abs(a.z - b.z) - (a.size + b.size) / 2
			if math.max(gapX, gapZ) < 8 then
				apart = false
				print("flags too close: " .. a.name .. " and " .. b.name)
			end
		end
	end
end
check("no two flags at the same height are closer than 8 studs", apart)

local signsOk = true
for _, territory in Territories.list do
	if math.abs(territory.sign.x) > plate or math.abs(territory.sign.z) > plate then
		signsOk = false
	end
end
check("every territory sign is on the plate", signsOk)

local routesOk = true
for _, entry in all do
	if entry.flag.y > 3 then
		local route = entry.flag.route
		if not route or #route < 1 then
			routesOk = false
			print("a raised flag needs a bot route: " .. entry.flag.name)
		end
	end
end
check("every raised flag has a route for bots", routesOk)
check("one portal at the top edge", #MapLayout.warPortals == 1 and MapLayout.warPortals[1].z < -100 and MapLayout.warPortals[1].x == 0)
check("four corner bases", #MapLayout.bases == 4)
check("one flag per part name", (function()
	local seen: { [string]: boolean } = {}
	for _, entry in all do
		local name = Territories.partName(entry.territory, entry.index)
		if seen[name] then
			return false
		end
		seen[name] = true
	end
	return true
end)())

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
