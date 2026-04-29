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

local function tryInvoke(method, weapon, ...)
    if not weapon or not weapon[method] then
        return false
    end

    local ok, result = pcall(weapon[method], weapon, ...)
    if not ok then
        return false
    end

    return result ~= false
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

    local attachmentId = self:GetNWString("ZCityAttachmentId", "")
    local attachmentName = self:GetNWString("ZCityAttachmentName", "Attachment")
    if attachmentId == "" then
        notifyPlayer(ply, false, "Attachment data is missing.")
        return
    end

    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) then
        notifyPlayer(ply, false, "Hold the weapon you want to upgrade first.")
        return
    end

    local applied = false
    applied = tryInvoke("Attach", weapon, attachmentId) or applied
    applied = tryInvoke("AttachAttachment", weapon, attachmentId) or applied
    applied = tryInvoke("InstallAttachment", weapon, attachmentId) or applied
    applied = tryInvoke("GiveAttachment", weapon, attachmentId) or applied

    if applied then
        notifyPlayer(ply, true, "Attachment applied: " .. attachmentName)
        self:Remove()
        return
    end

    notifyPlayer(ply, false, "Your current weapon base did not accept this attachment automatically.")
end
