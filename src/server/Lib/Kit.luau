--!strict
-- Building kit for the territory interiors. A Kit remembers a centre (x, z), a ground height and a folder, and every
-- position you give it is RELATIVE to that centre; `yb` is the height of the BOTTOM of the piece above the ground.
-- Everything is anchored. Solid by default; walls and props can be tagged "Cover" (bots hide behind them).
-- Stairs, spirals and ladders are DECORATION now: nobody has to climb them. Every one comes with a BUBBLE LIFT (Kit:lift):
-- step into the glowing bubbles and float up to the top (LiftSystem carries you; walk out at the top).

local CollectionService = game:GetService("CollectionService")

local Builder = require(script.Parent:WaitForChild("Builder"))
local Lifts = require(script.Parent:WaitForChild("Lifts"))

local Kit: any = {}
Kit.__index = Kit

export type Opts = { collide: boolean?, cover: boolean?, rotY: number?, transparency: number?, shape: Enum.PartType? }

function Kit.new(folder: Folder, cx: number, cz: number, groundY: number?)
	return setmetatable({ folder = folder, cx = cx, cz = cz, gy = groundY or 0 }, Kit)
end

-- World position of a relative one.
function Kit:at(x: number, yb: number, z: number): Vector3
	return Vector3.new(self.cx + x, self.gy + yb, self.cz + z)
end

local function finish(part: Part, color: Color3, material: Enum.Material?, opts: Opts?)
	part.Color = color
	if material then
		part.Material = material
	end
	local o = opts or {}
	part.CanCollide = o.collide ~= false
	if o.transparency then
		part.Transparency = o.transparency
	end
	if o.cover then
		CollectionService:AddTag(part, "Cover")
	end
end

function Kit:box(name: string, x: number, yb: number, z: number, sx: number, sy: number, sz: number, color: Color3, material: Enum.Material?, opts: Opts?): Part
	local position = Vector3.new(self.cx + x, self.gy + yb + sy / 2, self.cz + z)
	local part = Builder.part(name, Vector3.new(sx, sy, sz), position, color, self.folder)
	if opts and opts.rotY then
		part.CFrame = CFrame.new(position) * CFrame.Angles(0, opts.rotY, 0)
	end
	finish(part, color, material, opts)
	return part
end

-- An upright cylinder (diameter, height).
function Kit:cyl(name: string, x: number, yb: number, z: number, diameter: number, height: number, color: Color3, material: Enum.Material?, opts: Opts?): Part
	local part = Builder.cylinder(name, diameter, height, Vector3.new(self.cx + x, self.gy + yb + height / 2, self.cz + z), color, self.folder)
	finish(part, color, material, opts)
	return part
end

function Kit:ball(name: string, x: number, yb: number, z: number, sx: number, sy: number, sz: number, color: Color3, material: Enum.Material?, opts: Opts?): Part
	local part = Builder.ball(name, Vector3.new(sx, sy, sz), Vector3.new(self.cx + x, self.gy + yb + sy / 2, self.cz + z), color, self.folder)
	finish(part, color, material, opts)
	return part
end

-- A BUBBLE LIFT along `points` (world positions of the rider's feet; the first is the entrance). A faint glowing tube with
-- rising bubbles, a glowing pad at the entrance. `down` makes it a drop chute (bubbles fall). LiftSystem does the carrying.
function Kit:liftWorld(name: string, points: { Vector3 }, down: boolean?)
	Lifts.add(name, points, down)
	local colour = if down then Color3.fromRGB(150, 255, 170) else Color3.fromRGB(150, 225, 255)
	local pad = Builder.cylinder(name .. "Pad", 6, 0.4, points[1] + Vector3.new(0, 0.2, 0), colour, self.folder)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.45
	pad.CanCollide = false
	pad.CanQuery = false
	pad.CanTouch = false
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 14
	light.Parent = pad
	for index = 1, #points - 1 do
		local from, to = points[index] + Vector3.new(0, 3, 0), points[index + 1] + Vector3.new(0, 3, 0)
		local length = (to - from).Magnitude
		if length > 0.5 then
			local tube = Instance.new("Part")
			tube.Name = name .. "Bubbles"
			tube.Anchored = true
			tube.CanCollide = false
			tube.CanQuery = false
			tube.CanTouch = false
			tube.Material = Enum.Material.Neon
			tube.Color = colour
			tube.Transparency = 0.9
			tube.Size = Vector3.new(4.5, 4.5, length)
			tube.CFrame = CFrame.lookAt((from + to) / 2, to)
			tube.Parent = self.folder
			local emitter = Instance.new("ParticleEmitter")
			emitter.Shape = Enum.ParticleEmitterShape.Box
			emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut
			emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), colour)
			emitter.LightEmission = 0.8
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.1) })
			emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			emitter.Lifetime = NumberRange.new(1.2, 2)
			emitter.Speed = NumberRange.new(0, 0)
			emitter.Acceleration = (to - from).Unit * 14
			emitter.Rate = math.clamp(length * 1.2, 4, 60)
			emitter.Parent = tube
		end
	end
