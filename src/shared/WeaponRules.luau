--!strict
-- Pure weapon rules (no Roblox calls): every number a weapon uses at a star level, plus the geometry tests the server runs.
-- WeaponCatalog holds the base numbers (params); stars scale them by at most +20 percent (same curve as
-- WeaponCatalog.starScale). The server decides everything; the client only draws. Rarity never changes power.

local WeaponRules = {}

WeaponRules.MAX_STUDS = 60 -- no knockback is ever bigger than this
WeaponRules.MIN_REQUEST_INTERVAL = 0.25 -- seconds: faster requests are ignored, whatever their result
WeaponRules.COOLDOWN_SLACK = 0.15 -- a request this much early still counts (network jitter)
WeaponRules.BOOMERANG_SPEED = 46 -- studs per second, out and back
WeaponRules.BOOMERANG_HIT_RADIUS = 4
WeaponRules.ROSE_SPEED = 70 -- studs per second for the thrown rose
WeaponRules.ROSE_ANGLE = 24 -- degrees: how wide an aim the rose forgives
WeaponRules.HAMMER_ANGLE = 140
WeaponRules.GAUNTLET_ANGLE = 100
WeaponRules.MIST_DRIFT = 12 -- studs per second a slipper slides outward

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end
WeaponRules.finite = finite

-- Same curve as WeaponCatalog.starScale: 1.00 at one star up to 1.20 at five.
function WeaponRules.scale(stars: number): number
	if not finite(stars) then
		return 1
	end
	return 1 + 0.05 * (math.clamp(math.floor(stars), 1, 5) - 1)
end

-- ---------- request checks ----------

-- True when a request arrives too soon after the previous one (spam guard).
function WeaponRules.tooFast(now: number, lastRequest: number): boolean
	return now - lastRequest < WeaponRules.MIN_REQUEST_INTERVAL
end

function WeaponRules.cooldownReady(now: number, lastUse: number, cooldown: number): boolean
	return now - lastUse >= cooldown - WeaponRules.COOLDOWN_SLACK
end

-- A client aim vector (x, y, z) must be finite and roughly unit length. Returns the flat (x, z) direction, normalised, or nil.
function WeaponRules.cleanAim(x: number, y: number, z: number): (number?, number?)
	if not (finite(x) and finite(y) and finite(z)) then
		return nil, nil
	end
	local length = math.sqrt(x * x + y * y + z * z)
	if length < 0.9 or length > 1.1 then
		return nil, nil
	end
	local flat = math.sqrt(x * x + z * z)
	if flat < 0.05 then
		return nil, nil -- looking straight up or down: no usable direction
	end
	return x / flat, z / flat
end

-- A client charge time in seconds: nil when it is not a finite number from 0 up to 10. Otherwise clamped to the weapon's charge
-- (plus a little slack for latency).
function WeaponRules.cleanCharge(charge: number, maxCharge: number): number?
	if not finite(charge) or charge < 0 or charge > 10 then
		return nil
	end
	return math.min(charge, maxCharge + 0.25)
end

-- ---------- geometry ----------

-- Flat distance and unit direction from (ox, oz) to (tx, tz): returns dx, dz, distance. Direction is (0, 0) when on top of each other.
function WeaponRules.flat(ox: number, oz: number, tx: number, tz: number): (number, number, number)
	local dx, dz = tx - ox, tz - oz
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < 0.001 then
		return 0, 0, 0
	end
	return dx / distance, dz / distance, distance
end

-- Is the point inside a cone? The cone starts at (ox, oz), looks along the unit direction (ax, az), reaches `range` studs and is
-- `angleDeg` wide in total. Returns the distance, or nil if outside. A point on top of the origin counts as inside.
function WeaponRules.inCone(ox: number, oz: number, ax: number, az: number, tx: number, tz: number, range: number, angleDeg: number): number?
	local dx, dz, distance = WeaponRules.flat(ox, oz, tx, tz)
	if distance > range then
		return nil
	end
	if distance < 0.001 then
		return 0
	end
	local cosHalf = math.cos(math.rad(math.clamp(angleDeg, 0, 360) / 2))
	if dx * ax + dz * az >= cosHalf then
		return distance
	end
	return nil
