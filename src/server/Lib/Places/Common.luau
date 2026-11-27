--!strict
-- Pieces every territory shares: particles, ambient sound and the free Aura Stash in each secret spot.

local CollectionService = game:GetService("CollectionService")

local Builder = require(script.Parent.Parent:WaitForChild("Builder"))

local Common = {}

Common.SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
Common.SMOKE = "rbxasset://textures/particles/smoke_main.dds"

function Common.sparkles(folder: Instance, name: string, position: Vector3, color: Color3, rate: number, spread: number?): ParticleEmitter
	local emitter = Builder.emitter(name, position, Common.SPARKLES, color, folder)
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(spread or 180, spread or 180)
	emitter.Size = NumberSequence.new(1.4, 0)
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.LightEmission = 0.7
	return emitter
end

function Common.smoke(folder: Instance, name: string, position: Vector3, color: Color3, rate: number, size: number): ParticleEmitter
	local emitter = Builder.emitter(name, position, Common.SMOKE, color, folder)
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(2, 4)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new(size * 0.5, size)
	emitter.Transparency = NumberSequence.new(0.55, 1)
	return emitter
end

-- Looping ambient sound for a place. The id comes from Ambience.luau; empty means "no sound yet" and nothing is made.
function Common.ambience(folder: Instance, position: Vector3, soundId: string, volume: number?)
	if soundId == "" then
		return
	end
	local holder = Builder.part("Ambience", Vector3.one, position, Color3.new(1, 1, 1), folder)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = volume or 0.4
	sound.RollOffMaxDistance = 140
	sound.Parent = holder
	sound:Play()
end

-- The free Aura Stash in a secret spot: open it to refill your aura charge and ego and get a little aura.
function Common.stash(folder: Instance, position: Vector3, territoryId: string): Part
	local crate = Builder.part("AuraStash", Vector3.new(4, 3, 3), position + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 205, 60), folder)
	crate.Material = Enum.Material.Neon
	crate.CanCollide = true
	crate:SetAttribute("Territory", territoryId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Aura Stash"
	prompt.ObjectText = "Secret!"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = crate
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 100)
	light.Range = 14
	light.Parent = crate
	CollectionService:AddTag(crate, "AuraStash")
	return crate
end

return Common
