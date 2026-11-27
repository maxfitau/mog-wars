--!strict
-- Pieces for floating sky islands: a tapering rocky underside, dangling roots, waterfalls pouring off the edge, and
-- wooden rope bridges between islands. Everything is anchored; only the bridge deck is solid.

local Workspace = game:GetService("Workspace")

local Builder = require(script.Parent:WaitForChild("Builder"))
local TerrainKit = require(script.Parent:WaitForChild("TerrainKit"))
local Common = require(script.Parent:WaitForChild("Places"):WaitForChild("Common"))

local SkyKit = {}

local WOOD = Color3.fromRGB(150, 105, 62)
local ROPE = Color3.fromRGB(232, 215, 180)

-- An island body: a grassy top (its surface is at `topY`) over a rock underside that tapers like an upside-down cone.
-- `taper` above 1 keeps the rock wider for longer (room for caves). Uses absolute heights (it ignores TerrainKit.base).
function SkyKit.island(cx: number, cz: number, topY: number, radius: number, depth: number, taper: number?)
	local saved = TerrainKit.base
	TerrainKit.setBase(0)
	local slices = 8
	local power = taper or 0.85
	TerrainKit.cylinder(cx, topY - 5, cz, radius, 5, Enum.Material.Grass) -- grass top
	local sliceHeight = depth / slices
	for index = 1, slices do
		local fraction = index / (slices + 1)
		local sliceRadius = radius * (1 - fraction ^ power) + 8
		TerrainKit.cylinder(cx, topY - 5 - index * sliceHeight, cz, sliceRadius, sliceHeight + 1, Enum.Material.Rock)
	end
	TerrainKit.setBase(saved)
end

-- Roots and vines dangling from the rim and down the underside.
function SkyKit.vines(folder: Instance, cx: number, cz: number, topY: number, radius: number, count: number)
	local rng = Random.new(cx * 31 + cz)
	for index = 1, count do
		local angle = index / count * math.pi * 2 + rng:NextNumber() * 0.2
		local reach = radius * (0.72 + rng:NextNumber() * 0.2)
		local length = 14 + rng:NextNumber() * 26
		local position = Vector3.new(cx + math.cos(angle) * reach, topY - 10 - length / 2, cz + math.sin(angle) * reach)
		local root = Builder.part("Root", Vector3.new(1.2, length, 1.2), position, Color3.fromRGB(88, 62, 40), folder)
		root.Material = Enum.Material.Wood
		root.CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber() * 0.2, angle, rng:NextNumber() * 0.2)
		root.CanCollide = false
		root.CanQuery = false
		local leaf = Builder.ball("Leaves", Vector3.new(5, 4, 5), position - Vector3.new(0, length / 2, 0), Color3.fromRGB(88, 170, 78), folder)
		leaf.Material = Enum.Material.Grass
		leaf.CanCollide = false
		leaf.CanQuery = false
	end
end

-- A small waterfall pouring off the island edge at `rim` (a point on the edge, at the top height), facing outward.
function SkyKit.waterfall(folder: Instance, rim: Vector3, outward: Vector3, height: number)
	local flat = Vector3.new(outward.X, 0, outward.Z).Unit
	local top = rim + flat * 1.5
	local sheet = Builder.part("Waterfall", Vector3.new(5, height, 1.2), top - Vector3.new(0, height / 2, 0), Color3.fromRGB(190, 230, 255), folder)
	sheet.CFrame = CFrame.lookAt(sheet.Position, sheet.Position + flat)
	sheet.Material = Enum.Material.Glass
	sheet.Transparency = 0.45
	sheet.CanCollide = false
	sheet.CanQuery = false
	local mist = Builder.emitter("WaterfallMist", top - Vector3.new(0, height, 0), "rbxasset://textures/particles/smoke_main.dds", Color3.fromRGB(235, 245, 255), folder)
	mist.Rate = 4
	mist.Lifetime = NumberRange.new(2, 3)
	mist.Speed = NumberRange.new(2, 4)
	mist.Size = NumberSequence.new(6, 14)
	mist.Transparency = NumberSequence.new(0.6, 1)
	mist.EmissionDirection = Enum.NormalId.Top
end

-- A hidden stash on a little ledge BEHIND a waterfall: drop off the island edge through the water onto it.
function SkyKit.waterfallStash(folder: Instance, rim: Vector3, outward: Vector3, territoryId: string, stashId: string)
	local flat = Vector3.new(outward.X, 0, outward.Z).Unit
	local position = rim + flat * 4 - Vector3.new(0, 8, 0)
	local ledge = Builder.part("HiddenLedge", Vector3.new(9, 1, 7), position, Color3.fromRGB(110, 100, 120), folder)
	ledge.Material = Enum.Material.Rock
	Common.stash(folder, position + Vector3.new(0, 0.5, 0), territoryId, stashId)
end

