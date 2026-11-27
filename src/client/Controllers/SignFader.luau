--!strict
-- The small territory name signs fade in only when you are within about 80 studs, so they never clutter the screen.
-- Display only.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SignFader = {}

local FULL = 60 -- fully visible inside this many studs
local GONE = 85 -- invisible beyond this

function SignFader.init() end

function SignFader.start()
	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		if clock < 0.1 then
			return
		end
		clock = 0
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		for _, anchor in CollectionService:GetTagged("TerritorySign") do
			if anchor:IsA("BasePart") then
				local gui = anchor:FindFirstChildOfClass("BillboardGui")
				local fade = gui and gui:FindFirstChild("Fade")
				if gui and fade and fade:IsA("CanvasGroup") then
					local distance = (anchor.Position - camera.CFrame.Position).Magnitude
					local alpha = math.clamp((GONE - distance) / (GONE - FULL), 0, 1)
					gui.Enabled = alpha > 0
					fade.GroupTransparency = 1 - alpha
				end
			end
		end
	end)
end

return SignFader
