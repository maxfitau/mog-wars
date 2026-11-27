--!strict
-- Pure mog-off rules: a 5-second tapping duel between two enemies. The outcome depends on accepted tap
-- counts ONLY. Rank, aura power and faction give no advantage; a tie goes to the defender if there is one,
-- otherwise it is a draw. Taps above the rate cap are ignored.

export type Settings = {
	durationSeconds: number,
	closeRange: number,
	closeSeconds: number,
	maxTapsPerSecond: number,
	cooldownSeconds: number,
}

export type Duel = {
	a: number,
	b: number,
	startsAt: number,
	endsAt: number,
	defender: number, -- user id that wins a tie, 0 for none
	taps: { [number]: number },
	recent: { [number]: { number } }, -- accepted tap times in the last second, per player
}

export type Outcome = {
	winner: number, -- user id, 0 for a draw
	loser: number, -- user id, 0 for a draw
	tapsA: number,
	tapsB: number,
}

local MogOffRules = {}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- True when two players are close enough (3D distance in studs) to start a duel.
function MogOffRules.isClose(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	settings: Settings
): boolean
	if not (finite(ax) and finite(ay) and finite(az) and finite(bx) and finite(by) and finite(bz)) then
		return false
	end
	local dx, dy, dz = ax - bx, ay - by, az - bz
	return math.sqrt(dx * dx + dy * dy + dz * dz) <= settings.closeRange
end

function MogOffRules.offCooldown(now: number, lastDuelEnd: number, settings: Settings): boolean
	return now - lastDuelEnd >= settings.cooldownSeconds
end

function MogOffRules.newDuel(a: number, b: number, startsAt: number, defender: number, settings: Settings): Duel
	local validDefender = if defender == a or defender == b then defender else 0
	return {
		a = a,
		b = b,
		startsAt = startsAt,
		endsAt = startsAt + settings.durationSeconds,
		defender = validDefender,
		taps = { [a] = 0, [b] = 0 },
		recent = { [a] = {}, [b] = {} },
	}
end

-- Count a tap if it is allowed. Returns true if it counted. Only the two duellists can tap, only while the
-- duel is running, and no more than maxTapsPerSecond are accepted in any one-second window.
function MogOffRules.registerTap(duel: Duel, userId: number, now: number, settings: Settings): boolean
	if userId ~= duel.a and userId ~= duel.b then
		return false
	end
	if not finite(now) or now < duel.startsAt or now >= duel.endsAt then
		return false
	end
	local window = duel.recent[userId]
	local kept: { number } = {}
	for _, time in window do
		if now - time < 1 then
			table.insert(kept, time)
		end
	end
	duel.recent[userId] = kept
	if #kept >= settings.maxTapsPerSecond then
		return false
	end
	table.insert(kept, now)
	duel.taps[userId] += 1
	return true
end

-- Decide the duel. More taps wins; equal taps go to the defender; with no defender it is a draw.
function MogOffRules.resolve(duel: Duel): Outcome
	local tapsA, tapsB = duel.taps[duel.a], duel.taps[duel.b]
	if tapsA > tapsB then
		return { winner = duel.a, loser = duel.b, tapsA = tapsA, tapsB = tapsB }
	elseif tapsB > tapsA then
		return { winner = duel.b, loser = duel.a, tapsA = tapsA, tapsB = tapsB }
	end
	if duel.defender ~= 0 then
		local other = if duel.defender == duel.a then duel.b else duel.a
		return { winner = duel.defender, loser = other, tapsA = tapsA, tapsB = tapsB }
	end
	return { winner = 0, loser = 0, tapsA = tapsA, tapsB = tapsB }
end

return MogOffRules
