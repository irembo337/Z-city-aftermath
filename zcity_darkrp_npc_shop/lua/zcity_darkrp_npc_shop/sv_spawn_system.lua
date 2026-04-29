ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.SpawnSystem = ZCityDarkRPShop.SpawnSystem or {}

local SpawnSystem = ZCityDarkRPShop.SpawnSystem
local Config = ZCityDarkRPShop.Config
local Storage = ZCityDarkRPShop.Storage
local Net = ZCityDarkRPShop.Net

SpawnSystem.Spawns = SpawnSystem.Spawns or {}

util.AddNetworkString("ZCityAftermath.RequestSpawnState")
util.AddNetworkString("ZCityAftermath.SpawnState")
util.AddNetworkString("ZCityAftermath.OpenSpawnMenu")
util.AddNetworkString("ZCityAftermath.SpawnAction")

local function isSpawnAdmin(ply)
    if not IsValid(ply) or not ply.GetUserGroup then
        return false
    end

    return string.lower(ply:GetUserGroup() or "") == "superadmin"
end

local function notifyPlayer(ply, success, message)
    if not IsValid(ply) then return end

    if Net and Net.Notify then
        Net.Notify(ply, success, message)
        return
    end

    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, success and 0 or 1, 4, message or "")
    else
        ply:ChatPrint(message or "")
    end
end

local function vectorToRecord(pos)
    return { x = pos.x, y = pos.y, z = pos.z }
end

local function angleToRecord(ang)
    return { p = 0, y = ang.y, r = 0 }
end

local function recordToVector(record)
    local pos = record and record.pos or {}
    return Vector(tonumber(pos.x) or 0, tonumber(pos.y) or 0, tonumber(pos.z) or 0)
end

local function recordToAngle(record)
    local ang = record and record.ang or {}
    return Angle(tonumber(ang.p) or 0, tonumber(ang.y) or 0, tonumber(ang.r) or 0)
end

local function sendState(ply)
    if not isSpawnAdmin(ply) then
        return
    end

    net.Start("ZCityAftermath.SpawnState")
        net.WriteString(game.GetMap())
        net.WriteTable(SpawnSystem.Spawns or {})
    net.Send(ply)
end

local function broadcastState()
    for _, ply in ipairs(player.GetAll()) do
        if isSpawnAdmin(ply) then
            sendState(ply)
        end
    end
end

local function saveSpawns()
    SpawnSystem.Spawns = Storage.SaveSpawnRecords(SpawnSystem.Spawns)
    broadcastState()
end

local function nearestSpawnIndex(pos)
    local bestIndex
    local bestDist

    for index, record in ipairs(SpawnSystem.Spawns or {}) do
        local dist = recordToVector(record):DistToSqr(pos)
        if not bestDist or dist < bestDist then
            bestIndex = index
            bestDist = dist
        end
    end

    return bestIndex, bestDist
end

local function chooseSpawn()
    if not istable(SpawnSystem.Spawns) or #SpawnSystem.Spawns == 0 then
        return nil
    end

    local record = table.Random(SpawnSystem.Spawns)
    if not record then return nil end

    return recordToVector(record), recordToAngle(record)
end

function SpawnSystem.Load()
    SpawnSystem.Spawns = Storage.LoadSpawnRecords()
    return SpawnSystem.Spawns
end

function SpawnSystem.OpenMenu(ply)
    if not isSpawnAdmin(ply) then
        notifyPlayer(ply, false, "Only superadmin can edit Z-City spawns.")
        return
    end

    sendState(ply)
    net.Start("ZCityAftermath.OpenSpawnMenu")
    net.Send(ply)
end

