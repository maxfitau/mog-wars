--!strict
-- The four TEAM MASCOTS (original designs), built from parts:
--   1 Jawline Legion: a lion with a ridiculously chiseled jaw      2 Mewing Order: a calm owl, beak pressed shut, meditating
--   3 Sigma Syndicate: a lone wolf wearing sunglasses              4 Aura Collective: a glowing purple phoenix
-- `Mascots.build` makes one at a CFrame and scale (front faces -Z of the frame) and returns its model and a waving arm for the
-- small animated NPC. Everything is anchored and non-colliding. Faction colours appear only on small team gear (banners, scarf).

local Workspace = game:GetService("Workspace")

local Mascots = {}

export type Built = { model: Model, root: Part, arm: Part?, armPivot: CFrame?, armLocal: CFrame?, parts: { Part } }

local function make(parent: Instance, origin: CFrame, scale: number)
	local parts: { Part } = {}
	local function P(name: string, size: Vector3, position: Vector3, colour: Color3, material: Enum.Material, shape: Enum.PartType?, rotation: Vector3?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * scale
		p.Color = colour
		p.Material = material
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		local r = rotation or Vector3.zero
		p.CFrame = origin * CFrame.new(position * scale) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
		p.Parent = parent
		table.insert(parts, p)
		return p
	end
	return P, parts
end

local BALL = Enum.PartType.Ball

local function lion(P: any): Part
	local tan, dark, mane = Color3.fromRGB(226, 170, 92), Color3.fromRGB(190, 135, 70), Color3.fromRGB(176, 66, 38)
	P("Body", Vector3.new(6.4, 7, 6), Vector3.new(0, 4.4, 0), tan, Enum.Material.Concrete, BALL)
	for _, side in { -1, 1 } do
		P("FrontLeg", Vector3.new(1.9, 3.4, 1.9), Vector3.new(side * 1.7, 1.7, -2.3), tan, Enum.Material.Concrete)
		P("Paw", Vector3.new(2.2, 0.9, 2.8), Vector3.new(side * 1.7, 0.45, -2.8), dark, Enum.Material.Concrete)
		P("Ear", Vector3.new(1.4, 1.4, 0.8), Vector3.new(side * 2.3, 11.4, 0), dark, Enum.Material.Concrete, BALL)
		P("Cheekbone", Vector3.new(1.6, 1.4, 1.6), Vector3.new(side * 2.7, 8.1, -2.6), dark, Enum.Material.Concrete, nil, Vector3.new(0, 0, side * 20))
		P("Eye", Vector3.new(0.9, 0.9, 0.5), Vector3.new(side * 1.25, 9.8, -2.9), Color3.fromRGB(30, 24, 20), Enum.Material.Slate, BALL)
		P("Brow", Vector3.new(1.8, 0.4, 0.5), Vector3.new(side * 1.3, 10.5, -2.8), Color3.fromRGB(120, 70, 40), Enum.Material.Concrete, nil, Vector3.new(0, 0, side * -18))
	end
	P("Head", Vector3.new(5.2, 5, 5), Vector3.new(0, 9.2, -0.3), tan, Enum.Material.Concrete, BALL)
	for index = 0, 11 do -- the mane: a ring of fluffy balls round the head
		local angle = index / 12 * math.pi * 2
		P("Mane", Vector3.new(3.3, 3.3, 3), Vector3.new(math.cos(angle) * 3.3, 9.2 + math.sin(angle) * 3.3, 0.9), mane:Lerp(Color3.fromRGB(220, 110, 50), index % 3 / 4), Enum.Material.Fabric, BALL)
	end
	-- THE JAW: a huge square chin sticking out, with a chiselled cleft, a strong lower lip and angular jaw corners
	P("Jaw", Vector3.new(4.8, 2.8, 3.6), Vector3.new(0, 7.2, -2.7), dark, Enum.Material.Concrete)
	P("Chin", Vector3.new(3.4, 1.8, 2.4), Vector3.new(0, 6.4, -3.6), tan, Enum.Material.Concrete)
	P("ChinCleft", Vector3.new(0.3, 1.4, 0.3), Vector3.new(0, 6.5, -4.85), Color3.fromRGB(110, 70, 40), Enum.Material.Slate)
	for _, side in { -1, 1 } do
		P("JawCorner", Vector3.new(1.4, 2, 2), Vector3.new(side * 2.7, 6.9, -1.2), dark, Enum.Material.Concrete, nil, Vector3.new(0, side * 20, 0))
	end
	P("Nose", Vector3.new(1.3, 0.9, 1), Vector3.new(0, 8.7, -3.3), Color3.fromRGB(70, 40, 40), Enum.Material.Slate)
	P("Mouth", Vector3.new(2.4, 0.2, 0.3), Vector3.new(0, 7.9, -3.5), Color3.fromRGB(70, 40, 40), Enum.Material.Slate)
	P("Tail", Vector3.new(1.2, 1.2, 4), Vector3.new(0, 2.4, 3.8), tan, Enum.Material.Concrete)
	P("TailTuft", Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 3.6, 5.9), mane, Enum.Material.Fabric, BALL)
	return P("WavePaw", Vector3.new(1.9, 3.6, 1.9), Vector3.new(3.4, 6, -1.4), tan, Enum.Material.Concrete)
