--!strict
-- Draws the cosmetics a player has equipped, on their character, so everyone sees them. Created on the server
-- from the fixed catalog only (never from text a player typed). Everything is gentle: no flashing or strobing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))

local CosmeticVisuals = {}

local PREFIX = "Cosmetic_"

local function colorOf(item: CosmeticCatalog.Item): Color3
	local rgb = item.rgb or { 255, 255, 255 }
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function clear(character: Model, slot: string)
	local old = character:FindFirstChild(PREFIX .. slot, true)
	while old do
		old:Destroy()
		old = character:FindFirstChild(PREFIX .. slot, true)
	end
end

local function addTrail(character: Model, item: CosmeticCatalog.Item)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = PREFIX .. "trail"
	top.Position = Vector3.new(0, 0.9, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = PREFIX .. "trail"
	bottom.Position = Vector3.new(0, -0.9, 0)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = PREFIX .. "trail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(colorOf(item))
	trail.Lifetime = 0.6
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 0.4
	trail.Parent = root
end

local function addAura(character: Model, item: CosmeticCatalog.Item)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = PREFIX .. "aura"
	emitter.Color = ColorSequence.new(colorOf(item))
	emitter.Rate = 10 -- gentle
	emitter.Lifetime = NumberRange.new(0.8, 1.2)
	emitter.Speed = NumberRange.new(1, 2)
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.LightEmission = 0.5
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = root
end

local function addTitle(character: Model, item: CosmeticCatalog.Item)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = PREFIX .. "title"
	gui.Size = UDim2.new(0, 160, 0, 26)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	gui.Adornee = head
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 235, 150)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = item.text or ""
	label.Parent = gui
end

-- Redraw one slot on a character: remove what was there, then draw the equipped item if there is one.
function CosmeticVisuals.refreshSlot(character: Model, slot: string, id: string)
	clear(character, slot)
	local item = CosmeticCatalog.byId[id]
	if not item or item.slot ~= slot then
		return
	end
	if slot == "trail" then
		addTrail(character, item)
	elseif slot == "aura" then
		addAura(character, item)
	elseif slot == "title" then
		addTitle(character, item)
	end
end

-- Redraw every slot from the player's "Equip_<slot>" attributes.
function CosmeticVisuals.refreshAll(player: Player)
	local character = player.Character
	if not character then
		return
	end
	for _, slot in CosmeticCatalog.slots do
		local id = player:GetAttribute("Equip_" .. slot)
		CosmeticVisuals.refreshSlot(character, slot, if type(id) == "string" then id else "")
	end
end

return CosmeticVisuals
