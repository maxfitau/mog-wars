--!strict
-- Per-war tallies for the results screen: aura, mogs (knock-outs), assists and flags. Server only. Reset at the
-- start of each war. Bots are never counted.

local Stats = {}

export type Tally = { aura: number, mogs: number, assists: number, flags: number, stolen: number }

local tallies: { [Player]: Tally } = setmetatable({}, { __mode = "k" }) :: any

local function tallyOf(player: Player): Tally
	local tally = tallies[player]
	if not tally then
		tally = { aura = 0, mogs = 0, assists = 0, flags = 0, stolen = 0 }
		tallies[player] = tally
	end
	return tally
end

function Stats.add(player: Player, key: string, amount: number)
	local tally: any = tallyOf(player)
	if tally[key] ~= nil and amount == amount then
		tally[key] += amount
	end
end

function Stats.get(player: Player): Tally
	return tallyOf(player)
end

function Stats.reset()
	for player in tallies do
		tallies[player] = nil
	end
end

return Stats
