--!strict
-- STUDIO-ONLY test commands, typed in the chat. They only exist while playing in Roblox Studio (RunService:IsStudio()),
-- so a normal player in a live server has no debug access at all: this system does nothing there.
--   /mog level 25      jump to level 25      /mog gigachad    jump to Gigachad I (level 41)
--   /mog mogstar 5     jump to Mog God ★5    /mog mogod       jump to Mog God I (level 51)
--   /mog reset         reset your test data to a brand new player
--   /mog meteor        start the Aura Meteor now    /mog drop     drop a crate    /mog gold     drop a GOLD crate
--   /mog aura 1e9      add that much aura (level scaling applies)
--   /mog weapon <id>   give a weapon (a duplicate adds a star)   /mog weapons   one of every weapon   /mog chest   roll a chest weapon
--   /mog event [min]   start the weekly event now (default 10 minutes)   /mog eventstop   end it   /mog unequip   plain Shove

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local Levels = require(Shared:WaitForChild("Levels"))
local Features = require(Shared:WaitForChild("Features"))
local WeaponCatalog = require(Shared:WaitForChild("WeaponCatalog"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))

local DebugSystem = {}

-- Only in Studio, only for an allowed user id (Pace.debug.allowedUserIds, or the place owner when it is saved under a user).
local function allowed(player: Player): boolean
	if not RunService:IsStudio() then
		return false
	end
	if table.find(Pace.debug.allowedUserIds, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId ~= 0 and game.CreatorId == player.UserId
end

local function note(player: Player, text: string)
	PopupSystem.send(player, "announce", 1, text)
end

local function handle(player: Player, message: string)
	local words = string.split(string.lower(message), " ")
	if words[1] ~= "/mog" or not allowed(player) then
		return
	end
	local command, argument = words[2], tonumber(words[3] or "")
	if command == "level" and argument then
		DataService.debugSetLevel(player, argument)
		note(player, "debug: level " .. tostring(math.floor(argument)))
	elseif command == "gigachad" then
		DataService.debugSetLevel(player, Levels.firstLevelOfRank(6))
		note(player, "debug: Gigachad")
	elseif command == "mogod" then
		DataService.debugSetLevel(player, Levels.firstLevelOfRank(7))
		note(player, "debug: Mog God")
	elseif command == "mogstar" then
		DataService.debugSetLevel(player, 6 * Pace.levels.perRank + math.max(1, math.floor(argument or 5)))
		note(player, "debug: Mog God star")
	elseif command == "weapon" and words[3] then
		local isNew, stars = DataService.grantWeapon(player, words[3], "debug")
		note(player, if stars > 0 then ("debug: %s %d stars%s"):format(words[3], stars, if isNew then " (new)" else "") else "debug: no such weapon id")
	elseif command == "weapons" then
		for _, weapon in WeaponCatalog.weapons do
			DataService.grantWeapon(player, weapon.id, "debug")
		end
		note(player, "debug: one of every weapon")
	elseif command == "chest" then
		local id = DataService.rollWeapon(player, "chest")
		note(player, "debug: chest gave " .. tostring(id))
	elseif command == "unequip" then
		DataService.equipWeapon(player, "")
	elseif command == "event" or command == "eventstop" then
		local ok, WeeklyEventSystem = pcall(function()
			return require(script.Parent:WaitForChild("WeeklyEventSystem", 2))
		end)
		if ok then
			if command == "event" then
				(WeeklyEventSystem :: any).forceStart(argument or 10)
				note(player, "debug: weekly event started")
			else
				(WeeklyEventSystem :: any).forceStop()
				note(player, "debug: weekly event stopped")
			end
		else
			note(player, "debug: the weekly event system is not loaded")
		end
	elseif command == "reset" then
		DataService.debugReset(player)
		note(player, "debug: your test data was reset")
	elseif command == "aura" and argument then
		DataService.addAura(player, argument)
	elseif command == "meteor" or command == "drop" or command == "gold" then
		local ok, EventSystem = pcall(function()
			return require(script.Parent:WaitForChild("EventSystem", 2))
		end)
		local ok2, SupplyDropSystem = pcall(function()
			return require(script.Parent:WaitForChild("SupplyDropSystem", 2))
		end)
		if command == "meteor" and ok then
			(EventSystem :: any).trigger("meteor")
		elseif ok2 then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local where = if root and root:IsA("BasePart") then root.Position + root.CFrame.LookVector * 14 else nil
			;(SupplyDropSystem :: any).drop(command == "gold", where)
		end
	end
end

function DebugSystem.init() end

function DebugSystem.start()
	if not Features.debugCommands or not RunService:IsStudio() then
		return -- a live server: no debug commands for anyone
	end
	local function watch(player: Player)
		if not allowed(player) then
			print(("[mog-wars] debug commands are OFF for user id %d. To use them, add %d to Pace.debug.allowedUserIds in src/shared/Pace.luau."):format(player.UserId, player.UserId))
		end
		player.Chatted:Connect(function(message)
			handle(player, message) -- (handle checks Studio and the allowed user ids again)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	print("[mog-wars] Studio debug commands on: /mog level N | gigachad | mogod | mogstar N | meteor | drop | gold | aura N")
end

return DebugSystem
