AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local function notifyPlayer(ply, success, message)
    local Net = ZCityDarkRPShop and ZCityDarkRPShop.Net or nil

    if Net and Net.Notify then
        Net.Notify(ply, success, message)
    elseif DarkRP and DarkRP.notify then
        DarkRP.notify(ply, success and 0 or 1, 4, message or "")
    elseif IsValid(ply) then
        ply:ChatPrint(message or "")
    end
end

function ENT:Initialize()
    self:SetModel(self.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local physicsObject = self:GetPhysicsObject()
    if IsValid(physicsObject) then
        physicsObject:Wake()
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        return
    end

    local Config = ZCityDarkRPShop and ZCityDarkRPShop.Config or {}
    ply:Give(Config.CameraTabletWeapon or "weapon_zcity_camera_tablet")
    notifyPlayer(ply, true, "Camera tablet taken.")
    self:Remove()
end