end

-- Same, with positions relative to the kit (`yb` is the height of the feet above the ground).
function Kit:lift(name: string, relative: { { number } }, down: boolean?)
	local points = {}
	for _, point in relative do
		table.insert(points, self:at(point[1], point[2], point[3]))
	end
	self:liftWorld(name, points, down)
end

-- A ladder: decoration only. A bubble lift goes up beside it to the top, then (optionally) out over a rim to
-- (exitX, exitZ) at `exitUp` studs above the top, so you can step off.
function Kit:truss(name: string, x: number, yb: number, z: number, height: number, exitX: number?, exitZ: number?, exitUp: number?)
	local truss = Instance.new("TrussPart")
	truss.Name = name
	truss.Size = Vector3.new(2, height, 2)
	truss.Position = Vector3.new(self.cx + x, self.gy + yb + height / 2, self.cz + z)
	truss.Anchored = true
	truss.CanCollide = false
	truss.Color = Color3.fromRGB(150, 110, 60)
	truss.Parent = self.folder
	local top = yb + height + (exitUp or 0)
	local points = { { x, yb, z }, { x, top, z } }
	if exitX and exitZ then
		table.insert(points, { exitX, top, exitZ })
	end
	self:lift(name .. "Lift", points)
	return truss
end

-- Straight stairs from (x0, z0) to (x1, z1), rising `rise` studs in steps no taller than 1.5. The steps are for
-- looks (CanCollide off); a bubble lift beside it is what carries you. `thin` treads leave the space
-- underneath open (doors, tunnels).
function Kit:stairs(name: string, x0: number, yb: number, z0: number, x1: number, z1: number, rise: number, width: number, color: Color3, material: Enum.Material?, thin: boolean?)
	local steps = math.max(1, math.ceil(rise / 1.0)) -- one-stud steps (never above 1.5)
	if rise / steps > 1.5 then
		warn(("[mog-wars] stairs %s: step %.2f studs is taller than 1.5"):format(name, rise / steps))
	end
	local dx, dz = x1 - x0, z1 - z0
	local length = math.sqrt(dx * dx + dz * dz)
	local run = length / steps
	local direction = Vector3.new(dx, 0, dz).Unit
	local stepHeight = rise / steps
	for index = 1, steps do
		local t = (index - 0.5) / steps
		local height = index * stepHeight
		local thickness = if thin then 0.8 else height
		local centreY = if thin then self.gy + yb + height - 0.4 else self.gy + yb + height / 2
		local centre = Vector3.new(self.cx + x0 + dx * t, centreY, self.cz + z0 + dz * t)
		local part = Builder.part(name, Vector3.new(width, thickness, run + 0.05), centre, color, self.folder)
		part.CFrame = CFrame.lookAt(centre, centre + direction)
		finish(part, color, material, { collide = false }) -- looks only; the ramp below is what you walk on
	end
	-- the ramp's surface runs through the middle of the step tops
	self:lift(name .. "Lift", { { x0, yb, z0 }, { x1, yb + rise, z1 } })
end

-- A spiral staircase of thin treads around (x, z), rising `rise` studs over `turns` turns, one-stud steps. Treads run
-- from rInner to rOuter. `direction` is 1 (counter-clockwise from above) or -1. The treads are for looks; an invisible
-- tilted ramp between each pair of treads is what you walk on.
function Kit:spiral(name: string, x: number, z: number, rInner: number, rOuter: number, yb: number, rise: number, turns: number, startAngle: number, direction: number, color: Color3, material: Enum.Material?)
	local steps = math.max(2, math.ceil(rise))
	if rise / steps > 1.5 then
		warn(("[mog-wars] spiral %s: step is taller than 1.5"):format(name))
	end
	local middle = (rInner + rOuter) / 2
	local angleStep = turns * 2 * math.pi / steps
	local path: { { number } } = {}
	for index = 0, steps do
		local angle = startAngle + direction * angleStep * index
		local height = yb + index * (rise / steps)
		local top = Vector3.new(self.cx + x + math.cos(angle) * middle, self.gy + height + 0.8, self.cz + z + math.sin(angle) * middle)
		if index < steps then
			local position = top - Vector3.new(0, 0.4, 0)
			local length = math.max(2.5, middle * angleStep * 1.6)
			local part = Builder.part(name, Vector3.new(rOuter - rInner, 0.8, length), position, color, self.folder)
			part.CFrame = CFrame.lookAt(position, position + Vector3.new(-math.sin(angle) * direction, 0, math.cos(angle) * direction))
			finish(part, color, material, { collide = false })
		end
		if index % math.max(1, math.floor(steps / (turns * 4))) == 0 or index == steps then
			table.insert(path, { x + math.cos(angle) * middle, height, z + math.sin(angle) * middle })
		end
	end
	table.insert(path, 1, { x + math.cos(startAngle) * middle, yb, z + math.sin(startAngle) * middle })
	self:lift(name .. "Lift", path)
