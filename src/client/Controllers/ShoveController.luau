--!strict
-- THE shove (or, with a weapon equipped, THE WEAPON: same button, coloured and labelled for it, with its own cooldown cover; the
-- Gigachad Gauntlet charges while held). One big button bottom right (touch), or press E or click (PC). The client only sends a bare request; the
-- server decides everything (who, how far, the 1.5 second cooldown). The cooldown shading is display only (it reads
-- the server's ShoveReadyAt). Knockback and launch pads arrive from the server and are applied to this player's own
-- character.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Features = require(Shared:WaitForChild("Features"))
local WeaponCatalog = require(Shared:WaitForChild("WeaponCatalog"))
local UiTheme = require(script.Parent.Parent:WaitForChild("Lib"):WaitForChild("UiTheme"))

local ShoveController = {}

local button: TextButton
local shade: Frame
local request: RemoteEvent

local KNOCKBACK_SPEED_PER_STUD = 3.5 -- tune in playtest
local KNOCKBACK_LIFT = 25
local MAX_KNOCKBACK_STUDS = 60 -- same cap as WeaponRules.MAX_STUDS (weapons push further than plain Shove)

-- The weapon controller (only when weapons are on). An equipped weapon REPLACES Shove: this same button becomes the weapon button.
type WeaponUse = { use: (charge: number?) -> () }
local weaponController: WeaponUse? = nil

local LABELS: { [string]: string } = {
	hammer = "SMASH!",
	gust = "GUST!",
	boomerang = "THROW!",
	rose = "ROSE!",
	mist = "MIST!",
	mirror = "REFLECT!",
	shaker = "SHAKE!",
	mic = "MIC!",
	gauntlet = "PUNCH!",
}

local chargeStart: number? = nil -- the gauntlet: when the button went down
local shownWeapon: string? = nil -- which weapon the button is dressed for ("" = plain Shove)

local function currentWeapon(): WeaponCatalog.Weapon?
	if not weaponController then
		return nil
	end
	local id = Players.LocalPlayer:GetAttribute("Weapon")
	if type(id) == "string" and id ~= "" then
		return WeaponCatalog.byId[id]
	end
	return nil
end

local function remainingCooldown(weapon: WeaponCatalog.Weapon?): number
	local readyAt = Players.LocalPlayer:GetAttribute(if weapon then "WeaponReadyAt" else "ShoveReadyAt")
	return if type(readyAt) == "number" then readyAt - Workspace:GetServerTimeNow() else 0
end

local function refresh()
	local weapon = currentWeapon()
	local id = if weapon then weapon.id else ""
	if shownWeapon ~= id then -- dress the button for the equipped weapon (colour from the catalog), or back to Shove
		shownWeapon = id
		button.BackgroundColor3 = if weapon then Color3.fromRGB(weapon.rgb[1], weapon.rgb[2], weapon.rgb[3]) else UiTheme.colors.orange
		chargeStart = nil
	end
	local remaining = remainingCooldown(weapon)
	local started = chargeStart
	if started and weapon then
		local full = weapon.params.charge or 1
		button.Text = ("%d%%"):format(math.floor(math.clamp((os.clock() - started) / full, 0, 1) * 100))
		shade.Visible = false
	elseif remaining > 0 then
		button.Text = ("%.1f"):format(remaining)
		shade.Visible = true
	else
		button.Text = if weapon then (LABELS[weapon.kind] or "USE!") else "SHOVE!"
		shade.Visible = false
	end
end

-- Button or key goes down: Shove, or the weapon (the gauntlet starts charging instead).
local function press()
	local weapon = currentWeapon()
	if not weapon or not weaponController then
		request:FireServer() -- no data: the server decides
		return
	end
	if weapon.kind == "gauntlet" then
		if remainingCooldown(weapon) <= 0 then
			chargeStart = os.clock()
		end
		return
	end
	weaponController.use(nil)
end

-- Button or key goes up: the gauntlet throws its punch with how long it was held.
local function release()
	local started = chargeStart
	if not started then
		return
	end
	chargeStart = nil
	local weapon = currentWeapon()
	if weapon and weapon.kind == "gauntlet" and weaponController then
		weaponController.use(os.clock() - started)
	end
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function ShoveController.init()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	request = remotes:WaitForChild("ShoveRequest") :: RemoteEvent
	if Features.weapons then
		local module = script.Parent:FindFirstChild("WeaponController")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok then
				weaponController = result :: any
			else
				warn("[mog-wars] weapon button off: " .. tostring(result))
			end
		end
	end
	local knockback = remotes:WaitForChild("ShoveKnockback") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShoveHud"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- the one big round button, bottom right
	button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -24, 1, -28)
	button.Size = UDim2.new(0, 132, 0, 132)
	button.BackgroundColor3 = UiTheme.colors.orange
	button.Font = UiTheme.font
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeColor3 = UiTheme.outline
	button.TextStrokeTransparency = 0
	button.Text = "SHOVE!"
	button.Parent = gui
	UiTheme.round(button, UDim.new(1, 0))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- the ring round the button (the default would outline the LETTERS, which made the label a white blob)
	stroke.Parent = button
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.12, 0)
	pad.PaddingRight = UDim.new(0.12, 0)
	pad.PaddingTop = UDim.new(0.28, 0)
	pad.PaddingBottom = UDim.new(0.28, 0)
	pad.Parent = button
	shade = Instance.new("Frame") -- greys the button out while it recharges
	shade.Size = UDim2.new(1, 0, 1, 0)
	shade.BackgroundColor3 = Color3.fromRGB(40, 30, 70)
	shade.BackgroundTransparency = 0.45
	shade.Visible = false
	shade.ZIndex = 2
	shade.Parent = button
	UiTheme.round(shade, UDim.new(1, 0))
	button.InputBegan:Connect(function(input)
		if isPress(input) then
			press()
		end
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then
			release()
		end
	end)

	-- E or a click anywhere also shoves, or uses the weapon (PC)
	ContextActionService:BindAction("MogWarsShove", function(_, state)
		if state == Enum.UserInputState.Begin then
			press()
		elseif state == Enum.UserInputState.End then
			release()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			press()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			release()
		end
	end)

	knockback.OnClientEvent:Connect(function(dx: any, dz: any, studs: any)
		if type(dx) ~= "number" or type(dz) ~= "number" or type(studs) ~= "number" then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and math.abs(dx) <= 1.01 and math.abs(dz) <= 1.01 then
			local speed = math.clamp(studs, 0, MAX_KNOCKBACK_STUDS) * KNOCKBACK_SPEED_PER_STUD
			root.AssemblyLinearVelocity = Vector3.new(dx * speed, KNOCKBACK_LIFT, dz * speed)
		end
	end)

	-- a gentle wind push (added to your own movement)
	local pushRemote = remotes:WaitForChild("WorldPush") :: RemoteEvent
	pushRemote.OnClientEvent:Connect(function(velocity: any)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and typeof(velocity) == "Vector3" and velocity.Magnitude < 40 then
			root.AssemblyLinearVelocity += velocity
		end
	end)

	-- jump pads and launch pads throw you (the server sends the throw)
	local launch = remotes:WaitForChild("WorldLaunch") :: RemoteEvent
	launch.OnClientEvent:Connect(function(velocity: any)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and typeof(velocity) == "Vector3" and velocity.Magnitude < 400 then
			root.AssemblyLinearVelocity = velocity
		end
	end)
end

function ShoveController.start()
	RunService.RenderStepped:Connect(refresh)
end

return ShoveController
