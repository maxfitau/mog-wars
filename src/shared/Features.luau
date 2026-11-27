--!strict
-- Launch switches. Everything in the game is built, but only some of it is switched on at launch so the first
-- session stays simple for a young child. Flip a flag to true to turn a feature on (a weekly update).
-- The server and the client both read this file. Features that are not built yet are listed as false so the
-- plan is in one place; they do nothing until their systems exist.

local Features = {
	-- ON at launch
	war = true, -- zones, shove, mog-offs, war rounds
	ranks = true,
	boxes = true,
	units = true,
	treadmill = true,
	dailyStreak = true,
	cosmeticShop = true,

	-- OFF at launch, switched on as later weekly updates
	seasons = false,
	squadBonus = false,
	friendPlacement = false, -- placing a joining player with a friend; goes with the squad bonus
	barracks = false, -- offline income; not in the launch list, and replaced by recruits in the Mog Arena update

	-- NOT BUILT yet (see DESIGN.md release plan)
	trainingStations = false, -- Update 1
	prestige = false, -- Update 2
	arena = false, -- Update 3
}

return table.freeze(Features)