end

export type Point = { x: number, z: number }

-- The index of the nearest point inside the cone (or inside the plain circle when there is no aim). Nil if none.
function WeaponRules.pickNearest(ox: number, oz: number, ax: number?, az: number?, angleDeg: number, range: number, points: { Point }): number?
	local best: number? = nil
	local bestDistance = math.huge
	for index, point in points do
		local distance: number? = nil
		if ax and az then
			distance = WeaponRules.inCone(ox, oz, ax, az, point.x, point.z, range, angleDeg)
		else
			local _, _, flatDistance = WeaponRules.flat(ox, oz, point.x, point.z)
			if flatDistance <= range then
				distance = flatDistance
			end
		end
		if distance and distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

function WeaponRules.inCircle(cx: number, cz: number, x: number, z: number, radius: number): boolean
	local dx, dz = x - cx, z - cz
	return dx * dx + dz * dz <= radius * radius
end

function WeaponRules.clampStuds(studs: number): number
	if not finite(studs) then
		return 0
	end
	return math.clamp(studs, 0, WeaponRules.MAX_STUDS)
end

-- ---------- per weapon numbers (params from WeaponCatalog, stars 1 to 5) ----------

-- Jawline Hammer: reach and knockback (2x the plain shove distance).
function WeaponRules.hammerReach(params: { [string]: number }, stars: number): number
	return params.range * WeaponRules.scale(stars)
end

function WeaponRules.hammerKnock(params: { [string]: number }, stars: number, shoveStuds: number): number
	return WeaponRules.clampStuds(shoveStuds * params.knock * WeaponRules.scale(stars))
end

-- Mewing Fan: the gust cone (reach, total angle in degrees) and the push.
function WeaponRules.gustReach(params: { [string]: number }, stars: number): number
	return params.range * WeaponRules.scale(stars)
end

function WeaponRules.gustAngle(params: { [string]: number }): number
	return params.angle
end

function WeaponRules.gustKnock(params: { [string]: number }, stars: number, shoveStuds: number): number
	return WeaponRules.clampStuds(shoveStuds * params.knock * WeaponRules.scale(stars))
end

-- Sigma Shades: how far out the boomerang flies and how long the whole trip takes.
function WeaponRules.boomerangRange(params: { [string]: number }, stars: number): number
	return params.range * WeaponRules.scale(stars)
end

function WeaponRules.boomerangDuration(range: number): number
	return 2 * range / WeaponRules.BOOMERANG_SPEED
end

-- Where the boomerang is at time t of a trip lasting `duration`: leg 1 (going out) or leg 2 (coming back), and how far along that
-- leg it is (0 to 1). It only hits on leg 2. After the trip it is "done" (leg 3).
function WeaponRules.boomerangState(t: number, duration: number): (number, number)
	if duration <= 0 or t >= duration then
		return 3, 1
	end
	local half = duration / 2
	if t < half then
		return 1, math.max(0, t) / half
	end
	return 2, (t - half) / half
end

-- Distance from the thrower along the aim line while going out (it eases out) for a leg-1 fraction.
function WeaponRules.boomerangOut(range: number, fraction: number): number
	local f = math.clamp(fraction, 0, 1)
	return range * (1 - (1 - f) * (1 - f))
end

function WeaponRules.boomerangKnock(params: { [string]: number }, stars: number, shoveStuds: number): number
	return WeaponRules.clampStuds(shoveStuds * params.knock * WeaponRules.scale(stars))
end

-- Rizz Rose: throw range and how long the target walks toward you.
function WeaponRules.roseRange(params: { [string]: number }, stars: number): number
	return params.range * WeaponRules.scale(stars)
end

function WeaponRules.roseSeconds(params: { [string]: number }, stars: number): number
	return params.seconds * WeaponRules.scale(stars)
end

-- The pull stops once the target is this close to you (studs).
function WeaponRules.rosePullStop(): number
	return 3
end

