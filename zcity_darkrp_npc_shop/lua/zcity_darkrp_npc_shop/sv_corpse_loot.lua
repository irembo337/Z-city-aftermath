ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.CorpseLoot = ZCityDarkRPShop.CorpseLoot or {}

local CorpseLoot = ZCityDarkRPShop.CorpseLoot
local Core = ZCityDarkRPShop.Core
local Net = ZCityDarkRPShop.Net

util.AddNetworkString("ZCityAftermath.CorpseLootState")
util.AddNetworkString("ZCityAftermath.CorpseLootTake")

local blockedWeapons = {
    gmod_tool = true,
    weapon_physgun = true,
    weapon_physcannon = true,
    weapon_hands = true,
    weapon_hands_sh = true,
    keys = true
}

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

local function trimText(value)
    return string.Trim(tostring(value or ""))
end

local function weaponName(class)
    local stored = weapons.GetStored(class)
    if stored and stored.PrintName and stored.PrintName ~= "" then
        return stored.PrintName
    end

    return class
end

local function weaponModel(weapon, class)
    if IsValid(weapon) and weapon.GetModel then
        local model = trimText(weapon:GetModel())
        if model ~= "" then
            return model
        end
    end

    local stored = weapons.GetStored(class)
    if stored and stored.WorldModel and stored.WorldModel ~= "" then
        return stored.WorldModel
    end

    return "models/weapons/w_pistol.mdl"
end

local function collectWeapons(ply)
    local items = {}

    for _, weapon in ipairs(ply:GetWeapons() or {}) do
        if not IsValid(weapon) then
            continue
        end

        local class = trimText(weapon:GetClass())
        if class == "" or blockedWeapons[class] then
            continue
        end

        items[#items + 1] = {
            class = class,
            name = weaponName(class),
            model = weaponModel(weapon, class),
            clip1 = weapon.Clip1 and math.max(-1, math.floor(weapon:Clip1() or -1)) or -1,
            clip2 = weapon.Clip2 and math.max(-1, math.floor(weapon:Clip2() or -1)) or -1
        }
    end

    table.sort(items, function(a, b)
        return string.lower(a.name or a.class or "") < string.lower(b.name or b.class or "")
    end)

    return items
end

local function collectAmmo(ply)
    local items = {}

    for ammoId = 0, 255 do
        local ammoType = game.GetAmmoName(ammoId)
        if ammoType then
            local amount = math.max(0, math.floor(tonumber(ply:GetAmmoCount(ammoType)) or 0))
            if amount > 0 then
                items[#items + 1] = {
                    ammoType = ammoType,
                    amount = amount
                }
            end
        end
    end

    table.sort(items, function(a, b)
        return string.lower(a.ammoType or "") < string.lower(b.ammoType or "")
    end)

    return items
end

