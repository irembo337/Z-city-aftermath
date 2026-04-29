ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Housing = ZCityDarkRPShop.Housing or {}

local Housing = ZCityDarkRPShop.Housing
local Config = ZCityDarkRPShop.Config
local Storage = ZCityDarkRPShop.Storage
local Net = ZCityDarkRPShop.Net

Housing.Doors = Housing.Doors or {}

util.AddNetworkString("ZCityAftermath.RequestDoorState")
util.AddNetworkString("ZCityAftermath.DoorState")
util.AddNetworkString("ZCityAftermath.OpenDoorAdmin")
util.AddNetworkString("ZCityAftermath.DoorAction")
util.AddNetworkString("ZCityAftermath.RequestLookedDoor")
util.AddNetworkString("ZCityAftermath.LookedDoorInfo")

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

local function lookedDoor(ply)
    if not IsValid(ply) then return nil end

    local trace = ply:GetEyeTrace()
    local ent = trace.Entity

    if not IsValid(ent) or ply:GetPos():DistToSqr(ent:GetPos()) > 40000 then
        return nil
    end

    if ent.isKeysOwnable and ent:isKeysOwnable() then
        return ent
    end
end

local function doorMapId(ent)
    if not IsValid(ent) then return nil end
    if ent.doorIndex then
        return ent:doorIndex()
    end

    local id = ent:MapCreationID()
    return id and id > 0 and id or nil
end

local function doorRecord(ent)
    local mapId = doorMapId(ent)
    if not mapId then return nil end

    local record = Housing.Doors[tostring(mapId)]
    if record then
        return record
    end

    return {
        mapId = mapId,
        price = Config.DefaultDoorPrice,
        name = "",
        enabled = true
    }
end

local function doorPrice(ent)
    local record = doorRecord(ent)
    return math.max(0, math.floor(tonumber(record and record.price) or Config.DefaultDoorPrice))
end

local function formatMoney(amount)
    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(amount)
    end

    return "$" .. tostring(amount)
end

local function applyDoorNW(ent)
    if not IsValid(ent) then return end

    local record = doorRecord(ent)
    if not record then return end

    ent:SetNWBool("ZCityAftermath.DoorEnabled", record.enabled ~= false)
    ent:SetNWInt("ZCityAftermath.DoorPrice", math.max(0, math.floor(tonumber(record.price) or Config.DefaultDoorPrice)))
    ent:SetNWString("ZCityAftermath.DoorName", tostring(record.name or ""))
end

local function applyDoorNetwork()
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent.isKeysOwnable and ent:isKeysOwnable() then
            applyDoorNW(ent)
        end
    end
end

local function sendState(ply)
    if not isSuperAdmin(ply) then return end

    net.Start("ZCityAftermath.DoorState")
        net.WriteString(game.GetMap())
        net.WriteTable(Housing.Doors or {})
    net.Send(ply)
end

local function sendLookedDoorInfo(ply)
    if not IsValid(ply) then return end

    local ent = lookedDoor(ply)
    local valid = IsValid(ent)
    local record = valid and doorRecord(ent) or nil
    local owner = valid and ent.getDoorOwner and ent:getDoorOwner() or nil

    net.Start("ZCityAftermath.LookedDoorInfo")
        net.WriteBool(valid)

        if valid then
            net.WriteUInt(doorMapId(ent) or 0, 32)
            net.WriteString((record and record.name ~= "" and record.name) or "Door")
            net.WriteUInt(math.max(0, math.floor(tonumber(record and record.price) or Config.DefaultDoorPrice)), 32)
            net.WriteBool(ent:isKeysOwned())
            net.WriteString(IsValid(owner) and owner:Nick() or "")
            net.WriteBool(ent.isKeysOwnedBy and ent:isKeysOwnedBy(ply) == true)
            net.WriteBool(ent.isLocked and ent:isLocked() == true)
        end
    net.Send(ply)
end

local function broadcastState()
    for _, ply in ipairs(player.GetAll()) do
        if isSuperAdmin(ply) then
            sendState(ply)
        end
    end
end

local function saveDoors()
    Housing.Doors = Storage.SaveDoorRecords(Housing.Doors)
    applyDoorNetwork()
    broadcastState()