-- Glow-Up Mist: where the puddle lands (up to `range` ahead), its radius and how long it lasts.
function WeaponRules.mistCentre(params: { [string]: number }, stars: number, ox: number, oz: number, ax: number, az: number): (number, number)
	local reach = params.range * WeaponRules.scale(stars)
	return ox + ax * reach, oz + az * reach
end

function WeaponRules.mistRadius(params: { [string]: number }, stars: number): number
	return params.radius * WeaponRules.scale(stars)
end

function WeaponRules.mistSeconds(params: { [string]: number }): number
	return params.seconds
end

-- Slide direction for someone standing in the puddle: straight out from the centre (+x at the exact centre).
function WeaponRules.mistDrift(cx: number, cz: number, x: number, z: number): (number, number)
	local dx, dz, distance = WeaponRules.flat(cx, cz, x, z)
	if distance < 0.001 then
		return 1, 0
	end
	return dx, dz
end

-- Mirror Shield: how long shoves bounce back.
function WeaponRules.reflectSeconds(params: { [string]: number }, stars: number): number
	return params.seconds * WeaponRules.scale(stars)
end

function WeaponRules.reflecting(now: number, reflectUntil: any): boolean
	return type(reflectUntil) == "number" and reflectUntil > now
end

-- Protein Shaker: shockwave radius, push, and the self speed boost (a share, 0.4 = +40 percent) with its length.
function WeaponRules.shakerRadius(params: { [string]: number }, stars: number): number
	return params.radius * WeaponRules.scale(stars)
end

function WeaponRules.shakerKnock(params: { [string]: number }, stars: number, shoveStuds: number): number
	return WeaponRules.clampStuds(shoveStuds * params.knock * WeaponRules.scale(stars))
end

function WeaponRules.shakerBoost(params: { [string]: number }, stars: number): number
	return params.boost * WeaponRules.scale(stars)
end

function WeaponRules.shakerSeconds(params: { [string]: number }): number
	return params.seconds
end

-- Main Character Mic: freeze radius and how long they stare.
function WeaponRules.micRadius(params: { [string]: number }, stars: number): number
	return params.radius * WeaponRules.scale(stars)
end

function WeaponRules.micSeconds(params: { [string]: number }, stars: number): number
	return params.seconds * WeaponRules.scale(stars)
end

-- Gigachad Gauntlet: how full the charge is (0 to 1) and the punch it throws. An instant tap is half power; a full charge is full.
function WeaponRules.chargeFraction(charge: number, params: { [string]: number }): number
	if not finite(charge) or params.charge <= 0 then
		return 1
	end
	return math.clamp(charge / params.charge, 0, 1)
end

function WeaponRules.gauntletReach(params: { [string]: number }, stars: number): number
	return params.range * WeaponRules.scale(stars)
end

function WeaponRules.gauntletKnock(params: { [string]: number }, stars: number, shoveStuds: number, fraction: number): number
	local power = 0.5 + 0.5 * math.clamp(fraction, 0, 1)
	return WeaponRules.clampStuds(shoveStuds * params.knock * WeaponRules.scale(stars) * power)
end

-- ---------- looks (never power) ----------

-- Sound key by rarity: common plain, rare and epic "weapon_rare", legendary and mythic "weapon_legendary".
function WeaponRules.soundKey(rarity: string): string
	if rarity == "legendary" or rarity == "mythic" then
		return "weapon_legendary"
	elseif rarity == "rare" or rarity == "epic" then
		return "weapon_rare"
	end
	return "weapon_swing"
end

-- Visual tier 1 (plain), 2 (rare, epic: sparkles) or 3 (legendary, mythic: sparkles and glow).
function WeaponRules.visualTier(rarity: string): number
	if rarity == "legendary" or rarity == "mythic" then
		return 3
	elseif rarity == "rare" or rarity == "epic" then
		return 2
	end
	return 1
end

function WeaponRules.glowSkin(stars: number): boolean
	return finite(stars) and stars >= 5
end

-- ---------- Moglings ----------

-- When a Mogling may use its weapon again: its cooldown times 2 to 4, so it is now and then, never constant.
function WeaponRules.moglingNextUse(now: number, cooldown: number, random: number): number
	return now + cooldown * (2 + 2 * math.clamp(random, 0, 1))
end

return WeaponRules
