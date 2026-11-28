--!strict
-- DAILY AND WEEKLY QUESTS (pure data and rules, no Roblox calls). 3 daily quests per UTC day and 5 weekly quests per week
-- (weeks start Monday 00:00 UTC) come from a seeded shuffle of the pools below, so every server picks the same ones.
-- Rewards are seconds of nominal income (the server turns them into aura and the level multiplier scales them) and an
-- optional weapon chest (rolled with the "quest" source). Quests are free: nothing here is ever sold.

export type Template = {
	id: string, -- unique across both pools: daily ids start "d_", weekly ids start "w_"
	text: string, -- plain ASCII
	kinds: { string }, -- Events kinds that each add 1 to the progress
	goal: number,
	auraSeconds: number, -- reward: seconds of nominal income
	chest: boolean, -- reward: also a weapon from the "quest" odds
}

export type Entry = { id: string, progress: number, goal: number, claimed: boolean }

local QuestCatalog = {}

QuestCatalog.dailyCount = 3
QuestCatalog.weeklyCount = 5
QuestCatalog.SECONDS_PER_DAY = 86400

-- Kinds nothing fires yet. Templates that need one are never picked. When SupplyDropSystem fires Events "supply" and
-- EventSystem fires "meteor" for the players who claim them, remove them from this list.
QuestCatalog.disabledKinds = {} :: { [string]: boolean }

local function t(id: string, text: string, kinds: { string }, goal: number, auraSeconds: number, chest: boolean): Template
	return { id = id, text = text, kinds = kinds, goal = goal, auraSeconds = auraSeconds, chest = chest }
end

QuestCatalog.daily = {
	t("d_flags", "Capture 3 flags", { "flag" }, 3, 60, false),
	t("d_moglings", "Shove 10 Moglings", { "shove_mogling" }, 10, 60, false),
	t("d_stashes", "Find 2 stashes", { "stash" }, 2, 90, false),
	t("d_steal", "Steal aura 2 times", { "steal" }, 2, 90, false),
	t("d_winwar", "Win a war", { "war_win" }, 1, 150, true),
	t("d_orbs", "Grab 5 aura orbs", { "orb" }, 5, 60, false),
	t("d_travel", "Use lifts or ziplines 5 times", { "zipline", "launch", "rift" }, 5, 60, false),
	t("d_supply", "Open a supply drop", { "supply" }, 1, 90, false),
	t("d_territory", "Capture a territory", { "territory" }, 1, 90, false),
	t("d_players", "Shove 4 players", { "shove_player" }, 4, 75, false),
	t("d_wars", "Play 2 wars", { "war" }, 2, 75, false),
	t("d_yeet", "Knock someone off an island", { "yeet" }, 1, 90, false),
	t("d_minis", "Finish 3 war mini-quests", { "quest" }, 3, 75, false),
} :: { Template }

QuestCatalog.weekly = {
	t("w_flags", "Capture 25 flags", { "flag" }, 25, 400, true),
	t("w_wins", "Win 5 wars", { "war_win" }, 5, 600, true),
	t("w_stashes", "Find 12 stashes", { "stash" }, 12, 450, false),
	t("w_meteors", "Claim 2 meteors", { "meteor" }, 2, 400, true),
	t("w_territory", "Capture 6 territories", { "territory" }, 6, 500, false),
	t("w_moglings", "Shove 60 Moglings", { "shove_mogling" }, 60, 350, false),
	t("w_steal", "Steal aura 12 times", { "steal" }, 12, 450, false),
	t("w_yeet", "Knock 8 people off islands", { "yeet" }, 8, 450, false),
	t("w_wars", "Play 12 wars", { "war" }, 12, 500, true),
	t("w_orbs", "Grab 40 aura orbs", { "orb" }, 40, 350, false),
	t("w_supply", "Open 4 supply drops", { "supply" }, 4, 450, false),
	t("w_bounty", "Claim 2 bounties", { "bounty" }, 2, 500, true),
	t("w_travel", "Use lifts or ziplines 40 times", { "zipline", "launch", "rift" }, 40, 350, false),
} :: { Template }

local byId: { [string]: Template } = {}
for _, template in QuestCatalog.daily do
	byId[template.id] = template
end
for _, template in QuestCatalog.weekly do
	byId[template.id] = template
end

function QuestCatalog.byId(id: string): Template?
	return byId[id]
end

