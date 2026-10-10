-- Doom Takeover demo: a marine with a shotgun in a world taken over by demons.
local function pack(kind, n, dist, spread, hold)
	local out = {}
	local base = Sigf.Front(dist)
	for i = 1, n do
		local p = Sigf.Ground(base + VectorRand() * 10, spread or 160)
		local e = Doom.MakeDemon(kind, p, hold)
		if IsValid(e) then
			e.SigfSide = "combine"
			out[#out + 1] = e
		end
	end
	return out
end

-- The best open stretch of lawn near the arena: long view ahead, room behind and on both sides.
local stage
local function pickStage()
	local function clear(from, dir, max)
		local tr = util.TraceLine({ start = from, endpos = from + dir * max, mask = MASK_SOLID_BRUSHONLY })
		return tr.Fraction * max
	end
	local best, bestScore = nil, -1
	for _ = 1, 60 do
		local c = Sigf.Ground(Sigf.Arena(), 1500)
		local from = c + Vector(0, 0, 50)
		for yaw = 0, 315, 45 do
			local f = Angle(0, yaw, 0)
			local score = math.min(clear(from, f:Forward(), 1400) / 1400, 1) + math.min(clear(from, -f:Forward(), 500) / 500, 1)
				+ math.min(clear(from, f:Right(), 400) / 400, 1) + math.min(clear(from, -f:Right(), 400) / 400, 1)
			if score > bestScore then best, bestScore = { pos = c, yaw = yaw }, score end
		end
	end
	return best
end

local function openSpot()
	local h = Sigf.Host()
	if not IsValid(h) then return end
	stage = stage or pickStage()
	Doom.CleanStage(stage.pos)
	Sigf.Teleport(h, stage.pos, Vector(0, 0, 0))
	h:SetEyeAngles(Angle(0, stage.yaw, 0))
end

local function resume(sec)
	Sigf.After(sec, function() Sigf.Give("weapon_shotgun") Sigf.Pilot(true) end)
end

local function caption(text, sec)
	Sigf.Text(text, sec or 4, { y = 0.17, size = 52 })
end

-- 1: title and a horde of imps and pinkies charges straight at the marine
Sigf.Demo(0.5, function()
	openSpot()
	Sigf.Pilot(false)
	net.Start("doom_title") net.Broadcast()
	Sigf.Give("weapon_shotgun")
	Sigf.Text("GARRY'S MOD x DOOM", 3, { y = 0.64, size = 56 })
	local base = Sigf.Front(330)
	for i = 1, 5 do
		local e = Doom.MakeDemon("imp", base + Vector(0, 0, 0) + Angle(0, Sigf.Host():EyeAngles().y + 90, 0):Forward() * (i * 70 - 210))
		if IsValid(e) then e.SigfSide = "combine" end
	end
	local p = Doom.MakeDemon("pinky", base + Angle(0, Sigf.Host():EyeAngles().y, 0):Forward() * 120)
	if IsValid(p) then p.SigfSide = "combine" end
	Sigf.After(1.5, function() Sigf.Pilot(true) end)
end)

-- 2: a giant cacodemon floats overhead
Sigf.Demo(5.5, function()
	caption("Hell gates open: a cacodemon floats in", 4)
	local cs = pack("caco", 1, 360, 10, 3)
	local c = cs[1]
	if IsValid(c) then
		c:SetPos(Sigf.Front(360) + Vector(0, 0, 110))
		c:SetAngles((Sigf.Host():GetPos() - c:GetPos()):Angle())
		Sigf.Sprite("sprites/light_glow02_add", c, 200, 3, { color = Color(255, 40, 20) })
		Sigf.LookAt(Vector(c:GetPos().x, c:GetPos().y, Sigf.Host():EyePos().z + 60), 3)
	end
end)

-- 3: BFG 9000 straight at the pack, caco included
Sigf.Demo(9.5, function()
	Sigf.Pilot(false)
	caption("BFG 9000: one ball zaps every demon in sight", 6)
	local h = Sigf.Host()
	h:Give("weapon_doom_bfg")
	h:SelectWeapon("weapon_doom_bfg")
	local imps = pack("imp", 5, 480, 150)
	pack("pinky", 2, 460, 150)
	Sigf.After(0.8, function()
		local t
		for _, e in ipairs(ents.GetAll()) do if e.DoomType == "caco" and e:Health() > 0 then t = e end end
		t = t or imps[1]
		if IsValid(t) then Sigf.LookAt(t, 2.5) end
		Sigf.After(0.3, function() Sigf.Shoot(0.3) end)
	end)
	resume(7)
end)

-- 2: explosive barrels next to a demon pack
Sigf.Demo(21, function()
	openSpot()
	Sigf.Pilot(false)
	caption("Shoot the explosive barrels")
	local base = Sigf.Front(450)
	local barrels = {}
	for i = 1, 3 do barrels[i] = Doom.SpawnBarrel(base + Vector(0, i * 45 - 90, 0)) end
	pack("imp", 3, 520, 60)
	pack("pinky", 1, 520, 60)
	Sigf.After(1.2, function()
		if IsValid(barrels[2]) then Sigf.LookAt(barrels[2], 3) Sigf.Shoot(2.5) end
	end)
	resume(6)
end)

-- 3: the real gravity gun punts a barrel into the demons
Sigf.Demo(33, function()
	openSpot()
	Sigf.Pilot(false)
	caption("Gravity gun: punt barrels at demons")
	Sigf.Give("weapon_physcannon")
	local h = Sigf.Host()
	local fwd = h:EyeAngles():Forward()
	fwd.z = 0
	fwd:Normalize()
	local b = Doom.SpawnBarrel(h:GetPos() + fwd * 110)
	local imps = pack("imp", 4, 650, 100)
	Sigf.After(1.2, function()
		if not IsValid(b) then return end
		local tgt = IsValid(imps[1]) and imps[1]:WorldSpaceCenter() or (b:GetPos() + fwd * 500)
		Sigf.LookAt(tgt, 2)
		b:SetPhysicsAttacker(h, 10)
		Sigf.After(0.5, function()
			if not IsValid(b) then return end
			local w = h:GetActiveWeapon()
			if IsValid(w) then w:EmitSound("weapons/physcannon/superphys_launch1.wav", 90) end
			Sigf.Effect("PhyscannonImpact", b:GetPos())
			local phys = b:GetPhysicsObject()
			if IsValid(phys) then phys:SetVelocity((tgt - b:GetPos()):GetNormalized() * 1500 + Vector(0, 0, 90)) end
		end)
	end)
	resume(6)
end)

-- 4: a cacodemon, the real 3D model, floats in
Sigf.Demo(45, function()
	openSpot()
	Sigf.Pilot(false)
	caption("Cacodemon: a floating 3D nightmare", 5)
	local cs = pack("caco", 1, 400, 10, 4.5)
	local c = cs[1]
	if IsValid(c) then
		c:SetPos(Sigf.Front(400) + Vector(0, 0, 75))
		c:SetAngles((Sigf.Host():GetPos() - c:GetPos()):Angle())
		Sigf.Sprite("sprites/light_glow02_add", c, 170, 3.5, { color = Color(255, 40, 20) })
		local flat = Vector(c:GetPos().x, c:GetPos().y, Sigf.Host():EyePos().z + 25)
		Sigf.LookAt(flat, 4.4)
		Sigf.After(4.6, function() if IsValid(c) then Sigf.LookAt(c, 3) Sigf.Shoot(3) end end)
	end
	resume(7)
end)

-- 5: finale, the baron of hell
Sigf.Demo(58, function()
	openSpot()
	Sigf.Pilot(true)
	Sigf.Give("weapon_shotgun")
	Sigf.Text("DOOM TAKEOVER", 5, { y = 0.17, size = 90, color = Color(255, 60, 30) })
	pack("baron", 1, 380, 100)
	pack("imp", 4, 360, 150)
	pack("pinky", 2, 380, 150)
end)
