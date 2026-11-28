--!strict
-- AURA STEALING and the BOUNTY. Knock someone off an island (or freeze them and then shove them) and they drop glowing aura
-- orbs worth a share of the aura they earned THIS WAR. It never touches their saved total, so ranks never go down. The orbs
-- float and magnet to whoever touches them first ("+45 STOLEN!" in purple); the victim sees a brief "-45 aura".
-- The player with the most aura this war wears a floating crown, a tall light beam and a "MOST AURA" tag; knocking them out
-- steals more and announces "BOUNTY CLAIMED!" to the whole server. Server only; numbers in Pace.steal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Levels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Levels"))
local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))
local Stats = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Stats"))

local StealSystem = {}

type Orb = { part: Part, value: number, owner: Player?, born: number, base: boolean? }

local lastHit: { [Player]: { attacker: Player?, time: number } } = {}
local lastSteal: { [Player]: number } = {}
local orbs: { Orb } = {}
local leader: Player? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Remember who last shoved/froze/hit a player (so a fall within a few seconds counts as a knock-off).
-- Scatter `count` free orbs around a point (used by events). `each` is in level-0 aura; DataService scales it for whoever
-- picks it up, so it is worth the same number of seconds of income at every level.
function StealSystem.dropFreeOrbs(position: Vector3, count: number, each: number, lifetime: number?)
	for index = 1, count do
		local angle = index / count * math.pi * 2 + math.random() * 0.4
		local radius = 8 + math.random() * 26
		local orb = Instance.new("Part")
		orb.Name = "AuraOrb"
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(2.6, 2.6, 2.6)
		orb.Material = Enum.Material.Neon
		orb.Color = if index % 2 == 0 then Color3.fromRGB(190, 90, 255) else Color3.fromRGB(255, 205, 70)
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CanTouch = false
		orb.Position = position + Vector3.new(math.cos(angle) * radius, 4 + (index % 3), math.sin(angle) * radius)
		orb.Parent = Workspace
		local light = Instance.new("PointLight")
		light.Color = orb.Color
		light.Range = 10
		light.Parent = orb
		table.insert(orbs, { part = orb, value = each, owner = nil, born = now() - Pace.steal.orbSeconds + (lifetime or Pace.meteor.orbSeconds), base = true })
	end
end

function StealSystem.noteHit(victim: Player, attacker: Player?)
	lastHit[victim] = { attacker = attacker, time = now() }
end

local function spawnOrbs(position: Vector3, total: number, owner: Player?)
	local count = Pace.steal.orbs
	local each = math.max(1, math.floor(total / count))
	for index = 1, count do
		local angle = index / count * math.pi * 2
		local orb = Instance.new("Part")
		orb.Name = "AuraOrb"
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(2.2, 2.2, 2.2)
		orb.Material = Enum.Material.Neon
		orb.Color = if index % 2 == 0 then Color3.fromRGB(190, 90, 255) else Color3.fromRGB(255, 205, 70)
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CanTouch = false
		orb.Position = position + Vector3.new(math.cos(angle) * 3, 3 + (index % 3), math.sin(angle) * 3)
		orb.Parent = Workspace
		local light = Instance.new("PointLight")
		light.Color = orb.Color
		light.Range = 10
		light.Parent = orb
		table.insert(orbs, { part = orb, value = each, owner = owner, born = now() })
	end
end

-- Steal from `victim` because `attacker` (nil for a Mogling) knocked them off or shoved them while frozen.
function StealSystem.steal(victim: Player, attacker: Player?)
	local t = now()
	if t - (lastSteal[victim] or -100) < Pace.steal.victimCooldownSeconds then
		return
	end
	local war = Stats.get(victim).aura
	if war < Pace.steal.minWarAura * Levels.multiplier((victim:GetAttribute("Level") :: any) or 0) then
		return
	end
	local isLeader = leader == victim
	local amount = math.floor(war * (if isLeader then Pace.steal.bountyFraction else Pace.steal.fraction))
	if amount < 1 then
		return
	end
	lastSteal[victim] = t
	Stats.add(victim, "aura", -amount) -- this war's tally only; the saved total is never touched
	PopupSystem.send(victim, "lost", amount, "")
	local root = rootOf(victim)
	if root then
		spawnOrbs(root.Position, amount, victim)
	end
	if attacker then
		Events.fire(attacker, "steal", amount)
		if isLeader then
			Events.fire(attacker, "bounty", 1)
		end
	end
	if isLeader then
		for _, player in Players:GetPlayers() do
			PopupSystem.send(player, "announce", 1, ("BOUNTY CLAIMED! %s got %s"):format(if attacker then attacker.DisplayName else "A Mogling", victim.DisplayName))
		end
	end
end

-- Called when a player falls off the world: if somebody pushed them recently, that is a knock-off.
function StealSystem.onFall(victim: Player)
	local hit = lastHit[victim]
	if hit and now() - hit.time <= Pace.steal.attributionSeconds then
		if hit.attacker then
			PopupSystem.send(hit.attacker, "announce", 1, "YEET!")
			Events.fire(hit.attacker, "yeet", 1)
		end
		StealSystem.steal(victim, hit.attacker)
	end
	lastHit[victim] = nil
