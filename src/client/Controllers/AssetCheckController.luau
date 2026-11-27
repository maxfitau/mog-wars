--!strict
-- Studio only. The client-side half of the asset id check (see AssetCheckSystem): looks at this player's own
-- screens (PlayerGui), the camera and the replicated world a few seconds after joining.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AssetCheck = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetCheck"))

local ASSET_ID = "203785492"
local CHECK_AFTER_SECONDS = { 4, 12, 30 }

local AssetCheckController = {}

function AssetCheckController.init() end

function AssetCheckController.start()
	if not RunService:IsStudio() then
		return
	end
	task.spawn(function()
		local waited = 0
		for _, at in CHECK_AFTER_SECONDS do
			task.wait(at - waited)
			waited = at
			local roots: { Instance } = { Players.LocalPlayer:WaitForChild("PlayerGui"), Workspace, Lighting }
			local found = AssetCheck.findAndClear(roots, ASSET_ID)
			for _, where in found do
				print(("[mog-wars] CLIENT ASSET %s was found on %s and has been cleared"):format(ASSET_ID, where))
			end
			if #found == 0 and at == CHECK_AFTER_SECONDS[#CHECK_AFTER_SECONDS] then
				print(("[mog-wars] CLIENT ASSET %s is not on any client-side object"):format(ASSET_ID))
			end
		end
	end)
end

return AssetCheckController
