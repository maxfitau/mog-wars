--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/CaptureBar.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local CaptureBar = require("../src/shared/CaptureBar")
local Config = require("../src/shared/EconomyConfig")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local params = { secondsForOneAura = Config.capture.secondsForOneAura, decayPerSecond = Config.capture.decayPerSecond }

local function run(state: CaptureBar.State, powers: { [number]: number }, seconds: number, dt: number): (CaptureBar.State, number)
	local capturedBy = 0
	local steps = math.floor(seconds / dt + 0.5)
	for _ = 1, steps do
		local result = CaptureBar.step(state, powers, dt, params)
		state = result.state
		if result.captured then
			capturedBy = result.newOwner
		end
	end
	return state, capturedBy
end

-- one player alone captures in about secondsForOneAura
do
	local state, by = run(CaptureBar.newState(), { [1] = 1 }, 23, 0.25)
	check("not captured at 23s", by == 0 and state.progress > 0.9)
	local state2, by2 = run(CaptureBar.newState(), { [1] = 1 }, 24.5, 0.25)
	check("captured by 24.5s", by2 == 1 and state2.owner == 1)
end

-- teammates stack: four players capture about four times faster
do
	local _, by = run(CaptureBar.newState(), { [1] = 4 }, 6.5, 0.25)
	check("four players capture in about 6s", by == 1)
end

-- an enemy cancels part of the push; equal power is a stalemate
do
	local state = run(CaptureBar.newState(), { [1] = 1, [2] = 1 }, 30, 0.25)
	check("equal power holds", state.progress == 0 and state.owner == 0)
	local state2, by2 = run(CaptureBar.newState(), { [1] = 2, [2] = 1 }, 30, 0.25)
	check("2 vs 1 captures at net power 1", by2 == 1 and state2.owner == 1)
end

-- two enemy factions together can outweigh one leader
do
	local state = run(CaptureBar.newState(), { [1] = 2, [2] = 1, [3] = 1 }, 30, 0.25)
	check("2 vs 1 vs 1 is a stalemate", state.progress == 0 and state.owner == 0)
end

-- net power sets the speed: three against one pushes at power 2
do
	local _, early = run(CaptureBar.newState(), { [1] = 3, [2] = 1 }, 11, 0.25)
	local _, late = run(CaptureBar.newState(), { [1] = 3, [2] = 1 }, 12.5, 0.25)
	check("3 vs 1 is not captured at 11s", early == 0)
	check("3 vs 1 is captured by 12.5s", late == 1)
end

-- empty zone decays
do
	local state = CaptureBar.newState()
	state.capturer, state.progress = 1, 0.5
	local after = run(state, {}, 10, 0.25)
	check("abandoned progress falls back", after.progress < 0.5 and after.progress > 0)
	local gone = run(state, {}, 60, 0.25)
	check("decay stops at zero and clears the capturer", gone.progress == 0 and gone.capturer == 0)
end

-- a new attacker first undoes the old attacker's progress
do
	local state = CaptureBar.newState()
	state.capturer, state.progress = 1, 0.5
	local after = run(state, { [2] = 1 }, 6, 0.25) -- 0.25 of a bar
	check("rival reduces existing progress", after.capturer == 1 and math.abs(after.progress - 0.25) < 1e-6)
	local flipped = run(state, { [2] = 1 }, 18, 0.25) -- 0.75 of a bar
	check("overflow carries to the new faction", flipped.capturer == 2 and math.abs(flipped.progress - 0.25) < 1e-6)
end

-- the owner defending erases attacker progress and never captures its own zone
do
	local state = CaptureBar.newState(1)
	state.capturer, state.progress = 2, 0.5
	local after, by = run(state, { [1] = 1 }, 30, 0.25)
	check("defender clears the attack", after.progress == 0 and after.capturer == 0 and by == 0 and after.owner == 1)
end

-- bad input changes nothing
do
	local state = CaptureBar.newState()
	local result = CaptureBar.step(state, { [1] = 1 }, -1, params)
	check("negative dt is ignored", result.state.progress == 0 and not result.captured)
end

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All tests passed")
