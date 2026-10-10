-- Doom Takeover: demons pour out of hell gates and fight space marines in the arena.
Doom = Doom or {}
local Doom = Doom

util.AddNetworkString("doom_title")
util.AddNetworkString("doom_zap")


local GLOW = "sprites/light_glow02_add"
local FIRE = "sprites/flamelet1"

---------------------------------------------------------------- the battle becomes marines vs demons
Sigf.Battle.combine = 8
Sigf.Battle.rebels = 3
Sigf.Battle.bots = 3
Sigf.Battle.combineClass = "npc_zombie"
Sigf.Battle.combineWeapons = { "" }
Sigf.Battle.rebelWeapons = { "weapon_shotgun", "weapon_shotgun", "weapon_smg1" }

local TYPES = {
	imp = { class = "npc_zombie", mat = "sigf/imp", health = 70, scale = 1.4, name = "IMP", fire = { speed = 800, dmg = 14, color = Color(255, 120, 20), rate = 2.6 } },
	pinky = { class = "npc_antlion", mat = "sigf/pinky", health = 130, scale = 1.55, name = "PINKY" },
	baron = { class = "npc_zombie", mat = "sigf/baron", health = 380, scale = 2.1, name = "BARON OF HELL", fire = { speed = 700, dmg = 30, color = Color(80, 255, 80), rate = 3.2, size = 2 } },
	caco = { class = "npc_manhack", health = 170, name = "CACODEMON", fire = { speed = 650, dmg = 22, color = Color(110, 140, 255), rate = 3.0, size = 1.5 } },
}
Doom.Types = TYPES

local function isDemon(e) return IsValid(e) and e.DoomType ~= nil end

