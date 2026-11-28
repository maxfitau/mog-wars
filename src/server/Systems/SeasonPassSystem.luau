--!strict
-- THE FREE SEASON PASS (server). THE PASS IS OFF UNTIL UPDATE 1: this system is only loaded when Features.seasonPass is true.
-- It is free for everyone and never sold. It adds xp from Events ("war", "flag", "quest"; amounts in SeasonPassConfig), saves
-- data.pass = { tier, xp, claimed } and gives a tier's reward when the player claims it with Remotes.ClaimPassTier.
-- The remote carries ONE value (a tier number or an id like "t5"); the server checks the type and range, the rate, that the
-- player has really reached the tier and that it is not claimed yet, and only then marks it claimed and pays.
-- The HUD reads three attributes on the player: PassXp, PassTier and PassClaimed (claimed tiers, "1,2,5").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared:WaitForChild("Levels"))
local SeasonPassConfig = require(Shared:WaitForChild("SeasonPassConfig"))
local CosmeticCatalog = require(Shared:WaitForChild("CosmeticCatalog"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local PopupSystem = require(script.Parent:WaitForChild("PopupSystem"))
local Events = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("Events"))

local SeasonPassSystem = {}

local CLAIM_GAP = 0.4 -- seconds between claim requests from one player
local lastClaim: { [Player]: number } = {}

-- The pass table of a player's save, repaired if it is somehow missing.
local function passOf(player: Player): { tier: number, xp: number, claimed: { [string]: boolean } }?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local pass = data.pass
	if type(pass) ~= "table" then
		pass = { tier = 0, xp = 0, claimed = {} }
		data.pass = pass
	end
	if type(pass.claimed) ~= "table" then
		pass.claimed = {}
	end
	if type(pass.xp) ~= "number" or pass.xp ~= pass.xp then
		pass.xp = 0
	end
	return pass
end

-- Publish the numbers the HUD shows.
local function sync(player: Player)
	local pass = passOf(player)
	if not pass then
		return
	end
	pass.tier = SeasonPassConfig.tierForXp(pass.xp)
	player:SetAttribute("PassXp", pass.xp)
	player:SetAttribute("PassTier", pass.tier)
	local claimed: { string } = {}
	for tier = 1, SeasonPassConfig.tierCount do
		if pass.claimed[SeasonPassConfig.claimId(tier)] then
			table.insert(claimed, tostring(tier))
		end
	end
	player:SetAttribute("PassClaimed", table.concat(claimed, ","))
end

local function addXp(player: Player, amount: number)
	local pass = passOf(player)
	if not pass or amount <= 0 then
		return
	end
	pass.xp = SeasonPassConfig.addXp(pass.xp, amount)
	sync(player)
end

-- Pay one reward. Returns true when it was given or recorded. Config-only ids and the future weapon have nothing to hand out
-- yet, so they are recorded as "grant:<id>" in pass.claimed for Update 1 to honour.
local function give(player: Player, pass: { tier: number, xp: number, claimed: { [string]: boolean } }, reward: SeasonPassConfig.Reward)
	if reward.kind == "aura" then
		local level = player:GetAttribute("Level")
		local income = Levels.nominalIncome(if type(level) == "number" then level else 0)
		local amount = SeasonPassConfig.auraAmount(reward, income)
		if amount > 0 then
			local shown = DataService.addAura(player, amount, true, true, true)
			if shown > 0 then
				PopupSystem.send(player, "aura", shown, "")
			end
		end
	elseif reward.kind == "chest" then
		DataService.rollWeapon(player, "quest")
	elseif reward.kind == "trail" and reward.inCatalog and reward.id and CosmeticCatalog.byId[reward.id] then
		DataService.grantCosmetic(player, reward.id)
	else
		pass.claimed[SeasonPassConfig.grantKey(reward)] = true
		if reward.kind == "title" and reward.text then
			local data = DataService.get(player)
			if data and data.title == "" then
				DataService.setTitle(player, reward.text) -- never replaces a title the player already has
			end
		end
	end
	PopupSystem.send(player, "pickup", 1, SeasonPassConfig.describe(reward))
end

local function claim(player: Player, value: any)
	local now = os.clock()
	if now - (lastClaim[player] or 0) < CLAIM_GAP then
		return
	end
	lastClaim[player] = now
	local tier = SeasonPassConfig.parseTier(value)
	local pass = passOf(player)
	if tier == nil or not pass then
		return
	end
	local id = SeasonPassConfig.claimId(tier)
	if pass.claimed[id] or SeasonPassConfig.tierForXp(pass.xp) < tier then
		return -- already claimed, or not reached yet
	end
	local reward = SeasonPassConfig.rewardFor(tier)
	if not reward then
		return
	end
	pass.claimed[id] = true -- marked BEFORE paying so a second request can never pay twice
	local ok, err = pcall(give, player, pass, reward)
	if not ok then
		warn("[mog-wars] season pass reward failed: " .. tostring(err))
	end
	sync(player)
end

function SeasonPassSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local request = Instance.new("RemoteEvent")
	request.Name = "ClaimPassTier"
	request.Parent = folder
	request.OnServerEvent:Connect(function(player: Player, value: any)
		claim(player, value)
	end)

	Events.on(function(player: Player, kind: string)
		local amount = SeasonPassConfig.xpForSource(kind)
		if amount > 0 then
			addXp(player, amount)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			if DataService.waitFor(player, 30) then
				sync(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)
end

function SeasonPassSystem.start()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if DataService.waitFor(player, 30) then
				sync(player)
			end
		end)
	end
end

return SeasonPassSystem
