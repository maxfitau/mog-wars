--!strict
-- Front-line spawning. During a war, every character that loads (joining mid-war or respawning after a
-- defeat) is moved to the faction's front line: just outside the owned zone nearest the map centre, on the
-- side facing its own base. A faction that owns nothing, and every spawn outside a war, uses the home base.
-- Roblox first places the character at the team's SpawnLocation; this system then moves it. Server only.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local SpawnRules = require(Shared:WaitForChild("SpawnRules"))
local CaptureSystem = require(script.Parent:WaitForChild("CaptureSystem"))

local SpawnSystem = {}

local slots: { [number]: number } = {} -- per faction counter that spreads players along the zone edge

-- A faction's home base position: the real SpawnLocation marked HomeBase if there is one, else the layout.
local function baseOf(faction: number): (number, number)
	for _, child in Workspace:GetChildren() do
		if child:IsA("SpawnLocation") and child:GetAttribute("HomeBase") == faction then
			return child.Position.X, child.Position.Z
		end
	end
	local fallback = MapLayout.bases[faction]
	return if fallback then fallback.x else 0, if fallback then fallback.z else 0
end

local function place(player: Player, character: Model)
	if player:GetAttribute("KnockoutRespawn") == true then
		player:SetAttribute("KnockoutRespawn", nil)
		-- after being reduced to NPC you respawn at your faction's corner, on the launch pad that throws you toward the action
		local faction = player:GetAttribute("Faction")
		local pad = Workspace:FindFirstChild("LaunchPad_" .. tostring(faction))
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if pad and pad:IsA("BasePart") and root and root:IsA("BasePart") and character.Parent then
			character:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
		end
		return
	end
	local faction = player:GetAttribute("Faction")
	if type(faction) ~= "number" or Workspace:GetAttribute("WarPhase") ~= "War" then
		return -- no faction yet, or not a war: stay at the home base
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root or not root:IsA("BasePart") or not character.Parent then
		return
	end
	slots[faction] = (slots[faction] or 0) + 1
	local baseX, baseZ = baseOf(faction)
	local x, z, kind = SpawnRules.spawnPoint(faction, CaptureSystem.zoneList(), baseX, baseZ, slots[faction])
	if kind ~= "zone" then
		return
	end
	local height = root.Position.Y
	local target = Vector3.new(x, height, z)
	character:PivotTo(CFrame.lookAt(target, Vector3.new(0, height, 0)))
end

-- Move a player (from Training Island) back to War Island. During a war they land on their faction's front
-- line; between wars, at their home base. Returns true if they were moved.
function SpawnSystem.sendToWar(player: Player): boolean
	local faction = player:GetAttribute("Faction")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if type(faction) ~= "number" or not character or not root or not root:IsA("BasePart") then
		return false
	end
	slots[faction] = (slots[faction] or 0) + 1
	local baseX, baseZ = baseOf(faction)
	local x, z
	if Workspace:GetAttribute("WarPhase") == "War" then
		x, z = SpawnRules.spawnPoint(faction, CaptureSystem.zoneList(), baseX, baseZ, slots[faction])
	else
		x, z = baseX, baseZ
	end
	local target = Vector3.new(x, 4, z)
	character:PivotTo(CFrame.lookAt(target, Vector3.new(0, 4, 0)))
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.defer(place, player, character)
	end)
end

function SpawnSystem.init()
	Players.PlayerAdded:Connect(watch)
end

function SpawnSystem.start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return SpawnSystem
