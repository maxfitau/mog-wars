--!strict
-- Launch pads and ziplines between the floating islands.
--  * LAUNCH PADS (pink glowing discs near an island's rim): step on one and you are thrown in an arc that lands on the
--    next island. The throw is worked out here from the real island positions (LaunchRules), then stored on the pad as a
--    "Launch" attribute; MovementSystem sends it to the player who touches the pad.
--  * ZIPLINES (a post with a prompt, a black cable, a post below): hold the prompt and you ride down to the lower island.
--    They only go downhill. ZiplineSystem starts the ride; the rider's own screen moves them along the cable.
-- Bots do not use either (they walk the bridges).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LaunchRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LaunchRules"))
local Builder = require(script.Parent:WaitForChild("Builder"))

local SkyLinks = {}

export type Island = { x: number, z: number, y: number, r: number }

local PAD_COLOR = Color3.fromRGB(255, 105, 190)
local WOOD = Color3.fromRGB(120, 84, 52)

local function flat(from: Island, to: Island): Vector3
	return Vector3.new(to.x - from.x, 0, to.z - from.z).Unit
end

local function perpendicular(direction: Vector3): Vector3
	return Vector3.new(-direction.Z, 0, direction.X)
end

-- One launch pad on island `a`, throwing toward island `b`, landing near b's rim on the side facing a.
local function launchPad(folder: Instance, a: Island, b: Island)
	local direction = flat(a, b)
	local side = perpendicular(direction)
	local padPosition = Vector3.new(a.x, a.y, a.z) + direction * (a.r - 22) + side * 14
	local target = Vector3.new(b.x, b.y, b.z) - direction * (b.r - 12)
	local startY = a.y + 3.4 -- standing on the pad
	local endY = b.y + 3
	local distance = Vector3.new(target.X - padPosition.X, 0, target.Z - padPosition.Z).Magnitude
	local seconds = LaunchRules.flightSeconds(distance)
	local vx, vy, vz = LaunchRules.velocity(padPosition.X, startY, padPosition.Z, target.X, endY, target.Z, Workspace.Gravity, seconds)
	local pad = Builder.cylinder("LaunchPad", 9, 0.6, Vector3.new(padPosition.X, a.y + 0.3, padPosition.Z), PAD_COLOR, folder)
	pad.Material = Enum.Material.Neon
	pad.CanCollide = false
	pad.CanQuery = false
	pad:SetAttribute("Launch", Vector3.new(vx, vy, vz))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right -- the flat top of a standing cylinder
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = pad
	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(1, 0, 1, 0)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.FredokaOne
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.new(1, 1, 1)
	arrow.Text = "^"
	arrow.Parent = gui
	local light = Instance.new("PointLight")
	light.Color = PAD_COLOR
	light.Range = 14
	light.Parent = pad
	CollectionService:AddTag(pad, "LaunchPad")
end

local function post(folder: Instance, position: Vector3)
	local pole = Builder.part("ZiplinePost", Vector3.new(1.6, 10, 1.6), position + Vector3.new(0, 5, 0), WOOD, folder)
	pole.Material = Enum.Material.Wood
	local deck = Builder.part("ZiplineDeck", Vector3.new(8, 1, 8), position + Vector3.new(0, 0.5, 0), WOOD, folder)
	deck.Material = Enum.Material.WoodPlanks
	return pole
end

-- One zipline from the higher island `a` down to the lower island `b`.
local function zipline(folder: Instance, a: Island, b: Island)
	local direction = flat(a, b)
	local side = perpendicular(direction)
	local startBase = Vector3.new(a.x, a.y, a.z) + direction * (a.r - 10) - side * 14
	local endBase = Vector3.new(b.x, b.y, b.z) - direction * (b.r - 16) - side * 14
	local startPole = post(folder, startBase)
	post(folder, endBase)
	local startHandle = startBase + Vector3.new(0, 9, 0)
	local endHandle = endBase + Vector3.new(0, 9, 0)
	local length = (endHandle - startHandle).Magnitude
	local cable = Instance.new("Part")
	cable.Name = "ZiplineCable"
	cable.Anchored = true
	cable.CanCollide = false
	cable.CanQuery = false
	cable.Size = Vector3.new(0.25, 0.25, length)
	cable.CFrame = CFrame.lookAt((startHandle + endHandle) / 2, endHandle)
	cable.Color = Color3.fromRGB(35, 35, 42)
	cable.Material = Enum.Material.Metal
	cable.Parent = folder
	local handle = Builder.part("ZiplineHandle", Vector3.new(3, 0.6, 0.6), startHandle - Vector3.new(0, 1.2, 0), Color3.fromRGB(255, 205, 60), folder)
	handle.CanCollide = false
	handle.CanQuery = false
	handle:SetAttribute("StartPos", startHandle)
	handle:SetAttribute("EndPos", endHandle)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ride the zipline"
	prompt.ObjectText = "Zipline"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = handle
	CollectionService:AddTag(handle, "ZiplineStart")
	startPole:SetAttribute("Zipline", true)
end

-- `islands` is a map of id to island. Pads go from each team island to the Gold island next to it, from each Gold and
-- Diamond island up to Gigachad Gate, and from the Gate down to each Diamond island. Ziplines run downhill from the Gate.
function SkyLinks.build(islands: { [string]: Island }, withPads: boolean, withZiplines: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "SkyLinks"
	folder.Parent = Workspace
	local pads = {
		{ "base1", "npc_village" }, { "base2", "rizz_ravine" }, { "base3", "cooked_canyon" }, { "base4", "brainrot_bog" },
		{ "npc_village", "gigachad_gate" }, { "brainrot_bog", "gigachad_gate" }, { "cooked_canyon", "gigachad_gate" },
		{ "rizz_ravine", "gigachad_gate" }, { "locked_in_lighthouse", "gigachad_gate" },
		{ "gigachad_gate", "rizz_ravine" }, { "gigachad_gate", "locked_in_lighthouse" },
	}
	for _, link in pads do
		local a, b = islands[link[1]], islands[link[2]]
		if withPads and a and b then
			launchPad(folder, a, b)
		end
	end
	local ziplines = {
		{ "gigachad_gate", "rizz_ravine" }, { "gigachad_gate", "locked_in_lighthouse" }, { "gigachad_gate", "npc_village" },
		{ "gigachad_gate", "brainrot_bog" }, { "gigachad_gate", "cooked_canyon" },
	}
	for _, link in ziplines do
		local a, b = islands[link[1]], islands[link[2]]
		if withZiplines and a and b and a.y > b.y then
			zipline(folder, a, b)
		end
	end
end

return SkyLinks
