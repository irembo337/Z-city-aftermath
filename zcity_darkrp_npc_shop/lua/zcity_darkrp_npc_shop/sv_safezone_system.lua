ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.SafeZones = ZCityDarkRPShop.SafeZones or {}

local SafeZones = ZCityDarkRPShop.SafeZones
local Config = ZCityDarkRPShop.Config
local Storage = ZCityDarkRPShop.Storage
local Net = ZCityDarkRPShop.Net

SafeZones.Zones = SafeZones.Zones or {}

util.AddNetworkString("ZCityAftermath.RequestSafeZoneState")
util.AddNetworkString("ZCityAftermath.SafeZoneState")
util.AddNetworkString("ZCityAftermath.OpenSafeZoneMenu")
util.AddNetworkString("ZCityAftermath.SafeZoneAction")

local function isSuperAdmin(ply)
    return IsValid(ply) and ply.GetUserGroup and string.lower(ply:GetUserGroup() or "") == "superadmin"
end

local function notifyPlayer(ply, success, message)
    if not IsValid(ply) then return end

    if Net and Net.Notify then
        Net.Notify(ply, success, message)
    elseif DarkRP and DarkRP.notify then
        DarkRP.notify(ply, success and 0 or 1, 4, message or "")
    else
        ply:ChatPrint(message or "")
    end
end

local function vectorToRecord(pos)
    return { x = pos.x, y = pos.y, z = pos.z }
end

local function recordToVector(record)
    local pos = record and record.pos or {}
    return Vector(tonumber(pos.x) or 0, tonumber(pos.y) or 0, tonumber(pos.z) or 0)
end

local function sendState(ply)
    if not isSuperAdmin(ply) then return end

    net.Start("ZCityAftermath.SafeZoneState")
        net.WriteString(game.GetMap())
        net.WriteTable(SafeZones.Zones or {})
    net.Send(ply)
end

local function broadcastState()
    for _, ply in ipairs(player.GetAll()) do
        if isSuperAdmin(ply) then
            sendState(ply)
        end
    end
end

local function saveZones()
    SafeZones.Zones = Storage.SaveSafeZoneRecords(SafeZones.Zones)
    broadcastState()
end

local function nearestZoneIndex(pos)
    local bestIndex
    local bestDist

    for index, zone in ipairs(SafeZones.Zones or {}) do
        local dist = recordToVector(zone):DistToSqr(pos)
        if not bestDist or dist < bestDist then
            bestIndex = index
            bestDist = dist
        end
    end

    return bestIndex, bestDist
end

function SafeZones.Load()
    SafeZones.Zones = Storage.LoadSafeZoneRecords()
    return SafeZones.Zones
end

function SafeZones.IsPositionSafe(pos)
    for _, zone in ipairs(SafeZones.Zones or {}) do
        local radius = tonumber(zone.radius) or Config.DefaultSafeZoneRadius
        if recordToVector(zone):DistToSqr(pos) <= radius * radius then
            return true, zone
        end
    end

    return false
end

function SafeZones.IsPlayerSafe(ply)
    return IsValid(ply) and SafeZones.IsPositionSafe(ply:GetPos())
end

function SafeZones.OpenMenu(ply)
    if not isSuperAdmin(ply) then
        notifyPlayer(ply, false, "Only ULX superadmin can edit safe zones.")
        return
    end

    sendState(ply)
    net.Start("ZCityAftermath.OpenSafeZoneMenu")
    net.Send(ply)
end

