AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

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
        physicsObject:EnableMotion(false)
    end
end
