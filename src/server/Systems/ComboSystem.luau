--!strict
-- COMBOS and CRITS. Captures, shoves, orb pickups and stashes within a few seconds of each other build a combo
-- (x2, x3, x5, x10) that multiplies aura (DataService.addAura reads the "ComboMult" attribute). The combo breaks after
-- Pace.combo.windowSeconds with a soft "combo ended +240" summary. Crits (MEGA MOG! x5, ULTRA MOG! x10) are rolled in
-- DataService.addAura and announced here. Server only; every number is in Pace.combo and Pace.crit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))

local ComboSystem = {}

local COMBO_KINDS = { flag = true, territory = true, shove_mogling = true, shove_player = true, orb = true, stash = true, stare = true, yeet = true }

local lastKind: { [Player]: string } = {}
local counts: { [Player]: number } = {}
local untilTime: { [Player]: number } = {}

local function multiplierFor(count: number): number
	local result = 1
	for _, tier in Pace.combo.tiers do
		if count >= tier[1] then
			result = tier[2]
		end
	end
	return result
end

local function endCombo(player: Player)
	local bonus = player:GetAttribute("ComboBonus")
	if type(bonus) == "number" and bonus >= 1 then
		PopupSystem.send(player, "comboend", bonus, "")
	end
	counts[player] = nil
	untilTime[player] = nil
	player:SetAttribute("ComboMult", 1)
	player:SetAttribute("ComboCount", 0)
	player:SetAttribute("ComboBonus", 0)
end

local function bump(player: Player, kind: string)
	local now = Workspace:GetServerTimeNow()
	if (untilTime[player] or 0) < now and (counts[player] or 0) > 0 then
		endCombo(player)
	end
	local count = (counts[player] or 0) + 1
	counts[player] = count
	untilTime[player] = now + Pace.combo.windowSeconds
	local mult = multiplierFor(count)
	player:SetAttribute("ComboCount", count)
	player:SetAttribute("ComboMult", mult)
	if mult >= 2 then
		PopupSystem.send(player, "combo", mult, tostring(count))
		Events.fire(player, "maxCombo", mult)
	end
	local callout = Pace.combo.callouts[count]
	if count == 2 and string.sub(kind, 1, 5) == "shove" and string.sub(lastKind[player] or "", 1, 5) == "shove" then
		callout = "DOUBLE SHOVE!"
	end
	lastKind[player] = kind
	if callout then
		PopupSystem.send(player, "announce", 1, callout)
	end
end

function ComboSystem.init()
	Events.on(function(player: Player, kind: string)
		if COMBO_KINDS[kind] then
			bump(player, kind)
		end
	end)
	DataService.onCrit = function(player: Player, tier: string, amount: number)
		PopupSystem.send(player, "crit", amount, tier)
		Events.fire(player, if tier == "ultra" then "ultra" else "mega", 1)
	end
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
		untilTime[player] = nil
	end)
end

function ComboSystem.start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = Workspace:GetServerTimeNow()
			for player, expires in untilTime do
				if expires < now and (counts[player] or 0) > 0 then
					endCombo(player)
				end
			end
		end
	end)
end

return ComboSystem
