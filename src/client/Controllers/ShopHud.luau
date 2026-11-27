--!strict
-- The cosmetic shop screen. Cosmetics only: nothing here changes how strong you are, and the screen says so.
-- Display only. The server owns what you own and wear (mirrored as the "Cosmetics" and "Equip_<slot>"
-- attributes). Buy opens Roblox's own purchase prompt, and a purchase only ever starts from a tap. The server
-- grants the item after Roblox confirms the purchase, and answers equip requests with a message.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CosmeticCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticCatalog"))

local ShopHud = {}

local player = Players.LocalPlayer
local panel: ScrollingFrame
local toggle: TextButton
local toast: TextLabel
local toastUntil = 0
local rows: { [string]: { button: TextButton, state: TextLabel, item: CosmeticCatalog.Item } } = {}
local ownedSet: { [string]: boolean } = {}
local lastOwnedText = ""

local MESSAGES: { [string]: string } = {
	not_owned = "You do not own that yet.",
	unknown_item = "Unknown item.",
	wrong_slot = "That does not go there.",
	unknown_slot = "Unknown slot.",
	bad_input = "Something went wrong. Try again.",
	not_loaded = "Still loading your data.",
	already_owned = "You already had that one. Nothing more was given.",
}

local SLOT_TITLES: { [string]: string } = { trail = "Trails", aura = "Auras", title = "Titles" }

local function refreshOwned()
	local text = player:GetAttribute("Cosmetics")
	local joined = if type(text) == "string" then text else ""
	if joined == lastOwnedText then
		return
	end
	lastOwnedText = joined
	ownedSet = {}
	for id in string.gmatch(joined, "[^,]+") do
		ownedSet[id] = true
	end
end

local function update()
	refreshOwned()
	local onTraining = player:GetAttribute("Island") == "training" -- the shop lives on Training Island
	toggle.Visible = onTraining
	if not onTraining then
		panel.Visible = false
	end
	for id, row in rows do
		local item = row.item
		local equippedId = player:GetAttribute("Equip_" .. item.slot)
		local owned = ownedSet[id] == true
		if owned then
			local worn = equippedId == id
			row.state.Text = if worn then "Wearing" else "Owned"
			row.button.Text = if worn then "Take off" else "Wear"
			row.button.BackgroundColor3 = Color3.fromRGB(70, 140, 200)
		elseif item.source == "shop" and item.productId ~= 0 then
			row.state.Text = "Robux"
			row.button.Text = "Buy"
			row.button.BackgroundColor3 = Color3.fromRGB(70, 180, 100)
		elseif item.source == "shop" then
			row.state.Text = "Not on sale yet"
			row.button.Text = "Soon"
			row.button.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		else
			row.state.Text = "Found in boxes"
			row.button.Text = "Locked"
			row.button.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		end
	end
	toast.Visible = Workspace:GetServerTimeNow() < toastUntil
end

