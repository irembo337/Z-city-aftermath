if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "Camera Tablet"
SWEP.Author = "Codex"
SWEP.Instructions = "LMB - next camera | RMB - previous camera | R - menu / exit"
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.UseHands = true
SWEP.ViewModel = "models/slusher/tablet/c_tablet.mdl"
SWEP.WorldModel = "models/slusher/tablet/w_tablet.mdl"
SWEP.ViewModelFOV = 54
SWEP.ViewModelFlip = false
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.HoldType = "slam"
SWEP.Base = "weapon_base"
SWEP.BobScale = 0.2
SWEP.SwayScale = 0.35

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    local cameras = ZCityDarkRPShop and ZCityDarkRPShop.Cameras or nil

    self:SetHoldType(self.HoldType)
    self.ViewModel = cameras and cameras.GetTabletViewModel and cameras.GetTabletViewModel() or self.ViewModel
    self.WorldModel = cameras and cameras.GetTabletWorldModel and cameras.GetTabletWorldModel() or self.WorldModel
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    return true
end

function SWEP:GetViewModelPosition(pos, ang)
    local offsetForward = 11
    local offsetRight = 0.2
    local offsetUp = -6.4

    pos = pos + ang:Forward() * offsetForward
    pos = pos + ang:Right() * offsetRight
    pos = pos + ang:Up() * offsetUp

    ang:RotateAroundAxis(ang:Right(), -10)
    ang:RotateAroundAxis(ang:Up(), 2)
    ang:RotateAroundAxis(ang:Forward(), -2)

    return pos, ang
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.25)

    if CLIENT and IsFirstTimePredicted() and ZCityDarkRPShop and ZCityDarkRPShop.Cameras and ZCityDarkRPShop.Cameras.SelectNextCamera then
        ZCityDarkRPShop.Cameras.SelectNextCamera()
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.25)

    if CLIENT and IsFirstTimePredicted() and ZCityDarkRPShop and ZCityDarkRPShop.Cameras and ZCityDarkRPShop.Cameras.SelectPreviousCamera then
        ZCityDarkRPShop.Cameras.SelectPreviousCamera()
    end
end

function SWEP:Reload()
    if CLIENT and IsFirstTimePredicted() and ZCityDarkRPShop and ZCityDarkRPShop.Cameras and ZCityDarkRPShop.Cameras.HandleReloadAction then
        ZCityDarkRPShop.Cameras.HandleReloadAction()
    end
end
