--!strict
-- Builds the six territories: each is its own module in Lib/Places (landmark, interior, cover, secret, particles).
-- A place that fails to build is reported with "[mog-wars] FAILED building ..." and the others still come up.
-- Each territory also gets one SMALL floating name sign that fades in when you are within about 80 studs.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Territories = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Territories"))
local Builder = require(script.Parent:WaitForChild("Builder"))
local Places = script.Parent:WaitForChild("Places")
local TerrainKit = require(script.Parent:WaitForChild("TerrainKit"))

local TerritoryScenery = {}

local TIER_COLORS = {
	gold = Color3.fromRGB(240, 170, 20),
	diamond = Color3.fromRGB(50, 170, 235),
	ultra = Color3.fromRGB(170, 70, 235),
}

-- How high the name sign floats over each landmark (above its tallest point).
local SIGN_HEIGHT: { [string]: number } = {
	gigachad_gate = 76,
	rizz_ravine = 82,
	locked_in_lighthouse = 130,
	npc_village = 98,
	brainrot_bog = 48,
	cooked_canyon = 46,
	chud_chambers = 22,
}

local builders: { [string]: string } = {
	gigachad_gate = "Gate",
	rizz_ravine = "RizzRavine",
	locked_in_lighthouse = "Lighthouse",
	npc_village = "NpcVillage",
	brainrot_bog = "BrainrotBog",
	cooked_canyon = "CookedCanyon",
	chud_chambers = "ChudChambers",
}

local function sign(folder: Folder, territory: Territories.Territory)
	local anchor = Builder.part("SignAnchor", Vector3.one, Vector3.new(territory.x, (SIGN_HEIGHT[territory.id] or 50) + territory.height, territory.z), Color3.new(1, 1, 1), folder)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	local tier = Territories.tiers[territory.tier]
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 150, 0, 40)
	gui.MaxDistance = 100
	gui.Enabled = false -- the client turns it on and fades it in when you are close
	gui.Parent = anchor
	local fade = Instance.new("CanvasGroup")
	fade.Name = "Fade"
	fade.Size = UDim2.new(1, 0, 1, 0)
	fade.BackgroundColor3 = TIER_COLORS[territory.tier] or Color3.new(1, 1, 1)
	fade.GroupTransparency = 1
	fade.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = fade
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = fade
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -8, 0.62, 0)
	nameLabel.Position = UDim2.new(0, 4, 0, 1)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(35, 25, 60)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Text = territory.name
	nameLabel.Parent = fade
	local tierLabel = Instance.new("TextLabel")
	tierLabel.BackgroundTransparency = 1
	tierLabel.Size = UDim2.new(1, -8, 0.32, 0)
	tierLabel.Position = UDim2.new(0, 4, 0.64, 0)
	tierLabel.Font = Enum.Font.FredokaOne
	tierLabel.TextScaled = true
	tierLabel.TextColor3 = Color3.fromRGB(35, 25, 60)
	tierLabel.Text = tier.label
	tierLabel.Parent = fade
	CollectionService:AddTag(anchor, "TerritorySign")
end

-- Build the scenery and one small name sign for every territory.
function TerritoryScenery.build()
	local root = Instance.new("Folder")
	root.Name = "TerritoryScenery"
	root.Parent = Workspace
	for _, territory in Territories.list do
		local folder = Instance.new("Folder")
		folder.Name = territory.id
		folder.Parent = root
		local moduleName = builders[territory.id]
		TerrainKit.setBase(territory.height) -- the module builds relative to its own island
		local ok, err = pcall(function()
			local build = require(Places:WaitForChild(moduleName)) :: (Folder, any) -> ()
			build(folder, territory)
		end)
		if not ok then
			warn(("[mog-wars] FAILED building %s: %s"):format(territory.name, tostring(err)))
		end
		TerrainKit.setBase(0)
		pcall(sign, folder, territory)
	end
end

return TerritoryScenery
