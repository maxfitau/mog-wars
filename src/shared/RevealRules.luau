--!strict
-- Pure rules for showing screens gradually. A brand-new player sees only the zone bar ("stand in the zone,
-- watch the bar fill"). More appears as they play: after their first capture, after their first finished war,
-- and so on. The stage is worked out on the server from saved counts and mirrored to the client.

local RevealRules = {}

RevealRules.MAX_STAGE = 4

-- Screens (ScreenGui names) and the stage at which each appears. Screens not listed here are never touched.
RevealRules.screens = {
	CaptureHud = 0, -- the zone bar: always there
	PointsHud = 1, -- after the first capture
	WarHud = 1,
	ShoveHud = 2, -- after the first finished war
	RankHud = 2,
	TrainingHud = 2,
	BoxHud = 3, -- after two finished wars
	UnitsHud = 3,
	RewardsHud = 4, -- after three finished wars
	ShopHud = 4,
	SeasonHud = 4,
} :: { [string]: number }

local function whole(value: any): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- The stage for a player with this many lifetime captures and finished wars.
function RevealRules.stage(captures: any, wars: any): number
	local c, w = whole(captures), whole(wars)
	if w >= 3 then
		return 4
	elseif w >= 2 then
		return 3
	elseif w >= 1 then
		return 2
	elseif c >= 1 then
		return 1
	end
	return 0
end

-- Should this screen be visible at this stage? Unknown screens return nil (leave them alone).
function RevealRules.visible(screen: string, stage: any): boolean?
	local needed = RevealRules.screens[screen]
	if needed == nil then
		return nil
	end
	return whole(stage) >= needed
end

return RevealRules