end

local function owl(P: any): Part
	local blue, light, deep = Color3.fromRGB(110, 140, 195), Color3.fromRGB(205, 218, 242), Color3.fromRGB(78, 108, 170)
	P("Cushion", Vector3.new(9, 0.9, 9), Vector3.new(0, 0.45, 0), Color3.fromRGB(150, 70, 90), Enum.Material.Fabric, Enum.PartType.Cylinder, Vector3.new(0, 0, 90))
	P("Body", Vector3.new(6.2, 7, 5.6), Vector3.new(0, 4.4, 0), blue, Enum.Material.Fabric, BALL)
	P("Belly", Vector3.new(4.2, 5.4, 2.2), Vector3.new(0, 3.9, -2), light, Enum.Material.Fabric, BALL)
	P("Head", Vector3.new(5.6, 4.8, 5.2), Vector3.new(0, 8.6, -0.2), blue, Enum.Material.Fabric, BALL)
	for _, side in { -1, 1 } do
		P("FaceDisc", Vector3.new(2.7, 2.7, 0.8), Vector3.new(side * 1.4, 8.8, -2.5), light, Enum.Material.Fabric, BALL)
		P("ClosedEye", Vector3.new(1.9, 0.22, 0.3), Vector3.new(side * 1.4, 8.8, -3), Color3.fromRGB(35, 40, 70), Enum.Material.Slate, nil, Vector3.new(0, 0, side * -12)) -- calm, closed eyes
		P("EarTuft", Vector3.new(0.9, 2.4, 0.9), Vector3.new(side * 2.1, 11.2, 0), deep, Enum.Material.Fabric, nil, Vector3.new(0, 0, side * -16))
		P("Foot", Vector3.new(1.8, 0.7, 2.6), Vector3.new(side * 1.5, 0.9, -2.7), Color3.fromRGB(240, 170, 60), Enum.Material.Concrete)
		P("Brow", Vector3.new(1.9, 0.35, 0.4), Vector3.new(side * 1.4, 9.5, -2.7), deep, Enum.Material.Fabric, nil, Vector3.new(0, 0, side * 10))
	end
	P("Beak", Vector3.new(0.9, 1.1, 1.1), Vector3.new(0, 8, -2.9), Color3.fromRGB(240, 170, 60), Enum.Material.Concrete, nil, Vector3.new(30, 0, 0))
	P("BeakLine", Vector3.new(1.5, 0.12, 0.2), Vector3.new(0, 7.5, -2.75), Color3.fromRGB(120, 80, 30), Enum.Material.Slate) -- pressed shut
	P("WingL", Vector3.new(1.5, 5.2, 3.6), Vector3.new(-3.2, 4.4, 0.3), deep, Enum.Material.Fabric, BALL)
	local aura = P("CalmRing", Vector3.new(11, 0.3, 11), Vector3.new(0, 4.6, 0), Color3.fromRGB(140, 200, 255), Enum.Material.Neon, Enum.PartType.Cylinder, Vector3.new(0, 0, 90))
	aura.Transparency = 0.82
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 200, 255)
	glow.Range = 16
	glow.Parent = aura
	return P("WaveWing", Vector3.new(1.5, 5.2, 3.6), Vector3.new(3.2, 4.4, 0.3), deep, Enum.Material.Fabric, BALL)
