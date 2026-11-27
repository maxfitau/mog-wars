--!strict
-- Small helpers for building the placeholder map from simple parts: plain blocks, signs on posts, ramps and
-- standing cylinders. Everything is anchored; scenery is non-colliding where it should not block movement.

local Workspace = game:GetService("Workspace")

local Builder = {}

-- A plain anchored block.
function Builder.part(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent or Workspace
	return part
end

-- A cylinder standing upright. `position` is its middle.
function Builder.cylinder(name: string, diameter: number, height: number, position: Vector3, color: Color3, parent: Instance?): Part
	local part = Builder.part(name, Vector3.new(height, diameter, diameter), position, color, parent)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's length runs along X, so stand it up
	return part
end

-- A walkable ramp from one point up (or down) to another.
function Builder.ramp(name: string, from: Vector3, to: Vector3, width: number, color: Color3, parent: Instance?): Part
	local length = (to - from).Magnitude + 2
	local middle = (from + to) / 2 - Vector3.new(0, 0.5, 0) -- the top surface runs through the two points
	local part = Builder.part(name, Vector3.new(width, 1, length), middle, color, parent)
	part.CFrame = CFrame.lookAt(middle, middle + (to - from))
	return part
end

-- One clear sign: a real board on a post standing in the world (not a floating label), facing `facing`.
function Builder.sign(name: string, text: string, base: Vector3, facing: Vector3, width: number, height: number, color: Color3, parent: Instance?)
	local postHeight = 5
	local post = Builder.part(name .. "Post", Vector3.new(1, postHeight, 1), base + Vector3.new(0, postHeight / 2, 0), Color3.fromRGB(60, 50, 80), parent)
	post.CanCollide = false
	local boardPosition = base + Vector3.new(0, postHeight + height / 2, 0)
	local board = Builder.part(name, Vector3.new(width, height, 1), boardPosition, color, parent)
	board.CFrame = CFrame.lookAt(boardPosition, Vector3.new(facing.X, boardPosition.Y, facing.Z))
	board.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
end

-- An invisible spot that gives off particles (bubbles, smoke). The texture is one of Roblox's own built-in
-- particle textures, named explicitly so nothing depends on a default asset.
function Builder.emitter(name: string, position: Vector3, texture: string, color: Color3, parent: Instance?): ParticleEmitter
	local spot = Builder.part(name, Vector3.new(4, 1, 4), position, color, parent)
	spot.Transparency = 1
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.Parent = spot
	return emitter
end

return Builder