end

-- A flat slab (floor or roof) with an optional rectangular hole in its middle (for stairs to come up through).
function Kit:slab(name: string, x: number, yb: number, z: number, w: number, d: number, thick: number, color: Color3, material: Enum.Material?, holeW: number?, holeD: number?)
	if not holeW or not holeD then
		return self:box(name, x, yb, z, w, thick, d, color, material)
	end
	local sideD = (d - holeD) / 2
	local sideW = (w - holeW) / 2
	self:box(name, x, yb, z - (holeD / 2 + sideD / 2), w, thick, sideD, color, material)
	self:box(name, x, yb, z + (holeD / 2 + sideD / 2), w, thick, sideD, color, material)
	self:box(name, x - (holeW / 2 + sideW / 2), yb, z, sideW, thick, holeD, color, material)
	self:box(name, x + (holeW / 2 + sideW / 2), yb, z, sideW, thick, holeD, color, material)
	return nil
end

-- One wall along X (alongX) or along Z, with door gaps centred in it. `door` is nil (a plain wall), true (one door),
-- a table { w = 7, h = 8, y = 0 } (y is how high the doorway starts), or a list of those (for example a ground door
-- and a high door for a corridor).
local function wall(kit: any, name: string, x: number, yb: number, z: number, length: number, height: number, thick: number, alongX: boolean, door: any, color: Color3, material: Enum.Material?)
	local function piece(offset: number, pieceLength: number, pieceBottom: number, pieceHeight: number)
		if pieceLength <= 0.05 or pieceHeight <= 0.05 then
			return
		end
		local sx, sz = if alongX then pieceLength else thick, if alongX then thick else pieceLength
		local px, pz = if alongX then x + offset else x, if alongX then z else z + offset
		kit:box(name, px, pieceBottom, pz, sx, pieceHeight, sz, color, material, { cover = true })
	end
	if not door then
		piece(0, length, yb, height)
		return
	end
	local doors: { any } = {}
	if door == true then
		doors = { {} }
	elseif door[1] ~= nil then
		doors = door
	else
		doors = { door }
	end
	local gaps: { { w: number, h: number, y: number } } = {}
	local widest = 0
	for _, entry in doors do
		local gap = { w = entry.w or 7, h = entry.h or 8, y = entry.y or 0 }
		widest = math.max(widest, gap.w)
		table.insert(gaps, gap)
	end
	table.sort(gaps, function(a, b)
		return a.y < b.y
	end)
	local side = (length - widest) / 2
	piece(-(widest / 2 + side / 2), side, yb, height)
	piece(widest / 2 + side / 2, side, yb, height)
	local cursor = 0 -- wall in the doorway column: the stretches between doorways
	for _, gap in gaps do
		if gap.y > cursor then
			piece(0, widest, yb + cursor, gap.y - cursor)
		end
		cursor = gap.y + gap.h
	end
	piece(0, widest, yb + cursor, height - cursor)
end

-- A room: four walls of `thick`, optional floor and roof, and door gaps. doors = { N = true, S = {w = 9, h = 9} ... }
-- (N is the -z wall, S the +z wall, W the -x wall, E the +x wall). Returns nothing; the room's floor top is at yb.
function Kit:room(name: string, x: number, yb: number, z: number, w: number, h: number, d: number, thick: number, color: Color3, material: Enum.Material?, doors: { [string]: any }?, floorColor: Color3?, withRoof: boolean?)
	local doorList = doors or {}
	wall(self, name .. "WallN", x, yb, z - d / 2 + thick / 2, w, h, thick, true, doorList.N, color, material)
	wall(self, name .. "WallS", x, yb, z + d / 2 - thick / 2, w, h, thick, true, doorList.S, color, material)
	wall(self, name .. "WallW", x - w / 2 + thick / 2, yb, z, d, h, thick, false, doorList.W, color, material)
	wall(self, name .. "WallE", x + w / 2 - thick / 2, yb, z, d, h, thick, false, doorList.E, color, material)
	if floorColor then
		self:box(name .. "Floor", x, yb - 1, z, w, 1, d, floorColor, material)
	end
	if withRoof then
		self:box(name .. "Roof", x, yb + h, z, w + thick, 1, d + thick, color, material)
	end
end

return Kit
