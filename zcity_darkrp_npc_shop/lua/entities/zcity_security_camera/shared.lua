ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Security Camera"
ENT.Category = "Z-City Aftermath"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.Model = "models/props_combine/combinecamera001.mdl"

function ENT:GetCameraFeedPos()
    local ang = self.ZCityCameraFeedAngle or self:GetNWAngle("ZCityCameraFeedAngle", self:GetAngles())
    local origin = self:GetPos() + ang:Forward() * 8 + ang:Up() * 4
    return origin, ang
end
