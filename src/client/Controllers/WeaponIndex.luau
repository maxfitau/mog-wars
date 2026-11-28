--!strict
-- The WEAPON INDEX: a screen (small "Weapons" pill under the minimap, or the key B) with all 9 weapons in a grid. Found weapons
-- show their colour, rarity, 1-5 drawn stars, blurb, cooldown and an EQUIP / UNEQUIP button; unfound ones are a dark silhouette
-- with a drawn question mark. Also plays the WEAPON REVEAL card when the server grants a weapon. Display only: the server owns
-- the collection (the "Collection" attribute) and checks ownership on EquipWeapon. Everything is drawn from shapes, ASCII text only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponCatalog = require(Shared:WaitForChild("WeaponCatalog"))
local Lib = script.Parent.Parent:WaitForChild("Lib")
local UiTheme = require(Lib:WaitForChild("UiTheme"))
local HudSlots = require(Lib:WaitForChild("HudSlots"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))

local WeaponIndex = {}

local PANEL_W = 560
local PANEL_H = 396
local STAR_ON = Color3.fromRGB(255, 205, 60)
local STAR_OFF = Color3.fromRGB(70, 60, 100)
local SILHOUETTE = Color3.fromRGB(28, 22, 48)

local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local grid: Frame
local equipRemote: RemoteEvent? = nil
local lastEquip = 0

local function rarityColour(rarityId: string): Color3
	local rarity = WeaponCatalog.rarityById[rarityId]
	if rarity then
		return Color3.fromRGB(rarity.rgb[1], rarity.rgb[2], rarity.rgb[3])
	end
	return Color3.new(1, 1, 1)
end

local function weaponColour(weapon: WeaponCatalog.Weapon): Color3
	return Color3.fromRGB(weapon.rgb[1], weapon.rgb[2], weapon.rgb[3])
end

local function box(parent: Instance, pos: UDim2, size: UDim2, colour: Color3, rotation: number?): Frame
	local frame = Instance.new("Frame")
	frame.Position = pos
	frame.Size = size
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	frame.Rotation = rotation or 0
	frame.Parent = parent
	return frame
end

-- A 5-point-ish star drawn from two squares (one turned 45 degrees). `size` is the box side in pixels.
local function drawStar(parent: Instance, x: number, y: number, size: number, colour: Color3)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.new(0, x, 0, y)
	holder.Size = UDim2.new(0, size, 0, size)
	holder.Parent = parent
	local inner = math.floor(size * 0.66)
	local offset = math.floor((size - inner) / 2)
	box(holder, UDim2.new(0, offset, 0, offset), UDim2.new(0, inner, 0, inner), colour, 0)
	box(holder, UDim2.new(0, offset, 0, offset), UDim2.new(0, inner, 0, inner), colour, 45)
end

local function drawStarRow(parent: Instance, x: number, y: number, size: number, count: number)
	for index = 1, 5 do
		drawStar(parent, x + (index - 1) * (size + 2), y, size, if index <= count then STAR_ON else STAR_OFF)
	end
end

