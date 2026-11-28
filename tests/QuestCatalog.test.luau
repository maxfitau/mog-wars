--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root: luau tests/QuestCatalog.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local QuestCatalog = require("../src/shared/QuestCatalog")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

-- every template is well formed and ids are unique
local seen: { [string]: boolean } = {}
local wellFormed = true
for _, pool in { QuestCatalog.daily, QuestCatalog.weekly } do
	for _, template in pool do
		if seen[template.id] or template.goal < 1 or template.auraSeconds <= 0 or #template.kinds == 0 then
			wellFormed = false
		end
		seen[template.id] = true
		for index = 1, #template.text do
			local byte = string.byte(template.text, index)
			if byte < 32 or byte > 126 then
				wellFormed = false
			end
		end
	end
end
check("templates are well formed, unique and ASCII", wellFormed)
for _, template in QuestCatalog.daily do
	check("daily id prefix " .. template.id, string.sub(template.id, 1, 2) == "d_")
end
for _, template in QuestCatalog.weekly do
	check("weekly id prefix " .. template.id, string.sub(template.id, 1, 2) == "w_")
end

-- selection sizes, determinism, no repeats
local day = 20400
local dailyA = QuestCatalog.dailyFor(day)
local dailyB = QuestCatalog.dailyFor(day)
check("3 daily quests", #dailyA == 3)
check("5 weekly quests", #QuestCatalog.weeklyFor(2900) == 5)
local same = true
for index = 1, 3 do
	if dailyA[index].id ~= dailyB[index].id then
		same = false
	end
end
check("daily selection is deterministic", same)
local distinct = true
for first = 1, 3 do
	for second = first + 1, 3 do
		if dailyA[first].id == dailyA[second].id then
			distinct = false
		end
	end
end
check("daily quests are distinct", distinct)

local changes = 0
for offset = 1, 30 do
	if QuestCatalog.dailyFor(day + offset)[1].id ~= dailyA[1].id then
		changes += 1
	end
end
check("the daily quests change from day to day", changes >= 10)

local weeklyOk = true
for week = 2900, 2950 do
	local list = QuestCatalog.weeklyFor(week)
	local ids: { [string]: boolean } = {}
	for _, template in list do
		if ids[template.id] or QuestCatalog.disabledKinds[template.kinds[1]] then
			weeklyOk = false
		end
		ids[template.id] = true
	end
	if #list ~= 5 then
		weeklyOk = false
	end
end
check("weekly lists are 5 distinct, enabled quests", weeklyOk)

-- week maths: 1970-01-05 (day 4) was a Monday
check("day 4 starts week 0", QuestCatalog.weekIndex(4) == 0)
check("day 3 (Sunday) is still week -1", QuestCatalog.weekIndex(3) == -1)
check("day 10 (Sunday) is week 0", QuestCatalog.weekIndex(10) == 0)
check("day 11 (Monday) is week 1", QuestCatalog.weekIndex(11) == 1)
check("daily reset is the next midnight", QuestCatalog.dailyResetAt(86400 * 5 + 100) == 86400 * 6)
check("weekly reset is the next Monday", QuestCatalog.weeklyResetAt(86400 * 5) == 86400 * 11)
check("weekly reset on a Monday moves a week on", QuestCatalog.weeklyResetAt(86400 * 11) == 86400 * 18)

-- progress helpers
local sample = QuestCatalog.daily[1]
check("clamp caps at the goal", QuestCatalog.clamp(sample, 99) == sample.goal)
check("clamp floors negatives", QuestCatalog.clamp(sample, -3) == 0)
check("complete at the goal", QuestCatalog.isComplete(sample, sample.goal))
check("not complete below the goal", not QuestCatalog.isComplete(sample, sample.goal - 1))
check("counts matches its kind", QuestCatalog.counts(sample, "flag") and not QuestCatalog.counts(sample, "orb"))

-- encode / decode
local text = QuestCatalog.encode({
	{ id = "d_flags", progress = 2, goal = 3, claimed = false },
	{ id = "d_orbs", progress = 5, goal = 5, claimed = true },
})
check("encode format", text == "d_flags|2|3|0;d_orbs|5|5|1")
local back = QuestCatalog.decode(text)
check("decode round trip", #back == 2 and back[1].progress == 2 and back[2].claimed and back[2].goal == 5)
check("decode ignores junk", #QuestCatalog.decode("junk;;a|b|c|d") == 0)
check("time text", QuestCatalog.timeText(3725) == "1h 02m" and QuestCatalog.timeText(90000) == "1d 1h")

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("All QuestCatalog tests passed")
