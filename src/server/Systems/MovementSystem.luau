--!strict
-- Fast movement. Server only. The server decides every speed:
--  * base speed on War Island (22) and on Training Island (16), from Pace.speed
--  * temporary boosts that add together: speed pads, AURA RUSH after a mog, Protein Shake
--  * the horse unit (an attribute UnitSystem sets), applied on top
--  * the short dash: the client asks, the server checks the cooldown, then tells that client to dash
--  * launch pads (one by each base) and the "WorldLaunch" message other systems use to throw a player
-- Players can only get faster through this module; a cheating client can still change its own speed, which is
-- why nothing here pays out for speed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local Features = require(Shared:WaitForChild("Features"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))

local MovementSystem = {}

type Boost = { id: string, bonus: number, untilTime: number }

local boosts: { [Player]: { Boost } } = {}
local frozenUntil: { [Player]: number } = {}
local slowUntil: { [Player]: number } = {}
local slowFactor: { [Player]: number } = {}
local lastDash: { [Player]: number } = {}
local lastPad: { [Player]: number } = {}
local remotes: { [string]: RemoteEvent } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Work out and apply this player's speed and jump.
function MovementSystem.refresh(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	local training = player:GetAttribute("Island") == "training"
	local base = if training then Pace.speed.normal else Pace.speed.war
	local bonus = 0
	local t = now()
	local list = boosts[player]
	if list then
		for index = #list, 1, -1 do
			if list[index].untilTime <= t then
				table.remove(list, index)
			else
				bonus += list[index].bonus
			end
		end
	end
	local horse = player:GetAttribute("HorseMultiplier")
	local speed = base.walk * (1 + bonus) * (if type(horse) == "number" then horse else 1)
	if (slowUntil[player] or 0) > t then
		speed *= slowFactor[player] or 1 -- slowed (Total Mog)
	end
	local frozen = (frozenUntil[player] or 0) > t -- frozen by a Mog Stare
	if humanoid.WalkSpeed ~= 0 or frozen then -- a stunned player (walk speed 0) stays stunned
		humanoid.WalkSpeed = if frozen then 0 else speed
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = if frozen then 0 else base.jump
	player:SetAttribute("SpeedBonus", bonus)
end

-- Add (or refresh) a temporary boost: `bonus` 0.5 means +50 percent. Same id replaces itself, so pads do not stack.
function MovementSystem.boost(player: Player, id: string, bonus: number, seconds: number)
	local list = boosts[player] or {}
	boosts[player] = list
	local untilTime = now() + seconds
	local found = false
	for _, entry in list do
		if entry.id == id then
			entry.bonus, entry.untilTime = bonus, untilTime
			found = true
		end
	end
	if not found then
		table.insert(list, { id = id, bonus = bonus, untilTime = untilTime })
	end
	MovementSystem.refresh(player)
	task.delay(seconds + 0.05, function()
		if player.Parent == Players then
			MovementSystem.refresh(player)
		end
	end)
end

function MovementSystem.isFrozen(player: Player): boolean
	return (frozenUntil[player] or 0) > now()
end

-- Slow a player to a share of their speed (0.5 = half) for a moment.
function MovementSystem.slow(player: Player, factor: number, seconds: number)
	slowUntil[player] = now() + seconds
	slowFactor[player] = factor
	MovementSystem.refresh(player)
	task.delay(seconds + 0.05, function()
		if player.Parent == Players then
			MovementSystem.refresh(player)
		end
	end)
end

-- Freeze a player in place (no walking, no jumping) for a moment: the Mog Stare.
function MovementSystem.freeze(player: Player, seconds: number)
	frozenUntil[player] = now() + seconds
	MovementSystem.refresh(player)
	task.delay(seconds + 0.05, function()
		if player.Parent == Players then
			MovementSystem.refresh(player)
		end
	end)
end

-- Throw a player (their own client applies it, because the client owns their character).
function MovementSystem.launch(player: Player, velocity: Vector3)
	if remotes.WorldLaunch then
		remotes.WorldLaunch:FireClient(player, velocity)
	end
end

-- A gentle push (added to what the player is already doing), for wind.
function MovementSystem.push(player: Player, velocity: Vector3)
	if remotes.WorldPush then
		remotes.WorldPush:FireClient(player, velocity)
	end
end

-- A short glowing trail behind the player while a speed boost lasts.
local function addTrail(player: Player, seconds: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or root:FindFirstChild("SpeedTrail") then
		return
	end
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 1.2, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -1.2, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "SpeedTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.45
	trail.LightEmission = 0.8
	trail.Color = ColorSequence.new(Color3.fromRGB(110, 230, 255), Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = root
	task.delay(seconds, function()
		trail:Destroy()
		top:Destroy()
		bottom:Destroy()
	end)
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

local function playSound(parent: Instance, id: string)
	if id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Parent = parent
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 3)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		MovementSystem.refresh(player)
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player:GetAttributeChangedSignal("Island"):Connect(function()
		task.defer(MovementSystem.refresh, player)
	end)
	player:GetAttributeChangedSignal("HorseMultiplier"):Connect(function()
		MovementSystem.refresh(player)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

local function bindPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or not humanoidOf(player) then
			return
		end
		local t = now()
		if t - (lastPad[player] or -100) < Pace.speed.pad.cooldownSeconds then
			return
		end
		lastPad[player] = t
		MovementSystem.boost(player, "pad", Pace.speed.pad.boost, Pace.speed.pad.seconds)
		addTrail(player, Pace.speed.pad.seconds)
		playSound(pad, Pace.sounds.whoosh)
	end)
end

local launchDebounce: { [Player]: number } = {}
local function bindLaunchPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	pad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local vector = pad:GetAttribute("Launch")
		if not player or not humanoidOf(player) or typeof(vector) ~= "Vector3" then
			return
		end
		local t = now()
		if t - (launchDebounce[player] or -100) < 1.5 then
			return
		end
		launchDebounce[player] = t
		MovementSystem.launch(player, vector)
		Events.fire(player, "launch", 1)
		playSound(pad, Pace.sounds.whoosh)
	end)
end

function MovementSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in { "DashRequest", "DashGo", "WorldLaunch", "WorldPush" } do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	remotes.DashRequest.OnServerEvent:Connect(function(player: Player, dx: any, dz: any)
		local rank = player:GetAttribute("Rank")
		if not Features.dash or not Features.abilities or type(rank) ~= "number" or rank < Pace.abilities.dash.rank then
			return -- dash is a Rookie ability
		end
		if type(dx) ~= "number" or type(dz) ~= "number" or dx ~= dx or dz ~= dz then
			return
		end
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 0.9 or length > 1.1 then
			return
		end
		local humanoid = humanoidOf(player)
		if not humanoid or player:GetAttribute("Island") == "training" then
			return
		end
		local t = now()
		if t - (lastDash[player] or -100) < Pace.speed.dash.cooldownSeconds then
			return
		end
		lastDash[player] = t
		player:SetAttribute("DashReadyAt", t + Pace.speed.dash.cooldownSeconds)
		remotes.DashGo:FireClient(player, dx / length, dz / length, Pace.speed.dash.speed, Pace.speed.dash.seconds)
	end)
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		boosts[player] = nil
		frozenUntil[player] = nil
		slowUntil[player] = nil
		slowFactor[player] = nil
		lastDash[player] = nil
		lastPad[player] = nil
		launchDebounce[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

function MovementSystem.start()
	for _, pad in CollectionService:GetTagged("SpeedPad") do
		bindPad(pad)
	end
	CollectionService:GetInstanceAddedSignal("SpeedPad"):Connect(bindPad)
	for _, pad in CollectionService:GetTagged("LaunchPad") do
		bindLaunchPad(pad)
	end
	CollectionService:GetInstanceAddedSignal("LaunchPad"):Connect(bindLaunchPad)
end

return MovementSystem
