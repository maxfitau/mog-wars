--!strict
-- Finds (and clears) one troublesome asset id on any object in the game, to fix the Output error
-- "ContentId rbxassetid://<id> failed due to: Asset type does not match requested type". That error means
-- something asks for an asset as the wrong kind (a mesh used as a texture, for example). It does not say WHICH
-- object. This looks through every common asset property and prints the full path of any object that uses the id,
-- then blanks that property so the error stops. Used by the Studio-only AssetCheckSystem and AssetCheckController.

local AssetCheck = {}

AssetCheck.PROPERTIES = {
	"Texture",
	"TextureID",
	"TextureId",
	"Image",
	"MeshId",
	"SoundId",
	"ColorMap",
	"MetalnessMap",
	"NormalMap",
	"RoughnessMap",
	"SkyboxBk",
	"SkyboxDn",
	"SkyboxFt",
	"SkyboxLf",
	"SkyboxRt",
	"SkyboxUp",
	"SunTextureId",
	"MoonTextureId",
	"AnimationId",
	"Graphic",
	"ImageContent",
}

-- Check one object. Returns a list of "FullName.Property" for each property that holds `id`, clearing each one.
local function checkOne(instance: Instance, id: string, found: { string })
	for _, property in AssetCheck.PROPERTIES do
		local ok, value = pcall(function()
			local target: any = instance
			return target[property]
		end)
		if ok and type(value) == "string" and string.find(value, id, 1, true) then
			table.insert(found, instance:GetFullName() .. "." .. property)
			pcall(function()
				local target: any = instance
				target[property] = ""
			end)
		end
	end
end

-- Look through `roots` and everything inside them. Returns where the id was found (and cleared).
function AssetCheck.findAndClear(roots: { Instance }, id: string): { string }
	local found: { string } = {}
	for _, root in roots do
		checkOne(root, id, found)
		for _, descendant in root:GetDescendants() do
			checkOne(descendant, id, found)
		end
	end
	return found
end

return AssetCheck
