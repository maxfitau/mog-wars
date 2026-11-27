--!strict
-- Pure squad rules. A squad is friends on the same faction capturing the same zone together. Each friend
-- you capture with adds a small bonus to your own points (never taken from anyone else). The bonus is capped.

export type Member = { id: number, faction: number }

export type Settings = {
	perFriendBonus: number, -- extra fraction of your points per friend in the capture (0.1 = +10 percent)
	maxFriends: number, -- friends beyond this add nothing more
	friendTolerance: number, -- how many players bigger than the smallest faction a friend's faction may be
}

local SquadRules = {}

-- For each member, how many OTHER members on the same faction are their friends. `areFriends` is given two
-- user ids and answers true or false; it only needs to be right for the pair asked (order does not matter).
function SquadRules.friendCounts(members: { Member }, areFriends: (number, number) -> boolean): { [number]: number }
	local counts: { [number]: number } = {}
	for _, member in members do
		counts[member.id] = 0
	end
	for i = 1, #members do
		for j = i + 1, #members do
			local a, b = members[i], members[j]
			if a.id ~= b.id and a.faction == b.faction and areFriends(a.id, b.id) then
				counts[a.id] += 1
				counts[b.id] += 1
			end
		end
	end
	return counts
end

-- Extra whole points for a player who captured with `friends` friends. Never negative, never more than the cap.
function SquadRules.bonusPoints(base: number, friends: number, settings: Settings): number
	if base ~= base or friends ~= friends or base <= 0 or friends <= 0 then
		return 0
	end
	local counted = math.min(math.floor(friends), settings.maxFriends)
	return math.floor(base * settings.perFriendBonus * counted)
end

return SquadRules
