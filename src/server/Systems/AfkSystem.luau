--!strict
-- AFK: no movement, ability or input for Pace.afk.seconds (30) = AFK. An AFK player earns no passive aura (PresenceSystem), cannot
-- hold flags (CaptureSystem), and shows an "AFK" tag over their head. After Pace.afk.moveSeconds (3 minutes) they are moved back
-- to their team island. Real input is reported by the client's ActivityPing (rate limited here); walking is also seen on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pace = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pace"))

local AfkSystem = {}

type State = { lastActive: number, afkSince: number?, moved: boolean, lastPing: number, tag: BillboardGui? }
local states: { [Player]: State } = {}

local function now(): number
	return os.clock()
end

local function setTag(player: Player, state: State, on: boolean)
	if on and not state.tag then
		local head = player.Character and player.Character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local gui = Instance.new("BillboardGui")
			gui.Name = "AfkTag"
			gui.Size = UDim2.fromOffset(70, 28)
			gui.StudsOffset = Vector3.new(0, 3.2, 0)
			gui.AlwaysOnTop = true
			gui.MaxDistance = 140
			gui.Adornee = head
			gui.Parent = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			label.BackgroundTransparency = 0.2
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.Text = "AFK"
			label.TextColor3 = Color3.fromRGB(255, 220, 120)
			label.Parent = gui
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = label
			state.tag = gui
		end
	elseif not on and state.tag then
		state.tag:Destroy()
		state.tag = nil
	end
end

local function markActive(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.lastActive = now()
	if state.afkSince then
		state.afkSince = nil
		state.moved = false
		player:SetAttribute("AFK", false)
		setTag(player, state, false)
	end
end

function AfkSystem.init()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local ping = Instance.new("RemoteEvent")
	ping.Name = "ActivityPing"
	ping.Parent = folder
	ping.OnServerEvent:Connect(function(player)
		local state = states[player]
		if state and now() - state.lastPing >= Pace.afk.pingSeconds * 0.8 then -- rate limit: ignore a flood
			state.lastPing = now()
			markActive(player)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		states[player] = { lastActive = now(), afkSince = nil, moved = false, lastPing = 0, tag = nil }
		player:SetAttribute("AFK", false)
		player.CharacterAdded:Connect(function()
			local state = states[player]
			if state then
				state.tag = nil
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		states[player] = { lastActive = now(), afkSince = nil, moved = false, lastPing = 0, tag = nil }
		player:SetAttribute("AFK", false)
	end
end

function AfkSystem.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in states do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				-- walking, or a ride (lift, zipline), counts as active
				if humanoid and (humanoid.MoveDirection.Magnitude > 0.1 or player:GetAttribute("Ziplining") == true) then
					markActive(player)
				end
				local idle = now() - state.lastActive
				if idle >= Pace.afk.seconds and not state.afkSince then
					state.afkSince = now()
					player:SetAttribute("AFK", true)
					setTag(player, state, true)
				end
				if state.afkSince and not state.moved and now() - state.afkSince >= Pace.afk.moveSeconds - Pace.afk.seconds then
					state.moved = true -- 3 minutes without input: back to the team island
					task.spawn(function()
						pcall(function()
							player:LoadCharacter() -- respawns at the team's own island
						end)
					end)
				end
				if state.afkSince and not state.tag then
					setTag(player, state, true) -- the tag is rebuilt after a respawn
				end
			end
		end
	end)
end

return AfkSystem