-- A wooden rope bridge from `from` to `to` (the deck's surface runs through both points). Walkable up to about 30 degrees.
function SkyKit.bridge(folder: Instance, from: Vector3, to: Vector3, width: number)
	local middle = (from + to) / 2
	local length = (to - from).Magnitude
	local deck = Instance.new("Part")
	deck.Name = "BridgeDeck"
	deck.Anchored = true
	deck.Size = Vector3.new(width, 1, length)
	deck.CFrame = CFrame.lookAt(middle, to) * CFrame.new(0, -0.5, 0)
	deck.Color = WOOD
	deck.Material = Enum.Material.WoodPlanks
	deck.Parent = folder
	local look = CFrame.lookAt(middle, to)
	for _, side in { -1, 1 } do
		local rail = Instance.new("Part")
		rail.Name = "BridgeRope"
		rail.Anchored = true
		rail.Size = Vector3.new(0.5, 0.5, length)
		rail.CFrame = look * CFrame.new(side * (width / 2 - 0.2), 3, 0)
		rail.Color = ROPE
		rail.Material = Enum.Material.Fabric
		rail.CanCollide = false
		rail.CanQuery = false
		rail.Parent = folder
		local posts = math.max(2, math.floor(length / 14))
		for index = 0, posts do
			local post = Instance.new("Part")
			post.Name = "BridgePost"
			post.Anchored = true
			post.Size = Vector3.new(0.8, 3.6, 0.8)
			post.CFrame = look * CFrame.new(side * (width / 2 - 0.2), 1.3, -length / 2 + index * length / posts)
			post.Color = WOOD
			post.Material = Enum.Material.Wood
			post.CanCollide = false
			post.CanQuery = false
			post.Parent = folder
		end
	end
	return deck
end

-- The cloud sea far below the islands: a soft peach-white floor and layers of fat puffs, so the void looks like endless sky.
function SkyKit.cloudSea()
	local sea = Instance.new("Folder")
	sea.Name = "CloudSea"
	sea.Parent = Workspace
	local floorPart = Builder.cylinder("CloudFloor", 4200, 2, Vector3.new(0, -170, 0), Color3.fromRGB(255, 236, 214), sea)
	floorPart.Material = Enum.Material.SmoothPlastic
	floorPart.CanCollide = false
	floorPart.CanQuery = false
	floorPart.Transparency = 0.1
	local rng = Random.new(77)
	for _ = 1, 110 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = 380 + rng:NextNumber() * 1400
		local puff = Builder.ball("Cloud", Vector3.new(120 + rng:NextNumber() * 220, 24 + rng:NextNumber() * 40, 120 + rng:NextNumber() * 220), Vector3.new(math.cos(angle) * radius, -165 + rng:NextNumber() * 55, math.sin(angle) * radius), Color3.fromRGB(255, 244, 232), sea)
		puff.Material = Enum.Material.SmoothPlastic
		puff.Transparency = 0.15 + rng:NextNumber() * 0.3
		puff.CanCollide = false
		puff.CanQuery = false
	end
	return sea
end

-- Life between the islands: three airships (a fat balloon over a wooden gondola) circling slowly, and floating mini rocks.
function SkyKit.decor()
	local folder = Instance.new("Folder")
	folder.Name = "SkyDecor"
	folder.Parent = Workspace
	local rng = Random.new(5)
	for _ = 1, 26 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = 150 + rng:NextNumber() * 420
		local size = 4 + rng:NextNumber() * 9
		local rock = Builder.ball("FloatingRock", Vector3.new(size, size * 0.8, size), Vector3.new(math.cos(angle) * radius, 30 + rng:NextNumber() * 190, math.sin(angle) * radius), Color3.fromRGB(110, 100, 120), folder)
		rock.Material = Enum.Material.Rock
		rock.CanCollide = false
		rock.CanQuery = false
	end
	local ships: { { model: Model, radius: number, speed: number, angle: number, height: number } } = {}
	local colors = { Color3.fromRGB(235, 215, 170), Color3.fromRGB(110, 175, 110), Color3.fromRGB(200, 120, 90) }
	for index = 1, 3 do
		local model = Instance.new("Model")
		model.Name = "Airship" .. index
		local balloon = Builder.ball("Balloon", Vector3.new(30, 38, 30), Vector3.new(0, 26, 0), colors[index], model)
		balloon.Material = Enum.Material.Fabric
		local stripe = Builder.ball("BalloonStripe", Vector3.new(31, 8, 31), Vector3.new(0, 26, 0), Color3.fromRGB(70, 50, 40), model)
		stripe.Material = Enum.Material.Fabric
		local hull = Builder.part("Gondola", Vector3.new(16, 5, 6), Vector3.new(0, 0, 0), Color3.fromRGB(120, 82, 50), model)
		hull.Material = Enum.Material.WoodPlanks
		local rail = Builder.part("GondolaRail", Vector3.new(17, 1.2, 7), Vector3.new(0, 3.2, 0), Color3.fromRGB(95, 66, 40), model)
		rail.Material = Enum.Material.Wood
		for _, dx in { -5, 5 } do
			local rope = Builder.part("Rope", Vector3.new(0.3, 20, 0.3), Vector3.new(dx, 12, 0), Color3.fromRGB(230, 215, 180), model)
			rope.CanCollide = false
		end
		local propeller = Builder.part("Propeller", Vector3.new(0.5, 6, 1), Vector3.new(-9, 1, 0), Color3.fromRGB(80, 60, 45), model)
		propeller.CanCollide = false
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				child.CanCollide = false
				child.CanQuery = false
			end
		end
		model.PrimaryPart = hull
		model.Parent = folder
		table.insert(ships, { model = model, radius = 190 + index * 40, speed = (if index % 2 == 0 then -1 else 1) * (0.012 + index * 0.003), angle = index * 2.1, height = 150 + index * 18 })
	end
	task.spawn(function()
		while folder.Parent do
			task.wait(0.1)
			for _, ship in ships do
				ship.angle += ship.speed
				local position = Vector3.new(math.cos(ship.angle) * ship.radius, ship.height + math.sin(ship.angle * 3) * 3, math.sin(ship.angle) * ship.radius)
				local heading = Vector3.new(-math.sin(ship.angle) * math.sign(ship.speed), 0, math.cos(ship.angle) * math.sign(ship.speed))
				ship.model:PivotTo(CFrame.lookAt(position, position + heading))
			end
		end
	end)
end

return SkyKit
