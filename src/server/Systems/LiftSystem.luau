--!strict
-- BUBBLE LIFTS: step into a glowing column of bubbles and float smoothly along its path to the top (or down a drop chute).
-- Walk out at the end. Players and Moglings both ride. The server owns the rider's physics while they ride (like ziplines),
-- so it cannot be fought by lag. The lifts are listed by Lib/Lifts (built by Kit). Aura and rank never change lift speed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lifts = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Lifts"))
local BotService = require(script.Parent:WaitForChild("BotService"))

local LiftSystem = {}

local SPEED = 26
local ENTRY_RADIUS = 3.6
local FEET = 3 -- root part height above the feet

type Rider = { root: BasePart, humanoid: Humanoid, player: Player?, lift: Lifts.Lift, index: number, startedAt: number }

local riders: { [BasePart]: Rider } = {}
local cooldown: { [BasePart]: { [Lifts.Lift]: number } } = {} -- a rider cannot re-enter the SAME lift for a moment after leaving it

local function start(root: BasePart, humanoid: Humanoid, player: Player?, lift: Lifts.Lift)
	riders[root] = { root = root, humanoid = humanoid, player = player, lift = lift, index = 2, startedAt = os.clock() }
	if player then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	humanoid.PlatformStand = true
end

local function finish(rider: Rider, direction: Vector3)
	riders[rider.root] = nil
	local entries = cooldown[rider.root] or {}
	entries[rider.lift] = os.clock() + 1.5
	cooldown[rider.root] = entries
	if rider.root.Parent then
		if rider.player then
			pcall(function()
				rider.root:SetNetworkOwner(rider.player)
			end)
		end
		local flat = Vector3.new(direction.X, 0, direction.Z)
		rider.root.AssemblyLinearVelocity = if flat.Magnitude > 0.1 then flat.Unit * 10 else Vector3.zero
	end
	rider.humanoid.PlatformStand = false
end

local function step(rider: Rider)
	local points = rider.lift.points
	local target = points[rider.index] + Vector3.new(0, FEET, 0)
	local offset = target - rider.root.Position
	if offset.Magnitude < 2.2 then
		rider.index += 1
		if rider.index > #points then
			finish(rider, points[#points] - points[#points - 1])
		end
		return
	end
	rider.root.AssemblyLinearVelocity = offset.Unit * SPEED
end

local function actors(): { { root: BasePart, humanoid: Humanoid, player: Player? } }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and player:GetAttribute("Ziplining") ~= true then
			table.insert(list, { root = root, humanoid = humanoid, player = player })
		end
	end
	for _, bot in BotService.list() do
		if BotService.isAlive(bot) then
			table.insert(list, { root = bot.root, humanoid = bot.humanoid, player = nil })
		end
	end
	return list
end

function LiftSystem.init() end

function LiftSystem.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		for root, rider in riders do
			-- stop if the rider died, left the game, or the ride has gone on far too long
			if not root.Parent or rider.humanoid.Health <= 0 or os.clock() - rider.startedAt > 25 then
				finish(rider, Vector3.zero)
			else
				step(rider)
			end
		end
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, actor in actors() do
			if not riders[actor.root] then
				for _, lift in Lifts.list do
					local entrance = lift.points[1]
					local offset = actor.root.Position - (entrance + Vector3.new(0, FEET, 0))
					if math.sqrt(offset.X ^ 2 + offset.Z ^ 2) <= ENTRY_RADIUS and math.abs(offset.Y) <= 3.5 and now >= ((cooldown[actor.root] or {})[lift] or 0) then
						start(actor.root, actor.humanoid, actor.player, lift)
						break
					end
				end
			end
		end
	end)
	print(("[mog-wars] %d bubble lifts"):format(#Lifts.list))
end

return LiftSystem
