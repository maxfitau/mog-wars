--!strict
-- A tiny message bus so that things that happen in the war (a flag captured, a shove, a stash found...) reach every system
-- that cares (combo, quests, achievements) without those systems needing to know about each other.
-- Kinds: flag, territory, shove_mogling, shove_player, stash, stashCount, zipline, launch, orb, stare, yeet, steal, bounty,
-- war, rank, maxCombo, mega, ultra, quest.

local Events = {}

local handlers: { (Player, string, number) -> () } = {}

function Events.on(handler: (Player, string, number) -> ())
	table.insert(handlers, handler)
end

function Events.fire(player: Player, kind: string, value: number?)
	for _, handler in handlers do
		local ok, err = pcall(handler, player, kind, value or 1)
		if not ok then
			warn("[mog-wars] event " .. kind .. " failed: " .. tostring(err))
		end
	end
end

return Events
