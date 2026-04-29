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
    local cameras = ZCityDarkRPShop and ZCityDarkRPShop.Cameras or nil

    self:SetModel(cameras and cameras.GetCameraModel and cameras.GetCameraModel() or self.Model)
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

    local cameras = ZCityDarkRPShop and ZCityDarkRPShop.Cameras or nil
    if not cameras or not cameras.DeployFromKit then
        notifyPlayer(ply, false, "Camera system is not available.")
        return
    end

    local success, message = cameras.DeployFromKit(self, ply)
    notifyPlayer(ply, success, message)
end
