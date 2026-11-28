--!strict
-- luau tests/WeaponCatalog.test.luau  (STATUS: not run in the cloud session, no Luau runtime)
local WeaponCatalog = require("../src/shared/WeaponCatalog")
local PlayerData = require("../src/shared/PlayerData")
local failures = 0
local function check(name: string, condition: boolean)
	if not condition then
		failures += 1
		print("FAIL " .. name)
	end
end
check("nine launch weapons", #WeaponCatalog.weapons == 9)
for _, weapon in WeaponCatalog.weapons do
	check(weapon.id .. " has a known rarity", WeaponCatalog.rarityById[weapon.rarity] ~= nil)
	check(weapon.id .. " has a cooldown", weapon.cooldown > 0)
end
for source, odds in WeaponCatalog.odds do
	local total = 0
	for _, chance in odds do
		total += chance
	end
	check(source .. " odds add up to 100", math.abs(total - 100) < 0.001)
end
check("star scale is 1 at one star and 1.2 at five, never more", WeaponCatalog.starScale(1) == 1 and math.abs(WeaponCatalog.starScale(5) - 1.2) < 1e-9 and WeaponCatalog.starScale(99) <= 1.2)
check("a roll of 0 is the most common, 99.9 the rarest", WeaponCatalog.rarityFor("chest", 0) == "common" and WeaponCatalog.rarityFor("chest", 99.9) == "mythic")
check("the streak source always gives Rare", WeaponCatalog.rarityFor("streak", 0) == "rare" and WeaponCatalog.rarityFor("streak", 99.9) == "rare")
check("a roll returns a weapon of that rarity", WeaponCatalog.roll("streak", function()
	return 0.3
end).rarity == "rare")
local data = PlayerData.template()
local isNew, stars = PlayerData.addWeapon(data, "jawline_hammer")
check("a new weapon is 1 star", isNew and stars == 1)
isNew, stars = PlayerData.addWeapon(data, "jawline_hammer")
check("a duplicate adds a star", not isNew and stars == 2)
for _ = 1, 9 do
	PlayerData.addWeapon(data, "jawline_hammer")
end
check("stars stop at five", data.collection.jawline_hammer == 5 and PlayerData.isValid(data))
check("encode and decode round trip", WeaponCatalog.decode(WeaponCatalog.encode(data.collection)).jawline_hammer == 5)
check("a bad id is rejected", select(2, PlayerData.addWeapon(data, "")) == 0)
if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
