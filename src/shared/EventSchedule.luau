--!strict
-- THE WEEKLY EVENT SCHEDULE (pure, no Roblox calls). Everything is UTC and every number lives in `settings`: change the day,
-- the hour or the length there and nothing else. Day numbers run Monday = 1 to Sunday = 7.
-- Today there is one event: METEOR STORM SATURDAY, Saturdays 18:00 UTC for 3 hours.

local EventSchedule = {}

EventSchedule.settings = {
	name = "Meteor Storm Saturday",
	day = 6, -- 1 = Monday ... 6 = Saturday ... 7 = Sunday
	startHourUtc = 18,
	hours = 3,
}

local DAY = 86400
local WEEK = 7 * DAY
local DAY_NAMES = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }

-- Unix time 0 was a Thursday, so 1970-01-05 00:00 UTC (a Monday) is 4 days in.
local FIRST_MONDAY = 4 * DAY

local function weekStart(unix: number): number
	return FIRST_MONDAY + math.floor((unix - FIRST_MONDAY) / WEEK) * WEEK
end

local function startOffset(): number
	local settings = EventSchedule.settings
	return (settings.day - 1) * DAY + settings.startHourUtc * 3600
end

local function duration(): number
	return EventSchedule.settings.hours * 3600
end

-- The weekday of a moment, 1 = Monday to 7 = Sunday.
function EventSchedule.dayIndex(unix: number): number
	return math.floor((unix - FIRST_MONDAY) / DAY) % 7 + 1
end

function EventSchedule.dayName(unix: number): string
	return DAY_NAMES[EventSchedule.dayIndex(unix)]
end

-- The day the event runs on, as a word ("Saturday").
function EventSchedule.eventDayName(): string
	return DAY_NAMES[EventSchedule.settings.day]
end

-- "Saturday 18:00-21:00 UTC"
function EventSchedule.windowText(): string
	local settings = EventSchedule.settings
	local endHour = (settings.startHourUtc + settings.hours) % 24
	return ("%s %02d:00-%02d:00 UTC"):format(
		EventSchedule.eventDayName(),
		settings.startHourUtc,
		endHour
	)
end

-- The start (unix seconds) of the event window that is on right now, or nil.
function EventSchedule.currentStart(unix: number): number?
	local base = weekStart(unix)
	for _, shift in { -WEEK, 0 } do -- a window that began last week can run over into this one
		local start = base + shift + startOffset()
		if unix >= start and unix < start + duration() then
			return start
		end
	end
	return nil
end

function EventSchedule.isActive(unix: number): boolean
	return EventSchedule.currentStart(unix) ~= nil
end

-- The first start that is strictly after `unix` (during an event this is next week's).
function EventSchedule.nextStart(unix: number): number
	local base = weekStart(unix)
	for _, shift in { 0, WEEK } do
		local start = base + shift + startOffset()
		if start > unix then
			return start
		end
	end
	return base + 2 * WEEK + startOffset()
end

-- Seconds until the next start (always above 0).
function EventSchedule.secondsUntil(unix: number): number
	return EventSchedule.nextStart(unix) - unix
end

-- When the live event ends, or nil when none is live.
function EventSchedule.endsAt(unix: number): number?
	local start = EventSchedule.currentStart(unix)
	return if start then start + duration() else nil
end

-- Seconds left in the live event (0 when none is live).
function EventSchedule.secondsLeft(unix: number): number
	local finish = EventSchedule.endsAt(unix)
	return if finish then finish - unix else 0
end

-- "2d 4h", "3h 12m" or "9m" (never negative).
function EventSchedule.spanText(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local days = math.floor(total / DAY)
	local hours = math.floor(total % DAY / 3600)
	local minutes = math.floor(total % 3600 / 60)
	if days >= 1 then
		return ("%dd %dh"):format(days, hours)
	elseif hours >= 1 then
		return ("%dh %dm"):format(hours, minutes)
	end
	return ("%dm"):format(minutes)
end

-- "2d 4h" / "3h 12m" until the start, or "LIVE: 1h 40m left" while it runs.
function EventSchedule.countdownText(unix: number): string
	if EventSchedule.isActive(unix) then
		return "LIVE: " .. EventSchedule.spanText(EventSchedule.secondsLeft(unix)) .. " left"
	end
	return EventSchedule.spanText(EventSchedule.secondsUntil(unix))
end

return EventSchedule
