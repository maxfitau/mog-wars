--!strict
-- Shared look for Mog Wars screens: bright, chunky, rounded font, big buttons. New screens use this; the older
-- panels get restyled to match once the owner's UI designs are shared (they were not available to the cloud
-- session). Change the look here and every screen that uses it follows.

local UiTheme = {}

UiTheme.font = Enum.Font.FredokaOne -- rounded and chunky
UiTheme.textColor = Color3.new(1, 1, 1)
UiTheme.outline = Color3.fromRGB(35, 25, 60) -- thick dark outline around buttons and text
UiTheme.panel = Color3.fromRGB(45, 35, 85) -- deep purple panels

UiTheme.colors = {
	orange = Color3.fromRGB(255, 160, 30),
	green = Color3.fromRGB(70, 210, 100),
	blue = Color3.fromRGB(60, 150, 255),
	red = Color3.fromRGB(255, 80, 90),
	yellow = Color3.fromRGB(255, 215, 60),
	grey = Color3.fromRGB(130, 125, 150),
}

UiTheme.cornerRadius = UDim.new(0, 22)
UiTheme.strokeThickness = 4

-- Round the corners of a frame or button.
function UiTheme.round(guiObject: GuiObject, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UiTheme.cornerRadius
	corner.Parent = guiObject
end

-- A thick dark outline.
function UiTheme.outlineBox(guiObject: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.Color = UiTheme.outline
	stroke.Thickness = UiTheme.strokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = guiObject
end

-- A big, bright, rounded button with a thick outline. Returns the button.
function UiTheme.button(parent: Instance, text: string, color: Color3, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.BackgroundColor3 = color
	button.TextColor3 = UiTheme.textColor
	button.Font = UiTheme.font
	button.TextScaled = true
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	UiTheme.round(button)
	UiTheme.outlineBox(button)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.15, 0)
	padding.PaddingBottom = UDim.new(0.15, 0)
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.Parent = button
	local textStroke = Instance.new("UIStroke") -- outline on the letters too
	textStroke.Color = UiTheme.outline
	textStroke.Thickness = 3
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent = button
	return button
end

return UiTheme
