--!strict
-- Cover for Mog fights: crates, walls, barrels and bushes scattered around each territory, along the paths and in
-- front of each base. Every piece is solid, anchored, and tagged "Cover" (bots hide behind tagged pieces). Placement
-- uses a fixed seed so the map is the same every time. Landmarks call Cover.reserve first so cover never lands inside
-- a building. Few parts, no meshes: phone-friendly.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local Territories = require(Shared:WaitForChild("Territories"))
local Builder = require(script.Parent:WaitForChild("Builder"))

local Cover = {}

local rng = Random.new(2718)
local placed: { Vector3 } = {}
local reserved: { { x: number, z: number, halfW: number, halfD: number } } = {}

-- Keep cover out of this rectangle (a landmark's footprint).
function Cover.reserve(cx: number, cz: number, halfW: number, halfD: number)
	table.insert(reserved, { x = cx, z = cz, halfW = halfW, halfD = halfD })
end

local function free(x: number, z: number, gap: number): boolean
	for _, other in placed do
		if (other.X - x) ^ 2 + (other.Z - z) ^ 2 < gap * gap then
			return false
		end
	end
	for _, base in MapLayout.bases do
		if (base.x - x) ^ 2 + (base.z - z) ^ 2 < 24 * 24 then
			return false
		end
	end
	for _, box in reserved do
		if math.abs(x - box.x) < box.halfW + 3 and math.abs(z - box.z) < box.halfD + 3 then
			return false
		end
	end
	return true
end

local function tag(part: Part): Part
	part.CanCollide = true
	CollectionService:AddTag(part, "Cover")
	return part
end

local function crate(folder: Folder, x: number, z: number)
	local size = 4 + rng:NextInteger(0, 2)
	local part = tag(Builder.part("Crate", Vector3.new(size, size, size), Vector3.new(x, size / 2, z), Color3.fromRGB(200, 150, 80), folder))
	part.Material = Enum.Material.WoodPlanks
	part.CFrame = CFrame.new(x, size / 2, z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
end

local function wall(folder: Folder, x: number, z: number)
	local part = tag(Builder.part("CoverWall", Vector3.new(12, 6, 2), Vector3.new(x, 3, z), Color3.fromRGB(150, 150, 160), folder))
	part.Material = Enum.Material.Slate
	part.CFrame = CFrame.new(x, 3, z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
end

local function barrel(folder: Folder, x: number, z: number)
	local part = tag(Builder.cylinder("Barrel", 3.4, 5, Vector3.new(x, 2.5, z), Color3.fromRGB(215, 70, 60), folder))
	part.Material = Enum.Material.Metal
end

local function bush(folder: Folder, x: number, z: number)
	local part = tag(Builder.ball("Bush", Vector3.new(6, 5, 6), Vector3.new(x, 2.2, z), Color3.fromRGB(70, 175, 65), folder))
	part.Material = Enum.Material.Grass
end

local makers = { crate, wall, barrel, bush }

-- Scatter `count` pieces in a ring around (cx, cz). Only on flat ground at y = 0 (checked with a ray).
function Cover.scatter(folder: Folder, cx: number, cz: number, count: number, minRadius: number, maxRadius: number)
	local made = 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	for _ = 1, count * 8 do
		if made >= count then
			return
		end
		local angle = rng:NextNumber() * math.pi * 2
		local radius = minRadius + rng:NextNumber() * (maxRadius - minRadius)
		local x, z = cx + math.cos(angle) * radius, cz + math.sin(angle) * radius
		if free(x, z, 9) then
			local result = Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -240, 0), params)
			if result and result.Material ~= Enum.Material.Water and math.abs(result.Position.Y) < 1.5 and result.Normal.Y > 0.9 then
				makers[rng:NextInteger(1, #makers)](folder, x, z)
				table.insert(placed, Vector3.new(x, 0, z))
				made += 1
			end
		end
	end
end

function Cover.build()
	local folder = Instance.new("Folder")
	folder.Name = "Cover"
	folder.Parent = Workspace
	-- plenty around every territory
	for _, territory in Territories.list do
		Cover.scatter(folder, territory.x, territory.z, 16, 35, 105)
	end
	-- along each base's way out, and in front of each base
	for _, base in MapLayout.bases do
		for step = 1, 3 do
			local t = step / 4
			Cover.scatter(folder, base.x * (1 - t), base.z * (1 - t), 2, 8, 16)
		end
		Cover.scatter(folder, base.x * 0.9, base.z * 0.9, 4, 14, 30)
	end
end

return Cover
