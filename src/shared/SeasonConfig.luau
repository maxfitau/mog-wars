--!strict
-- THE SEASONS (pure). One line picks the season the game wears: change `SeasonConfig.current` below and the NPC Village
-- decorations and the season name tag follow. (This is the cosmetic Season system, not the older SeasonRules points season.)

export type Season = {
	id: string,
	name: string,
	accent: { number }, -- a colour (r, g, b) for the little tag on the HUD
}

local SeasonConfig = {}

SeasonConfig.current = "winter" -- <-- change this one line: "winter", "spring", "summer" or "autumn"

SeasonConfig.seasons = {
	{ id = "winter", name = "Winter", accent = { 170, 215, 255 } },
	{ id = "spring", name = "Spring", accent = { 255, 160, 200 } },
	{ id = "summer", name = "Summer", accent = { 255, 215, 70 } },
	{ id = "autumn", name = "Autumn", accent = { 240, 140, 50 } },
} :: { Season }

function SeasonConfig.byId(id: any): Season?
	for _, season in SeasonConfig.seasons do
		if season.id == id then
			return season
		end
	end
	return nil
end

function SeasonConfig.isValid(id: any): boolean
	return SeasonConfig.byId(id) ~= nil
end

-- The season to wear right now; a typo in `current` falls back to the first season.
function SeasonConfig.currentSeason(): Season
	return SeasonConfig.byId(SeasonConfig.current) or SeasonConfig.seasons[1]
end

-- The season after this one (winter, spring, summer, autumn, winter ...).
function SeasonConfig.nextId(id: string): string
	for index, season in SeasonConfig.seasons do
		if season.id == id then
			return SeasonConfig.seasons[index % #SeasonConfig.seasons + 1].id
		end
	end
	return SeasonConfig.seasons[1].id
end

return SeasonConfig
