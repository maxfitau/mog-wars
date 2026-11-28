--!strict
-- Moglings carry weapons too. Each Mogling is given a random Common or Rare weapon (WeaponCatalog odds "mogling"), shows it in its
-- hand, and now and then uses it on a nearby enemy with the very same server effects as a player (WeaponSystem.use). Never constant:
-- after each use a Mogling waits 2 to 4 times the weapon's cooldown, and it only tries when an enemy is within reach.
-- Moglings only act while the war is running.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponCatalog = require(Shared:WaitForChild("WeaponCatalog"))
local WeaponRules = require(Shared:WaitForChild("WeaponRules"))
local BotService = require(script.Parent:WaitForChild("BotService"))
local WeaponSystem = require(script.Parent:WaitForChild("WeaponSystem"))

local MoglingWeapons = {}

local THINK_SECONDS = 0.6
local TRY_CHANCE = 0.45 -- each think, a Mogling that is ready and has an enemy in reach tries with this chance
-- how close an enemy must be before a Mogling bothers (studs), by weapon kind
local ENGAGE: { [string]: number } = { hammer = 8, gust = 12, boomerang = 20, rose = 22 }

type Carry = { weapon: WeaponCatalog.Weapon, nextUse: number }

local carried: { [Model]: Carry } = setmetatable({}, { __mode = "k" }) :: any

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- The nearest enemy position (a player or another faction's Mogling) within `reach`, or nil.
local function nearestEnemy(bot: BotService.Bot, reach: number): Vector3?
	local origin = bot.root.Position
	local best: Vector3? = nil
	local bestDistance = reach
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local faction = player:GetAttribute("Faction")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and type(faction) == "number" and faction ~= 0 and faction ~= bot.faction then
			local distance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
			if distance < bestDistance and math.abs(root.Position.Y - origin.Y) < 10 then
				best, bestDistance = root.Position, distance
			end
		end
	end
	for _, other in BotService.list() do
		if other.faction ~= bot.faction then
			local position = other.root.Position
			local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
			if distance < bestDistance and math.abs(position.Y - origin.Y) < 10 then
				best, bestDistance = position, distance
			end
		end
	end
	return best
end

local function think()
	if Workspace:GetAttribute("WarPhase") ~= "War" then
		return
	end
	local t = now()
	for _, bot in BotService.list() do
		local carry = carried[bot.model]
		if not carry then
			local weapon = WeaponCatalog.roll("mogling", math.random)
			carry = { weapon = weapon, nextUse = WeaponRules.moglingNextUse(t, weapon.cooldown, math.random()) - weapon.cooldown }
			carried[bot.model] = carry
		end
		local current = carry :: Carry
		if not bot.model:FindFirstChild("HeldWeapon") then
			WeaponSystem.attachModel(bot.model, current.weapon, 1)
		end
		if t >= current.nextUse and bot.humanoid.WalkSpeed > 0 and math.random() < TRY_CHANCE then
			local reach = ENGAGE[current.weapon.kind] or 10
			local enemy = nearestEnemy(bot, reach)
			local att = WeaponSystem.attackerOfBot(bot)
			if enemy and att then
				local ax, az = WeaponRules.flat(bot.root.Position.X, bot.root.Position.Z, enemy.X, enemy.Z)
				if (ax ~= 0 or az ~= 0) and WeaponSystem.use(att, current.weapon, 1, ax, az, 0) then
					current.nextUse = WeaponRules.moglingNextUse(t, current.weapon.cooldown, math.random())
				end
			end
		end
	end
end

function MoglingWeapons.init() end

function MoglingWeapons.start()
	task.spawn(function()
		while true do
			task.wait(THINK_SECONDS)
			local ok, err = pcall(think)
			if not ok then
				warn("[mog-wars] Mogling weapons error: " .. tostring(err))
			end
		end
	end)
end

return MoglingWeapons
