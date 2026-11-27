--!strict
-- Pure rules for the bots that fill a war. No Roblox calls, so they can be tested anywhere.
-- Bots are fillers, not rivals to beat the player down: they tap at human-like speeds that depend on the rank of
-- the player they face, are slower against brand-new players, and sometimes win and sometimes lose.

export type Settings = {
	minFighters: number,
	rewardFactor: number,
	tapRateBase: number,
	tapRatePerRank: number,
	tapRateSpread: number,
	tapRateNewPlayerFactor: number,
	tapRateMin: number,
	tapRateMax: number,
	auraPerRank: number,
}

export type ZoneView = { x: number, z: number, owner: number, value: number }

local BotRules = {}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- How many bots a war needs: enough to bring the number of real fighters up to `minFighters`.
function BotRules.desiredBots(humans: number, minFighters: number): number
	if not finite(humans) or not finite(minFighters) then
		return 0
	end
	return math.max(0, math.floor(minFighters) - math.max(0, math.floor(humans)))
end

-- The faction that should get the next bot: the one with the fewest fighters (real players plus bots).
-- Ties go to the lowest id. `totals` maps faction id to its current fighter count.
function BotRules.factionForAdd(totals: { [number]: number }, factionCount: number): number
	local best, bestCount = 1, math.huge
	for id = 1, factionCount do
		local count = totals[id] or 0
		if count < bestCount then
			best, bestCount = id, count
		end
	end
	return best
end

-- The faction that should lose a bot: among factions that have a bot, the one with the most fighters.
-- Ties go to the highest id. Returns nil if no faction has a bot.
function BotRules.factionForRemoval(botCounts: { [number]: number }, totals: { [number]: number }, factionCount: number): number?
	local best, bestTotal = nil, -1
	for id = 1, factionCount do
		if (botCounts[id] or 0) > 0 and (totals[id] or 0) >= bestTotal then
			best, bestTotal = id, totals[id] or 0
		end
	end
	return best
end

-- A bot's tapping speed (taps a second) for one mog-off against a player of `humanRank` who has reached
-- `revealStage` (below 2 means they have not finished a war yet). `rand` returns a number in [0, 1).
-- The result is always inside [tapRateMin, tapRateMax], which is below the server's cap.
function BotRules.duelRate(humanRank: number, revealStage: number, rand: () -> number, settings: Settings): number
	local rank = if finite(humanRank) then math.max(1, humanRank) else 1
	local mean = settings.tapRateBase + settings.tapRatePerRank * (rank - 1)
	if not finite(revealStage) or revealStage < 2 then
		mean *= settings.tapRateNewPlayerFactor
	end
	local noise = 0 -- the sum of 12 uniform numbers, minus 6, is close to a normal distribution
	for _ = 1, 12 do
		noise += rand()
	end
	noise -= 6
	return math.clamp(mean + settings.tapRateSpread * noise, settings.tapRateMin, settings.tapRateMax)
end

-- Taps a bot makes in one short step. `owed` carries leftover fractions between steps; `jitter` (about
-- 0.7 to 1.3) makes the rhythm uneven. Returns the whole taps to count now and the new leftover.
function BotRules.tapsThisStep(rate: number, dt: number, owed: number, jitter: number): (number, number)
	if not (finite(rate) and finite(dt) and finite(owed) and finite(jitter)) or rate <= 0 or dt <= 0 then
		return 0, if finite(owed) then owed else 0
	end
	local total = owed + rate * math.clamp(jitter, 0.5, 1.5) * dt
	local whole = math.floor(total)
	return whole, total - whole
end

-- Aura power for bots: a small rise with the average rank of the real players.
function BotRules.aura(averageRank: number, settings: Settings): number
	local rank = if finite(averageRank) then math.max(1, averageRank) else 1
	return 1 + settings.auraPerRank * (rank - 1)
end

-- Which zone should a bot run to? Prefers a nearby zone its faction does not own, spreads bots out
-- (`assigned` counts bots already heading to each zone), likes valuable zones a little, and adds a random
-- nudge so they do not all behave the same. Returns the zone's index, or nil if there are none.
-- `rand` returns a number in [0, 1).
function BotRules.chooseZone(
	faction: number,
	x: number,
	z: number,
	zones: { ZoneView },
	assigned: { [number]: number },
	rand: () -> number
): number?
	if not (finite(x) and finite(z)) then
		return nil
	end
	local best, bestScore = nil, math.huge
	for index, zone in zones do
		if finite(zone.x) and finite(zone.z) then
			local dx, dz = zone.x - x, zone.z - z
			local score = math.sqrt(dx * dx + dz * dz)
			score += 40 * (assigned[index] or 0) -- spread out
			score -= 25 * (zone.value - 1) -- a little pull toward valuable zones
			if zone.owner == faction then
				score += 120 -- already ours: go and take another
			end
			score += rand() * 25
			if score < bestScore then
				best, bestScore = index, score
			end
		end
	end
	return best
end

-- Points for a capture, reduced when the zone was taken from a faction that has no real players.
function BotRules.capturePoolFactor(previousOwner: number, humansOnPreviousOwner: number, settings: Settings): number
	if previousOwner ~= 0 and humansOnPreviousOwner <= 0 then
		return settings.rewardFactor
	end
	return 1
end

return BotRules
