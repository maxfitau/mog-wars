--!strict
-- ALL SOUND IDS LIVE HERE. Paste Roblox-owned or licensed audio ids as "rbxassetid://123456789" (find them in the Creator Store under
-- Audio, filtered to Roblox's own library, and check the audio is usable in your experience). An empty string means "no sound": the
-- game skips it safely, nothing errors. In Studio the client prints an audit shortly after you join: every key with no id, and every
-- id that failed to load. Nothing else in the code needs to change.

local Sounds = {}

Sounds.ids = {
	-- music (loops): calm on the islands, intense in the last minute of a war
	music_calm = "",
	music_intense = "",
	-- captures
	capture_tick = "", -- every second you capture a flag (pitch rises with progress)
	capture_done = "", -- a flag flips
	-- fighting
	shove = "", -- the shove "bonk"
	crit = "", -- MEGA / ULTRA MOG
	combo = "", -- a combo step (pitch rises)
	steal = "", -- aura orbs flying to you
	lost = "", -- you lost aura
	knockout = "",
	whoosh = "", -- falling into the clouds, speed and launch pads
	-- abilities
	ability_dash = "",
	ability_stare = "",
	ability_slam = "",
	ability_flip = "",
	ability_shield = "",
	ability_total = "",
	-- rewards
	aura_pickup = "", -- every aura pop-up (pitch rises with a streak)
	pickup = "", -- a pickup or a cosmetic
	levelup = "",
	rankup = "", -- the rank-up fanfare
	-- events and drops
	meteor_alarm = "",
	meteor_boom = "",
	meteor_claim = "",
	drop_land = "", -- a supply crate touches down
	drop_open = "", -- the pop and confetti
	drop_gold = "",
	-- traps
	trap_warn = "",
	trap_boom = "",
	trap_slime = "",
	trap_zap = "",
	trap_chomp = "",
	-- interface
	ui_click = "",
	announcer = "", -- a short sting whenever a banner appears
}

-- Ambient loops, one per territory (3D, they get louder as you get close). Key = territory id.
Sounds.ambient = {
	npc_village = "", -- murmuring villagers, a quiet breeze, birds
	brainrot_bog = "", -- bubbling swamp, croaks
	cooked_canyon = "", -- crackling lava
	rizz_ravine = "", -- wind and soft chimes
	locked_in_lighthouse = "", -- waves and gulls
	gigachad_gate = "", -- a low heroic drone
	chud_chambers = "", -- cave drips and a low rumble
}

-- Per-key volume (0 to 1); anything not listed uses `defaultVolume`.
Sounds.defaultVolume = 0.5
Sounds.volumes = {
	music_calm = 0.28,
	music_intense = 0.34,
	capture_tick = 0.3,
	ui_click = 0.35,
	aura_pickup = 0.3,
	announcer = 0.45,
}

-- Is this a usable asset id? (rbxassetid:// followed by digits)
function Sounds.valid(id: any): boolean
	return type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

-- The id for a key, or "" when none is set (or it is malformed): play only when this is not "".
function Sounds.get(key: string): string
	local id = (Sounds.ids :: any)[key]
	if Sounds.valid(id) then
		return id
	end
	return ""
end

function Sounds.volume(key: string): number
	return (Sounds.volumes :: any)[key] or Sounds.defaultVolume
end

-- The loop for a territory ("" if none).
function Sounds.ambientFor(territoryId: string): string
	local id = (Sounds.ambient :: any)[territoryId]
	if Sounds.valid(id) then
		return id
	end
	return ""
end

-- The three volume groups (Music, SFX, Ambient) in SoundService. The server makes them (PopupSystem.init); the client's volume
-- toggles change them. Returns the group or nil.
function Sounds.group(name: string): SoundGroup?
	local found = game:GetService("SoundService"):FindFirstChild(name)
	return if found and found:IsA("SoundGroup") then found else nil
end

-- Play a one-shot 3D sound at/inside `parent` (a Part) for `key`, safely: nothing happens when no valid id is set.
function Sounds.playAt(parent: Instance, key: string, pitch: number?)
	local id = Sounds.get(key)
	if id == "" or not parent.Parent then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Sounds.volume(key)
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMaxDistance = 140
	sound.SoundGroup = Sounds.group("SFX")
	sound.Parent = parent
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 6)
end

return Sounds
