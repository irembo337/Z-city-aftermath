ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Backpack = ZCityDarkRPShop.Backpack or {}

local Backpack = ZCityDarkRPShop.Backpack
local Config = ZCityDarkRPShop.Config
local Net = ZCityDarkRPShop.Net

util.AddNetworkString("ZCityAftermath.RequestBackpack")
util.AddNetworkString("ZCityAftermath.BackpackState")
util.AddNetworkString("ZCityAftermath.BackpackAction")

local pdataKey = "zcity_aftermath_backpack_v1"
local blockedWeapons = {
    gmod_tool = true,
    weapon_physgun = true,
    weapon_physcannon = true,
    keys = true
}

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

local function weaponName(class)
    local stored = weapons.GetStored(class)
    if stored and stored.PrintName and stored.PrintName ~= "" then
        return stored.PrintName
    end

    return class
end

local function weaponModel(weapon, class)
    if IsValid(weapon) and weapon:GetModel() and weapon:GetModel() ~= "" then
        return weapon:GetModel()
    end

    local stored = weapons.GetStored(class)
    if stored and stored.WorldModel and stored.WorldModel ~= "" then
        return stored.WorldModel
    end

    return "models/weapons/w_pistol.mdl"
end

local function sanitizeItem(item)
    if not istable(item) then return nil end

    local class = string.Trim(tostring(item.class or ""))
    if class == "" then return nil end

    return {
        kind = item.kind == "entity" and "entity" or "weapon",
        class = string.sub(class, 1, 96),
        name = string.sub(string.Trim(tostring(item.name or class)), 1, 64),
        model = string.sub(string.Trim(tostring(item.model or "")), 1, 128),
        clip1 = math.Clamp(math.floor(tonumber(item.clip1) or -1), -1, 9999),
        clip2 = math.Clamp(math.floor(tonumber(item.clip2) or -1), -1, 9999)
    }
end

