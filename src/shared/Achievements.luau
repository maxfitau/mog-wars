--!strict
-- About 30 quick achievements. Each watches one counter (saved per player); when the counter reaches `goal` the
-- achievement unlocks with a big pop-up card and, for some, a title. Counters are bumped by the server only.
-- Tune the goals here.

export type Achievement = { id: string, name: string, desc: string, counter: string, goal: number, title: string? }

local Achievements: { Achievement } = {
	{ id = "first_capture", name = "First Flag!", desc = "Capture your first flag", counter = "flags", goal = 1 },
	{ id = "flags_10", name = "Flag Fan", desc = "Capture 10 flags", counter = "flags", goal = 10 },
	{ id = "flags_50", name = "Flag Master", desc = "Capture 50 flags", counter = "flags", goal = 50, title = "Flag Master" },
	{ id = "flags_250", name = "Flag Legend", desc = "Capture 250 flags", counter = "flags", goal = 250, title = "Flag Legend" },
	{ id = "first_shove", name = "BONK!", desc = "Shove someone for the first time", counter = "shoves", goal = 1 },
	{ id = "shoves_10", name = "Shover", desc = "Shove 10 times", counter = "shoves", goal = 10 },
	{ id = "shoves_100", name = "Shove Machine", desc = "Shove 100 times", counter = "shoves", goal = 100, title = "Shover" },
	{ id = "shoves_500", name = "Bonk King", desc = "Shove 500 times", counter = "shoves", goal = 500, title = "Bonk King" },
	{ id = "first_rank", name = "Rank Up!", desc = "Earn your first rank", counter = "rank", goal = 2 },
	{ id = "rank_sigma", name = "Sigma!", desc = "Reach Sigma", counter = "rank", goal = 3 },
	{ id = "rank_chad", name = "Chad!", desc = "Reach Chad", counter = "rank", goal = 5, title = "Chad" },
	{ id = "rank_god", name = "Mog God!", desc = "Reach Mog God", counter = "rank", goal = 7, title = "Mog God" },
	{ id = "zip_1", name = "Zip!", desc = "Ride a zipline", counter = "ziplines", goal = 1 },
	{ id = "zip_25", name = "Zipliner", desc = "Ride 25 ziplines", counter = "ziplines", goal = 25, title = "Zipliner" },
	{ id = "pad_1", name = "Blast Off!", desc = "Use a launch pad", counter = "launches", goal = 1 },
	{ id = "pad_50", name = "Pad Pilot", desc = "Use 50 launch pads", counter = "launches", goal = 50, title = "Pad Pilot" },
	{ id = "stash_1", name = "Treasure!", desc = "Find a hidden stash", counter = "stashFinds", goal = 1 },
	{ id = "stash_6", name = "Stash Seeker", desc = "Find 6 different stashes", counter = "stashFinds", goal = 6 },
	{ id = "stash_12", name = "Stash Hunter", desc = "Find all 12 stashes", counter = "stashFinds", goal = 12, title = "Stash Hunter" },
	{ id = "bounty_1", name = "Bounty Hunter", desc = "Claim a bounty", counter = "bounties", goal = 1, title = "Bounty Hunter" },
	{ id = "steal_1", name = "Sticky Fingers", desc = "Steal aura for the first time", counter = "steals", goal = 1 },
	{ id = "steal_500", name = "Aura Thief", desc = "Steal 500 aura", counter = "stolen", goal = 500, title = "Aura Thief" },
	{ id = "yeet_1", name = "YEET!", desc = "Knock someone off an island", counter = "yeets", goal = 1 },
	{ id = "yeet_25", name = "Yeet Master", desc = "Knock 25 people off islands", counter = "yeets", goal = 25, title = "Yeeter" },
	{ id = "combo_5", name = "Combo x5!", desc = "Reach a x5 combo", counter = "maxCombo", goal = 5 },
	{ id = "combo_10", name = "Combo x10!", desc = "Reach a x10 combo", counter = "maxCombo", goal = 10, title = "Combo King" },
	{ id = "mega_1", name = "MEGA MOG!", desc = "Get a MEGA MOG", counter = "megas", goal = 1 },
	{ id = "ultra_1", name = "ULTRA MOG!", desc = "Get an ULTRA MOG", counter = "ultras", goal = 1, title = "Ultra Mog" },
	{ id = "territory_1", name = "Territory Taken", desc = "Capture a whole territory", counter = "territories", goal = 1 },
	{ id = "territory_25", name = "Land Grabber", desc = "Capture 25 territories", counter = "territories", goal = 25, title = "Land Grabber" },
	{ id = "war_1", name = "War Veteran", desc = "Play a whole war", counter = "wars", goal = 1 },
	{ id = "war_25", name = "Battle Hardened", desc = "Play 25 wars", counter = "wars", goal = 25, title = "Veteran" },
	{ id = "quest_10", name = "Quest Doer", desc = "Finish 10 quests", counter = "quests", goal = 10 },
}

return Achievements
