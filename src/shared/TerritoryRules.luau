--!strict
-- Pure territory rules. A territory is owned only when ONE faction holds ALL of its flags.

local TerritoryRules = {}

-- The faction that owns a territory, given who holds each flag (0 = nobody). 0 unless every flag has the same
-- faction (and there is at least one flag).
function TerritoryRules.owner(flagOwners: { number }): number
	local first = flagOwners[1]
	if first == nil or first == 0 then
		return 0
	end
	for _, owner in flagOwners do
		if owner ~= first then
			return 0
		end
	end
	return first
end

-- How many of the territory's flags a faction holds.
function TerritoryRules.flagsHeld(flagOwners: { number }, faction: number): number
	local count = 0
	for _, owner in flagOwners do
		if owner == faction and faction ~= 0 then
			count += 1
		end
	end
	return count
end

-- Did a faction just capture the territory? True when it now owns it and did not before.
function TerritoryRules.justCaptured(ownerBefore: number, ownerAfter: number): boolean
	return ownerAfter ~= 0 and ownerAfter ~= ownerBefore
end

return TerritoryRules
