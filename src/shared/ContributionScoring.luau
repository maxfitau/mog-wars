--!strict
-- Pure contribution scoring and payout splitting. Payouts are whole numbers and never exceed the pool.

local ContributionScoring = {}

-- Contribution earned by pushing: aura power times seconds. Bad input scores nothing.
function ContributionScoring.fromPush(power: number, seconds: number): number
	if power ~= power or seconds ~= seconds or power <= 0 or seconds <= 0 then
		return 0
	end
	if power == math.huge or seconds == math.huge then
		return 0
	end
	return power * seconds
end

export type SplitOptions = {
	minContribution: number, -- below this a player is not paid at all
	minAward: number, -- smallest payout for a paid player
}

-- Split `pool` points among players by contribution. `contributions` maps user id to units.
function ContributionScoring.split(
	pool: number,
	contributions: { [number]: number },
	options: SplitOptions
): { [number]: number }
	local payouts: { [number]: number } = {}
	if pool ~= pool or pool < 1 then
		return payouts
	end
	pool = math.floor(pool)

	local eligible: { number } = {}
	local total = 0
	for userId, units in contributions do
		if units == units and units ~= math.huge and units >= options.minContribution and units > 0 then
			table.insert(eligible, userId)
			total += units
		end
	end
	if #eligible == 0 or total <= 0 then
		return payouts
	end
	table.sort(eligible) -- deterministic order for ties

	local paid = 0
	for _, userId in eligible do
		local amount = math.max(options.minAward, math.floor(pool * contributions[userId] / total))
		payouts[userId] = amount
		paid += amount
	end

	-- Minimum awards can push the sum over the pool. Take points from the largest payouts first.
	while paid > pool do
		local biggestId, biggest = 0, 0
		for _, userId in eligible do
			if payouts[userId] > biggest then
				biggestId, biggest = userId, payouts[userId]
			end
		end
		if biggest <= 0 then
			break
		end
		payouts[biggestId] -= 1
		paid -= 1
	end
	return payouts
end

return ContributionScoring