-- Day and week maths (UTC). Day 0 (1970-01-01) was a Thursday, so a Monday is a day number with day % 7 == 4.
function QuestCatalog.dayNumber(unixSeconds: number): number
	return math.floor(unixSeconds / QuestCatalog.SECONDS_PER_DAY)
end

function QuestCatalog.weekIndex(day: number): number
	return math.floor((day - 4) / 7)
end

-- Unix time the current daily quests end (next 00:00 UTC) and the weekly ones end (next Monday 00:00 UTC).
function QuestCatalog.dailyResetAt(unixSeconds: number): number
	return (QuestCatalog.dayNumber(unixSeconds) + 1) * QuestCatalog.SECONDS_PER_DAY
end

function QuestCatalog.weeklyResetAt(unixSeconds: number): number
	local week = QuestCatalog.weekIndex(QuestCatalog.dayNumber(unixSeconds))
	return (week * 7 + 4 + 7) * QuestCatalog.SECONDS_PER_DAY
end

-- Seeded random numbers (Park-Miller): every product stays under 2^53, so the same seed gives the same list on every server.
local function nextState(state: number): number
	return (state * 48271) % 2147483647
end

local function shuffled(pool: { Template }, seed: number): { Template }
	local state = (math.floor(seed) * 7919 + 12345) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	for _ = 1, 4 do
		state = nextState(state)
	end
	local list: { Template } = {}
	for _, template in pool do
		if not QuestCatalog.disabledKinds[template.kinds[1]] then
			table.insert(list, template)
		end
	end
	for index = #list, 2, -1 do
		state = nextState(state)
		local other = (state % index) + 1
		list[index], list[other] = list[other], list[index]
	end
	return list
end

-- Take `count` from a shuffled list, preferring different kinds so a day never has three of the same job.
local function choose(list: { Template }, count: number): { Template }
	local chosen: { Template } = {}
	local usedKind: { [string]: boolean } = {}
	for _, template in list do
		if #chosen < count and not usedKind[template.kinds[1]] then
			usedKind[template.kinds[1]] = true
			table.insert(chosen, template)
		end
	end
	for _, template in list do
		if #chosen < count and table.find(chosen, template) == nil then
			table.insert(chosen, template)
		end
	end
	return chosen
end

-- The 3 daily quests for a UTC day number.
function QuestCatalog.dailyFor(day: number): { Template }
	return choose(shuffled(QuestCatalog.daily, day * 2 + 1), QuestCatalog.dailyCount)
end

-- The 5 weekly quests for a week index.
function QuestCatalog.weeklyFor(week: number): { Template }
	return choose(shuffled(QuestCatalog.weekly, week * 2 + 100003), QuestCatalog.weeklyCount)
end

-- Progress helpers.
function QuestCatalog.clamp(template: Template, progress: number): number
	if progress ~= progress then
		return 0
	end
	return math.clamp(math.floor(progress), 0, template.goal)
end

function QuestCatalog.isComplete(template: Template, progress: number): boolean
	return progress >= template.goal
end

-- Does an event of `kind` count for this quest?
function QuestCatalog.counts(template: Template, kind: string): boolean
	return table.find(template.kinds, kind) ~= nil
end

-- Compact text for a player attribute: "id|progress|goal|claimed" entries joined by ";" (claimed is 1 or 0).
function QuestCatalog.encode(entries: { Entry }): string
	local parts: { string } = {}
	for _, entry in entries do
		table.insert(parts, ("%s|%d|%d|%d"):format(entry.id, entry.progress, entry.goal, if entry.claimed then 1 else 0))
	end
	return table.concat(parts, ";")
end

function QuestCatalog.decode(text: string): { Entry }
	local entries: { Entry } = {}
	for part in string.gmatch(text, "[^;]+") do
		local id, progress, goal, claimed = string.match(part, "^([%w_]+)|(%d+)|(%d+)|([01])$")
		if id then
			table.insert(entries, {
				id = id,
				progress = tonumber(progress) :: number,
				goal = tonumber(goal) :: number,
				claimed = claimed == "1",
			})
		end
	end
	return entries
end

-- "1h 05m" or "2d 3h" style text for a number of seconds, ASCII only.
function QuestCatalog.timeText(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local days = total // 86400
	local hours = (total % 86400) // 3600
	local minutes = (total % 3600) // 60
	if days > 0 then
		return ("%dd %dh"):format(days, hours)
	end
	return ("%dh %02dm"):format(hours, minutes)
end

return QuestCatalog