function SafeZones.AddCurrentPosition(ply, radius, name)
    if not isSuperAdmin(ply) then
        notifyPlayer(ply, false, "Only ULX superadmin can add safe zones.")
        return
    end

    if #SafeZones.Zones >= Config.MaxSafeZones then
        notifyPlayer(ply, false, "Safe zone limit reached.")
        return
    end

    radius = math.Clamp(math.floor(tonumber(radius) or Config.DefaultSafeZoneRadius), 64, 8192)
    name = string.Trim(tostring(name or ""))
    if name == "" then
        name = "Safe Zone " .. tostring(#SafeZones.Zones + 1)
    end

    SafeZones.Zones[#SafeZones.Zones + 1] = {
        pos = vectorToRecord(ply:GetPos()),
        radius = radius,
        name = name
    }

    saveZones()
    notifyPlayer(ply, true, "Safe zone saved.")
end

function SafeZones.RemoveNearest(ply)
    if not isSuperAdmin(ply) then
        notifyPlayer(ply, false, "Only ULX superadmin can remove safe zones.")
        return
    end

    local index = nearestZoneIndex(ply:GetPos())
    if not index then
        notifyPlayer(ply, false, "No safe zones on this map.")
        return
    end

    table.remove(SafeZones.Zones, index)
    saveZones()
    notifyPlayer(ply, true, "Nearest safe zone removed.")
end

function SafeZones.RemoveIndex(ply, index)
    if not isSuperAdmin(ply) then
        notifyPlayer(ply, false, "Only ULX superadmin can remove safe zones.")
        return
    end

    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > #SafeZones.Zones then
        notifyPlayer(ply, false, "Safe zone not found.")
        return
    end

    table.remove(SafeZones.Zones, index)
    saveZones()
    notifyPlayer(ply, true, "Safe zone removed.")
end

function SafeZones.Clear(ply)
    if not isSuperAdmin(ply) then
        notifyPlayer(ply, false, "Only ULX superadmin can clear safe zones.")
        return
    end

    SafeZones.Zones = {}
    saveZones()
    notifyPlayer(ply, true, "All safe zones removed for this map.")
end

hook.Add("EntityTakeDamage", "ZCityAftermath.SafeZoneDamageBlock", function(target, dmg)
    local victim = IsValid(target) and target:IsPlayer() and target or nil
    local attacker = IsValid(dmg:GetAttacker()) and dmg:GetAttacker():IsPlayer() and dmg:GetAttacker() or nil

    if victim and SafeZones.IsPlayerSafe(victim) then
        dmg:SetDamage(0)
        return true
    end

    if attacker and SafeZones.IsPlayerSafe(attacker) then
        dmg:SetDamage(0)
        return true
    end
end)

timer.Create("ZCityAftermath.SafeZoneNW", 1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        ply:SetNWBool("ZCityAftermath.InSafeZone", SafeZones.IsPlayerSafe(ply) == true)
    end
end)

net.Receive("ZCityAftermath.RequestSafeZoneState", function(_, ply)
    sendState(ply)
end)

net.Receive("ZCityAftermath.SafeZoneAction", function(_, ply)
    local action = net.ReadString()

    if action == "add" then
        SafeZones.AddCurrentPosition(ply, net.ReadUInt(16), net.ReadString())
    elseif action == "remove_nearest" then
        SafeZones.RemoveNearest(ply)
    elseif action == "remove_index" then
        SafeZones.RemoveIndex(ply, net.ReadUInt(16))
    elseif action == "clear" then
        SafeZones.Clear(ply)
    end
end)

concommand.Add(Config.SafeZoneMenuCommand, function(ply)
    SafeZones.OpenMenu(ply)
end)

concommand.Add(Config.SafeZoneAddCommand, function(ply, _, args)
    SafeZones.AddCurrentPosition(ply, args and args[1], table.concat(args or {}, " ", 2))
end)

concommand.Add(Config.SafeZoneRemoveNearestCommand, function(ply)
    SafeZones.RemoveNearest(ply)
end)

concommand.Add(Config.SafeZoneClearCommand, function(ply)
    SafeZones.Clear(ply)
end)

local ulxRegistered = false

local function registerULXSafeZoneCommands()
    if ulxRegistered or not ulx or not ULib or not ULib.cmds then return end
    ulxRegistered = true

    function ulx.zcitysafezonemenu(callingPly)
        SafeZones.OpenMenu(callingPly)
    end

    local menuCmd = ulx.command("Z-City Aftermath", "ulx zcitysafezonemenu", ulx.zcitysafezonemenu, "!zcitysafezonemenu")
    menuCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    menuCmd:help("Open the Z-City safe zone manager.")

    function ulx.zcitysafezoneadd(callingPly, radius, name)
        SafeZones.AddCurrentPosition(callingPly, radius, name)
    end

    local addCmd = ulx.command("Z-City Aftermath", "ulx zcitysafezoneadd", ulx.zcitysafezoneadd, "!zcitysafezoneadd")
    addCmd:addParam{ type = ULib.cmds.NumArg, min = 64, max = 8192, default = Config.DefaultSafeZoneRadius, hint = "radius", ULib.cmds.optional }
    addCmd:addParam{ type = ULib.cmds.StringArg, hint = "zone name", ULib.cmds.optional }
    addCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    addCmd:help("Save your current position as a safe zone.")

    function ulx.zcitysafezoneremove(callingPly)
        SafeZones.RemoveNearest(callingPly)
    end

    local removeCmd = ulx.command("Z-City Aftermath", "ulx zcitysafezoneremove", ulx.zcitysafezoneremove, "!zcitysafezoneremove")
    removeCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    removeCmd:help("Remove the nearest safe zone.")

    function ulx.zcitysafezoneclear(callingPly)
        SafeZones.Clear(callingPly)
    end

    local clearCmd = ulx.command("Z-City Aftermath", "ulx zcitysafezoneclear", ulx.zcitysafezoneclear, "!zcitysafezoneclear")
    clearCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    clearCmd:help("Remove all safe zones on this map.")
end

timer.Simple(0, registerULXSafeZoneCommands)
hook.Add("Initialize", "ZCityAftermath.RegisterULXSafeZoneCommands", registerULXSafeZoneCommands)
hook.Add("InitPostEntity", "ZCityAftermath.RegisterULXSafeZoneCommandsLate", registerULXSafeZoneCommands)
