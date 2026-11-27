--!strict
-- Pure war-round rules: zone-control score, winner and tie-breaks, bonus payouts and the phase cycle.

export type ZoneSummary = { owner: number, value: number }

export type PlayerResult = { faction: number, units: number }

export type BonusOptions = {
	winnerBonus: number,
	participantBonus: number,
	minUnits: number, -- contribution needed to count as taking part (stops standing-by freeloading)
}

local WarRules = {}

-- Total value of the zones each faction holds. Unowned zones (owner 0) score for nobody.
function WarRules.scores(zones: { ZoneSummary }): { [number]: number }
	local result: { [number]: number } = {}
	for _, zone in zones do
		if zone.owner ~= 0 and zone.value > 0 then
			result[zone.owner] = (result[zone.owner] or 0) + zone.value
		end
	end
	return result
end

-- The winning faction id, or 0 for a draw. Highest score wins; a tie goes to the faction that made more
-- captures this war; a tie there, or a top score of zero, is a draw.
function WarRules.winner(scores: { [number]: number }, captures: { [number]: number }): number
	local top = 0
	for _, score in scores do
		top = math.max(top, score)
	end
	if top <= 0 then
		return 0
	end
	local leaders: { number } = {}
	for faction, score in scores do
		if score == top then
			table.insert(leaders, faction)
		end
	end
	if #leaders == 1 then
		return leaders[1]
	end
	local best, bestCaptures, tied = 0, -1, false
	table.sort(leaders)
	for _, faction in leaders do
		local count = captures[faction] or 0
		if count > bestCaptures then
			best, bestCaptures, tied = faction, count, false
		elseif count == bestCaptures then
			tied = true
		end
	end
	return if tied then 0 else best
end

-- Bonus points before any daily multiplier. Everyone who contributed enough gets the participant bonus;
-- contributors on the winning faction also get the winner bonus. A draw (winner 0) has no winner bonus.
function WarRules.bonuses(
	winner: number,
	players: { [number]: PlayerResult },
	options: BonusOptions
): { [number]: number }
	local result: { [number]: number } = {}
	for userId, entry in players do
		if entry.units >= options.minUnits then
			local amount = options.participantBonus
			if winner ~= 0 and entry.faction == winner then
				amount += options.winnerBonus
			end
			result[userId] = amount
		end
	end
	return result
end

-- Apply a reward multiplier. Whole numbers only, and a paid reward never rounds down to nothing.
function WarRules.applyMultiplier(amount: number, multiplier: number): number
	if amount <= 0 or multiplier <= 0 or amount ~= amount or multiplier ~= multiplier then
		return 0
	end
	return math.max(1, math.floor(amount * multiplier))
end

-- A war lasts between 10 and 15 minutes (DESIGN.md). A configured value outside that, or not a number, is
-- brought back into range so a bad config edit cannot make a war last seconds or hours.
WarRules.MIN_WAR_SECONDS = 180
WarRules.MAX_WAR_SECONDS = 900

function WarRules.clampWarSeconds(configured: number): number
	if configured ~= configured then
		return WarRules.MIN_WAR_SECONDS
	end
	return math.clamp(configured, WarRules.MIN_WAR_SECONDS, WarRules.MAX_WAR_SECONDS)
end

-- The war cycle is Intermission, then War, then back to Intermission.
function WarRules.nextPhase(phase: string): string
	return if phase == "War" then "Intermission" else "War"
end

function WarRules.phaseSeconds(phase: string, warSeconds: number, intermissionSeconds: number): number
	return if phase == "War" then warSeconds else intermissionSeconds
end

return WarRules
