--!strict
-- Giant 3D name letters (Hollywood-sign style) and an entrance arch for every territory. The letters are drawn from a
-- 5x7 pixel font, merged into one block per horizontal run so a name costs only about a hundred parts. Each territory has its own
-- look (see `style`): slimy, stone, glowing pink, lava-cracked, blocky, striped, snack-bag. The signs are not solid, so
-- they never block a path. Server only; built once with the map.

local Workspace = game:GetService("Workspace")

local Territories = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Territories"))

local TerritorySigns = {}

local FONT: { [string]: { string } } = {
	A = { ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" },
	B = { "####.", "#...#", "#...#", "####.", "#...#", "#...#", "####." },
	C = { ".####", "#....", "#....", "#....", "#....", "#....", ".####" },
	D = { "####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####." },
	E = { "#####", "#....", "#....", "####.", "#....", "#....", "#####" },
	G = { ".####", "#....", "#....", "#..##", "#...#", "#...#", ".####" },
	H = { "#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" },
	I = { "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####" },
	K = { "#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#" },
	L = { "#....", "#....", "#....", "#....", "#....", "#....", "#####" },
	M = { "#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#" },
	N = { "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#" },
	O = { ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." },
	P = { "####.", "#...#", "#...#", "####.", "#....", "#....", "#...." },
	R = { "####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#" },
	S = { ".####", "#....", "#....", ".###.", "....#", "....#", "####." },
	T = { "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.." },
	U = { "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." },
	V = { "#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.." },
	Y = { "#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.." },
	Z = { "#####", "....#", "...#.", "..#..", ".#...", "#....", "#####" },
	["-"] = { ".....", ".....", ".....", "#####", ".....", ".....", "....." },
}

local PALETTE = {
	Color3.fromRGB(235, 80, 80), Color3.fromRGB(250, 205, 70), Color3.fromRGB(80, 160, 240),
	Color3.fromRGB(90, 200, 120), Color3.fromRGB(240, 140, 60), Color3.fromRGB(190, 110, 230),
}

-- How each territory's letters look: returns colour and material for a run (line, letter number, pixel row).
local function style(id: string, line: number, letter: number, row: number, rng: Random): (Color3, Enum.Material)
	if id == "gigachad_gate" then
		return Color3.fromRGB(150 + (letter % 2) * 10, 148, 158), Enum.Material.Slate
	elseif id == "chud_chambers" then
		return PALETTE[letter % #PALETTE + 1], Enum.Material.Foil
	elseif id == "rizz_ravine" then
		return Color3.fromRGB(255, 110, 190), Enum.Material.Neon
	elseif id == "locked_in_lighthouse" then
		return if (row + line) % 2 == 0 then Color3.fromRGB(215, 50, 50) else Color3.fromRGB(245, 245, 245), Enum.Material.Concrete
	elseif id == "npc_village" then
		return PALETTE[(letter + line * 2) % #PALETTE + 1], Enum.Material.WoodPlanks
	elseif id == "brainrot_bog" then
		return Color3.fromRGB(105 + rng:NextInteger(0, 30), 200, 60), Enum.Material.Marble
	end
	-- cooked canyon: dark cracked rock with glowing lava seams
	if rng:NextNumber() < 0.22 then
		return Color3.fromRGB(255, 110, 30), Enum.Material.Neon
	end
	return Color3.fromRGB(70, 44, 42), Enum.Material.Basalt
end

-- Build `text` as letters in `parent`. `base` has the sign's centre bottom at its origin; +X is the viewer's right.
function TerritorySigns.letters(parent: Instance, id: string, text: string, base: CFrame, pixel: number, depth: number)
	local lines = string.split(text, " ")
	local rng = Random.new(#text * 31)
	local lineHeight = 7 * pixel
	local gap = pixel * 2
	local totalHeight = #lines * lineHeight + (#lines - 1) * gap
	for lineIndex, line in lines do
		local width = (#line * 6 - 1) * pixel
		local top = totalHeight - (lineIndex - 1) * (lineHeight + gap)
		for letterIndex = 1, #line do
			local glyph = FONT[string.sub(line, letterIndex, letterIndex)]
			if glyph then
				local startX = (letterIndex - 1) * 6 * pixel - width / 2
				for rowIndex, rowText in glyph do
					local column = 1
					while column <= 5 do
						if string.sub(rowText, column, column) == "#" then
							local first = column
							while column < 5 and string.sub(rowText, column + 1, column + 1) == "#" do
								column += 1
							end
							local run = column - first + 1
							local colour, material = style(id, lineIndex, letterIndex, rowIndex, rng)
							local part = Instance.new("Part")
							part.Name = "SignLetter"
							part.Anchored = true
							part.CanCollide = false
							part.CanQuery = false
							part.CanTouch = false
							part.Size = Vector3.new(run * pixel, pixel, depth)
							part.Color = colour
							part.Material = material
							local localX = startX + (first - 1) * pixel + run * pixel / 2
							local localY = top - (rowIndex - 0.5) * pixel
							part.CFrame = base * CFrame.new(localX, localY, 0)
							part.Parent = parent
						end
						column += 1
					end
				end
			end
		end
	end
end

local function groundAt(x: number, z: number, from: number): Vector3
	local result = Workspace:Raycast(Vector3.new(x, from + 80, z), Vector3.new(0, -300, 0))
	return if result then result.Position else Vector3.new(x, from, z)
end

local function plaque(parent: Instance, frame: CFrame, size: Vector3, text: string)
	local board = Instance.new("Part")
	board.Name = "ArchPlaque"
	board.Anchored = true
	board.CanCollide = false
	board.Size = size
	board.CFrame = frame
	board.Color = Color3.fromRGB(70, 48, 34)
	board.Material = Enum.Material.Wood
	board.Parent = parent
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = Color3.fromRGB(255, 232, 170)
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
	end
end

-- An entrance arch (two stone pillars, a lintel with the name, two lanterns) at `ground`, passage along `forward`.
local function arch(parent: Instance, id: string, name: string, ground: Vector3, forward: Vector3)
	local side = forward:Cross(Vector3.yAxis).Unit
	local face = CFrame.lookAt(ground, ground + forward)
	local stone = Color3.fromRGB(150, 140, 130)
	for _, sign in { -1, 1 } do
		local pillarBase = ground + side * sign * 11
		local pillar = Instance.new("Part")
		pillar.Name = "ArchPillar"
		pillar.Anchored = true
		pillar.Size = Vector3.new(4, 17, 4)
		pillar.CFrame = CFrame.lookAt(pillarBase + Vector3.new(0, 8.5, 0), pillarBase + Vector3.new(0, 8.5, 0) + forward)
		pillar.Color = stone
		pillar.Material = Enum.Material.Cobblestone
		pillar.Parent = parent
		local cap = Instance.new("Part")
		cap.Name = "ArchCap"
		cap.Anchored = true
		cap.CanCollide = false
		cap.Size = Vector3.new(5.4, 1.6, 5.4)
		cap.CFrame = pillar.CFrame * CFrame.new(0, 9.2, 0)
		cap.Color = Color3.fromRGB(120, 110, 104)
		cap.Material = Enum.Material.Slate
		cap.Parent = parent
		local lantern = Instance.new("Part")
		lantern.Name = "ArchLantern"
		lantern.Anchored = true
		lantern.CanCollide = false
		lantern.Shape = Enum.PartType.Ball
		lantern.Size = Vector3.new(2, 2.4, 2)
		lantern.Material = Enum.Material.Neon
		lantern.Color = Color3.fromRGB(255, 190, 90)
		lantern.Position = pillarBase + side * -sign * 2.8 + Vector3.new(0, 11, 0)
		lantern.Parent = parent
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 90)
		light.Range = 22
		light.Parent = lantern
	end
	plaque(parent, face * CFrame.new(0, 16.5, 0), Vector3.new(24, 5, 2), string.upper(name))
	local lintel = Instance.new("Part")
	lintel.Name = "ArchLintel"
	lintel.Anchored = true
	lintel.CanCollide = false
	lintel.Size = Vector3.new(26, 1.4, 3)
	lintel.CFrame = face * CFrame.new(0, 19.6, 0)
	lintel.Color = stone
	lintel.Material = Enum.Material.Cobblestone
	lintel.Parent = parent
	local flag = Instance.new("Part") -- a little pennant on top in the territory's accent colour (never a faction colour)
	flag.Name = "ArchPennant"
	flag.Anchored = true
	flag.CanCollide = false
	flag.Size = Vector3.new(0.3, 3, 5)
	flag.CFrame = face * CFrame.new(0, 22.2, 0)
	flag.Color = PALETTE[(#id % #PALETTE) + 1]
	flag.Material = Enum.Material.Fabric
	flag.Parent = parent
end

function TerritorySigns.build()
	local folder = Instance.new("Folder")
	folder.Name = "TerritorySigns"
	folder.Parent = Workspace
	for _, territory in Territories.list do
		local name = string.upper(territory.name)
		if territory.radius > 0 then
			local toward = Vector3.new(-territory.x, 0, -territory.z)
			local direction = if toward.Magnitude > 20 then toward.Unit else Vector3.zAxis -- toward the middle of the map (the Gate faces south)
			-- the big name letters stand on a rock plinth at the far rim, facing the middle of the map
			local longest = 1
			for word in string.gmatch(name, "%S+") do
				longest = math.max(longest, #word)
			end
			local pixel = math.min(3.4, territory.radius * 1.3 / (longest * 6))
			local spot = groundAt(territory.x - direction.X * territory.radius * 0.7, territory.z - direction.Z * territory.radius * 0.7, territory.height)
			local plinth = Instance.new("Part")
			plinth.Name = "SignPlinth"
			plinth.Anchored = true
			plinth.Size = Vector3.new(longest * 6 * pixel + 8, 3, 7)
			plinth.CFrame = CFrame.lookAt(spot + Vector3.new(0, 1, 0), spot + Vector3.new(0, 1, 0) + direction)
			plinth.Color = Color3.fromRGB(96, 90, 90)
			plinth.Material = Enum.Material.Rock
			plinth.Parent = folder
			TerritorySigns.letters(folder, territory.id, name, CFrame.lookAt(spot + Vector3.new(0, 2.5, 0), spot + Vector3.new(0, 2.5, 0) - direction), pixel, 4)
			-- the entrance arch where visitors arrive from the middle of the map
			arch(folder, territory.id, territory.name, groundAt(territory.x + direction.X * territory.radius * 0.66, territory.z + direction.Z * territory.radius * 0.66, territory.height), direction)
		else
			-- the cave (Chud Chambers): snack-bag letters high on the hall's south wall
			local base = CFrame.lookAt(Vector3.new(territory.x, territory.height + 10, territory.z + 46.4), Vector3.new(territory.x, territory.height + 10, territory.z + 50))
			TerritorySigns.letters(folder, territory.id, name, base, 1.1, 1.2)
		end
	end
end

return TerritorySigns