local function demonList()
	local out = {}
	for _, e in ipairs(ents.GetAll()) do
		if e.DoomType and e:Health() > 0 then out[#out + 1] = e end
	end
	return out
end

local function marineList()
	local out = {}
	for _, p in ipairs(Sigf.Players()) do out[#out + 1] = p end
	for _, e in ipairs(ents.FindByClass("npc_citizen")) do
		if e:Health() > 0 then out[#out + 1] = e end
	end
	return out
end

---------------------------------------------------------------- fireballs (imps, barons, cacodemons)
function Doom.Fireball(owner, from, dir, f)
	local ball = ents.Create("prop_physics")
	if not IsValid(ball) then return end
	ball:SetModel("models/hunter/misc/sphere025x025.mdl")
	ball:SetPos(from)
	ball:Spawn()
	ball:SetModelScale(f.size or 1, 0)
	ball:SetMaterial("models/debug/debugwhite")
	ball:SetColor(f.color)
	ball:SetCollisionGroup(COLLISION_GROUP_WORLD)
	ball.DoomFire = true
	local phys = ball:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableGravity(false)
		phys:EnableDrag(false)
		phys:SetVelocity(dir * f.speed)
	end
	ball:SetAngles(dir:Angle())
	local c = f.color
	local sid = Sigf.Sprite(GLOW, ball, 110 * (f.size or 1), 0, { color = Color(c.r, c.g, c.b, 255) })
	util.SpriteTrail(ball, 0, Color(c.r, c.g, c.b), true, 28 * (f.size or 1), 2, 0.6, 1 / 30, "trails/laser")
	if c.r > 200 then ball:Ignite(8) end
	ball:EmitSound("sigf/fireball.wav", 80, math.random(95, 110))
	ball.Born = CurTime()
	local last = from
	local name = "doom_fb" .. ball:EntIndex() .. "_" .. math.floor(CurTime() * 100)
	timer.Create(name, 0.03, 0, function()
		if not IsValid(ball) then timer.Remove(name) Sigf.Remove(sid) return end
		local pos = ball:GetPos()
		local tr = util.TraceHull({ start = last, endpos = pos, mins = Vector(-10, -10, -10), maxs = Vector(10, 10, 10), filter = { ball, owner }, mask = MASK_SHOT })
		local old = CurTime() - ball.Born > 5
		if tr.Hit or old or (IsValid(phys) and phys:GetVelocity():LengthSqr() < 40000) then
			timer.Remove(name)
			Sigf.Remove(sid)
			local hp = tr.Hit and tr.HitPos or pos
			Sigf.Effect("Explosion", hp, { magnitude = 0.6, scale = 0.6 })
			Sigf.Effect("cball_explode", hp)
			local atk = IsValid(owner) and owner or game.GetWorld()
			util.BlastDamage(ball, atk, hp, 120 * (f.size or 1), f.dmg)
			ball:Remove()
			return
		end
		last = pos
	end)
	return ball
end

local function aimAt(e, target)
	local from = e:WorldSpaceCenter() + e:GetForward() * 20
	local dir = (target:WorldSpaceCenter() - from)
	dir:Normalize()
	return from, dir
end

local function demonThink()
	local now = CurTime()
	for _, e in ipairs(demonList()) do
		local t = TYPES[e.DoomType]
		local en = e:GetEnemy()
		if t.fire and IsValid(en) and now >= (e.NextShot or 0) then
			local d = e:GetPos():Distance(en:GetPos())
			if d > 180 and d < 1200 then
				local tr = util.TraceLine({ start = e:WorldSpaceCenter(), endpos = en:WorldSpaceCenter(), filter = { e, en }, mask = MASK_SOLID_BRUSHONLY })
				if not tr.Hit then
					e.NextShot = now + t.fire.rate + math.Rand(0, 1.2)
					local from, dir = aimAt(e, en)
					Doom.Fireball(e, from, dir, t.fire)
				end
			end
		end
		if e.DoomType == "caco" then e:StopSound("npc/manhack/mh_engine_loop1.wav") e:StopSound("npc/manhack/mh_engine_loop2.wav") end
		if now >= (e.NextGrowl or 0) then
			e.NextGrowl = now + math.Rand(6, 12)
			if math.random() < 0.5 then e:EmitSound("sigf/growl.wav", 80, math.random(80, 125)) end
		end
	end
end

---------------------------------------------------------------- demon spawning
local function hellFlash(pos)
	Sigf.Effect("cball_explode", pos + Vector(0, 0, 30))
	Sigf.Sprite(GLOW, pos + Vector(0, 0, 50), 220, 1.2, { color = Color(255, 60, 20) })
	Sigf.Sprite(FIRE, pos + Vector(0, 0, 50), 140, 1.0, { color = Color(255, 160, 40) })
	sound.Play("ambient/fire/ignite.wav", pos, 80, 90, 1)
end

local function makeDemon(kind, pos, hold)
	local t = TYPES[kind]
	local e = Sigf.NPC(t.class, pos, { health = t.health, scale = t.scale })
	if not IsValid(e) then return end
	e.DoomType = kind
	e.Born = CurTime()
	if t.mat then e:SetMaterial(t.mat) end
	if kind == "caco" then
		-- an invisible, oversized manhack carries the 3D cacodemon: it flies, the model floats on it
		e:SetPos(pos + Vector(0, 0, 90))
		e:SetModelScale(3.4, 0)
		e:SetNoDraw(true)
		local v = ents.Create("prop_dynamic")
		v:SetModel("models/sigf/cacodemon.mdl")
		v:SetPos(e:GetPos())
		v:SetAngles(e:GetAngles())
		v:Spawn()
		v:SetModelScale(1.8, 0)
		v:SetParent(e)
		v:SetLocalPos(Vector(0, 0, 0))
		v:SetLocalAngles(Angle(0, 0, 0))
		e.DoomVisual = v
		e:SetMaxHealth(t.health)
		e:SetHealth(t.health)
		e:CallOnRemove("doom_vis", function() if IsValid(v) then v:Remove() end end)
	end
	e:SetKeyValue("spawnflags", "0")
	e:SetNWString("doom_name", t.name)
	hellFlash(pos)
	-- grand entrance: hovers untouchable for a moment so everyone can admire it
	if hold and hold > 0 then
		e.DoomHold = CurTime() + hold
		local mt = e:GetMoveType()
		e:SetMoveType(MOVETYPE_NONE)
		timer.Simple(hold, function() if IsValid(e) then e:SetMoveType(mt) end end)
	end
	return e
end
Doom.MakeDemon = makeDemon

local function spawnMarine(e)
	e:SetMaterial("sigf/marine")
	e:SetMaxHealth(100)
	e:SetHealth(100)
	e.DoomMarine = true
end

hook.Add("SigfBattleSpawn", "doom_spawn", function(npc, side)
	if side == "rebel" then spawnMarine(npc) return end
	-- the battle asks for a "combine": we send a demon of hell instead
	local pos = npc:GetPos()
	npc:Remove()
	local roll = math.random()
	local barons, cacos = 0, 0
	for _, d in ipairs(demonList()) do
		if d.DoomType == "baron" then barons = barons + 1 end
		if d.DoomType == "caco" then cacos = cacos + 1 end
	end
	local kind = "imp"
	if roll > 0.93 and barons < 1 then kind = "baron"
	elseif roll > 0.72 and cacos < 2 and util.IsValidModel("models/sigf/cacodemon.mdl") then kind = "caco"
	elseif roll > 0.5 then kind = "pinky" end
	local e = makeDemon(kind, pos)
	if IsValid(e) then
		e.SigfSide = "combine"
		hook.Run("DoomDemonSpawn", e, kind)
	end
end)

-- demons never fight each other and always hunt the marines
Sigf.Every(2, function()
	local demons, marines = demonList(), marineList()
	for _, d in ipairs(demons) do
		for _, o in ipairs(demons) do
			if o ~= d then d:AddEntityRelationship(o, D_LI, 99) end
		end
		for _, m in ipairs(marines) do d:AddEntityRelationship(m, D_HT, 99) end
	end
	for _, m in ipairs(marines) do
		if m:IsNPC() then
			for _, d in ipairs(demons) do m:AddEntityRelationship(d, D_HT, 99) end
		end
	end
end)

Sigf.Every(0.5, demonThink)
-- cacodemons drift slowly instead of zipping around like manhacks
Sigf.Every(0.05, function()
	for _, e in ipairs(ents.FindByClass("npc_manhack")) do
		if e.DoomType == "caco" then
			local v = e:GetVelocity()
			if v:Length() > 150 then e:SetLocalVelocity(v:GetNormalized() * 150) end
		end
	end
end)
Sigf.Every(1, function() SetGlobalInt("doom_demons", #demonList()) end)

-- headcrabs that jump out of dying zombies are not part of hell
hook.Add("OnEntityCreated", "doom_nocrab", function(e)
	if e:GetClass() == "npc_headcrab" or e:GetClass() == "npc_headcrab_fast" then
		timer.Simple(0, function()
			if IsValid(e) and not e.SigfSide and e:GetOwner() == NULL and Sigf.ModReady then e:Remove() end
		end)
	end
end)


---------------------------------------------------------------- BFG 9000: a green ball that zaps everything in sight
local function zap(a, b)
	net.Start("doom_zap")
	net.WriteVector(a)
	net.WriteVector(b)
	net.Broadcast()
end

function Doom.BFG(owner, from, dir)
	if IsValid(owner) then
		from = from or (owner:IsPlayer() and owner:GetShootPos() or owner:WorldSpaceCenter()) + (owner:GetAimVector() * 40)
		dir = dir or owner:GetAimVector()
		-- soft aim assist: lock on the demon closest to the crosshair
		local best, bestDot = nil, 0.8
		for _, d in ipairs(demonList()) do
			local to = (d:WorldSpaceCenter() - from):GetNormalized()
			local dot = to:Dot(dir)
			if dot > bestDot then best, bestDot = d, dot end
		end
		if best then dir = (best:WorldSpaceCenter() - from):GetNormalized() end
		if dir.z < -0.12 then dir.z = -0.12 dir:Normalize() end
	end
	local ball = ents.Create("prop_physics")
	if not IsValid(ball) then return end
	ball:SetModel("models/hunter/misc/sphere075x075.mdl")
	ball:SetPos(from)
	ball:Spawn()
	ball:SetModelScale(2.6, 0)
	ball:SetMaterial("models/debug/debugwhite")
	ball:SetColor(Color(90, 255, 90))
	ball:SetCollisionGroup(COLLISION_GROUP_WORLD)
	ball.DoomFire = true
	local phys = ball:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableGravity(false)
		phys:EnableDrag(false)
		phys:SetVelocity(dir * 520)
	end
	local sid = Sigf.Sprite(GLOW, ball, 650, 0, { color = Color(80, 255, 80) })
	Sigf.Overlay("sigf/flash_green", 0.7, 70)
	util.SpriteTrail(ball, 0, Color(80, 255, 80), true, 60, 6, 1.0, 1 / 30, "trails/laser")
	ball:EmitSound("ambient/energy/zap9.wav", 95, 70)
	local born = CurTime()
	local last = from
	local name = "doom_bfg" .. ball:EntIndex() .. "_" .. math.floor(CurTime() * 100)
	local zapped = {}
	timer.Create(name, 0.12, 0, function()
		if not IsValid(ball) then timer.Remove(name) Sigf.Remove(sid) return end
		local pos = ball:GetPos()
		for _, e in ipairs(ents.FindInSphere(pos, 1600)) do
			if (e.DoomType or (e:IsNPC() and e:Disposition(IsValid(owner) and owner or e) == D_HT)) and e:Health() > 0 then
				local c = e:WorldSpaceCenter()
				local tr = util.TraceLine({ start = pos, endpos = c, filter = { ball, e }, mask = MASK_SOLID_BRUSHONLY })
				if not tr.Hit and (zapped[e] or 0) < CurTime() then
					zapped[e] = CurTime() + 0.35
					zap(pos, c)
					local d = DamageInfo()
					d:SetDamage(45)
					d:SetAttacker(IsValid(owner) and owner or game.GetWorld())
					d:SetInflictor(IsValid(owner) and owner or game.GetWorld())
					d:SetDamageType(DMG_SHOCK)
					d:SetDamagePosition(c)
					d:SetDamageForce((c - pos):GetNormalized() * 4000)
					e:TakeDamageInfo(d)
				end
			end
		end
		local tr = util.TraceHull({ start = last, endpos = pos, mins = Vector(-14, -14, -14), maxs = Vector(14, 14, 14), filter = { ball, owner }, mask = MASK_SHOT })
		if tr.Hit or CurTime() - born > 5 then
			timer.Remove(name)
			Sigf.Remove(sid)
			local hp = tr.Hit and tr.HitPos or pos
			Sigf.Effect("HelicopterMegaBomb", hp)
			Sigf.Effect("cball_explode", hp, { scale = 3 })
			Sigf.Overlay("sigf/flash_green", 0.5, 90)
			Sigf.Shake(hp, 14, 1.2)
			util.BlastDamage(ball, IsValid(owner) and owner or game.GetWorld(), hp, 500, 220)
			sound.Play("ambient/explosions/explode_4.wav", hp, 100, 90, 1)
			ball:Remove()
			return
		end
		last = pos
	end)
	return ball
end

---------------------------------------------------------------- hits show: blood, flash, knockback, sound
local function flash(e)
	if not IsValid(e) then return end
	if IsValid(e.DoomVisual) then e = e.DoomVisual end
	e:SetColor(Color(255, 70, 70))
	timer.Simple(0.12, function() if IsValid(e) then e:SetColor(color_white) end end)
end

hook.Add("EntityTakeDamage", "doom_dmg", function(target, dmg)
	local atk = dmg:GetAttacker()
	-- hell does not burn itself: fireballs, barrels and fire only hurt the other side
	if target.DoomHold and CurTime() < target.DoomHold then return true end
	if isDemon(target) then
		if isDemon(atk) or (IsValid(dmg:GetInflictor()) and dmg:GetInflictor().DoomFire and isDemon(atk)) then
			return true
		end
		if dmg:IsDamageType(DMG_BURN) and not (IsValid(atk) and atk:IsPlayer()) then dmg:ScaleDamage(0.15) end
		local pos = dmg:GetDamagePosition()
		if pos == vector_origin then pos = target:WorldSpaceCenter() end
		Sigf.Effect("BloodImpact", pos, { color = 0, scale = 1 })
		flash(target)
		if (target.NextPain or 0) < CurTime() then
			target.NextPain = CurTime() + 0.35
			target:EmitSound("sigf/growl.wav", 75, math.random(110, 150))
			local push = dmg:GetDamageForce()
			if push:LengthSqr() > 0 and not target:IsFlagSet(FL_FLY) then
				push:Normalize()
				target:SetVelocity(push * 140 + Vector(0, 0, 60))
			end
		end
	elseif target.DoomMarine then
		if isDemon(atk) or (IsValid(dmg:GetInflictor()) and dmg:GetInflictor().DoomFire) then
			dmg:ScaleDamage(1.2)
		end
		Sigf.Effect("BloodImpact", target:WorldSpaceCenter(), { color = 0 })
	end
end)

---------------------------------------------------------------- death: gibs and counters
local GIBS = { "models/gibs/hgibs.mdl", "models/gibs/hgibs_rib.mdl", "models/gibs/hgibs_scapula.mdl", "models/gibs/hgibs_spine.mdl", "models/gibs/antlion_gib_small_1.mdl", "models/gibs/antlion_gib_small_2.mdl" }

local kills, lastKill, streak = 0, 0, 0
local STREAK = { [2] = "DOUBLE KILL", [4] = "MULTI KILL", [6] = "MEGA KILL", [9] = "ULTRA KILL", [12] = "MASSACRE", [16] = "HELLSLAYER" }

function Doom.Gib(npc)
	local c = npc:WorldSpaceCenter()
	Sigf.Effect("BloodImpact", c, { color = 0, scale = 3 })
	Sigf.Effect("AntlionGib", c, { scale = 2 })
	for i = 1, 6 do
		local g = ents.Create("prop_physics")
		if IsValid(g) then
			g:SetModel(GIBS[math.random(#GIBS)])
			g:SetPos(c + VectorRand() * 12)
			g:Spawn()
			g:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			local p = g:GetPhysicsObject()
			if IsValid(p) then p:SetVelocity(VectorRand() * 280 + Vector(0, 0, 260)) end
			SafeRemoveEntityDelayed(g, 7)
			util.Decal("Blood", c, c - Vector(0, 0, 60), g)
		end
	end
	sound.Play("sigf/death.wav", c, 85, math.random(95, 115), 1)
end

hook.Add("CreateEntityRagdoll", "doom_gib", function(owner, rag)
	if IsValid(owner) and owner.DoomGibbed then rag:Remove() return end
	if IsValid(owner) and owner.DoomType then rag:SetColor(color_white) end
end)

hook.Add("OnNPCKilled", "doom_kill", function(npc, attacker, inflictor)
	if not npc.DoomType or npc.DoomDead then return end
	npc.DoomDead = true
	npc:SetColor(color_white)
	if IsValid(npc.DoomVisual) then npc.DoomVisual:SetColor(color_white) end
	if math.random() < 0.65 or (IsValid(inflictor) and inflictor.DoomFire == nil and IsValid(attacker) and attacker:IsPlayer() and attacker:GetActiveWeapon():IsValid() and attacker:GetActiveWeapon():GetClass() == "weapon_shotgun") then
		npc.DoomGibbed = true
		Doom.Gib(npc)
	else
		npc:EmitSound("sigf/death.wav", 80, math.random(95, 110))
	end
	if npc.DoomType == "caco" then Sigf.Explode(npc:WorldSpaceCenter(), 150, 25, attacker) end
	kills = kills + 1
	SetGlobalInt("doom_kills", kills)
	SetGlobalFloat("doom_lastkill", CurTime())
	if CurTime() - lastKill < 4 then streak = streak + 1 else streak = 1 end
	lastKill = CurTime()
	if STREAK[streak] then Sigf.Text(STREAK[streak], 1.2, { y = 0.3, size = 90, color = Color(255, 60, 30) }) end
	if npc.DoomType == "baron" then Sigf.Text("BARON OF HELL SLAIN", 2, { y = 0.3, size = 70, color = Color(80, 255, 80) }) end
end)

hook.Add("PlayerHurt", "doom_hurt", function(ply)
	ply:SetNWFloat("doom_hurt", CurTime())
end)

---------------------------------------------------------------- explosive barrels everywhere
local barrels = {}
local function spawnBarrel(pos)
	local b = ents.Create("prop_physics")
	if not IsValid(b) then return end
	b:SetModel("models/props_c17/oildrum001_explosive.mdl")
	b:SetPos(pos + Vector(0, 0, 30))
	b:SetAngles(Angle(0, math.random(0, 359), 0))
	b:Spawn()
	b:Activate()
	b:SetColor(Color(130, 255, 90))
	b.DoomBarrel = true
	barrels[#barrels + 1] = b
	return b
end
Doom.SpawnBarrel = spawnBarrel

local function barrelTick()
	local alive = 0
	for i = #barrels, 1, -1 do
		if IsValid(barrels[i]) then alive = alive + 1 else table.remove(barrels, i) end
	end
	for _ = 1, math.min(3, 12 - alive) do
		spawnBarrel(Sigf.Ground(Sigf.Arena(), 1100))
	end
end
Sigf.Every(6, barrelTick)
Sigf.After(1, barrelTick)

hook.Add("PropBreak", "doom_barrel", function(att, prop)
	if prop.DoomBarrel then
		Sigf.Effect("HelicopterMegaBomb", prop:GetPos())
		Sigf.Shake(prop:GetPos(), 10, 0.8)
	end
end)

---------------------------------------------------------------- soulsphere: blue health orb
local orbs = {}
local function spawnOrb(pos)
	local o = ents.Create("prop_dynamic")
	if not IsValid(o) then return end
	o:SetModel("models/hunter/misc/sphere025x025.mdl")
	o:SetPos(pos + Vector(0, 0, 40))
	o:Spawn()
	o:SetModelScale(1.4, 0)
	o:SetMaterial("models/debug/debugwhite")
	o:SetColor(Color(60, 120, 255))
	o.SpriteId = Sigf.Sprite(GLOW, o, 90, 0, { color = Color(80, 140, 255) })
	o.Born = CurTime()
	orbs[#orbs + 1] = o
	SafeRemoveEntityDelayed(o, 45)
end

local function orbTick()
	for i = #orbs, 1, -1 do
		local o = orbs[i]
		if not IsValid(o) then table.remove(orbs, i) else
			o:SetPos(o:GetPos() + Vector(0, 0, math.sin(CurTime() * 3) * 0.4))
			for _, a in ipairs(Sigf.Near(o:GetPos(), 70, function(e) return e:IsPlayer() or e.DoomMarine end)) do
				local hp = a:Health()
				a:SetHealth(math.min(a:GetMaxHealth() + 100, hp + 100))
				a:EmitSound("items/smallmedkit1.wav", 80, 120)
				Sigf.Effect("balloon_pop", o:GetPos(), { color = 3 })
				Sigf.Text("SUPERCHARGE!", 1.5, { y = 0.45, size = 60, color = Color(100, 160, 255) })
				Sigf.Remove(o.SpriteId)
				o:Remove()
				table.remove(orbs, i)
				break
			end
		end
	end
end
Sigf.Every(0.1, orbTick)
Sigf.Every(18, function()
	if #orbs < 2 then spawnOrb(Sigf.Ground(Sigf.Arena(), 900)) end
end)
Doom.SpawnOrb = spawnOrb

---------------------------------------------------------------- marines look like the Doom guy
local function dress(p)
	timer.Simple(0.3, function()
		if not IsValid(p) then return end
		p:SetModel("models/player/combine_soldier.mdl")
		p:SetMaterial("sigf/marine")
		p:StripWeapons()
		p:Give("weapon_shotgun")
		p:Give("weapon_rpg")
		p:GiveAmmo(120, "Buckshot", true)
		p:GiveAmmo(20, "RPG_Round", true)
		p:SelectWeapon("weapon_shotgun")
	end)
end
hook.Add("PlayerSpawn", "doom_dress", dress)
Sigf.Every(10, function()
	for _, p in ipairs(Sigf.Players()) do
		if p:GetMaterial() ~= "sigf/marine" or p:GetModel() ~= "models/player/combine_soldier.mdl" then dress(p) end
		p:GiveAmmo(30, "Buckshot", true)
	end
end)

---------------------------------------------------------------- Doom shotgun: more pellets, big boom
hook.Add("EntityFireBullets", "doom_ssg", function(ent, data)
	if not (ent:IsPlayer() or ent:IsNPC()) then return end
	local w = ent:IsPlayer() and ent:GetActiveWeapon() or ent:GetActiveWeapon()
	if IsValid(w) and w:GetClass() == "weapon_shotgun" then
		data.Num = 12
		data.Damage = 11
		data.Spread = Vector(0.07, 0.04, 0)
		data.Force = 12
		data.Tracer = 1
		ent:EmitSound("sigf/ssg.wav", 90, math.random(96, 106))
		return true
	end
end)

Sigf.ModReady = false
Sigf.After(3, function() Sigf.ModReady = true end)

-- Title at the start: the cl side draws the logo; the server plays the red flash.
Sigf.After(2, function()
	net.Start("doom_title") net.Broadcast()
end)


-- Fresh arena for a staged moment: clears fire, barrels, demons and gibs around a point.
function Doom.CleanStage(pos, radius)
	for _, e in ipairs(ents.FindInSphere(pos, radius or 2200)) do
		local c = e:GetClass()
		if c == "entityflame" or c == "env_fire" or e.DoomBarrel or e.DoomType or e.DoomFire then
			e:Remove()
		elseif c == "prop_physics" and e:GetCollisionGroup() == COLLISION_GROUP_DEBRIS then
			e:Remove()
		end
	end
end

hook.Add("OnAchievementAchieved", "doom_noach", function() return true end)
