--!strict
-- Pure Training Arena rules. A "stride" is one second of valid running on a treadmill. Strides fill the
-- player's training level, and each level raises aura power. Training can never be bought.

export type Settings = {
	maxLevel: number,
	perLevelBonus: number,
	firstLevelSeconds: number,
	stepSeconds: number,
	dailyStrideCap: number,
}

local TrainingRules = {}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- Strides needed to go from `level` to `level + 1`. Level 0 needs the first-level cost; each level after
-- needs a little more.
function TrainingRules.levelCost(level: number, settings: Settings): number
	if not finite(level) or level < 0 then
		return settings.firstLevelSeconds
	end
	return settings.firstLevelSeconds + math.floor(level) * settings.stepSeconds
end

-- Aura power multiplier at a training level: 1 at level 0, rising to the cap at the top level.
function TrainingRules.auraMultiplier(level: number, settings: Settings): number
	if not finite(level) then
		return 1
	end
	return 1 + settings.perLevelBonus * math.clamp(math.floor(level), 0, settings.maxLevel)
end

-- Strides that may still be counted today, given how many were counted already and how many are offered.
function TrainingRules.allowedStrides(trainedToday: number, offered: number, settings: Settings): number
	if not (finite(trainedToday) and finite(offered)) or offered <= 0 then
		return 0
	end
	return math.max(0, math.min(math.floor(offered), settings.dailyStrideCap - math.max(0, trainedToday)))
end

-- Add strides to a level and progress. Returns the new level, the new progress (strides into the current
-- level) and how many levels were gained. At the top level nothing more is added.
function TrainingRules.addStrides(level: number, progress: number, strides: number, settings: Settings): (number, number, number)
	if not (finite(level) and finite(progress) and finite(strides)) or strides <= 0 then
		return level, progress, 0
	end
	local gained = 0
	progress += math.floor(strides)
	while level < settings.maxLevel do
		local cost = TrainingRules.levelCost(level, settings)
		if progress < cost then
			break
		end
		progress -= cost
		level += 1
		gained += 1
	end
	if level >= settings.maxLevel then
		progress = 0
	end
	return level, progress, gained
end

-- Total strides needed to reach a level from level 0 (used by the pacing check).
function TrainingRules.totalToReach(level: number, settings: Settings): number
	local total = 0
	for step = 0, math.min(level, settings.maxLevel) - 1 do
		total += TrainingRules.levelCost(step, settings)
	end
	return total
end

-- Is this a valid running step? The player must be alive, on a treadmill and actually moving.
function TrainingRules.isRunning(moveMagnitude: number, onTreadmill: boolean, alive: boolean): boolean
	return alive and onTreadmill and finite(moveMagnitude) and moveMagnitude >= 0.5
end

return TrainingRules