end

function Housing.Load()
    Housing.Doors = Storage.LoadDoorRecords()
    timer.Simple(1, applyDoorNetwork)
    return Housing.Doors
end

function Housing.OpenAdmin(ply)
    if not isSuperAdmin(ply) then
        notifyPlayer(ply, false, "Only ULX superadmin can edit doors.")
        return
    end

    sendState(ply)
    net.Start("ZCityAftermath.OpenDoorAdmin")
    net.Send(ply)
end

function Housing.SetLookedDoor(ply, price, name)
    if not isSuperAdmin(ply) then
        notifyPlayer(ply, false, "Only ULX superadmin can edit doors.")
        return
    end

    local ent = lookedDoor(ply)
    if not ent then
        notifyPlayer(ply, false, "Look at a door.")
        return
    end

    local mapId = doorMapId(ent)
    if not mapId then
        notifyPlayer(ply, false, "This door has no map id.")
        return
    end

    price = math.max(0, math.floor(tonumber(price) or Config.DefaultDoorPrice))
    name = string.Trim(tostring(name or ""))

    Housing.Doors[tostring(mapId)] = {
        mapId = mapId,
        price = price,
        name = name,
        enabled = true
    }

    if ent.setKeysNonOwnable then
        ent:setKeysNonOwnable(false)
    end

    if name ~= "" and ent.setKeysTitle then
        ent:setKeysTitle(name)
    end

    saveDoors()
    notifyPlayer(ply, true, "Door price saved: " .. formatMoney(price))
end

function Housing.ClearLookedDoor(ply)
    if not isSuperAdmin(ply) then
        notifyPlayer(ply, false, "Only ULX superadmin can edit doors.")
        return
    end

    local ent = lookedDoor(ply)
    if not ent then
        notifyPlayer(ply, false, "Look at a door.")
        return
    end

    local mapId = doorMapId(ent)
    if not mapId then return end

    Housing.Doors[tostring(mapId)] = nil
    ent:SetNWBool("ZCityAftermath.DoorEnabled", false)
    ent:SetNWInt("ZCityAftermath.DoorPrice", 0)
    ent:SetNWString("ZCityAftermath.DoorName", "")

    saveDoors()
    notifyPlayer(ply, true, "Door config removed.")
end

function Housing.BuyLookedDoor(ply)
    local ent = lookedDoor(ply)
    if not ent then
        notifyPlayer(ply, false, "Look at a door.")
        return
    end

    if ent:getKeysNonOwnable() then
        notifyPlayer(ply, false, "This door is not for sale.")
        return
    end

    if ent:isKeysOwned() and not ent:isKeysAllowedToOwn(ply) then
        notifyPlayer(ply, false, "This door is already owned.")
        return
    end

    local price = doorPrice(ent)
    if not ply.canAfford or not ply:canAfford(price) then
        notifyPlayer(ply, false, "Not enough money. Price: " .. formatMoney(price))
        return
    end

    local allowed, reason = hook.Call("playerBuyDoor", GAMEMODE, ply, ent)
    if allowed == false then
        notifyPlayer(ply, false, reason or "Door purchase blocked.")
        return
    end

    ply:addMoney(-price)
    ent:keysOwn(ply)

    local record = doorRecord(ent)
    if record and record.name ~= "" and ent.setKeysTitle then
        ent:setKeysTitle(record.name)
    end

    hook.Call("playerBoughtDoor", GAMEMODE, ply, ent, price)
    notifyPlayer(ply, true, "Door bought for " .. formatMoney(price))
end

function Housing.SellLookedDoor(ply)
    local ent = lookedDoor(ply)
    if not ent then
        notifyPlayer(ply, false, "Look at your door.")
        return
    end

    if not ent:isKeysOwnedBy(ply) then
        notifyPlayer(ply, false, "You do not own this door.")
        return
    end

    local refund = math.floor(doorPrice(ent) * 0.66)
    ent:keysUnOwn(ply)
    ent:Fire("unlock", "", 0)
    ply:addMoney(refund)
    notifyPlayer(ply, true, "Door sold for " .. formatMoney(refund))
end

