--!strict
-- FLAGS YOU CAN SEE FROM ANYWHERE. For every flag the server publishes (parts tagged "Zone") this draws, on your screen only:
--   a tall pole with a big waving cloth flag in the owner's colour (white while neutral),
--   a tall beam of light in the owner's colour (it pulses while the flag is contested),
--   a glowing capture circle on the ground that fills like a pie in the capturing team's colour,
--   a floating flag icon (through walls, within ~150 studs) showing the owner colour and the capture percent,
--   and when the owner changes: the cloth whips to the new colour, with a burst of confetti.
-- Display only: it reads OwnerFaction, CapturerFaction, Progress (0 to 1) and Contested from the flag part.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FactionRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FactionRules"))

local FlagVisuals = {}

local STRIPS = 9
local SPOKES = 24
local touch = game:GetService("UserInputService").TouchEnabled

type Flag = {
	zone: BasePart,
	pole: Part,
	strips: { Part },
	beam: Part,
	spokes: { Part },
	icon: BillboardGui,
	percent: TextLabel,
	glyph: TextLabel,
	colour: Color3,
	whipUntil: number,
	lastOwner: number,
	height: number,
}

local flags: { Flag } = {}
local folder: Folder

local function colourOf(id: any): Color3
	local faction = if type(id) == "number" then FactionRules.factions[id] else nil
	return if faction then FactionRules.color(faction) else Color3.new(1, 1, 1)
end

local function part(name: string, size: Vector3, colour: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

local function confetti(position: Vector3, colour: Color3)
	local anchor = part("Confetti", Vector3.one, colour, Enum.Material.Neon)
	anchor.Transparency = 1
	anchor.Position = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colour), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, colour:Lerp(Color3.fromRGB(255, 215, 80), 0.5)),
	})
	emitter.Size = NumberSequence.new(0.7)
	emitter.Speed = NumberRange.new(20, 40)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Acceleration = Vector3.new(0, -26, 0)
	emitter.RotSpeed = NumberRange.new(-300, 300)
	emitter.LightEmission = 0.4
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(if touch then 35 else 70)
	game:GetService("Debris"):AddItem(anchor, 3)
end

local function build(zone: BasePart)
	local poleHeight = 30 -- much taller than the server's pole
	local position = zone.Position + Vector3.new(0, -0.5, 0)
	local pole = part("FlagPole", Vector3.new(0.9, poleHeight, 0.9), Color3.fromRGB(240, 240, 245), Enum.Material.Metal, Enum.PartType.Cylinder)
	pole.CFrame = CFrame.new(position + Vector3.new(0, poleHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pole.Size = Vector3.new(poleHeight, 0.9, 0.9)
	local strips: { Part } = {}
	for index = 1, STRIPS do
		strips[index] = part("Cloth", Vector3.new(1.6, 9, 0.25), Color3.new(1, 1, 1), Enum.Material.Fabric)
	end
	local beam = part("FlagBeam", Vector3.new(2.4, 240, 2.4), Color3.new(1, 1, 1), Enum.Material.Neon)
	beam.Position = position + Vector3.new(0, 120, 0)
	beam.Transparency = 0.6
	local spokes: { Part } = {}
	local radius = zone.Size.X / 2
	for index = 1, SPOKES do
		local spoke = part("PieSpoke", Vector3.new(radius, 0.15, math.pi * radius / SPOKES * 1.15), Color3.new(1, 1, 1), Enum.Material.Neon)
		local angle = (index - 0.5) / SPOKES * math.pi * 2
		spoke.CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * radius / 2, 0.45, math.sin(angle) * radius / 2)) * CFrame.Angles(0, -angle, 0)
		spoke.Transparency = 1
		spokes[index] = spoke
	end
	-- the floating icon: visible through walls within 150 studs
	local anchor = part("FlagIconAnchor", Vector3.one, Color3.new(1, 1, 1), Enum.Material.Neon)
	anchor.Transparency = 1
	anchor.Position = position + Vector3.new(0, poleHeight + 5, 0)
	local icon = Instance.new("BillboardGui")
	icon.Size = UDim2.fromOffset(86, 62)
	icon.AlwaysOnTop = true
	icon.MaxDistance = 150
	icon.Parent = anchor
	local glyph = Instance.new("TextLabel")
	glyph.Size = UDim2.new(1, 0, 0.62, 0)
	glyph.BackgroundTransparency = 1
	glyph.Font = Enum.Font.GothamBlack
	glyph.TextScaled = true
	glyph.Text = "⚑"
	glyph.TextStrokeTransparency = 0
	glyph.Parent = icon
	local percent = Instance.new("TextLabel")
	percent.Position = UDim2.fromScale(0, 0.6)
	percent.Size = UDim2.new(1, 0, 0.4, 0)
	percent.BackgroundTransparency = 1
	percent.Font = Enum.Font.GothamBlack
	percent.TextScaled = true
	percent.TextColor3 = Color3.new(1, 1, 1)
	percent.TextStrokeTransparency = 0
	percent.Text = ""
	percent.Parent = icon
	local owner = zone:GetAttribute("OwnerFaction")
	table.insert(flags, {
		zone = zone, pole = pole, strips = strips, beam = beam, spokes = spokes, icon = icon, percent = percent, glyph = glyph,
		colour = Color3.new(1, 1, 1), whipUntil = 0, lastOwner = if type(owner) == "number" then owner else 0, height = poleHeight,
	})
	-- hide the server's own small pole and cloth on this screen (the big ones above replace them)
	for _, name in { "Pole", "Cloth", "PoleTop" } do
		local old = zone:FindFirstChild(name)
		if old and old:IsA("BasePart") then
			old.Transparency = 1
		end
	end
