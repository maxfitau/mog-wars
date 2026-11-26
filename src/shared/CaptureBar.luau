--!strict
-- Pure capture-bar math for one zone. No Roblox calls, so it can be tested anywhere.
-- Rules: the faction with the most power wins the tug-of-war only by the margin over ALL others combined.
-- A tie or a negative margin is a stalemate and nothing moves. Overflow carries across a change of control.

export type State = {
	owner: number, -- faction id that holds the zone, 0 = nobody
	capturer: number, -- faction id the progress belongs to, 0 = nobody
	progress: number, -- 0 to 1
}

export type Params = {
	secondsForOneAura: number, -- seconds for power 1 to fill an empty bar
	decayPerSecond: number, -- bar fraction lost per second when nobody is pushing
}

export type Result = {
	state: State,
	captured: boolean, -- true on the step the zone changed owner
	newOwner: number, -- the faction that captured it, or 0
}

local CaptureBar = {}

function CaptureBar.newState(owner: number?): State
	return { owner = owner or 0, capturer = 0, progress = 0 }
end

local function copy(state: State): State
	return { owner = state.owner, capturer = state.capturer, progress = state.progress }
end

-- The leading faction and its net margin. Returns 0, 0 when nobody is present or the lead is tied.
function CaptureBar.leader(powers: { [number]: number }): (number, number)
	local topId, topPower, total, tied = 0, 0, 0, false
	for id, power in powers do
		if power > 0 then
			total += power
			if power > topPower then
				topId, topPower, tied = id, power, false
			elseif power == topPower then
				tied = true
			end
		end
	end
	if topId == 0 or tied then
		return 0, 0
	end
	local margin = topPower - (total - topPower)
	if margin <= 0 then
		return 0, 0
	end
	return topId, margin
end

-- Advance one zone by dt seconds. `powers` maps faction id to the summed aura power standing in the zone.
function CaptureBar.step(
	state: State,
	powers: { [number]: number },
	dt: number,
	params: Params
): Result
	local nextState = copy(state)
	local result: Result = { state = nextState, captured = false, newOwner = 0 }
	if dt <= 0 or params.secondsForOneAura <= 0 then
		return result
	end

	local anyone = false
	for _, power in powers do
		if power > 0 then
			anyone = true
			break
		end
	end

	if not anyone then
		-- Abandoned: progress slowly falls back.
		nextState.progress = math.max(0, nextState.progress - params.decayPerSecond * dt)
		if nextState.progress == 0 then
			nextState.capturer = 0
		end
		return result
	end

	local leaderId, margin = CaptureBar.leader(powers)
	if leaderId == 0 then
		return result -- stalemate: hold
	end

	local delta = margin * dt / params.secondsForOneAura -- fraction of a full bar this step

	if leaderId == nextState.owner then
		-- The owner is defending: it pushes any attacker progress back toward zero.
		nextState.progress = math.max(0, nextState.progress - delta)
		if nextState.progress == 0 then
			nextState.capturer = 0
		end
		return result
	end

	if nextState.capturer ~= 0 and nextState.capturer ~= leaderId and nextState.progress > 0 then
		-- A different faction is pushing: it first undoes the previous attacker's progress.
		if delta <= nextState.progress then
			nextState.progress -= delta
			return result
		end
		delta -= nextState.progress
		nextState.progress = 0
	end

	nextState.capturer = leaderId
	nextState.progress += delta
	if nextState.progress >= 1 then
		nextState.owner = leaderId
		nextState.capturer = 0
		nextState.progress = 0
		result.captured = true
		result.newOwner = leaderId
	end
	return result
end

return CaptureBar