function Housing.LockLookedDoor(ply, locked)
    local ent = lookedDoor(ply)
    if not ent then
        notifyPlayer(ply, false, "Look at your door.")
        return
    end

    if not ent:isKeysOwnedBy(ply) then
        notifyPlayer(ply, false, "You do not own this door.")
        return
    end

    if locked then
        ent:keysLock()
        notifyPlayer(ply, true, "Door locked.")
    else
        ent:keysUnLock()
        notifyPlayer(ply, true, "Door unlocked.")
    end
end

hook.Add("getDoorCost", "ZCityAftermath.CustomDoorCost", function(_, ent)
    if IsValid(ent) then
        return doorPrice(ent)
    end
end)

hook.Add("PlayerSpawn", "ZCityAftermath.GiveKeysOnSpawn", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end
        if not ply:HasWeapon("keys") then
            ply:Give("keys")
        end
    end)
end)

hook.Add("InitPostEntity", "ZCityAftermath.ApplyDoorNetwork", function()
    Housing.Load()
end)

net.Receive("ZCityAftermath.RequestDoorState", function(_, ply)
    sendState(ply)
end)

net.Receive("ZCityAftermath.RequestLookedDoor", function(_, ply)
    sendLookedDoorInfo(ply)
end)

net.Receive("ZCityAftermath.DoorAction", function(_, ply)
    local action = net.ReadString()

    if action == "buy" then
        Housing.BuyLookedDoor(ply)
    elseif action == "sell" then
        Housing.SellLookedDoor(ply)
    elseif action == "lock" then
        Housing.LockLookedDoor(ply, true)
    elseif action == "unlock" then
        Housing.LockLookedDoor(ply, false)
    elseif action == "set_price" then
        Housing.SetLookedDoor(ply, net.ReadUInt(32), net.ReadString())
    elseif action == "clear" then
        Housing.ClearLookedDoor(ply)
    end
end)

concommand.Add(Config.DoorBuyCommand, function(ply) Housing.BuyLookedDoor(ply) end)
concommand.Add(Config.DoorSellCommand, function(ply) Housing.SellLookedDoor(ply) end)
concommand.Add(Config.DoorLockCommand, function(ply) Housing.LockLookedDoor(ply, true) end)
concommand.Add(Config.DoorUnlockCommand, function(ply) Housing.LockLookedDoor(ply, false) end)
concommand.Add(Config.DoorMenuCommand, function(ply) sendLookedDoorInfo(ply) end)
concommand.Add(Config.DoorAdminMenuCommand, function(ply) Housing.OpenAdmin(ply) end)
concommand.Add(Config.DoorSetPriceCommand, function(ply, _, args)
    Housing.SetLookedDoor(ply, args and args[1], table.concat(args or {}, " ", 2))
end)
concommand.Add(Config.DoorClearCommand, function(ply) Housing.ClearLookedDoor(ply) end)

local ulxRegistered = false

local function registerULXDoorCommands()
    if ulxRegistered or not ulx or not ULib or not ULib.cmds then return end
    ulxRegistered = true

    function ulx.zcitydoormenu(callingPly)
        Housing.OpenAdmin(callingPly)
    end

    local menuCmd = ulx.command("Z-City Aftermath", "ulx zcitydoormenu", ulx.zcitydoormenu, "!zcitydoormenu")
    menuCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    menuCmd:help("Open the Z-City door manager.")

    function ulx.zcitydoorsetprice(callingPly, price, name)
        Housing.SetLookedDoor(callingPly, price, name)
    end

    local priceCmd = ulx.command("Z-City Aftermath", "ulx zcitydoorsetprice", ulx.zcitydoorsetprice, "!zcitydoorsetprice")
    priceCmd:addParam{ type = ULib.cmds.NumArg, min = 0, default = Config.DefaultDoorPrice, hint = "price" }
    priceCmd:addParam{ type = ULib.cmds.StringArg, hint = "door name", ULib.cmds.optional }
    priceCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    priceCmd:help("Set the looked-at door price.")
end

timer.Simple(0, registerULXDoorCommands)
hook.Add("Initialize", "ZCityAftermath.RegisterULXDoorCommands", registerULXDoorCommands)
hook.Add("InitPostEntity", "ZCityAftermath.RegisterULXDoorCommandsLate", registerULXDoorCommands)
