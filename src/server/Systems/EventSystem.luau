--!strict
-- SERVER EVENTS: one per war, rotating (Pace.events). Today there is one, the AURA METEOR; add Golden Hour, Mogling
-- Invasion, Gigachad Awakens and so on by adding an entry to `events` below and its id to Pace.events.rotation.
-- Everything is free: nothing here is ever sold. The server decides everything; the client (EventController) only displays.
-- AURA METEOR: about half way through the war the sky tints purple and an alarm sounds for 15s, then a meteor crashes onto
-- a random island, scatters aura orbs and leaves a METEOR FLAG (worth 5x). The team that holds it for 20s in total wins a
-- huge aura burst for every member (seconds of income, so it scales with level). Moglings rush it too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local Config = require(Shared:WaitForChild("EconomyConfig"))
local FactionRules = require(Shared:WaitForChild("FactionRules"))
local Territories = require(Shared:WaitForChild("Territories"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local StealSystem = require(script.Parent:WaitForChild("StealSystem"))

local EventSystem = {}

local remote: RemoteEvent? = nil
local running = false
local lastWarRun = -1
local flagPart: Part? = nil
local flagOwner = 0

-- Set by WeeklyEventSystem: called when a team claims a meteor, with the winning faction id and the real players of that
-- team who stood on the flag. (The reward itself stays here; this is only so the weekly event can count who took part.)
EventSystem.onClaim = nil :: ((number, { Player }) -> ())?

local function fxAll(kind: string, a: any?, b: any?)
	if remote then
		remote:FireAllClients(kind, a, b)
	end
end

local function banner(text: string)
	for _, player in Players:GetPlayers() do
		PopupSystem.send(player, "announce", 1, text)
	end
end

local function setState(name: string, phase: string, endsAt: number, text: string)
	Workspace:SetAttribute("EventName", name)
	Workspace:SetAttribute("EventPhase", phase)
	Workspace:SetAttribute("EventEndsAt", endsAt)
	Workspace:SetAttribute("EventText", text)
end

local function clearState()
	Workspace:SetAttribute("EventName", "")
	Workspace:SetAttribute("EventPhase", "")
	Workspace:SetAttribute("EventEndsAt", 0)
	Workspace:SetAttribute("EventText", "")
	Workspace:SetAttribute("EventPos", nil)
end

local function groundAt(x: number, z: number): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = Workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), params)
	if result then
		return result.Position
	end
	return Vector3.new(x, 100, z)
end

