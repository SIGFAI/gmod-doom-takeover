-- Doom Takeover, shared: the BFG 9000 weapon (a big green plasma ball that zaps every demon in sight).
local SWEP = { Primary = {}, Secondary = {} }
SWEP.PrintName = "BFG 9000"
SWEP.Author = "Doom Takeover"
SWEP.Category = "Doom Takeover"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Slot = 4
SWEP.SlotPos = 1
SWEP.ViewModel = "models/weapons/c_smg1.mdl"
SWEP.WorldModel = "models/sigf/bfg.mdl"
SWEP.UseHands = true
SWEP.HoldType = "rpg"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.DrawAmmo = false

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
	if self:GetNextPrimaryFire() > CurTime() then return end
	self:SetNextPrimaryFire(CurTime() + 2.2)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	self:EmitSound("ambient/energy/weld1.wav", 90, 60)
	if SERVER then
		timer.Simple(0.6, function()
			if not IsValid(self) or not IsValid(owner) then return end
			if Doom and Doom.BFG then Doom.BFG(owner) end
		end)
	end
end

function SWEP:SecondaryAttack() end

if CLIENT then
	-- held at the shoulder, muzzle always pointing where the owner aims
	function SWEP:DrawWorldModel()
		local owner = self:GetOwner()
		if not IsValid(owner) then self:DrawModel() return end
		local ang = owner:GetAimVector():Angle()
		local pos = owner:GetShootPos() + ang:Forward() * 14 + ang:Right() * 13 + ang:Up() * -14
		self:SetRenderOrigin(pos)
		self:SetRenderAngles(ang)
		self:SetModelScale(1.5, 0)
		self:DrawModel()
	end
end

SWEP.Base = "weapon_base"
-- The weapon table is rebuilt after autorun files load: register now and again once the game is up.
local function register() weapons.Register(SWEP, "weapon_doom_bfg") end
register()
hook.Add("InitPostEntity", "doom_bfg_register", register)
hook.Add("OnReloaded", "doom_bfg_register", register)
timer.Simple(0, register)