-- A question mark made of shapes: a ring with its lower left cut away, a short stem and a dot.
local function drawQuestionMark(parent: Instance, backdrop: Color3)
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.Position = UDim2.new(0, 11, 0, 4)
	ring.Size = UDim2.new(0, 22, 0, 22)
	ring.Parent = parent
	UiTheme.round(ring, UDim.new(1, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(150, 140, 185)
	stroke.Thickness = 5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = ring
	box(parent, UDim2.new(0, 9, 0, 16), UDim2.new(0, 13, 0, 12), backdrop, 0)
	box(parent, UDim2.new(0, 19, 0, 24), UDim2.new(0, 5, 0, 8), Color3.fromRGB(150, 140, 185), 0)
	local dot = box(parent, UDim2.new(0, 18, 0, 35), UDim2.new(0, 7, 0, 7), Color3.fromRGB(150, 140, 185), 0)
	UiTheme.round(dot, UDim.new(1, 0))
end

-- The weapon's icon: a rounded tile in its own colour with a light diamond and a dark bar (a stylised handle).
local function drawWeaponIcon(parent: Instance, weapon: WeaponCatalog.Weapon, stars: number)
	local colour = weaponColour(weapon)
	local tile = box(parent, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), colour, 0)
	UiTheme.round(tile, UDim.new(0, 10))
	local edge = Instance.new("UIStroke")
	edge.Color = if WeaponCatalog.hasGlowSkin(stars) then STAR_ON else rarityColour(weapon.rarity)
	edge.Thickness = if WeaponCatalog.hasGlowSkin(stars) then 4 else 3
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = tile
	box(tile, UDim2.new(0.5, -3, 0.45, 0), UDim2.new(0, 6, 0.45, 0), colour:Lerp(Color3.new(0, 0, 0), 0.5), 0)
	box(tile, UDim2.new(0.5, -9, 0.12, 0), UDim2.new(0, 18, 0, 18), colour:Lerp(Color3.new(1, 1, 1), 0.6), 45)
end

local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, colour: Color3, textSize: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = pos
	item.Size = size
	item.Font = UiTheme.font
	item.TextSize = textSize
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.TextColor3 = colour
	item.TextStrokeColor3 = UiTheme.outline
	item.TextStrokeTransparency = 0.4
	item.Text = text
	item.Parent = parent
	return item
end

local function fireEquip(id: string)
	if os.clock() - lastEquip < 0.3 then
		return
	end
	lastEquip = os.clock()
	if equipRemote then
		equipRemote:FireServer(id)
	end
	SoundController.play("ui_click")
end

local function drawCell(weapon: WeaponCatalog.Weapon, stars: number, equipped: boolean)
	local cell = Instance.new("Frame")
	cell.Name = weapon.id
	cell.BackgroundColor3 = UiTheme.panel
	cell.Parent = grid
	UiTheme.round(cell, UDim.new(0, 12))
	local edge = Instance.new("UIStroke")
	edge.Color = if stars > 0 then rarityColour(weapon.rarity) else Color3.fromRGB(80, 70, 110)
	edge.Thickness = if equipped then 4 else 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = cell

	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.new(0, 8, 0, 8)
	icon.Size = UDim2.new(0, 44, 0, 44)
	icon.Parent = cell
	local rarity = WeaponCatalog.rarityById[weapon.rarity]
	local rarityLabel = if rarity then rarity.label else ""
	if stars > 0 then
		drawWeaponIcon(icon, weapon, stars)
		label(cell, weapon.name, UDim2.new(0, 58, 0, 6), UDim2.new(1, -62, 0, 18), Color3.new(1, 1, 1), 15)
		label(cell, rarityLabel, UDim2.new(0, 58, 0, 24), UDim2.new(0, 60, 0, 14), rarityColour(weapon.rarity), 12)
		drawStarRow(cell, 58, 40, 14, stars)
		local blurb = label(cell, weapon.blurb, UDim2.new(0, 8, 0, 58), UDim2.new(1, -16, 0, 28), Color3.fromRGB(200, 195, 225), 11)
		blurb.TextWrapped = true
		blurb.TextTruncate = Enum.TextTruncate.None
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		label(cell, ("Cooldown %gs"):format(weapon.cooldown), UDim2.new(0, 8, 1, -22), UDim2.new(0, 80, 0, 16), Color3.fromRGB(190, 235, 255), 11)
		local button = UiTheme.button(cell, if equipped then "UNEQUIP" else "EQUIP", if equipped then UiTheme.colors.grey else UiTheme.colors.green, UDim2.new(0, 72, 0, 22))
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -8, 1, -6)
		button.Activated:Connect(function()
			fireEquip(if equipped then "" else weapon.id)
		end)
	else
		local tile = box(icon, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0), SILHOUETTE, 0)
		UiTheme.round(tile, UDim.new(0, 10))
		drawQuestionMark(tile, SILHOUETTE)
		label(cell, "???", UDim2.new(0, 58, 0, 6), UDim2.new(1, -62, 0, 18), Color3.fromRGB(150, 140, 185), 15)
		label(cell, rarityLabel, UDim2.new(0, 58, 0, 24), UDim2.new(0, 60, 0, 14), rarityColour(weapon.rarity), 12)
		drawStarRow(cell, 58, 40, 14, 0)
		local hint = label(cell, "Not found yet. Win chests, crates and quests!", UDim2.new(0, 8, 0, 58), UDim2.new(1, -16, 0, 28), Color3.fromRGB(150, 140, 185), 11)
		hint.TextWrapped = true
		hint.TextTruncate = Enum.TextTruncate.None
		hint.TextYAlignment = Enum.TextYAlignment.Top
	end