function ShopHud.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local equipRemote = remotes:WaitForChild("EquipCosmeticRequest") :: RemoteEvent
	local resultRemote = remotes:WaitForChild("ShopResult") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(0, 0.5)
	toggle.Position = UDim2.new(0, 16, 0.5, 104)
	toggle.Size = UDim2.new(0, 90, 0, 40)
	toggle.BackgroundColor3 = Color3.fromRGB(60, 90, 200)
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.Font = Enum.Font.GothamBold
	toggle.TextScaled = true
	toggle.Text = "Shop"
	toggle.Parent = gui
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.Parent = toggle

	panel = Instance.new("ScrollingFrame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.new(0.85, 0, 0.85, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
	panel.ScrollBarThickness = 8
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 580)
	sizeLimit.MinSize = Vector2.new(280, 260)
	sizeLimit.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = panel
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local note = Instance.new("TextLabel")
	note.LayoutOrder = nextOrder()
	note.Size = UDim2.new(1, 0, 0, 36)
	note.BackgroundTransparency = 1
	note.TextWrapped = true
	note.TextColor3 = Color3.fromRGB(255, 220, 90)
	note.Font = Enum.Font.GothamBold
	note.TextSize = 15
	note.Text = "Cosmetics only. Nothing here changes how strong you are."
	note.Parent = panel

	for _, slot in CosmeticCatalog.slots do
		local heading = Instance.new("TextLabel")
		heading.LayoutOrder = nextOrder()
		heading.Size = UDim2.new(1, 0, 0, 24)
		heading.BackgroundTransparency = 1
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.TextColor3 = Color3.new(1, 1, 1)
		heading.Font = Enum.Font.GothamBold
		heading.TextSize = 18
		heading.Text = SLOT_TITLES[slot] or slot
		heading.Parent = panel

		for _, item in CosmeticCatalog.items do
			if item.slot == slot then
				local row = Instance.new("Frame")
				row.LayoutOrder = nextOrder()
				row.Size = UDim2.new(1, 0, 0, 40)
				row.BackgroundColor3 = Color3.fromRGB(34, 36, 48)
				row.Parent = panel
				local rowCorner = Instance.new("UICorner")
				rowCorner.Parent = row

				local name = Instance.new("TextLabel")
				name.BackgroundTransparency = 1
				name.Position = UDim2.new(0, 8, 0, 0)
				name.Size = UDim2.new(0.45, 0, 1, 0)
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.TextColor3 = Color3.new(1, 1, 1)
				name.Font = Enum.Font.Gotham
				name.TextSize = 14
				name.TextWrapped = true
				name.Text = item.name
				name.Parent = row

				local state = Instance.new("TextLabel")
				state.BackgroundTransparency = 1
				state.Position = UDim2.new(0.46, 0, 0, 0)
				state.Size = UDim2.new(0.28, 0, 1, 0)
				state.TextColor3 = Color3.fromRGB(190, 190, 205)
				state.Font = Enum.Font.Gotham
				state.TextSize = 13
				state.TextWrapped = true
				state.Parent = row

				local button = Instance.new("TextButton")
				button.Position = UDim2.new(0.75, 0, 0, 5)
				button.Size = UDim2.new(0.24, 0, 1, -10)
				button.TextColor3 = Color3.new(1, 1, 1)
				button.Font = Enum.Font.GothamBold
				button.TextScaled = true
				button.Parent = row
				local buttonCorner = Instance.new("UICorner")
				buttonCorner.Parent = button
				button.Activated:Connect(function()
					if ownedSet[item.id] then
						local worn = player:GetAttribute("Equip_" .. item.slot) == item.id
						equipRemote:FireServer(item.slot, if worn then "" else item.id)
					elseif item.source == "shop" and item.productId ~= 0 then
						MarketplaceService:PromptProductPurchase(player, item.productId) -- Roblox shows the price
					end
				end)

				rows[item.id] = { button = button, state = state, item = item }
			end
		end
	end

	toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0.1, 0)
	toast.Size = UDim2.new(0, 340, 0, 50)
	toast.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	toast.BackgroundTransparency = 0.1
	toast.TextColor3 = Color3.fromRGB(255, 220, 90)
	toast.Font = Enum.Font.GothamBold
	toast.TextScaled = true
	toast.Visible = false
	toast.ZIndex = 5
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.Parent = toast

	resultRemote.OnClientEvent:Connect(function(ok: any, reason: any, action: any, id: any)
		local item = CosmeticCatalog.byId[tostring(id)]
		local name = if item then item.name else "item"
		if action == "purchase" and ok == true then
			toast.Text = if reason == "already_owned" then MESSAGES.already_owned else ("Thanks! You got %s"):format(name)
		elseif action == "equip" and ok == true then
			toast.Text = if id == "" then "Taken off" else ("Wearing %s"):format(name)
		else
			toast.Text = MESSAGES[tostring(reason)] or "That did not work."
		end
		toastUntil = Workspace:GetServerTimeNow() + 3
	end)
end

function ShopHud.start()
	RunService.RenderStepped:Connect(update)
end

return ShopHud