end

local function wolf(P: any): Part
	local grey, pale, dark = Color3.fromRGB(122, 128, 145), Color3.fromRGB(200, 205, 215), Color3.fromRGB(70, 74, 90)
	P("Body", Vector3.new(5.2, 6.6, 5), Vector3.new(0, 4.2, 0), grey, Enum.Material.Fabric, BALL)
	P("Chest", Vector3.new(3.4, 4, 2), Vector3.new(0, 4.2, -2.2), pale, Enum.Material.Fabric, BALL)
	P("Head", Vector3.new(4.6, 4.2, 4.6), Vector3.new(0, 8.4, -0.3), grey, Enum.Material.Fabric, BALL)
	P("Snout", Vector3.new(2.2, 1.7, 3.2), Vector3.new(0, 7.6, -3.1), pale, Enum.Material.Fabric)
	P("Nose", Vector3.new(1.1, 0.9, 0.9), Vector3.new(0, 8, -4.7), Color3.fromRGB(25, 25, 32), Enum.Material.Slate, BALL)
	for _, side in { -1, 1 } do
		P("Ear", Vector3.new(1.3, 2.8, 0.9), Vector3.new(side * 1.7, 11.2, 0), grey, Enum.Material.Fabric, nil, Vector3.new(0, 0, side * -12))
		P("EarInner", Vector3.new(0.6, 1.7, 0.4), Vector3.new(side * 1.7, 11.1, -0.35), Color3.fromRGB(230, 170, 170), Enum.Material.Fabric, nil, Vector3.new(0, 0, side * -12))
		P("Foot", Vector3.new(1.9, 3.6, 1.9), Vector3.new(side * 1.5, 1.8, -2.1), dark, Enum.Material.Fabric)
		P("Lens", Vector3.new(1.9, 1.1, 0.3), Vector3.new(side * 1.2, 9, -2.65), Color3.fromRGB(12, 12, 18), Enum.Material.Glass)
		P("Glint", Vector3.new(0.6, 0.18, 0.1), Vector3.new(side * 1.5, 9.35, -2.83), Color3.new(1, 1, 1), Enum.Material.Neon, nil, Vector3.new(0, 0, 25))
	end
	P("GlassesBridge", Vector3.new(0.7, 0.3, 0.3), Vector3.new(0, 9.1, -2.7), Color3.fromRGB(12, 12, 18), Enum.Material.Metal)
	P("GlassesArm", Vector3.new(4.8, 0.25, 0.25), Vector3.new(0, 9.1, -1.2), Color3.fromRGB(12, 12, 18), Enum.Material.Metal)
	P("Scarf", Vector3.new(5.4, 1.4, 4.8), Vector3.new(0, 6.3, -0.2), Color3.fromRGB(245, 205, 48), Enum.Material.Fabric) -- team gear (Sigma yellow)
	P("ScarfTail", Vector3.new(1.2, 3.4, 0.4), Vector3.new(2.4, 4.6, 1.6), Color3.fromRGB(245, 205, 48), Enum.Material.Fabric, nil, Vector3.new(0, 0, -12))
	P("Tail", Vector3.new(2.4, 2.6, 5), Vector3.new(0, 3.2, 4), grey, Enum.Material.Fabric, BALL)
	P("TailTip", Vector3.new(1.8, 1.8, 2), Vector3.new(0, 4.6, 6.3), pale, Enum.Material.Fabric, BALL)
	return P("WavePaw", Vector3.new(1.7, 3.6, 1.7), Vector3.new(3, 5.6, -1.4), dark, Enum.Material.Fabric)
end