end

-- A shove on a player who is frozen steals straight away.
function StealSystem.shoveFrozen(victim: Player, attacker: Player?)
	StealSystem.steal(victim, attacker)
end

local function setBounty(player: Player?)
	-- remove the old marker
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local old = character and character:FindFirstChild("BountyMarker")
		if old and other ~= player then
			old:Destroy()
		end
	end
	leader = player
end

local function ensureMarker(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local head = character and character:FindFirstChild("Head")
	if not character or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") or character:FindFirstChild("BountyMarker") then
		return
	end
	local marker = Instance.new("Folder")
	marker.Name = "BountyMarker"
	marker.Parent = character
	local function attach(part: Part, offset: CFrame)
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = marker
	end
	local crown = Instance.new("Part")
	crown.Name = "Crown"
	crown.Size = Vector3.new(3.4, 1.4, 3.4)
	crown.Material = Enum.Material.Neon
	crown.Color = Color3.fromRGB(255, 205, 60)
	attach(crown, CFrame.new(0, 4.4, 0))
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Size = Vector3.new(1.4, 220, 1.4)
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 220, 90)
	beam.Transparency = 0.55
	attach(beam, CFrame.new(0, 112, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 150, 0, 30)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 500
	gui.Adornee = head
	gui.Parent = marker
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	label.TextStrokeTransparency = 0
	label.Text = "MOST AURA"
	label.Parent = gui
end

function StealSystem.init()
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
		lastSteal[player] = nil
		if leader == player then
			leader = nil
		end
	end)
end

function StealSystem.start()
	-- orbs: float, magnet to the nearest player, and pay out to whoever touches them first
	task.spawn(function()
		while true do
			task.wait(0.12)
			local t = now()
			local paid: { [Player]: number } = {}
			local paidBase: { [Player]: number } = {}
			for index = #orbs, 1, -1 do
				local orb = orbs[index]
				if t - orb.born > Pace.steal.orbSeconds or not orb.part.Parent then
					orb.part:Destroy()
					table.remove(orbs, index)
				else
					local bestPlayer: Player? = nil
					local bestRoot: BasePart? = nil
					local bestDistance = Pace.steal.magnetRange
					for _, player in Players:GetPlayers() do
						local root = rootOf(player)
						if root and type(player:GetAttribute("Faction")) == "number" then
							local distance = (root.Position - orb.part.Position).Magnitude
							if distance < bestDistance then
								bestPlayer, bestRoot, bestDistance = player, root, distance
							end
						end
					end
					if bestPlayer and bestRoot then
						if bestDistance < Pace.steal.pickupRange then
							if orb.base then
								paidBase[bestPlayer] = (paidBase[bestPlayer] or 0) + orb.value
							else
								paid[bestPlayer] = (paid[bestPlayer] or 0) + orb.value
							end
							Events.fire(bestPlayer, "orb", 1)
							orb.part:Destroy()
							table.remove(orbs, index)
						else
							local toward = (bestRoot.Position + Vector3.new(0, 2, 0) - orb.part.Position).Unit
							orb.part.Position += toward * 30 * 0.12
						end
					else
						orb.part.Position += Vector3.new(0, math.sin(t * 3 + index) * 0.04, 0)
					end
				end
			end
			for player, value in paidBase do -- event orbs: worth "seconds of income" for whoever collects them (DataService scales)
				local shown = DataService.addAura(player, value)
				if shown > 0 then
					Stats.add(player, "aura", shown)
					PopupSystem.send(player, "aura", shown, "")
				end
			end
			for player, value in paid do
				local shown = DataService.addAura(player, value, true)
				if shown > 0 then
					Stats.add(player, "aura", shown)
					Stats.add(player, "stolen", shown)
					PopupSystem.send(player, "stolen", shown, "")
				end
			end
		end
	end)
	-- the bounty: the player with the most aura this war
	task.spawn(function()
		while true do
			task.wait(2)
			local best: Player? = nil
			local bestAura = 0
			if Workspace:GetAttribute("WarPhase") == "War" then
				for _, player in Players:GetPlayers() do
					local aura = Stats.get(player).aura
					-- the crown threshold is "seconds of income", so it grows with the leader's level
					local needed = Pace.steal.bountyMinAura * Levels.multiplier((player:GetAttribute("Level") :: any) or 0)
					if aura > bestAura and aura >= needed then
						best, bestAura = player, aura
					end
				end
			end
			if best ~= leader then
				setBounty(best)
				if best then
					for _, player in Players:GetPlayers() do
						PopupSystem.send(player, "announce", 1, ("%s has the most aura! BOUNTY!"):format(best.DisplayName))
					end
				end
			end
			if leader then
				ensureMarker(leader)
			end
		end
	end)
end

return StealSystem