local function sanitizeItems(items)
    local clean = {}

    for _, item in ipairs(items or {}) do
        local cleanItem = sanitizeItem(item)
        if cleanItem then
            clean[#clean + 1] = cleanItem
        end

        if #clean >= Config.MaxBackpackItems then
            break
        end
    end

    return clean
end

function Backpack.Load(ply)
    if not IsValid(ply) then return end

    local decoded = util.JSONToTable(ply:GetPData(pdataKey, "[]") or "[]")
    ply.ZCityBackpack = sanitizeItems(istable(decoded) and decoded or {})
end

function Backpack.Save(ply)
    if not IsValid(ply) then return end

    ply.ZCityBackpack = sanitizeItems(ply.ZCityBackpack or {})
    ply:SetPData(pdataKey, util.TableToJSON(ply.ZCityBackpack, true) or "[]")
end

function Backpack.Send(ply)
    if not IsValid(ply) then return end

    ply.ZCityBackpack = sanitizeItems(ply.ZCityBackpack or {})

    net.Start("ZCityAftermath.BackpackState")
        net.WriteTable(ply.ZCityBackpack)
    net.Send(ply)
end

local function canAdd(ply)
    ply.ZCityBackpack = sanitizeItems(ply.ZCityBackpack or {})

    if #ply.ZCityBackpack >= Config.MaxBackpackItems then
        notifyPlayer(ply, false, "Backpack is full.")
        return false
    end

    return true
end

local function storeActiveWeapon(ply)
    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) or not weapon:IsWeapon() then
        return false
    end

    local class = weapon:GetClass()
    if blockedWeapons[class] then
        notifyPlayer(ply, false, "This item cannot be stored.")
        return true
    end

    local item = {
        kind = "weapon",
        class = class,
        name = weaponName(class),
        model = weaponModel(weapon, class),
        clip1 = weapon:Clip1(),
        clip2 = weapon:Clip2()
    }

    ply.ZCityBackpack[#ply.ZCityBackpack + 1] = item
    ply:StripWeapon(class)
    Backpack.Save(ply)
    Backpack.Send(ply)
    notifyPlayer(ply, true, "Stored: " .. item.name)
    return true
end

local function storeLookedWeapon(ply)
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity

    if not IsValid(ent) or ply:GetPos():DistToSqr(ent:GetPos()) > 22500 then
        return false
    end

    if not ent:IsWeapon() then
        return false
    end

    local class = ent:GetClass()
    if blockedWeapons[class] then
        notifyPlayer(ply, false, "This item cannot be stored.")
        return true
    end

    local item = {
        kind = "weapon",
        class = class,
        name = weaponName(class),
        model = weaponModel(ent, class),
        clip1 = ent.Clip1 and ent:Clip1() or -1,
        clip2 = ent.Clip2 and ent:Clip2() or -1
    }

    ply.ZCityBackpack[#ply.ZCityBackpack + 1] = item
    ent:Remove()
    Backpack.Save(ply)
    Backpack.Send(ply)
    notifyPlayer(ply, true, "Stored: " .. item.name)
    return true
end

local function storeLookedEntity(ply)
    local tr = ply:GetEyeTrace()
    local ent = tr.Entity

    if not IsValid(ent) or ply:GetPos():DistToSqr(ent:GetPos()) > 22500 then
        return false
    end

    local Cameras = ZCityDarkRPShop and ZCityDarkRPShop.Cameras or nil
    local className = ent:GetClass()
    local supported = Cameras and (
        (Cameras.IsCameraItemClass and Cameras.IsCameraItemClass(className))
        or (Cameras.IsTabletPickupClass and Cameras.IsTabletPickupClass(className))
        or (Cameras.IsAttachmentTokenClass and Cameras.IsAttachmentTokenClass(className))
    )

    if not supported then
        return false
    end

    local item = {
        kind = "entity",
        class = className,
        name = string.Trim(tostring(ent.PrintName or className or "Stored Item")),
        model = string.Trim(tostring(ent:GetModel() or (Cameras and Cameras.GetCameraModel and Cameras.GetCameraModel() or "")))
    }

    ply.ZCityBackpack[#ply.ZCityBackpack + 1] = item
    ent:Remove()
    Backpack.Save(ply)
    Backpack.Send(ply)
    notifyPlayer(ply, true, "Stored: " .. item.name)
    return true
end

function Backpack.Put(ply)
    if not IsValid(ply) or not canAdd(ply) then return end

    if storeActiveWeapon(ply) then return end
    if storeLookedWeapon(ply) then return end
    if storeLookedEntity(ply) then return end

    notifyPlayer(ply, false, "Hold a weapon or look at a supported item to store it.")
end

function Backpack.Take(ply, index)
    if not IsValid(ply) then return end

    index = math.floor(tonumber(index) or 0)
    ply.ZCityBackpack = sanitizeItems(ply.ZCityBackpack or {})

    local item = ply.ZCityBackpack[index]
    if not item then
        notifyPlayer(ply, false, "Backpack item not found.")
        return
    end

    if item.kind == "weapon" then
        local weapon = ply:Give(item.class)
        if IsValid(weapon) then
            if weapon.SetClip1 and item.clip1 >= 0 then weapon:SetClip1(item.clip1) end
            if weapon.SetClip2 and item.clip2 >= 0 then weapon:SetClip2(item.clip2) end
            ply:SelectWeapon(item.class)
        end
    else
        local ent = ents.Create(item.class)
        if not IsValid(ent) then
            notifyPlayer(ply, false, "Could not create this item.")
            return
        end

        ent:SetPos(ply:GetShootPos() + ply:GetAimVector() * 48)
        ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
        ent:Spawn()
    end

    table.remove(ply.ZCityBackpack, index)
    Backpack.Save(ply)
    Backpack.Send(ply)
    notifyPlayer(ply, true, "Taken: " .. item.name)
end

function Backpack.Drop(ply, index)
    if not IsValid(ply) then return end

    index = math.floor(tonumber(index) or 0)
    ply.ZCityBackpack = sanitizeItems(ply.ZCityBackpack or {})

    local item = ply.ZCityBackpack[index]
    if not item then
        notifyPlayer(ply, false, "Backpack item not found.")
        return
    end

    local ent = ents.Create(item.class)
    if not IsValid(ent) then
        notifyPlayer(ply, false, "Could not drop this item.")
        return
    end

    ent:SetPos(ply:GetShootPos() + ply:GetAimVector() * 48)
    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ent:Spawn()

    table.remove(ply.ZCityBackpack, index)
    Backpack.Save(ply)
    Backpack.Send(ply)
    notifyPlayer(ply, true, "Dropped: " .. item.name)
end

hook.Add("PlayerInitialSpawn", "ZCityAftermath.BackpackLoad", function(ply)
    Backpack.Load(ply)
end)

hook.Add("PlayerDisconnected", "ZCityAftermath.BackpackSave", function(ply)
    Backpack.Save(ply)
end)

net.Receive("ZCityAftermath.RequestBackpack", function(_, ply)
    if not ply.ZCityBackpack then
        Backpack.Load(ply)
    end

    Backpack.Send(ply)
end)

net.Receive("ZCityAftermath.BackpackAction", function(_, ply)
    local action = net.ReadString()

    if action == "put" then
        Backpack.Put(ply)
    elseif action == "take" then
        Backpack.Take(ply, net.ReadUInt(8))
    elseif action == "drop" then
        Backpack.Drop(ply, net.ReadUInt(8))
    end
end)

concommand.Add(Config.BackpackCommand, function(ply)
    Backpack.Send(ply)
end)

concommand.Add(Config.BackpackPutCommand, function(ply)
    Backpack.Put(ply)
end)