local function phoenix(P: any): Part
	local purple, magenta, hot = Color3.fromRGB(150, 70, 225), Color3.fromRGB(230, 90, 220), Color3.fromRGB(255, 160, 235)
	local body = P("Body", Vector3.new(4, 6, 4), Vector3.new(0, 6, 0), purple, Enum.Material.Neon, BALL)
	body.Transparency = 0.12
	P("Head", Vector3.new(2.9, 2.9, 2.9), Vector3.new(0, 9.6, -0.7), purple:Lerp(magenta, 0.4), Enum.Material.Neon, BALL)
	P("Beak", Vector3.new(0.7, 0.7, 1.4), Vector3.new(0, 9.4, -2.3), Color3.fromRGB(255, 190, 70), Enum.Material.Neon)
	for _, side in { -1, 1 } do
		P("Eye", Vector3.new(0.6, 0.6, 0.3), Vector3.new(side * 0.8, 9.9, -2), Color3.new(1, 1, 1), Enum.Material.Neon, BALL)
	end
	for index = -1, 1 do
		P("Crest", Vector3.new(0.6, 2.6, 0.6), Vector3.new(index * 0.8, 11.6, -0.7), hot, Enum.Material.Neon, nil, Vector3.new(index * 14, 0, index * -18))
	end
	for index = 0, 5 do -- wings: a fan of feathers each side
		local angle = 20 + index * 16
		for _, side in { -1, 1 } do
			if not (side == 1 and index == 5) then
				P("Feather", Vector3.new(1, 6.6, 0.4), Vector3.new(side * (2.4 + math.sin(math.rad(angle)) * 3), 7 + math.cos(math.rad(angle)) * 2.6, 0.2), purple:Lerp(magenta, index / 5), Enum.Material.Neon, nil, Vector3.new(0, 0, side * (-angle + 5)))
			end
		end
	end
	for index = 1, 6 do -- tail plumes: flames hanging back and down
		P("Plume", Vector3.new(0.9, 5 + (index % 3) * 1.4, 0.5), Vector3.new((index - 3.5) * 0.8, 2.6, 2.2 + (index % 2)), if index % 2 == 0 then magenta else hot, Enum.Material.Neon, nil, Vector3.new(24, 0, (index - 3.5) * 6))
	end
	P("Talon", Vector3.new(1.6, 0.8, 1.6), Vector3.new(0, 1.5, -0.8), Color3.fromRGB(255, 190, 70), Enum.Material.Neon)
	local emitter = Instance.new("ParticleEmitter") -- drifting purple embers
	emitter.Color = ColorSequence.new(hot, purple)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Lifetime = NumberRange.new(1.5, 3)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.Rate = 6
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = body
	local light = Instance.new("PointLight")
	light.Color = purple
	light.Range = 26
	light.Brightness = 1.6
	light.Parent = body
	return P("WaveFeather", Vector3.new(1, 6.6, 0.4), Vector3.new(6.2, 8.4, 0.2), hot, Enum.Material.Neon, nil, Vector3.new(0, 0, -100))
end

local builders = { lion, owl, wolf, phoenix }

-- Build mascot `faction` (1 to 4) at `origin`. `plinth` adds a round stone base and team banners (for the big statue).
function Mascots.build(faction: number, origin: CFrame, scale: number, plinth: boolean, teamColour: Color3): Built
	local model = Instance.new("Model")
	model.Name = "Mascot" .. faction
	local P, parts = make(model, origin, scale)
	local arm = builders[faction](P)
	if plinth then
		local base = P("Plinth", Vector3.new(15, 2, 15), Vector3.new(0, -1, 0), Color3.fromRGB(128, 122, 118), Enum.Material.Cobblestone, Enum.PartType.Cylinder, Vector3.new(0, 0, 90))
		base.CanCollide = false
		P("PlinthTrim", Vector3.new(15.8, 0.5, 15.8), Vector3.new(0, 0.1, 0), teamColour:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Metal, Enum.PartType.Cylinder, Vector3.new(0, 0, 90))
		for _, side in { -1, 1 } do
			P("BannerPole", Vector3.new(0.7, 16, 0.7), Vector3.new(side * 8.5, 7, 1), Color3.fromRGB(104, 72, 48), Enum.Material.Wood)
			P("Banner", Vector3.new(3.4, 9, 0.3), Vector3.new(side * 8.5, 10, 1), teamColour, Enum.Material.Fabric)
		end
	end
	local root = parts[1]
	model.PrimaryPart = root
	model.Parent = Workspace
	local result: Built = { model = model, root = root, arm = arm, parts = parts }
	result.armLocal = origin:ToObjectSpace(arm.CFrame)
	result.armPivot = origin:ToObjectSpace(arm.CFrame * CFrame.new(0, arm.Size.Y / 2 * 0.9, 0)) -- the shoulder, near the top of the arm
	return result
end

return Mascots
