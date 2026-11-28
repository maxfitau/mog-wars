--!strict
-- The list of BUBBLE LIFTS in the map. Places build them through Kit (Kit:lift, and the stairs / spirals / ladders, which
-- are now decorative and each come with a lift); LiftSystem reads this list and does the carrying. Points are world
-- positions of the rider's FEET along the path.

export type Lift = { name: string, points: { Vector3 }, down: boolean }

local Lifts = {}

Lifts.list = {} :: { Lift }

function Lifts.add(name: string, points: { Vector3 }, down: boolean?)
	table.insert(Lifts.list, { name = name, points = points, down = down == true })
end

return Lifts
