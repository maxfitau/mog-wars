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
		if (base.x - x) ^ 2 + (base.z - z) ^ 2 < 12 * 12 then
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

local function crate(folder: Folder, x: number, y: number, z: number)
	local size = 4 + rng:NextInteger(0, 2)
	local part = tag(Builder.part("Crate", Vector3.new(size, size, size), Vector3.new(x, y + size / 2, z), Color3.fromRGB(200, 150, 80), folder))
	part.Material = Enum.Material.WoodPlanks
	part.CFrame = CFrame.new(x, y + size / 2, z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
end

local function wall(folder: Folder, x: number, y: number, z: number)
	local part = tag(Builder.part("CoverWall", Vector3.new(12, 6, 2), Vector3.new(x, y + 3, z), Color3.fromRGB(150, 150, 160), folder))
	part.Material = Enum.Material.Slate
	part.CFrame = CFrame.new(x, y + 3, z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
end

local function barrel(folder: Folder, x: number, y: number, z: number)
	local part = tag(Builder.cylinder("Barrel", 3.4, 5, Vector3.new(x, y + 2.5, z), Color3.fromRGB(215, 70, 60), folder))
	part.Material = Enum.Material.Metal
end

local function bush(folder: Folder, x: number, y: number, z: number)
	local part = tag(Builder.ball("Bush", Vector3.new(6, 5, 6), Vector3.new(x, y + 2.2, z), Color3.fromRGB(70, 175, 65), folder))
	part.Material = Enum.Material.Grass
end

local makers = { crate, wall, barrel, bush }

-- Scatter `count` pieces in a ring around (cx, cz) on an island whose surface is at `groundY`. Only on flat ground at that
-- height (checked with a ray).
function Cover.scatter(folder: Folder, cx: number, cz: number, count: number, minRadius: number, maxRadius: number, groundY: number)
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
			local result = Workspace:Raycast(Vector3.new(x, groundY + 60, z), Vector3.new(0, -120, 0), params)
			if result and result.Material ~= Enum.Material.Water and math.abs(result.Position.Y - groundY) < 1.5 and result.Normal.Y > 0.9 then
				makers[rng:NextInteger(1, #makers)](folder, x, groundY, z)
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
	-- plenty on every island (the cave has its own props)
	for _, territory in Territories.list do
		if territory.radius > 0 then
			Cover.scatter(folder, territory.x, territory.z, 16, 35, math.max(60, territory.radius - 12), territory.height)
		end
	end
	-- and a little on each team island
	for _, base in MapLayout.bases do
		Cover.scatter(folder, base.x, base.z, 4, 14, MapLayout.baseIslandRadius - 8, MapLayout.baseIslandHeight)
	end
end

return Cover