local function collectAttachments(ply)
    local inventory = ply.GetNetVar and ply:GetNetVar("Inventory", {}) or {}
    local attachments = istable(inventory) and inventory.Attachments or nil
    local items = {}
    local seen = {}

    for _, attachmentId in ipairs(attachments or {}) do
        attachmentId = trimText(attachmentId)
        if attachmentId ~= "" and not seen[string.lower(attachmentId)] then
            seen[string.lower(attachmentId)] = true
            items[#items + 1] = attachmentId
        end
    end

    table.sort(items, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return items
end

local function hasLoot(loot)
    return istable(loot)
        and ((istable(loot.weapons) and #loot.weapons > 0)
        or (istable(loot.ammo) and #loot.ammo > 0)
        or (istable(loot.attachments) and #loot.attachments > 0))
end

local function buildLootPayload(ply)
    return {
        owner = IsValid(ply) and ply:Nick() or "",
        weapons = collectWeapons(ply),
        ammo = collectAmmo(ply),
        attachments = collectAttachments(ply)
    }
end

local function sanitizeClientLoot(loot)
    return {
        owner = trimText(loot and loot.owner),
        weapons = table.Copy((loot and loot.weapons) or {}),
        ammo = table.Copy((loot and loot.ammo) or {}),
        attachments = table.Copy((loot and loot.attachments) or {})
    }
end

local function findDeathRagdoll(ply, deathPos)
    if IsValid(ply) and ply.GetNWEntity then
        local ragdoll = ply:GetNWEntity("RagdollDeath")
        if IsValid(ragdoll) and ragdoll:GetClass() == "prop_ragdoll" then
            return ragdoll
        end
    end

    if IsValid(ply) and IsValid(ply.FakeRagdoll) then
        return ply.FakeRagdoll
    end

    local nearest
    local bestDist

    for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
        local dist = ent:GetPos():DistToSqr(deathPos)
        if dist <= 160000 and (not bestDist or dist < bestDist) then
            nearest = ent
            bestDist = dist
        end
    end

    return nearest
end

local function setRagdollLoot(ent, loot, owner)
    if not IsValid(ent) then
        return
    end

    ent.ZCityCorpseLoot = sanitizeClientLoot(loot)
    ent.ZCityCorpseLootOwner = IsValid(owner) and owner or nil
    ent:SetNWBool("ZCityAftermathHasCorpseLoot", hasLoot(ent.ZCityCorpseLoot))
end

local function clearRagdollLoot(ent)
    if not IsValid(ent) then
        return
    end

    ent.ZCityCorpseLoot = nil
    ent.ZCityCorpseLootOwner = nil
    ent:SetNWBool("ZCityAftermathHasCorpseLoot", false)
end

local function sendLootState(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then
        return
    end

    local loot = ent.ZCityCorpseLoot
    if not hasLoot(loot) then
        clearRagdollLoot(ent)
        notifyPlayer(ply, false, "На этом трупе больше ничего нет.")
        return
    end

    net.Start("ZCityAftermath.CorpseLootState")
        net.WriteEntity(ent)
        net.WriteString(util.TableToJSON(sanitizeClientLoot(loot), true) or "{}")
    net.Send(ply)
end

hook.Add("PlayerDeath", "ZCityAftermath.AttachCorpseLoot", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        return
    end

    local deathPos = ply:GetPos()
    local loot = buildLootPayload(ply)
    if not hasLoot(loot) then
        return
    end

    timer.Simple(0.1, function()
        if not IsValid(ply) then
            return
        end

        local ragdoll = findDeathRagdoll(ply, deathPos)
        if not IsValid(ragdoll) then
            return
        end

        setRagdollLoot(ragdoll, loot, ply)
    end)
end)

hook.Add("EntityRemoved", "ZCityAftermath.CorpseLootCleanup", function(ent)
    if not IsValid(ent) then
        return
    end

    if ent:GetClass() == "prop_ragdoll" and ent.ZCityCorpseLoot then
        clearRagdollLoot(ent)
    end
end)

hook.Add("KeyPress", "ZCityAftermath.OpenCorpseLoot", function(ply, key)
    if key ~= IN_USE or not IsValid(ply) or not ply:IsPlayer() then
        return
    end

    local trace = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 110,
        filter = ply
    })

    local ent = trace.Entity
    if not IsValid(ent) or ent:GetClass() ~= "prop_ragdoll" then
        return
    end

    if ply:GetPos():DistToSqr(ent:GetPos()) > 22500 then
        return
    end

    if not ent:GetNWBool("ZCityAftermathHasCorpseLoot", false) then
        return
    end

    sendLootState(ply, ent)
end)

local function takeWeapon(ply, item)
    if not istable(item) then
        return false, "Предмет не найден."
    end

    local class = trimText(item.class)
    if class == "" then
        return false, "Некорректное оружие."
    end

    local weapon = ply:Give(class)
    if not IsValid(weapon) and not ply:HasWeapon(class) then
        return false, "Не удалось выдать оружие."
    end

    local activeWeapon = IsValid(weapon) and weapon or ply:GetWeapon(class)
    if IsValid(activeWeapon) then
        if activeWeapon.SetClip1 and tonumber(item.clip1) and tonumber(item.clip1) >= 0 then
            activeWeapon:SetClip1(math.floor(tonumber(item.clip1)))
        end

        if activeWeapon.SetClip2 and tonumber(item.clip2) and tonumber(item.clip2) >= 0 then
            activeWeapon:SetClip2(math.floor(tonumber(item.clip2)))
        end
    end

    return true
end

local function takeAmmo(ply, item)
    if not istable(item) then
        return false, "Боеприпасы не найдены."
    end

    local ammoType = trimText(item.ammoType)
    local amount = math.max(1, math.floor(tonumber(item.amount) or 0))
    if ammoType == "" then
        return false, "Некорректный тип патронов."
    end

    ply:GiveAmmo(amount, ammoType, true)
    return true
end

local function takeAttachment(ply, attachmentId)
    attachmentId = trimText(attachmentId)
    if attachmentId == "" then
        return false, "Обвес не найден."
    end

    if Core and Core.GiveZCityAttachment then
        return Core.GiveZCityAttachment(ply, {
            class = attachmentId,
            attachmentId = attachmentId,
            zcityId = attachmentId
        })
    end

    return false, "Система обвесов недоступна."
end

net.Receive("ZCityAftermath.CorpseLootTake", function(_, ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        return
    end

    local ent = net.ReadEntity()
    local bucket = trimText(net.ReadString())
    local index = math.max(1, net.ReadUInt(8))

    if not IsValid(ent) or ent:GetClass() ~= "prop_ragdoll" then
        return
    end

    if ply:GetPos():DistToSqr(ent:GetPos()) > 22500 then
        return
    end

    local loot = ent.ZCityCorpseLoot
    if not hasLoot(loot) then
        clearRagdollLoot(ent)
        return
    end

    local success, reason

    if bucket == "weapon" then
        local item = loot.weapons[index]
        success, reason = takeWeapon(ply, item)
        if success then
            table.remove(loot.weapons, index)
        end
    elseif bucket == "ammo" then
        local item = loot.ammo[index]
        success, reason = takeAmmo(ply, item)
        if success then
            table.remove(loot.ammo, index)
        end
    elseif bucket == "attachment" then
        local item = loot.attachments[index]
        success, reason = takeAttachment(ply, item)
        if success then
            table.remove(loot.attachments, index)
        end
    elseif bucket == "all" then
        local hadAny = false

        for i = #loot.weapons, 1, -1 do
            local ok = takeWeapon(ply, loot.weapons[i])
            if ok then
                hadAny = true
                table.remove(loot.weapons, i)
            end
        end

        for i = #loot.ammo, 1, -1 do
            local ok = takeAmmo(ply, loot.ammo[i])
            if ok then
                hadAny = true
                table.remove(loot.ammo, i)
            end
        end

        for i = #loot.attachments, 1, -1 do
            local ok = takeAttachment(ply, loot.attachments[i])
            if ok then
                hadAny = true
                table.remove(loot.attachments, i)
            end
        end

        if hadAny then
            success = true
        else
            success = false
            reason = "Не удалось забрать лут."
        end
    end

    if not success then
        notifyPlayer(ply, false, reason or "Не удалось забрать лут.")
        return
    end

    if not hasLoot(loot) then
        clearRagdollLoot(ent)
        notifyPlayer(ply, true, "Труп полностью облутан.")
        return
    end

    ent.ZCityCorpseLoot = loot
    ent:SetNWBool("ZCityAftermathHasCorpseLoot", true)
    sendLootState(ply, ent)
end)