end

local function refresh()
	if not grid then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local collection = WeaponCatalog.decode(tostring(player:GetAttribute("Collection") or ""))
	local equippedId = tostring(player:GetAttribute("Weapon") or "")
	for _, weapon in WeaponCatalog.weapons do
		local stars = math.clamp(collection[weapon.id] or 0, 0, 5)
		drawCell(weapon, stars, stars > 0 and equippedId == weapon.id)
	end
end

local function setOpen(open: boolean)
	if panel.Visible == open then
		return
	end
	panel.Visible = open
	if open then
		refresh()
		SoundController.play("ui_click")
	end
end

local function buildScreen()
	gui = Instance.new("ScreenGui")
	gui.Name = "WeaponIndex"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 13
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The small pill: right column, BELOW the minimap and its control bar (minimap y 64 to 192, bar to about 222), y 236.
	-- The left column (aura box, Quests pill) is untouched and the middle third stays clear until the screen is opened.
	local pill = Instance.new("TextButton")
	pill.Name = "WeaponsPill"
	local fit = HudSlots.leftScale() -- the same shrink as the rest of the left column
	pill.AnchorPoint = Vector2.new(0, 0)
	pill.Position = UDim2.new(0, 16 + 126 * fit, 0, 172) -- the left column, in the Quests pill's row (always on screen, also on phones)
	local pillScale = Instance.new("UIScale")
	pillScale.Scale = fit
	pillScale.Parent = pill
	pill.Size = UDim2.new(0, 96, 0, 26)
	pill.BackgroundColor3 = UiTheme.panel
	pill.BackgroundTransparency = 0.2
	pill.Font = UiTheme.font
	pill.TextScaled = true
	pill.TextColor3 = Color3.new(1, 1, 1)
	pill.Text = "Weapons (B)"
	pill.Parent = gui
	UiTheme.round(pill, UDim.new(1, 0))
	local pillPad = Instance.new("UIPadding")
	pillPad.PaddingTop = UDim.new(0, 4)
	pillPad.PaddingBottom = UDim.new(0, 4)
	pillPad.PaddingLeft = UDim.new(0, 8)
	pillPad.PaddingRight = UDim.new(0, 8)
	pillPad.Parent = pill
	pill.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
	panel.BackgroundColor3 = Color3.fromRGB(30, 22, 58)
	panel.Visible = false
	panel.Parent = gui
	UiTheme.round(panel, UDim.new(0, 18))
	UiTheme.outlineBox(panel)
	local fit = Instance.new("UIScale") -- shrink on small screens
	fit.Parent = panel
	local function rescale()
		local camera = workspace.CurrentCamera
		if camera then
			local view = camera.ViewportSize
			fit.Scale = math.clamp(math.min((view.X - 24) / PANEL_W, (view.Y - 24) / PANEL_H), 0.5, 1)
		end
	end
	rescale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	local title = label(panel, "WEAPON INDEX", UDim2.new(0, 16, 0, 8), UDim2.new(1, -80, 0, 28), STAR_ON, 24)
	title.TextTruncate = Enum.TextTruncate.None
	local close = UiTheme.button(panel, "X", UiTheme.colors.red, UDim2.new(0, 36, 0, 28))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Activated:Connect(function()
		setOpen(false)
	end)

	grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.new(0, 12, 0, 46)
	grid.Size = UDim2.new(1, -24, 1, -56)
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, 170, 0, 104)
	layout.CellPadding = UDim2.new(0, 8, 0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
end

-- The reveal card (card slot, upper third): name, a rarity-colour burst, NEW! or the new star count.
local function reveal(id: string, stars: number, isNew: boolean)
	local weapon = WeaponCatalog.byId[id]
	if not weapon then
		return
	end
	local colour = rarityColour(weapon.rarity)
	local rarity = WeaponCatalog.rarityById[weapon.rarity]
	local rank = if rarity then rarity.rank else 1
	HudSlots.card(function(done)
		local card = Instance.new("Frame")
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, -140)
		card.Size = UDim2.new(0, 300, 0, 104)
		card.BackgroundColor3 = UiTheme.panel
		card.Parent = gui
		UiTheme.round(card, UDim.new(0, 18))
		local edge = Instance.new("UIStroke")
		edge.Color = colour
		edge.Thickness = 4
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = card
		local head = if isNew then "NEW WEAPON!" else ("STAR UP! %d of 5 stars"):format(stars)
		label(card, head, UDim2.new(0, 12, 0, 6), UDim2.new(1, -24, 0, 20), STAR_ON, 16)
		label(card, weapon.name, UDim2.new(0, 12, 0, 26), UDim2.new(1, -24, 0, 32), colour, 26)
		drawStarRow(card, 12, 62, 16, stars)
		local note = if WeaponCatalog.hasGlowSkin(stars) then "5 stars: it GLOWS now!" else ("%s - press B"):format(if rarity then rarity.label else "")
		label(card, note, UDim2.new(0, 108, 0, 62), UDim2.new(1, -118, 0, 18), Color3.fromRGB(190, 235, 255), 13)
		-- the colour burst: little squares fly out from the card centre
		for _ = 1, 14 do
			local bit = box(card, UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, 8, 0, 8), colour, math.random(0, 90))
			bit.ZIndex = 5
			TweenService:Create(bit, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
				Position = UDim2.new(0.5, math.random(-170, 170), 0.5, math.random(-60, 70)),
				BackgroundTransparency = 1,
			}):Play()
		end
		SoundController.play(if rank >= 2 then "chest_rare" else "chest_open")
		TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, HudSlots.cardY) }):Play()
		task.delay(if stars >= 5 or rank >= 4 then 3.4 else 2.6, function()
			local out = TweenService:Create(card, TweenInfo.new(0.35), { Position = UDim2.new(0.5, 0, 0, -140) })
			out.Completed:Connect(function()
				card:Destroy()
				done()
			end)
			out:Play()
		end)
	end)
end

function WeaponIndex.init()
	buildScreen()
end

function WeaponIndex.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	equipRemote = remotes:WaitForChild("EquipWeapon") :: RemoteEvent
	local granted = remotes:WaitForChild("WeaponGranted") :: RemoteEvent
	granted.OnClientEvent:Connect(function(id: any, stars: any, isNew: any, source: any)
		if type(id) ~= "string" or type(stars) ~= "number" or type(isNew) ~= "boolean" then
			return
		end
		if panel.Visible then
			refresh()
		end
		if source == "chest" then
			return -- the war chest card reveals its own weapon
		end
		reveal(id, math.clamp(math.floor(stars), 1, 5), isNew)
	end)
	player:GetAttributeChangedSignal("Collection"):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("Weapon"):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			setOpen(not panel.Visible)
		end
	end)
end

return WeaponIndex
