--!strict
-- THE HUD'S STRICT LAYOUT RULES, in code. There are two shared slots and each shows ONE thing at a time, others wait in order:
--   LINE slot  = the mission bar line under the timer. A big banner (RANK UP, MEGA MOG, AURA METEOR INCOMING ...) temporarily
--                REPLACES the mission bar text for its time (3 s by default), then the mission bar comes back. Never stacked.
--   CARD slot  = one pop-up card at a time (ENTERING a territory, an unlock card, an achievement). The next waits for `done`.
-- Controllers call HudSlots.line / HudSlots.card; MissionHud registers how the line slot is drawn.

local HudSlots = {}

type LineItem = { text: string, colour: Color3, seconds: number }
type LineHandler = { show: (text: string, colour: Color3) -> (), hide: () -> () }

local lineQueue: { LineItem } = {}
local lineHandler: LineHandler? = nil
local lineRunning = false

local function runLine()
	if lineRunning then
		return
	end
	lineRunning = true
	task.spawn(function()
		while #lineQueue > 0 do
			local item = table.remove(lineQueue, 1) :: LineItem
			local handler = lineHandler
			if handler then
				handler.show(item.text, item.colour)
				task.wait(item.seconds)
				handler.hide()
				task.wait(0.15)
			end
		end
		lineRunning = false
	end)
end

function HudSlots.setLineHandler(handler: LineHandler)
	lineHandler = handler
end

-- Show a short banner in the line slot (replacing the mission text), after any that are already waiting.
function HudSlots.line(text: string, colour: Color3, seconds: number?)
	if #lineQueue > 0 and lineQueue[#lineQueue].text == text then
		return -- the same banner twice in a row is one banner
	end
	if #lineQueue >= 5 then
		table.remove(lineQueue, 1) -- never a long backlog: drop the oldest waiting one
	end
	table.insert(lineQueue, { text = text, colour = colour, seconds = seconds or 3 })
	runLine()
end

local cardQueue: { (done: () -> ()) -> () } = {}
local cardRunning = false

local function runCard()
	if cardRunning then
		return
	end
	local show = table.remove(cardQueue, 1)
	if not show then
		return
	end
	cardRunning = true
	local finished = false
	local function done()
		if not finished then
			finished = true
			cardRunning = false
			runCard()
		end
	end
	task.delay(12, done) -- a card that forgets to call done can never block the slot
	task.spawn(show, done)
end

-- Queue a pop-up card. `show` draws it and MUST call `done()` when it has gone away.
function HudSlots.card(show: (done: () -> ()) -> ())
	if #cardQueue >= 6 then
		table.remove(cardQueue, 1)
	end
	table.insert(cardQueue, show)
	runCard()
end

-- The left column (aura box, quest pill, pop-ups) shrinks on narrow screens so it never reaches the top-centre tiles or timer.
function HudSlots.leftScale(): number
	local camera = workspace.CurrentCamera
	return if camera then math.clamp(camera.ViewportSize.X / 1200, 0.6, 1) else 1
end

return HudSlots