-- A random island to land on (not the cave, not a spawn island).
local function pickLanding(): Vector3
	local islands = {}
	for _, territory in Territories.list do
		if territory.radius > 40 then
			table.insert(islands, territory)
		end
	end
	local island = islands[math.random(1, #islands)]
	local angle = math.random() * math.pi * 2
	local distance = math.random() * island.radius * 0.45
	return groundAt(island.x + math.cos(angle) * distance, island.z + math.sin(angle) * distance)
end

local function marker(position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "MeteorMarker"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position + Vector3.new(0, 30, 0)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 5000
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "METEOR LANDS HERE"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(215, 140, 255)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local ring = Instance.new("Part")
	ring.Name = "MeteorRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(190, 90, 255)
	ring.Transparency = 0.6
	ring.Size = Vector3.new(0.5, Pace.meteor.flagRadius * 2, Pace.meteor.flagRadius * 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = part
	part.Parent = Workspace
	return part
end

-- Who is standing on the flag: human and Mogling counts per faction.
local function countOn(position: Vector3): { [number]: number }
	local counts: { [number]: number } = {}
	local radius = Pace.meteor.flagRadius
	local function add(faction: number, root: BasePart)
		local offset = root.Position - position
		if math.sqrt(offset.X ^ 2 + offset.Z ^ 2) <= radius and math.abs(offset.Y) < 25 then
			counts[faction] = (counts[faction] or 0) + 1
		end
	end
	for _, player in Players:GetPlayers() do
		local faction = player:GetAttribute("Faction")
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if type(faction) == "number" and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			add(faction, root)
		end
	end
	for _, bot in BotService.list() do
		if BotService.isAlive(bot) then
			add(bot.faction, bot.root)
		end
	end
	return counts
end

-- `storm` = a METEOR STORM meteor (the weekly event): it does not need a war to be running.
local function runMeteor(storm: boolean)
	local landing = pickLanding()
	local warnEnds = Workspace:GetServerTimeNow() + Pace.meteor.warningSeconds
	setState("meteor", "incoming", warnEnds, "AURA METEOR INCOMING")
	Workspace:SetAttribute("EventPos", landing)
	local mark = marker(landing)
	fxAll("warn", landing)
	banner("Aura Meteor incoming!")
	task.wait(Pace.meteor.warningSeconds)

	-- the meteor streaks in from high up and far away
	local rock = Instance.new("Part")
	rock.Name = "Meteor"
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.new(18, 18, 18)
	rock.Material = Enum.Material.Neon
	rock.Color = Color3.fromRGB(190, 90, 255)
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	local from = landing + Vector3.new(-420, 520, -300)
	rock.Position = from
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 7, 0)
	a0.Parent = rock
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -7, 0)
	a1.Parent = rock
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 1.4
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(150, 60, 255))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Parent = rock
	rock.Parent = Workspace
	local fall = TweenService:Create(rock, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = landing + Vector3.new(0, 6, 0) })
	fall:Play()
	fall.Completed:Wait()
	rock:Destroy()
	mark:Destroy()

	-- BOOM: shake, flash, orbs, a crater and the METEOR FLAG
	fxAll("boom", landing)
	local blast = Instance.new("Explosion")
	blast.Position = landing
	blast.BlastRadius = 0
	blast.BlastPressure = 0
	blast.DestroyJointRadiusPercent = 0
	blast.Parent = Workspace
	StealSystem.dropFreeOrbs(landing, Pace.meteor.orbCount, Pace.meteor.orbSeconds * Pace.levels.nominalIncome, Pace.meteor.activeSeconds)

	local flag = Instance.new("Part")
	flag.Name = "MeteorFlag"
	flag.Shape = Enum.PartType.Cylinder
	flag.Anchored = true
	flag.CanCollide = false
	flag.Material = Enum.Material.Neon
	flag.Color = Color3.fromRGB(190, 90, 255)
	flag.Transparency = 0.35
	flag.Size = Vector3.new(1, Pace.meteor.flagRadius * 2, Pace.meteor.flagRadius * 2)
	flag.CFrame = CFrame.new(landing + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 60)
	gui.StudsOffset = Vector3.new(0, 26, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 5000
	gui.Parent = flag
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "METEOR FLAG x5"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(240, 190, 255)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(210, 130, 255)
	beam.Transparency = 0.5
	beam.Size = Vector3.new(4, 160, 4)
	beam.Position = landing + Vector3.new(0, 80, 0)
	beam.Parent = flag
	flag.Parent = Workspace
	flagPart, flagOwner = flag, 0
	BotService.setExtraZones(function()
		if not flagPart then
			return {}
		end
		return { { part = flagPart, x = landing.X, z = landing.Z, y = landing.Y, size = Pace.meteor.flagRadius * 2, owner = flagOwner, value = Pace.meteor.flagValue } :: any }
	end)

	local held: { [number]: number } = {}
	local stood: { [Player]: boolean } = {} -- real players who stood on the flag
	local startedAt = Workspace:GetServerTimeNow()
	local winner = 0
	setState("meteor", "active", startedAt + Pace.meteor.activeSeconds, "METEOR FLAG")
	while Workspace:GetServerTimeNow() - startedAt < Pace.meteor.activeSeconds and winner == 0 and (storm or Workspace:GetAttribute("WarPhase") == "War") do
		task.wait(0.5)
		local counts = countOn(landing)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local offset = root.Position - landing
				if math.sqrt(offset.X ^ 2 + offset.Z ^ 2) <= Pace.meteor.flagRadius and math.abs(offset.Y) < 25 then
					stood[player] = true
				end
			end
		end
		local best, bestCount, tie = 0, 0, false
		for faction, count in counts do
			if count > bestCount then
				best, bestCount, tie = faction, count, false
			elseif count == bestCount then
				tie = true
			end
		end
		if best ~= 0 and not tie then
			flagOwner = best
			held[best] = (held[best] or 0) + 0.5
			flag.Color = Color3.fromRGB(table.unpack(FactionRules.factions[best].rgb))
			local info = FactionRules.factions[best]
			Workspace:SetAttribute("EventText", ("%s holds the METEOR FLAG %d/%ds"):format(string.upper(info.name), math.floor(held[best]), Pace.meteor.holdSeconds))
			if held[best] >= Pace.meteor.holdSeconds then
				winner = best
			end
		elseif best ~= 0 then
			Workspace:SetAttribute("EventText", "METEOR FLAG contested!")
		end
	end

	if winner ~= 0 then
		local info = FactionRules.factions[winner]
		banner(("METEOR CLAIMED BY %s!"):format(string.upper(info.name)))
		fxAll("claim", landing, winner)
		local claimers: { Player } = {}
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Faction") == winner and player:GetAttribute("AFK") ~= true then
				if stood[player] then
					table.insert(claimers, player)
				end
				local shown = DataService.addAura(player, Pace.meteor.rewardSeconds * Pace.levels.nominalIncome, false, true, true)
				if shown > 0 then
					PopupSystem.send(player, "aura", shown, "")
				end
			end
		end
		for _, claimer in claimers do
			Events.fire(claimer, "meteor", 1) -- the weekly quests count meteor claims
		end
		local onClaim = EventSystem.onClaim
		if onClaim then
			local ok, err = pcall(onClaim, winner, claimers)
			if not ok then
				warn("[mog-wars] meteor claim hook failed: " .. tostring(err))
			end
		end
	else
		banner("The meteor crumbled...")
	end
	-- the meteor crumbles
	TweenService:Create(flag, TweenInfo.new(2.5), { Transparency = 1 }):Play()
	flagPart = nil
	BotService.setExtraZones(nil)
	Debris:AddItem(flag, 3)
	clearState()
	fxAll("clear")
end

-- All events. Add new ones here; each runs on its own thread when its turn comes.
local events: { [string]: (boolean) -> () } = {
	meteor = runMeteor,
}

-- Is an event running right now?
function EventSystem.isRunning(): boolean
	return running
end

-- Start an event now (used by the rotation, the weekly METEOR STORM and the Studio debug command). Returns false if one is
-- already running. `storm` = a storm meteor: it runs even when no war is on.
function EventSystem.trigger(id: string, storm: boolean?): boolean
	local run = events[id]
	if not run or running then
		return false
	end
	running = true
	task.spawn(function()
		local ok, err = pcall(run, storm == true)
		if not ok then
			warn("[mog-wars] event " .. id .. " failed: " .. tostring(err))
			clearState()
			fxAll("clear")
			BotService.setExtraZones(nil)
			for _, child in Workspace:GetChildren() do -- a meteor that failed part way leaves nothing behind
				if child.Name == "MeteorMarker" or child.Name == "Meteor" or child.Name == "MeteorFlag" then
					child:Destroy()
				end
			end
			flagPart = nil
		end
		running = false
	end)
	return true
end

function EventSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local created = Instance.new("RemoteEvent")
	created.Name = "EventFx"
	created.Parent = folder
	remote = created
	clearState()
end

-- The rotation: about half way through each war, start that war's event once.
function EventSystem.start()
	task.spawn(function()
		while true do
			task.wait(1)
			-- (during the weekly METEOR STORM the storm sends the meteors, so the per-war one waits)
			if Workspace:GetAttribute("WarPhase") == "War" and not running and Workspace:GetAttribute("WeeklyEventLive") ~= true then
				local warNumber = Workspace:GetAttribute("WarNumber")
				local endsAt = Workspace:GetAttribute("WarPhaseEndsAt")
				if type(warNumber) == "number" and type(endsAt) == "number" and warNumber ~= lastWarRun then
					local total = Config.war.durationSeconds
					local elapsed = total - (endsAt - Workspace:GetServerTimeNow())
					-- leave room for the 15s warning, the fall and the hold before the war ends
					if elapsed >= total * Pace.events.startFraction then
						lastWarRun = warNumber
						local rotation = Pace.events.rotation
						EventSystem.trigger(rotation[(warNumber - 1) % #rotation + 1])
					end
				end
			end
		end
	end)
end

return EventSystem
