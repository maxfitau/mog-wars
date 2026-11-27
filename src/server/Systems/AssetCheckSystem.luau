--!strict
-- Studio only. Looks for the asset id behind the Output error "ContentId rbxassetid://203785492 failed due to:
-- Asset type does not match requested type" on the server's objects (the map, Lighting, bots, StarterGui and so
-- on) a few seconds after the game starts, prints the exact object and property if it finds it, and clears it.
-- If it prints nothing, the id is not on any of our objects (it may come from Roblox's own built-in scripts).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local Workspace = game:GetService("Workspace")

local AssetCheck = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetCheck"))

local ASSET_ID = "203785492"
local CHECK_AFTER_SECONDS = { 3, 10, 30 }

local AssetCheckSystem = {}

function AssetCheckSystem.init() end

function AssetCheckSystem.start()
	if not RunService:IsStudio() then
		return
	end
	task.spawn(function()
		local waited = 0
		for _, at in CHECK_AFTER_SECONDS do
			task.wait(at - waited)
			waited = at
			local roots: { Instance } = { Workspace, Lighting, ReplicatedStorage, StarterGui, StarterPack, SoundService }
			local found = AssetCheck.findAndClear(roots, ASSET_ID)
			for _, where in found do
				print(("[mog-wars] ASSET %s was found on %s and has been cleared"):format(ASSET_ID, where))
			end
			if #found == 0 and at == CHECK_AFTER_SECONDS[#CHECK_AFTER_SECONDS] then
				print(("[mog-wars] ASSET %s is not on any server-side object"):format(ASSET_ID))
			end
		end
	end)
end

return AssetCheckSystem
