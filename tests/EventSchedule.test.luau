--!strict
-- Plain-Luau tests, no Roblox needed. Run from the repo root with the standalone Luau runtime:
--   luau tests/EventSchedule.test.luau
-- STATUS: written but NOT yet run (no Luau runtime in the cloud session). Run it on a PC first.

local EventSchedule = require("../src/shared/EventSchedule")

local failures = 0

local function check(name: string, condition: boolean)
	if condition then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

-- Known moments (UTC): Monday 2026-11-23 00:00, Saturday 2026-11-28 18:00 (the event start).
local MONDAY = 1795392000
local SAT_START = 1795888800
local SAT_END = SAT_START + 3 * 3600
local NEXT_SAT_START = SAT_START + 7 * 86400

check("day name of the Monday", EventSchedule.dayName(MONDAY) == "Monday")
check("day name of the event start", EventSchedule.dayName(SAT_START) == "Saturday")
check("day name just before Monday ends Sunday", EventSchedule.dayName(MONDAY - 1) == "Sunday")
check("event day word", EventSchedule.eventDayName() == "Saturday")
check("window text", EventSchedule.windowText() == "Saturday 18:00-21:00 UTC")

check("not active on Monday", not EventSchedule.isActive(MONDAY))
check("not active one second before the start", not EventSchedule.isActive(SAT_START - 1))
check("active at the start", EventSchedule.isActive(SAT_START))
check("active in the middle", EventSchedule.isActive(SAT_START + 5000))
check("active one second before the end", EventSchedule.isActive(SAT_END - 1))
check("not active at the end", not EventSchedule.isActive(SAT_END))
check("not active next day", not EventSchedule.isActive(SAT_START + 86400))
check("active again next week", EventSchedule.isActive(NEXT_SAT_START + 60))

check("next start from Monday", EventSchedule.nextStart(MONDAY) == SAT_START)
check("next start one second before", EventSchedule.nextStart(SAT_START - 1) == SAT_START)
check("next start while live is next week", EventSchedule.nextStart(SAT_START + 10) == NEXT_SAT_START)
check("next start after the end is next week", EventSchedule.nextStart(SAT_END) == NEXT_SAT_START)
check("next start from the Sunday before", EventSchedule.nextStart(MONDAY - 1) == SAT_START)

check("seconds until, three hours before", EventSchedule.secondsUntil(SAT_START - 3 * 3600) == 3 * 3600)
check("seconds until is always above 0", EventSchedule.secondsUntil(SAT_START) > 0)
check("current start while live", EventSchedule.currentStart(SAT_START + 100) == SAT_START)
check("no current start when idle", EventSchedule.currentStart(MONDAY) == nil)
check("ends at", EventSchedule.endsAt(SAT_START + 100) == SAT_END)
check("seconds left", EventSchedule.secondsLeft(SAT_START + 4800) == 6000)
check("seconds left when idle", EventSchedule.secondsLeft(MONDAY) == 0)

check("span days", EventSchedule.spanText(2 * 86400 + 4 * 3600 + 59) == "2d 4h")
check("span hours", EventSchedule.spanText(3 * 3600 + 12 * 60 + 5) == "3h 12m")
check("span minutes", EventSchedule.spanText(9 * 60 + 30) == "9m")
check("span zero", EventSchedule.spanText(0) == "0m")
check("span negative", EventSchedule.spanText(-50) == "0m")

check("countdown days", EventSchedule.countdownText(SAT_START - (2 * 86400 + 4 * 3600)) == "2d 4h")
check("countdown hours", EventSchedule.countdownText(SAT_START - (3 * 3600 + 12 * 60)) == "3h 12m")
check("countdown live", EventSchedule.countdownText(SAT_START + 4800) == "LIVE: 1h 40m left")
check("countdown from Monday", EventSchedule.countdownText(MONDAY) == "5d 18h")

-- the settings table really drives everything
local savedDay = EventSchedule.settings.day
local savedHour = EventSchedule.settings.startHourUtc
local savedHours = EventSchedule.settings.hours
EventSchedule.settings.day = 7
EventSchedule.settings.startHourUtc = 22
EventSchedule.settings.hours = 4 -- Sunday 22:00 to Monday 02:00: runs over the week boundary
local sundayStart = MONDAY - 86400 + 22 * 3600
check("settings: Sunday event active at start", EventSchedule.isActive(sundayStart))
check("settings: still live after midnight Monday", EventSchedule.isActive(MONDAY + 3600))
check("settings: over at 02:00 Monday", not EventSchedule.isActive(MONDAY + 2 * 3600))
check("settings: current start belongs to last week", EventSchedule.currentStart(MONDAY + 3600) == sundayStart)
EventSchedule.settings.day = savedDay
EventSchedule.settings.startHourUtc = savedHour
EventSchedule.settings.hours = savedHours

if failures > 0 then
	error(("%d test(s) failed"):format(failures))
end
print("all EventSchedule tests passed")
