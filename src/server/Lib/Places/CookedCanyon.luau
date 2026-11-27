--!strict
-- Cooked Canyon (Gold, south-east): a red canyon with a glowing lava river, rock bridges and a giant frying pan held up
-- on rock pillars over the river. Climb rock-jump stepping stones up to the pan; the flag stands in the egg yolk.
-- Lava geysers erupt now and then (they only throw you, never hurt). Secret: a cave behind a lava fall.
-- Palette: canyon red, lava orange, iron black, egg white and yellow. Ground and walls: sandstone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ambience = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ambience"))
local Builder = require(script.Parent.Parent:WaitForChild("Builder"))
local Cover = require(script.Parent.Parent:WaitForChild("Cover"))
local Common = require(script.Parent:WaitForChild("Common"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local TerrainKit = require(script.Parent.Parent:WaitForChild("TerrainKit"))
local SkyKit = require(script.Parent.Parent:WaitForChild("SkyKit"))

local RED = Color3.fromRGB(190, 80, 52)
local RED_DARK = Color3.fromRGB(150, 60, 42)
local IRON = Color3.fromRGB(48, 48, 56)
local LAVA = Color3.fromRGB(255, 120, 25)

local PAN_Y = 16 -- bottom of the pan; its top is at y = 18, where the flag stands

return function(folder: Folder, territory: any)
	local cx, cz = territory.x, territory.z
	local k = Kit.new(folder, cx, cz, territory.height)
	Cover.reserve(cx, cz, 100, 110)
	SkyKit.island(cx, cz, territory.height, territory.radius, 60)
	SkyKit.vines(folder, cx, cz, territory.height, territory.radius, 14)
	TerrainKit.cylinder(cx, -6, cz, 100, 6, Enum.Material.Sandstone) -- red canyon floor
	-- canyon walls, 40 high, running north to south on both sides
	TerrainKit.block(cx - 68, 0, cz, 24, 40, 160, Enum.Material.Sandstone)
	TerrainKit.block(cx + 68, 0, cz, 24, 40, 160, Enum.Material.Sandstone)
	-- the lava river: dug out and filled with cracked lava, a glowing sheet on top
	TerrainKit.carve(cx, -8, cz, 24, 8, 200)
	TerrainKit.block(cx, -8, cz, 24, 6, 200, Enum.Material.CrackedLava)
	k:box("LavaGlow", 0, -1.8, 0, 24, 0.2, 200, LAVA, Enum.Material.Neon, { collide = false, transparency = 0.35 })
	for _, z in { -80, -40, 0, 40, 80 } do
		local glow = Instance.new("PointLight")
		glow.Color = LAVA
		glow.Range = 40
		glow.Brightness = 2
		glow.Parent = k:box("LavaLight", 0, 0, z, 1, 1, 1, LAVA, Enum.Material.Neon, { collide = false, transparency = 1 })
	end

	-- two rock bridges across the river
	for _, z in { -62, 62 } do
		k:box("RockBridge", 0, 0, z, 30, 2.4, 9, RED_DARK, Enum.Material.Rock)
	end

	-- the giant frying pan, held up by four rock pillars, with a rim of cover and a short handle
	for _, leg in { { -22, -20 }, { 22, -20 }, { -22, 20 }, { 22, 20 } } do
		k:cyl("PanLeg", leg[1], 0, leg[2], 8, PAN_Y, RED_DARK, Enum.Material.Rock)
	end
	k:cyl("Pan", 0, PAN_Y, 0, 70, 2, IRON, Enum.Material.Metal)
	k:box("PanHandle", 43, PAN_Y, 0, 18, 2, 7, Color3.fromRGB(80, 56, 42), Enum.Material.Wood)
	local rim = 16
	for index = 0, rim - 1 do
		if index ~= 0 and index ~= rim / 2 then -- openings east and west, where the stepping stones arrive
			local angle = index / rim * math.pi * 2
			local piece = k:box("PanRim", math.cos(angle) * 34, PAN_Y + 2, math.sin(angle) * 34, 13, 3.5, 2, IRON, Enum.Material.Metal, { cover = true })
			piece.CFrame = CFrame.lookAt(piece.Position, piece.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
		end
	end
	-- the egg: a thin white blob and a yellow yolk; the flag is planted in the yolk
	k:ball("EggWhite", -2, PAN_Y + 1.9, 0, 46, 0.4, 40, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { collide = false })
	k:ball("EggWhiteLobe", 17, PAN_Y + 1.9, 10, 22, 0.4, 20, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { collide = false })
	k:ball("Yolk", 0, PAN_Y + 2.1, 0, 18, 8, 18, Color3.fromRGB(255, 205, 40), Enum.Material.SmoothPlastic, { collide = false })
	for index, offset in { { -10, -8 }, { 6, 10 }, { 14, -6 }, { -14, 12 } } do
		Common.smoke(folder, "Steam" .. index, k:at(offset[1], PAN_Y + 4, offset[2]), Color3.fromRGB(250, 250, 250), 5, 9)
	end
	-- rock jumps: stepping stones, 3 higher each, from the west bank up to the pan (and the same to the handle on the east)
	for index = 1, 5 do
		local height = index * 3
		k:cyl("StepStone", -52 + index * 3.6, 0, -8 + index * 2, 7, height, RED, Enum.Material.Rock)
		k:cyl("StepStone", 52 - index * 3, 0, 8 - index * 1.6, 7, height, RED, Enum.Material.Rock)
	end

	-- geyser vents in the river (the moment makes them erupt)
	for index, z in { -70, -35, 35, 70 } do
		local vent = k:cyl("Geyser", 0, -1.7, z, 7, 0.4, LAVA, Enum.Material.Neon, { collide = false })
		vent:SetAttribute("Territory", territory.id)
		game:GetService("CollectionService"):AddTag(vent, "Geyser")
		local emitter = Builder.emitter("GeyserSpray" .. index, vent.Position + Vector3.new(0, 1, 0), Common.SPARKLES, LAVA, vent)
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(30, 50)
		emitter.SpreadAngle = Vector2.new(12, 12)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Size = NumberSequence.new(3, 0)
		emitter.LightEmission = 1
		emitter.Name = "GeyserSpray"
	end
	-- embers over the river
	for index, z in { -90, -50, -10, 30, 70 } do
		Common.smoke(folder, "Embers" .. index, k:at(0, 0, z), Color3.fromRGB(255, 150, 70), 2, 7)
	end

	-- the secret: a cave carved into the east wall behind a lava fall, with a free Aura Stash
	TerrainKit.carve(cx + 64, 0, cz - 12, 24, 12, 20)
	local fall = k:box("LavaFall", 55, 0, -12, 1, 26, 20, LAVA, Enum.Material.Neon, { collide = false, transparency = 0.2 })
	local drip = Builder.emitter("FallDrops", fall.Position, Common.SPARKLES, LAVA, fall)
	drip.Rate = 12
	drip.Lifetime = NumberRange.new(0.6, 1)
	drip.Speed = NumberRange.new(4, 8)
	drip.EmissionDirection = Enum.NormalId.Bottom
	drip.Size = NumberSequence.new(1.5, 0)
	drip.LightEmission = 1
	Common.stash(folder, k:at(68, 0, -12), territory.id)

	-- cover: boulders along both banks
	for index, spot in { { -40, -30 }, { -36, 24 }, { -46, 70 }, { -44, -78 }, { 40, -34 }, { 36, 28 }, { 44, 72 }, { 40, -80 } } do
		k:ball("Boulder", spot[1], 0, spot[2], 8, 6, 8, RED_DARK, Enum.Material.Rock, { cover = true })
		if index % 2 == 0 then
			k:box("RockSlab", spot[1] + 8, 0, spot[2] + 4, 3, 5, 10, RED, Enum.Material.Rock, { cover = true, rotY = index * 0.5 })
		end
	end
	Common.ambience(folder, k:at(0, 4, 0), Ambience.cooked_canyon, 0.4)
end
