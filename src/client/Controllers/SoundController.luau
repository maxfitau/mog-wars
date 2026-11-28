--!strict
-- THE SOUND SYSTEM (client). Every sound goes through here and every id comes from Sounds.luau, so a missing or bad id is skipped
-- safely and never errors. It plays: music (calm on the islands, intense in the last minute), the capture tick and flag-captured
-- sound, shove, crits, ability sounds (when a cooldown starts), aura pop-up sounds (the pitch rises along a streak), level up and
-- rank up, UI clicks, an announcer sting on every banner, and meteor/drop sounds (called by EventController). Music and SFX each have
-- an on/off toggle (the little buttons under the minimap). In Studio it prints an audit: keys with no id and ids that failed to load.

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pace = require(Shared:WaitForChild("Pace"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local HudSlots = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("HudSlots"))

local SoundController = {}

local player = Players.LocalPlayer
local lastPlayed: { [string]: number } = {}
local musicOn, sfxOn = true, true
local groups: { [string]: SoundGroup } = {}

local function group(name: string): SoundGroup
	local found = groups[name]
	if found and found.Parent then
		return found
	end
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		groups[name] = existing
		return existing
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Parent = SoundService
	groups[name] = made
	return made
end

-- Play a one-shot UI/world sound by key, at an optional pitch. Safe with no id set.
function SoundController.play(key: string, pitch: number?)
	local id = Sounds.get(key)
	if id == "" or not sfxOn then
		return
	end
	local now = os.clock()
	if now - (lastPlayed[key] or 0) < 0.04 then
		return -- never stack the same sound in one frame
	end
	lastPlayed[key] = now
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Sounds.volume(key)
	sound.PlaybackSpeed = pitch or 1
	sound.SoundGroup = group("SFX")
	sound.Parent = SoundService
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 8)
end

function SoundController.setMusic(on: boolean)
	musicOn = on
	group("Music").Volume = if on then 1 else 0
end

function SoundController.setSfx(on: boolean)
	sfxOn = on
	group("SFX").Volume = if on then 1 else 0
	group("Ambient").Volume = if on then 1 else 0
end

function SoundController.isMusicOn(): boolean
	return musicOn
end

function SoundController.isSfxOn(): boolean
	return sfxOn
end

-- The pitch streak for aura pop-ups: rises with each one in a row, resets after a pause.
local streak, lastAura, lastAuraSound = 0, 0, 0
local function auraPitch(): number
	local now = os.clock()
	streak = if now - lastAura > 1.5 then 0 else math.min(streak + 1, 12)
	lastAura = now
	return 1 + streak * 0.06
end

-- Called by PopupController for every reward pop-up the server sends.
function SoundController.onPopup(kind: string, amount: number)
	if kind == "aura" or kind == "points" or kind == "box" then
		if os.clock() - lastAuraSound > 0.25 then -- a pitch-rising ping at most four times a second
			lastAuraSound = os.clock()
			SoundController.play("aura_pickup", auraPitch())
		end
	elseif kind == "crit" then
		SoundController.play("crit")
	elseif kind == "combo" then
		SoundController.play("combo", 1 + 0.12 * (amount - 1))
	elseif kind == "bonk" then
		SoundController.play("shove")
	elseif kind == "stolen" then
		SoundController.play("steal")
	elseif kind == "lost" then
		SoundController.play("lost")
	elseif kind == "knockout" then
		SoundController.play("knockout")
	elseif kind == "levelup" then
		SoundController.play("levelup")
	elseif kind == "rankup" then
		SoundController.play("rankup")
	elseif kind == "capture" then
		SoundController.play("capture_done")
	elseif kind == "pickup" then
		SoundController.play("pickup")
	elseif kind == "whoosh" then
		SoundController.play("whoosh")
	end
end

-- Music: two loops on the Music group, crossfaded. Calm normally, intense in the last minute of a war.
local function startMusic()
	local calm, intense
	local function track(key: string): Sound?
		local id = Sounds.get(key)
		if id == "" then
			return nil
		end
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = group("Music")
		sound.Parent = SoundService
		sound:Play()
		return sound
	end
	calm, intense = track("music_calm"), track("music_intense")
	if not calm and not intense then
		return
	end
	task.spawn(function()
		while true do
			task.wait(1)
			local phase = Workspace:GetAttribute("WarPhase")
			local endsAt = Workspace:GetAttribute("WarPhaseEndsAt")
			local last = phase == "War" and type(endsAt) == "number" and endsAt - Workspace:GetServerTimeNow() <= Pace.overtime.seconds
			local wantIntense = last and intense ~= nil
			if calm then
				TweenService:Create(calm, TweenInfo.new(2), { Volume = if wantIntense then 0 else Sounds.volume("music_calm") }):Play()
			end
			if intense then
				TweenService:Create(intense, TweenInfo.new(2), { Volume = if wantIntense then Sounds.volume("music_intense") else 0 }):Play()
			end
		end
	end)