function SpawnSystem.AddCurrentPosition(ply, name)
    if not isSpawnAdmin(ply) then
        notifyPlayer(ply, false, "Only superadmin can add spawns.")
        return
    end

    if #SpawnSystem.Spawns >= Config.MaxSpawns then
        notifyPlayer(ply, false, "Spawn limit reached.")
        return
    end

    local record = {
        pos = vectorToRecord(ply:GetPos()),
        ang = angleToRecord(ply:EyeAngles()),
        name = string.Trim(tostring(name or ""))
    }

    if record.name == "" then
        record.name = "Spawn " .. tostring(#SpawnSystem.Spawns + 1)
    end

    SpawnSystem.Spawns[#SpawnSystem.Spawns + 1] = record
    saveSpawns()
    notifyPlayer(ply, true, "Spawn point saved.")
end

function SpawnSystem.RemoveNearest(ply)
    if not isSpawnAdmin(ply) then
        notifyPlayer(ply, false, "Only superadmin can remove spawns.")
        return
    end

    local index = nearestSpawnIndex(ply:GetPos())
    if not index then
        notifyPlayer(ply, false, "No saved spawns on this map.")
        return
    end

    table.remove(SpawnSystem.Spawns, index)
    saveSpawns()
    notifyPlayer(ply, true, "Nearest spawn point removed.")
end

function SpawnSystem.RemoveIndex(ply, index)
    if not isSpawnAdmin(ply) then
        notifyPlayer(ply, false, "Only superadmin can remove spawns.")
        return
    end

    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > #SpawnSystem.Spawns then
        notifyPlayer(ply, false, "Spawn point not found.")
        return
    end

    table.remove(SpawnSystem.Spawns, index)
    saveSpawns()
    notifyPlayer(ply, true, "Spawn point removed.")
end

function SpawnSystem.Clear(ply)
    if not isSpawnAdmin(ply) then
        notifyPlayer(ply, false, "Only superadmin can clear spawns.")
        return
    end

    SpawnSystem.Spawns = {}
    saveSpawns()
    notifyPlayer(ply, true, "All custom spawns removed for this map.")
end

function SpawnSystem.TeleportToIndex(ply, index)
    if not isSpawnAdmin(ply) then
        notifyPlayer(ply, false, "Only superadmin can inspect spawns.")
        return
    end

    index = math.floor(tonumber(index) or 0)
    local record = SpawnSystem.Spawns[index]
    if not record then
        notifyPlayer(ply, false, "Spawn point not found.")
        return
    end

    local pos, ang = recordToVector(record), recordToAngle(record)
    ply:SetPos(pos + Vector(0, 0, 4))
    ply:SetEyeAngles(Angle(0, ang.y, 0))
end

local function applyCustomSpawn(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then
        return
    end

    if not ply.ZCityAftermathPendingSpawnMove then
        return
    end

    if ply.ZCityAftermathUsedJobSpawn then
        ply.ZCityAftermathUsedJobSpawn = nil
        return
    end

    local pos, ang = chooseSpawn()
    if not pos then
        return
    end

    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end
        ply:SetPos(pos + Vector(0, 0, 4))
        ply:SetEyeAngles(Angle(0, ang.y, 0))
        ply.ZCityAftermathPendingSpawnMove = nil
    end)
end

hook.Add("PlayerSpawn", "ZCityAftermath.ApplyCustomSpawn", applyCustomSpawn)

hook.Add("PlayerInitialSpawn", "ZCityAftermath.MarkInitialSpawnMove", function(ply)
    ply.ZCityAftermathPendingSpawnMove = true
    ply.ZCityAftermathUsedJobSpawn = nil
end)

hook.Add("PlayerDeath", "ZCityAftermath.AutoRespawn", function(ply)
    ply.ZCityAftermathPendingSpawnMove = true
    ply.ZCityAftermathUsedJobSpawn = nil

    local delay = math.max(0, tonumber(Config.AutoRespawnDelay) or 5)
    if delay <= 0 then return end

    timer.Simple(delay, function()
        if not IsValid(ply) or ply:Alive() then return end
        ply:Spawn()
    end)
end)

net.Receive("ZCityAftermath.RequestSpawnState", function(_, ply)
    sendState(ply)
end)

net.Receive("ZCityAftermath.SpawnAction", function(_, ply)
    local action = net.ReadString()

    if action == "add" then
        SpawnSystem.AddCurrentPosition(ply, net.ReadString())
    elseif action == "remove_nearest" then
        SpawnSystem.RemoveNearest(ply)
    elseif action == "remove_index" then
        SpawnSystem.RemoveIndex(ply, net.ReadUInt(16))
    elseif action == "clear" then
        SpawnSystem.Clear(ply)
    elseif action == "goto" then
        SpawnSystem.TeleportToIndex(ply, net.ReadUInt(16))
    end
end)

concommand.Add(Config.SpawnMenuCommand, function(ply)
    SpawnSystem.OpenMenu(ply)
end)

concommand.Add(Config.SpawnAddCommand, function(ply, _, args)
    SpawnSystem.AddCurrentPosition(ply, table.concat(args or {}, " "))
end)

concommand.Add(Config.SpawnRemoveNearestCommand, function(ply)
    SpawnSystem.RemoveNearest(ply)
end)

concommand.Add(Config.SpawnClearCommand, function(ply)
    SpawnSystem.Clear(ply)
end)

local ulxRegistered = false

local function registerULXSpawnCommands()
    if ulxRegistered or not ulx or not ULib or not ULib.cmds then
        return
    end

    ulxRegistered = true

    function ulx.zcityspawnmenu(callingPly)
        SpawnSystem.OpenMenu(callingPly)
    end

    local menuCmd = ulx.command("Z-City Aftermath", "ulx zcityspawnmenu", ulx.zcityspawnmenu, "!zcityspawnmenu")
    menuCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    menuCmd:help("Open the Z-City spawn manager.")

    function ulx.zcityspawnadd(callingPly, name)
        SpawnSystem.AddCurrentPosition(callingPly, name)
    end

    local addCmd = ulx.command("Z-City Aftermath", "ulx zcityspawnadd", ulx.zcityspawnadd, "!zcityspawnadd")
    addCmd:addParam{ type = ULib.cmds.StringArg, hint = "spawn name", ULib.cmds.optional }
    addCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    addCmd:help("Save your current position as a respawn point.")

    function ulx.zcityspawnremove(callingPly)
        SpawnSystem.RemoveNearest(callingPly)
    end

    local removeCmd = ulx.command("Z-City Aftermath", "ulx zcityspawnremove", ulx.zcityspawnremove, "!zcityspawnremove")
    removeCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    removeCmd:help("Remove the nearest saved respawn point.")

    function ulx.zcityspawnclear(callingPly)
        SpawnSystem.Clear(callingPly)
    end

    local clearCmd = ulx.command("Z-City Aftermath", "ulx zcityspawnclear", ulx.zcityspawnclear, "!zcityspawnclear")
    clearCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    clearCmd:help("Remove all custom respawn points on this map.")
end

timer.Simple(0, registerULXSpawnCommands)
hook.Add("Initialize", "ZCityAftermath.RegisterULXSpawnCommands", registerULXSpawnCommands)
hook.Add("InitPostEntity", "ZCityAftermath.RegisterULXSpawnCommandsLate", registerULXSpawnCommands)
