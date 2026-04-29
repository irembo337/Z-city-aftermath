ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Net = ZCityDarkRPShop.Net or {}

local Net = ZCityDarkRPShop.Net
local Core = ZCityDarkRPShop.Core
local Config = ZCityDarkRPShop.Config

util.AddNetworkString("ZCityDarkRPShop.RequestState")
util.AddNetworkString("ZCityDarkRPShop.State")
util.AddNetworkString("ZCityDarkRPShop.BuyItem")
util.AddNetworkString("ZCityDarkRPShop.SaveCatalog")
util.AddNetworkString("ZCityDarkRPShop.SaveSettings")
util.AddNetworkString("ZCityDarkRPShop.RequestDetectedCatalog")
util.AddNetworkString("ZCityDarkRPShop.DetectedCatalog")
util.AddNetworkString("ZCityDarkRPShop.Notify")
util.AddNetworkString("ZCityDarkRPShop.OpenMenu")

function Net.SendState(target)
    if not IsValid(target) then return end

    net.Start("ZCityDarkRPShop.State")
    net.WriteString(util.TableToJSON(Core.BuildState(target)) or "{}")
    net.Send(target)
end

function Net.Notify(target, success, message)
    if not IsValid(target) then return end

    net.Start("ZCityDarkRPShop.Notify")
    net.WriteBool(success)
    net.WriteString(message or "")
    net.Send(target)
end

function Net.OpenMenu(target, tabName)
    if not IsValid(target) then return end

    Net.SendState(target)

    net.Start("ZCityDarkRPShop.OpenMenu")
    net.WriteString(tabName or "shop")
    net.Send(target)
end

function Net.SendDetectedCatalog(target)
    if not IsValid(target) then return end

    local canManage = Core.CanManageShop(target)
    if not canManage then
        Net.Notify(target, false, "Only ULX admin or superadmin can load manager lists.")
        return
    end

    local payload = util.TableToJSON(Core.GetDetectedCatalog(true)) or "{}"
    local compressed = util.Compress(payload)
    if not compressed then
        Net.Notify(target, false, "Could not compress detected catalog.")
        return
    end

    net.Start("ZCityDarkRPShop.DetectedCatalog")
    net.WriteUInt(#compressed, 32)
    net.WriteData(compressed, #compressed)
    net.Send(target)
end

local function broadcastStates()
    for _, ply in ipairs(player.GetAll()) do
        Net.SendState(ply)
    end
end

net.Receive("ZCityDarkRPShop.RequestState", function(_, ply)
    Net.SendState(ply)
end)

net.Receive("ZCityDarkRPShop.RequestDetectedCatalog", function(_, ply)
    Net.SendDetectedCatalog(ply)
end)

net.Receive("ZCityDarkRPShop.BuyItem", function(_, ply)
    local itemId = net.ReadString()
    local success, message = Core.PurchaseItem(ply, itemId)
    Net.Notify(ply, success, message)
    Net.SendState(ply)
end)

net.Receive("ZCityDarkRPShop.SaveCatalog", function(_, ply)
    local allowed, reason = Core.CanManageShop(ply)
    if not allowed then
        Net.Notify(ply, false, reason)
        return
    end

    local decoded = util.JSONToTable(net.ReadString() or "")
    if not istable(decoded) then
        Net.Notify(ply, false, "Could not parse catalog data.")
        return
    end

    local items = Core.SaveCatalog(decoded)
    Net.Notify(ply, true, string.format("Catalog saved (%d items).", #items))
    broadcastStates()
end)

net.Receive("ZCityDarkRPShop.SaveSettings", function(_, ply)
    local allowed, reason = Core.CanManageShop(ply)
    if not allowed then
        Net.Notify(ply, false, reason)
        return
    end

    local decoded = util.JSONToTable(net.ReadString() or "")
    if not istable(decoded) then
        Net.Notify(ply, false, "Could not parse settings data.")
        return
    end

    local settings = Core.SaveSettings(decoded)
    Net.Notify(ply, true, "NPC settings saved.")
    broadcastStates()

    for _, ent in ipairs(ents.FindByClass(Config.NPCClass)) do
        if IsValid(ent) then
            ent:SetNWString("ZCityDarkRPShopNPCName", settings.npcName or Config.NPCName)
        end
    end
end)

concommand.Add(Config.SpawnNPCCommand, function(ply)
    local success, message = Core.AddNPCFromPlayer(ply)
    Net.Notify(ply, success, message)
    if success then
        broadcastStates()
    end
end)

concommand.Add(Config.RemoveNPCCommand, function(ply)
    local success, message = Core.RemoveLookedAtNPC(ply)
    Net.Notify(ply, success, message)
    if success then
        broadcastStates()
    end
end)

concommand.Add(Config.RemoveAllNPCsCommand, function(ply)
    local success, message = Core.RemoveAllNPCs(ply)
    Net.Notify(ply, success, message)
    if success then
        broadcastStates()
    end
end)

concommand.Add(Config.ReloadNPCCommand, function(ply)
    if IsValid(ply) then
        local allowed, reason = Core.CanManageShop(ply)
        if not allowed then
            Net.Notify(ply, false, reason)
            return
        end
    end

    Core.LoadNPCs()
    Core.LoadSettings()
    Core.RespawnNPCs()

    if IsValid(ply) then
        Net.Notify(ply, true, "Saved shop NPCs reloaded for this map.")
    else
        print("[ZCityDarkRPShop] NPCs reloaded.")
    end

    broadcastStates()
end)
