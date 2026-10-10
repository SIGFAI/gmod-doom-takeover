-- Doom Takeover, client: retro low-res look, hell fog, status bar with the marine's face, title logo, music.
local function sw(v) return v * ScrH() / 1080 end

surface.CreateFont("DoomBig", { font = "Impact", size = 84, weight = 700, antialias = false })
surface.CreateFont("DoomSmall", { font = "Impact", size = 26, weight = 500, antialias = false })

local mats = {
	face_ok = Material("sigf/face_ok"),
	face_hurt = Material("sigf/face_hurt"),
	face_grin = Material("sigf/face_grin"),
	logo = Material("sigf/logo"),
}

---------------------------------------------------------------- retro look: render small, scale up with hard pixels
local rt = GetRenderTarget("doom_lowres_" .. 480, 480, 270)
local scr = CreateMaterial("doom_scr_mat", "UnlitGeneric", { ["$basetexture"] = "_rt_FullFrameFB", ["$ignorez"] = 1, ["$vertexcolor"] = 1 })
local low = CreateMaterial("doom_low_mat", "UnlitGeneric", { ["$basetexture"] = rt:GetName(), ["$ignorez"] = 1, ["$vertexcolor"] = 1 })

hook.Add("RenderScreenspaceEffects", "doom_retro", function()
	DrawColorModify({
		["$pp_colour_addr"] = 0.04, ["$pp_colour_addg"] = -0.01, ["$pp_colour_addb"] = -0.03,
		["$pp_colour_brightness"] = 0.0, ["$pp_colour_contrast"] = 1.0, ["$pp_colour_colour"] = 1.1,
		["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
	})
	render.UpdateScreenEffectTexture()
	render.PushRenderTarget(rt)
	cam.Start2D()
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(scr)
	surface.DrawTexturedRect(0, 0, 480, 270)
	cam.End2D()
	render.PopRenderTarget()
	render.PushFilterMag(TEXFILTER.POINT)
	render.PushFilterMin(TEXFILTER.POINT)
	cam.Start2D()
	surface.SetDrawColor(255, 150, 125, 255)
	surface.SetMaterial(low)
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	cam.End2D()
	render.PopFilterMin()
	render.PopFilterMag()
end)

---------------------------------------------------------------- hell fog
local function fog(scale)
	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(1200 * scale)
	render.FogEnd(7000 * scale)
	render.FogMaxDensity(0.55)
	render.FogColor(150, 40, 20)
	return true
end
hook.Add("SetupWorldFog", "doom_fog", function() return fog(1) end)
hook.Add("SetupSkyboxFog", "doom_fog", function(s) return fog(s) end)

---------------------------------------------------------------- status bar
local function faceMat(lp)
	local now = CurTime()
	if lp:Health() < 35 or now - lp:GetNWFloat("doom_hurt", -10) < 1.2 then return mats.face_hurt end
	if now - GetGlobalFloat("doom_lastkill", -10) < 1.6 then return mats.face_grin end
	return mats.face_ok
end

local function plate(x, y, w, h)
	surface.SetDrawColor(70, 62, 58, 255)
	surface.DrawRect(x, y, w, h)
	surface.SetDrawColor(120, 110, 100, 255)
	surface.DrawRect(x, y, w, sw(3))
	surface.DrawRect(x, y, sw(3), h)
	surface.SetDrawColor(30, 26, 24, 255)
	surface.DrawRect(x, y + h - sw(3), w, sw(3))
	surface.DrawRect(x + w - sw(3), y, sw(3), h)
end

local function number(txt, label, cx, y, c)
	draw.SimpleText(txt, "DoomBig", cx, y + sw(18), c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(label, "DoomSmall", cx, y + sw(86), Color(220, 190, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local titleAt = -100
net.Receive("doom_title", function() titleAt = CurTime() end)

hook.Add("HUDPaint", "doom_hud", function()
	local lp = LocalPlayer()
	if not IsValid(lp) then return end
	local W, H = ScrW(), ScrH()
	local bh = sw(118)
	local y = H - bh
	plate(0, y, W, bh)
	local third = W / 2
	local fs = bh - sw(10)
	-- face in the middle
	plate(third - fs / 2 - sw(8), y - sw(6), fs + sw(16), bh + sw(6))
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(faceMat(lp))
	surface.DrawTexturedRect(third - fs / 2, y + sw(2), fs, fs)

	local w = lp:GetActiveWeapon()
	local ammo = "99"
	if IsValid(w) and w:GetPrimaryAmmoType() >= 0 then ammo = tostring(lp:GetAmmoCount(w:GetPrimaryAmmoType()) + math.max(w:Clip1(), 0)) end
	local red = Color(210, 30, 20)
	local hp = lp:Health()
	number(ammo, "AMMO", W * 0.12, y, red)
	number(math.max(hp, 0) .. "%", "HEALTH", W * 0.30, y, hp < 35 and Color(255, 60, 30) or red)
	number(tostring(GetGlobalInt("doom_kills", 0)), "KILLS", W * 0.70, y, red)
	number(tostring(GetGlobalInt("doom_demons", 0)), "DEMONS LEFT", W * 0.88, y, red)

	-- red flash when hurt
	local since = CurTime() - lp:GetNWFloat("doom_hurt", -10)
	if since < 0.4 then
		surface.SetDrawColor(200, 0, 0, 120 * (1 - since / 0.4))
		surface.DrawRect(0, 0, W, H)
	end

	-- title logo
	local t = CurTime() - titleAt
	if t >= 0 and t < 6 then
		local a = math.Clamp(t / 0.6, 0, 1) * math.Clamp((6 - t) / 1.2, 0, 1)
		local lw = W * 0.46
		local lh = lw * 576 / 1024
		surface.SetDrawColor(255, 255, 255, 255 * a)
		surface.SetMaterial(mats.logo)
		surface.DrawTexturedRect((W - lw) / 2, H * 0.03, lw, lh)
	end
end)

---------------------------------------------------------------- music
local music
local function startMusic()
	sound.PlayFile("sound/sigf/e1m1.wav", "noplay", function(ch)
		if not IsValid(ch) then return end
		ch:SetVolume(0.45)
		ch:EnableLooping(true)
		ch:Play()
		music = ch
	end)
end
hook.Add("InitPostEntity", "doom_music", function() timer.Simple(3, startMusic) end)

---------------------------------------------------------------- BFG lightning
local zaps = {}
net.Receive("doom_zap", function()
	zaps[#zaps + 1] = { a = net.ReadVector(), b = net.ReadVector(), die = CurTime() + 0.3 }
end)
local beam = Material("sprites/physbeam")
hook.Add("PostDrawTranslucentRenderables", "doom_zaps", function(depth, sky)
	if depth or sky then return end
	render.SetMaterial(beam)
	for i = #zaps, 1, -1 do
		local z = zaps[i]
		if CurTime() > z.die then table.remove(zaps, i) else
			local n = 10
			local prev = z.a
			render.StartBeam(n + 1)
			render.AddBeam(z.a, 44, 0, Color(120, 255, 120))
			for k = 1, n - 1 do
				local p = LerpVector(k / n, z.a, z.b) + VectorRand() * 22
				render.AddBeam(p, 44, k / n, Color(180, 255, 180))
			end
			render.AddBeam(z.b, 44, 1, Color(120, 255, 120))
			render.EndBeam()
		end
	end
end)

-- no default popups: hints, achievements and pickup toasts are hidden
if notification then
	notification.AddLegacy = function() end
	notification.AddProgress = function() end
end
hook.Add("HUDShouldDraw", "doom_nopopups", function(name)
	if name == "CHudHintDisplay" or name == "CHudHistoryResource" or name == "CHudChat" and false then return false end
end)
hook.Add("OnAchievementAchieved", "doom_noach", function() return true end)
