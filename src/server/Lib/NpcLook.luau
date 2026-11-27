--!strict
-- REDUCED TO NPC: for a moment the body turns grey, the face goes blank and a "..." bubble floats over the head; then it all
-- goes back. Used by Total Mog. Works on a player's character or a Mogling's model.

local NpcLook = {}

local GREY = Color3.fromRGB(150, 150, 158)

function NpcLook.apply(character: Model, seconds: number)
	local undo: { () -> () } = {}
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
			local part = item
			local color = part.Color
			part.Color = GREY
			table.insert(undo, function()
				part.Color = color
			end)
		elseif item:IsA("Decal") and item.Parent and item.Parent.Name == "Head" then
			local decal = item
			local transparency = decal.Transparency
			decal.Transparency = 1
			table.insert(undo, function()
				decal.Transparency = transparency
			end)
		end
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local gui = Instance.new("BillboardGui")
		gui.Name = "NpcBubble"
		gui.Size = UDim2.new(0, 80, 0, 44)
		gui.StudsOffset = Vector3.new(0, 3.4, 0)
		gui.Adornee = head
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(35, 25, 60)
		label.Text = "..."
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = label
		table.insert(undo, function()
			gui:Destroy()
		end)
	end
	task.delay(seconds, function()
		for _, step in undo do
			step()
		end
	end)
end

return NpcLook