end

-- Studio audit: which keys have no id, and which ids failed to load.
local function audit()
	if not RunService:IsStudio() then
		return
	end
	task.delay(6, function()
		local missing: { string } = {}
		local toLoad: { { key: string, sound: Sound } } = {}
		local holder = Instance.new("Folder")
		holder.Name = "SoundAudit"
		holder.Parent = SoundService
		for key, id in Sounds.ids do
			if id == "" then
				table.insert(missing, key)
			elseif not Sounds.valid(id) then
				warn(("[mog-wars] sound %s has a malformed id: %s"):format(key, tostring(id)))
			else
				local sound = Instance.new("Sound")
				sound.SoundId = id
				sound.Parent = holder
				table.insert(toLoad, { key = key, sound = sound })
			end
		end
		for key, id in Sounds.ambient do
			if id == "" then
				table.insert(missing, "ambient." .. key)
			end
		end
		local failed = 0
		if #toLoad > 0 then
			pcall(function()
				ContentProvider:PreloadAsync(holder:GetChildren())
			end)
			for _, entry in toLoad do
				if not entry.sound.IsLoaded or entry.sound.TimeLength <= 0 then
					failed += 1
					warn(("[mog-wars] sound FAILED to load: %s (%s)"):format(entry.key, entry.sound.SoundId))
				end
			end
		end
		holder:Destroy()
		table.sort(missing)
		print(("[mog-wars] sound audit: %d ids set, %d failed to load, %d have no id yet: %s"):format(#toLoad, failed, #missing, table.concat(missing, ", ")))
	end)
end

function SoundController.init()
	for _, name in { "Music", "SFX", "Ambient" } do
		group(name)
	end
	-- an announcer sting whenever a banner appears in the line slot
	HudSlots.onLine = function()
		SoundController.play("announcer")
	end
	-- UI clicks on every real button
	local gui = player:WaitForChild("PlayerGui")
	local function watch(descendant: Instance)
		if (descendant:IsA("TextButton") or descendant:IsA("ImageButton")) and not (descendant:IsA("TextButton") and descendant.Text == "" and descendant.BackgroundTransparency >= 1) then
			descendant.Activated:Connect(function()
				SoundController.play("ui_click")
			end)
		end
	end
	for _, descendant in gui:GetDescendants() do
		watch(descendant)
	end
	gui.DescendantAdded:Connect(watch)
	-- ability sounds: a cooldown starting means you used it
	for _, name in { "Dash", "Stare", "Slam", "Flip", "Shield", "Total" } do
		player:GetAttributeChangedSignal(name .. "ReadyAt"):Connect(function()
			local value = player:GetAttribute(name .. "ReadyAt")
			if type(value) == "number" and value > Workspace:GetServerTimeNow() then
				SoundController.play("ability_" .. string.lower(name))
			end
		end)
	end
	startMusic()
	audit()
end

function SoundController.start()
	-- the capture tick: once a second while you are standing on a flag your team is capturing (the pitch rises with progress)
	task.spawn(function()
		while true do
			task.wait(1)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local faction = player:GetAttribute("Faction")
			if root and root:IsA("BasePart") and type(faction) == "number" then
				for _, zone in CollectionService:GetTagged("Zone") do
					if zone:IsA("BasePart") then
						local offset = root.Position - zone.Position
						if math.sqrt(offset.X ^ 2 + offset.Z ^ 2) < zone.Size.X / 2 + 2 and math.abs(offset.Y) < 12 then
							local capturer, owner, progress = zone:GetAttribute("CapturerFaction"), zone:GetAttribute("OwnerFaction"), zone:GetAttribute("Progress")
							if capturer == faction and owner ~= faction and type(progress) == "number" then
								SoundController.play("capture_tick", 0.9 + progress * 0.6)
							end
						end
					end
				end
			end
		end
	end)
end

return SoundController