end

function FlagVisuals.init()
	folder = Instance.new("Folder")
	folder.Name = "FlagVisuals"
	folder.Parent = Workspace
	for _, zone in CollectionService:GetTagged("Zone") do
		if zone:IsA("BasePart") then
			build(zone)
		end
	end
	CollectionService:GetInstanceAddedSignal("Zone"):Connect(function(zone)
		if zone:IsA("BasePart") then
			build(zone)
		end
	end)
end

function FlagVisuals.start()
	local last = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < (if touch then 0.06 else 0.033) then
			return
		end
		last = now
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		for _, flag in flags do
			local zone = flag.zone
			local owner = zone:GetAttribute("OwnerFaction")
			local capturer = zone:GetAttribute("CapturerFaction")
			local progress = zone:GetAttribute("Progress")
			local ownerId = if type(owner) == "number" then owner else 0
			local capturerId = if type(capturer) == "number" then capturer else 0
			local fraction = if type(progress) == "number" then math.clamp(progress, 0, 1) else 0
			local contested = zone:GetAttribute("Contested") == true
			local target = colourOf(ownerId)
			flag.colour = flag.colour:Lerp(target, 0.25) -- the cloth whips to the new colour
			if ownerId ~= flag.lastOwner then
				if ownerId ~= 0 then
					flag.whipUntil = now + 1.4
					confetti(zone.Position + Vector3.new(0, flag.height - 4, 0), target)
				end
				flag.lastOwner = ownerId
			end
			local close = (zone.Position - eye).Magnitude < 420
			-- cloth: nine strips with a travelling wave (bigger and faster while whipping)
			local whip = if now < flag.whipUntil then 2.6 else 1
			local base = zone.Position + Vector3.new(0, flag.height - 5.2, 0)
			for index, strip in flag.strips do
				strip.Color = flag.colour
				if close then
					local wave = math.sin(now * 3.4 * whip - index * 0.8)
					local wave2 = math.sin(now * 2.1 * whip - index * 0.5)
					strip.CFrame = CFrame.new(base + Vector3.new(0.5 + (index - 0.5) * 1.55, wave * 0.35 * index / STRIPS * whip, wave2 * 0.9 * index / STRIPS * whip)) * CFrame.Angles(0, wave * 0.18 * whip, 0)
				end
			end
			-- beam: tall, in the owner's colour (white while neutral); a fast pulse when contested
			local pulse = if contested then 0.5 + 0.5 * math.sin(now * 9) else 0
			flag.beam.Color = if capturerId ~= 0 and fraction > 0.02 and ownerId ~= capturerId then colourOf(capturerId):Lerp(flag.colour, 0.4) else flag.colour
			flag.beam.Transparency = 0.55 + pulse * 0.3
			-- pie: spokes light up in the capturing team's colour; an owned flag shows a faint full ring in the owner's colour
			local lit = 0
			local pieColour = flag.colour
			local pieTransparency = 0.25
			if capturerId ~= 0 and ownerId ~= capturerId and fraction > 0 then
				lit = math.floor(fraction * SPOKES + 0.5)
				pieColour = colourOf(capturerId)
			elseif ownerId ~= 0 then
				lit = SPOKES
				pieTransparency = 0.7
			end
			for index, spoke in flag.spokes do
				if index <= lit then
					spoke.Color = pieColour
					spoke.Transparency = pieTransparency
				else
					spoke.Transparency = 1
				end
			end
			-- floating icon
			flag.glyph.TextColor3 = flag.colour
			local shownCapturer = capturerId ~= 0 and ownerId ~= capturerId and fraction > 0.01
			flag.percent.Text = if shownCapturer then ("%d%%"):format(math.floor(fraction * 100 + 0.5)) else ""
			flag.percent.TextColor3 = if shownCapturer then colourOf(capturerId):Lerp(Color3.new(1, 1, 1), 0.3) else Color3.new(1, 1, 1)
		end
	end)
end

return FlagVisuals
