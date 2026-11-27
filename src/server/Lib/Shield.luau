--!strict
-- Mewing Shield bookkeeping: who is immune to shove, stare and knockback right now. Keys are a Player or a Mogling's model.

local Workspace = game:GetService("Workspace")

local Shield = {}

local untilTime: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

function Shield.give(key: Instance, seconds: number)
	untilTime[key] = Workspace:GetServerTimeNow() + seconds
end

function Shield.active(key: Instance): boolean
	return (untilTime[key] or 0) > Workspace:GetServerTimeNow()
end

return Shield
