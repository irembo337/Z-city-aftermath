AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local Config = ZCityDarkRPShop and ZCityDarkRPShop.Config or {}

function ENT:Initialize()
    self:SetModel(self.NPCModelOverride or Config.NPCModel or "models/Humans/Group01/male_07.mdl")
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(SIMPLE_USE)
    self:CapabilitiesAdd(bit.bor(CAP_ANIMATEDFACE, CAP_TURN_HEAD))
    self:SetMaxYawSpeed(90)
    self:SetNPCState(NPC_STATE_SCRIPT)
    self:SetNWString("ZCityDarkRPShopNPCName", (ZCityDarkRPShop.Core and ZCityDarkRPShop.Core.GetNPCName and ZCityDarkRPShop.Core.GetNPCName()) or (Config.NPCName or "Gun Dealer"))
    self:DropToFloor()

    local sequence = self:LookupSequence("idle_all_01")
    if sequence and sequence > 0 then
        self:ResetSequence(sequence)
        self:SetCycle(0)
    end
end

function ENT:AcceptInput(name, activator)
    if name ~= "Use" or not IsValid(activator) or not activator:IsPlayer() then
        return
    end

    if self:GetPos():DistToSqr(activator:GetPos()) > (Config.NPCUseDistance or 160) ^ 2 then
        return
    end

    self.NextUseTime = self.NextUseTime or 0
    if self.NextUseTime > CurTime() then
        return
    end

    self.NextUseTime = CurTime() + 0.5
    ZCityDarkRPShop.Net.OpenMenu(activator, "shop")
end

function ENT:Think()
    self:NextThink(CurTime())
    self:FrameAdvance()
    return true
end
