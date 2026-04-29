ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Weapon Attachment"
ENT.Category = "Z-City Others"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.Model = "models/items/boxsrounds.mdl"

function ENT:SetAttachmentId(value)
    self:SetNWString("ZCityAttachmentId", string.Trim(tostring(value or "")))
end

function ENT:SetAttachmentName(value)
    self:SetNWString("ZCityAttachmentName", string.Trim(tostring(value or "Attachment")))
end
