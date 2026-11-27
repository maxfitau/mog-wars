--!strict
-- Building kit for the territory interiors. A Kit remembers a centre (x, z), a ground height and a folder, and every
-- position you give it is RELATIVE to that centre; `yb` is the height of the BOTTOM of the piece above the ground.
-- Everything is anchored. Solid by default; walls and props can be tagged "Cover" (bots hide behind them).
-- Stairs, spirals and rooms are what make interiors: nothing here makes a ramp.

local CollectionService = game:GetService("CollectionService")

local Builder = require(script.Parent:WaitForChild("Builder"))

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

-- A climbable ladder.
function Kit:truss(name: string, x: number, yb: number, z: number, height: number)
	local truss = Instance.new("TrussPart")
	truss.Name = name
	truss.Size = Vector3.new(2, height, 2)
	truss.Position = Vector3.new(self.cx + x, self.gy + yb + height / 2, self.cz + z)
	truss.Anchored = true
	truss.Color = Color3.fromRGB(150, 110, 60)
	truss.Parent = self.folder
	return truss
end

-- Straight solid stairs from (x0, z0) to (x1, z1), rising `rise` studs (one-stud steps).
function Kit:stairs(name: string, x0: number, yb: number, z0: number, x1: number, z1: number, rise: number, width: number, color: Color3, material: Enum.Material?, thin: boolean?)
	local steps = math.max(1, math.floor(rise))
	local dx, dz = x1 - x0, z1 - z0
	local length = math.sqrt(dx * dx + dz * dz)
	local run = length / steps
	local direction = Vector3.new(dx, 0, dz).Unit
	for index = 1, steps do
		local t = (index - 0.5) / steps
		local height = index * (rise / steps)
		local centre = Vector3.new(self.cx + x0 + dx * t, self.gy + yb + height / 2, self.cz + z0 + dz * t)
		local thickness = if thin then 0.8 else height -- thin treads leave the space underneath open (doors, tunnels)
		if thin then
			centre = Vector3.new(centre.X, self.gy + yb + height - 0.4, centre.Z)
		end
		local part = Builder.part(name, Vector3.new(width, thickness, run + 0.05), centre, color, self.folder)
		part.CFrame = CFrame.lookAt(centre, centre + direction)
		finish(part, color, material, nil)
	end
end

-- A spiral staircase of thin treads around (x, z), rising `rise` studs over `turns` turns. Treads run from rInner
-- to rOuter. `direction` is 1 (counter-clockwise from above) or -1.
function Kit:spiral(name: string, x: number, z: number, rInner: number, rOuter: number, yb: number, rise: number, turns: number, startAngle: number, direction: number, color: Color3, material: Enum.Material?)
	local steps = math.max(2, math.floor(rise))
	local middle = (rInner + rOuter) / 2
	local angleStep = turns * 2 * math.pi / steps
	for index = 0, steps - 1 do
		local angle = startAngle + direction * angleStep * index
		local height = yb + index * (rise / steps) + 0.4
		local position = Vector3.new(self.cx + x + math.cos(angle) * middle, self.gy + height, self.cz + z + math.sin(angle) * middle)
		local length = math.max(2.5, middle * angleStep * 1.6)
		local part = Builder.part(name, Vector3.new(rOuter - rInner, 0.8, length), position, color, self.folder)
		part.CFrame = CFrame.lookAt(position, position + Vector3.new(-math.sin(angle) * direction, 0, math.cos(angle) * direction))
		finish(part, color, material, nil)
	end
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
