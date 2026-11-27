--!strict
-- Cheap ambient villagers that make an island feel alive. They are NOT players: pale green-grey skin and a brown tunic
-- (no team colour), no name tag, a slightly different blocky style. They follow a few waypoints (no pathfinding: they
-- just walk straight between points), idle, wave, sit, and say short funny lines in a speech bubble. Shoving one makes it
-- ragdoll comically and get back up (ShoveSystem sets the "BonkedAt" attribute). They never capture flags.
-- All the animation is one loop per NPC at 10 steps a second, moving a handful of anchored parts.

local CollectionService = game:GetService("CollectionService")

local Builder = require(script.Parent:WaitForChild("Builder"))

local AmbientNpc = {}

export type Config = {
	lines: { string },
	waypoints: { Vector3 }?,
	skin: Color3?,
	clothes: Color3?,
	speed: number?,
}

local SKIN = Color3.fromRGB(190, 205, 170)
local CLOTHES = Color3.fromRGB(110, 80, 55)

function AmbientNpc.spawn(folder: Instance, position: Vector3, config: Config): Model
	local skin = config.skin or SKIN
	local clothes = config.clothes or CLOTHES
	local model = Instance.new("Model")
	model.Name = "AmbientNpc"
	local function part(name: string, size: Vector3, color: Color3): Part
		local item = Builder.part(name, size, position, color, model)
		item.Material = Enum.Material.Fabric
		item.CanCollide = false
		item.CanQuery = true
		return item
	end
	local torso = part("Torso", Vector3.new(2.6, 3.2, 1.6), clothes)
	local head = part("Head", Vector3.new(2.2, 2.2, 2.2), skin)
	local armL = part("ArmL", Vector3.new(0.9, 3, 0.9), skin)
	local armR = part("ArmR", Vector3.new(0.9, 3, 0.9), skin)
	local legL = part("LegL", Vector3.new(1, 3, 1), Color3.fromRGB(80, 60, 45))
	local legR = part("LegR", Vector3.new(1, 3, 1), Color3.fromRGB(80, 60, 45))
	torso.CanCollide = true
	model.PrimaryPart = torso
	model.Parent = folder
	CollectionService:AddTag(model, "AmbientNpc")

	-- speech bubble over the head
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.new(0, 190, 0, 40)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 60
	gui.Enabled = false
	gui.Adornee = head
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(35, 25, 60)
	label.Text = "..."
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = label

	local rng = Random.new(math.floor(position.X * 7 + position.Z * 13))
	local waypoints = config.waypoints or { position }
	local speed = config.speed or 4
	local here = position
	local facing = Vector3.new(0, 0, -1)
	local target = 1
	local state = "idle" -- idle, walk, wave, sit
	local stateUntil = 0
	local nextSpeech = os.clock() + 4 + rng:NextNumber() * 8
	local speechUntil = 0
	local phase = 0
	local lastBonk = 0

	-- the pose: every part placed from the root point, so there are no joints to simulate
	local function pose(root: CFrame, swing: number, armLift: number, sitting: boolean, tilt: number)
		local base = root * CFrame.Angles(0, 0, tilt)
		local crouch = if sitting then -1.4 else 0
		torso.CFrame = base * CFrame.new(0, 3 + crouch, 0)
		head.CFrame = base * CFrame.new(0, 5.4 + crouch, 0)
		armL.CFrame = base * CFrame.new(-1.75, 3.2 + crouch, 0) * CFrame.Angles(swing * 0.6, 0, 0)
		armR.CFrame = base * CFrame.new(1.75, 3.2 + crouch, 0) * CFrame.Angles(-swing * 0.6 + armLift, 0, 0)
		if sitting then
			legL.CFrame = base * CFrame.new(-0.6, 1.4, -1.4) * CFrame.Angles(math.rad(90), 0, 0)
			legR.CFrame = base * CFrame.new(0.6, 1.4, -1.4) * CFrame.Angles(math.rad(90), 0, 0)
		else
			legL.CFrame = base * CFrame.new(-0.6, 1.5, 0) * CFrame.Angles(-swing, 0, 0)
			legR.CFrame = base * CFrame.new(0.6, 1.5, 0) * CFrame.Angles(swing, 0, 0)
		end
	end

	task.spawn(function()
		while model.Parent do
			task.wait(0.1)
			local now = os.clock()
			phase += 0.1
			local bonkedAt = model:GetAttribute("BonkedAt")
			if type(bonkedAt) == "number" and bonkedAt ~= lastBonk then
				-- BONK! tip over comically, lie there a moment, then get back up
				lastBonk = bonkedAt
				for step = 1, 6 do
					pose(CFrame.new(here, here + facing), 0, 0, false, math.rad(15 * step))
					task.wait(0.05)
				end
				gui.Enabled = true
				label.Text = "ow."
				task.wait(1.6)
				for step = 6, 0, -1 do
					pose(CFrame.new(here, here + facing), 0, 0, false, math.rad(15 * step))
					task.wait(0.06)
				end
				gui.Enabled = false
				state, stateUntil = "idle", now + 1
			else
				if now >= stateUntil then
					local roll = rng:NextNumber()
					if #waypoints > 1 and roll < 0.55 then
						state, stateUntil = "walk", now + 30
						target = rng:NextInteger(1, #waypoints)
					elseif roll < 0.7 then
						state, stateUntil = "wave", now + 2.2
					elseif roll < 0.85 then
						state, stateUntil = "sit", now + 4 + rng:NextNumber() * 3
					else
						state, stateUntil = "idle", now + 2 + rng:NextNumber() * 3
					end
				end
				local swing, lift, sitting = 0, 0, false
				if state == "walk" then
					local goal = waypoints[target]
					local delta = Vector3.new(goal.X - here.X, 0, goal.Z - here.Z)
					if delta.Magnitude < 1 then
						state, stateUntil = "idle", now + 1.5
					else
						facing = delta.Unit
						here += facing * speed * 0.1
						swing = math.sin(phase * 8) * 0.7
					end
				elseif state == "wave" then
					lift = math.rad(150) + math.sin(phase * 14) * 0.3
				elseif state == "sit" then
					sitting = true
				end
				local bob = if state == "idle" then math.sin(phase * 2) * 0.12 else 0
				pose(CFrame.new(here + Vector3.new(0, bob, 0), here + Vector3.new(0, bob, 0) + facing), swing, lift, sitting, 0)
				-- speech: a short funny line every so often
				if now >= nextSpeech and #config.lines > 0 then
					label.Text = config.lines[rng:NextInteger(1, #config.lines)]
					gui.Enabled = true
					speechUntil = now + 3.5
					nextSpeech = now + 9 + rng:NextNumber() * 14
				elseif gui.Enabled and now >= speechUntil then
					gui.Enabled = false
				end
			end
		end
	end)
	pose(CFrame.new(here, here + facing), 0, 0, false, 0)
	return model
end

-- The nearest ambient NPC within `range` of a point, or nil. ShoveSystem uses it so shoves can bonk villagers.
function AmbientNpc.nearest(position: Vector3, range: number): Model?
	local best: Model? = nil
	local bestDistance = range
	for _, model in CollectionService:GetTagged("AmbientNpc") do
		if model:IsA("Model") and model.PrimaryPart then
			local distance = (model.PrimaryPart.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best
end

return AmbientNpc
