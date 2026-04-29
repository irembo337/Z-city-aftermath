ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Core = ZCityDarkRPShop.Core or {}

local Core = ZCityDarkRPShop.Core
local Config = ZCityDarkRPShop.Config
local Storage = ZCityDarkRPShop.Storage

Core.Items = Core.Items or {}
Core.NPCRecords = Core.NPCRecords or {}
Core.Settings = Core.Settings or {}
Core.DetectedCatalog = Core.DetectedCatalog or nil

local armorKeywords = { "armor", "armour", "vest", "kevlar", "helmet", "plate" }
local ammoKeywords = { "ammo", "round", "mag", "magazine", "bullet", "shell" }
local attachmentKeywords = { "attachment", "optic", "scope", "sight", "grip", "laser", "suppressor", "silencer", "stock", "barrel", "muzzle", "rail" }
local weaponKeywords = { "weapon", "gun", "rifle", "pistol", "smg", "shotgun", "sniper", "revolver", "launcher", "grenade", "tfa", "arc9", "m9k", "cw", "ins2", "fas2", "swep" }

local function containsKeyword(haystack, keywords)
    for _, keyword in ipairs(keywords) do
        if string.find(haystack, keyword, 1, true) then
            return true
        end
    end

    return false
end

local function classifyCandidate(name, className, defaultCategory)
    local haystack = string.lower(string.format("%s %s", tostring(name or ""), tostring(className or "")))

    if containsKeyword(haystack, armorKeywords) then
        return "armor"
    end

    if containsKeyword(haystack, ammoKeywords) then
        return "ammo"
    end

    if containsKeyword(haystack, attachmentKeywords) then
        return "attachment"
    end

    if defaultCategory then
        return defaultCategory
    end

    if containsKeyword(haystack, weaponKeywords) then
        return "weapon"
    end

    return "misc"
end

local function darkRPReady()
    return DarkRP ~= nil
end

local function sortCandidates(items)
    table.sort(items, function(left, right)
        local leftName = string.lower(left.name or left.class or "")
        local rightName = string.lower(right.name or right.class or "")

        if leftName == rightName then
            return string.lower(left.class or "") < string.lower(right.class or "")
        end

        return leftName < rightName
    end)
end

local function prettifyClassName(className)
    local text = tostring(className or "")
    text = string.gsub(text, "%.lua$", "")
    text = string.gsub(text, "^weapon_", "")
    text = string.gsub(text, "[%._%-]+", " ")
    text = string.Trim(text)
    text = string.gsub(text, "%s+", " ")

    if text == "" then
        return tostring(className or "Unknown")
    end

    return string.gsub(text, "(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)
end

local ammoAmountByType = {
    pistol = 48,
    ["357"] = 18,
    smg1 = 90,
    ar2 = 60,
    buckshot = 20,
    xbowbolt = 8,
    ["rpg_round"] = 3,
    grenade = 1,
    slam = 1,
    alyxgun = 36,
    sniperround = 12,
    ["sniperpenetratedround"] = 8,
    airboatgun = 40,
    striderminigun = 120,
    gaussenergy = 18
}

local function resolveAmmoType(className)
    local rawClass = string.Trim(tostring(className or ""))
    if rawClass == "" then
        return nil
    end

    if game.GetAmmoID(rawClass) >= 0 then
        return rawClass
    end

    local lowered = string.lower(rawClass)
    for ammoType in pairs(ammoAmountByType) do
        if lowered == ammoType or string.find(lowered, ammoType, 1, true) then
            return ammoType
        end
    end

    local ammoList = list.Get("Ammo") or {}
    for ammoType, ammoData in pairs(ammoList) do
        local loweredType = string.lower(tostring(ammoType or ""))
        local loweredName = string.lower(tostring(istable(ammoData) and ammoData.name or ""))
        if lowered == loweredType or lowered == loweredName then
            return ammoType
        end

        if loweredType ~= "" and string.find(lowered, loweredType, 1, true) then
            return ammoType
        end
    end
end

local function defaultAmmoAmount(ammoType)
    local lowered = string.lower(tostring(ammoType or ""))
    return ammoAmountByType[lowered] or 30
end

local function trimOptional(value)
    local text = string.Trim(tostring(value or ""))
    return text ~= "" and text or nil
end

local function stripPrefix(value, prefix)
    local text = trimOptional(value)
    if not text then
        return nil
    end

    if prefix and string.StartWith(string.lower(text), string.lower(prefix)) then
        return string.sub(text, #prefix + 1)
    end

    return text
end

local function itemModelFromEntry(entry)
    if not istable(entry) then
        return nil
    end

    return trimOptional(entry.WorldModel)
        or trimOptional(entry.Model)
        or trimOptional(entry.model)
        or trimOptional(entry.WorldModelOverride)
end

local function addMetadata(candidate, metadata)
    if not istable(metadata) then
        return candidate
    end

    for key, value in pairs(metadata) do
        if value ~= nil and value ~= "" then
            candidate[key] = value
        end
    end

    return candidate
end

local function isZCityItem(item, category)
    local sourceType = string.lower(tostring(item and item.sourceType or ""))
    local zcityType = string.lower(tostring(item and item.zcityType or ""))
    local className = string.lower(tostring(item and item.class or ""))

    if sourceType == "zcity" then
        return true
    end

    if zcityType ~= "" and zcityType == string.lower(tostring(category or "")) then
        return true
    end

    if category == "armor" then
        return string.StartWith(className, "ent_armor_")
    end

    if category == "ammo" then
        return string.StartWith(className, "ent_ammo_")
    end

    if category == "attachment" then
        return string.StartWith(className, "ent_att_")
    end

    return false
end

local function addInventoryAttachment(ply, attachmentId)
    if not IsValid(ply) or not attachmentId or attachmentId == "" then
        return false
    end

    local inv = ply.GetNetVar and ply:GetNetVar("Inventory", {}) or {}
    if not istable(inv) then
        inv = {}
    end

    inv.Attachments = inv.Attachments or {}
    inv.Attachments[#inv.Attachments + 1] = attachmentId

    if ply.SetNetVar then
        ply:SetNetVar("Inventory", inv)
    end

    return true
end

local function giveZCityArmor(ply, item)
    local armorClass = trimOptional(item and item.armorClass)
        or trimOptional(item and item.class)
        or trimOptional(item and item.zcityId)

    if not armorClass then
        return false, "Missing Z-City armor id."
    end

    if not string.StartWith(string.lower(armorClass), "ent_armor_") then
        armorClass = "ent_armor_" .. armorClass
    end

    if hg and hg.AddArmor then
        hg.AddArmor(ply, armorClass)
        return true
    end

    local currentArmor = math.max(0, math.floor(tonumber(ply:Armor()) or 0))
    ply:SetArmor(math.Clamp(math.max(currentArmor, 100), 0, 255))
    return true
end

local function resolveZCityAmmo(item)
    local zcityId = trimOptional(item and item.zcityId)
        or stripPrefix(item and item.class, "ent_ammo_")
        or trimOptional(item and item.ammoType)

    local ammoData
    if zcityId and hg and istable(hg.ammotypes) then
        ammoData = hg.ammotypes[zcityId]
    end

    if not ammoData and zcityId and hg and istable(hg.ammotypeshuy) then
        ammoData = hg.ammotypeshuy[zcityId]
    end

    local ammoName = trimOptional(item and item.ammoType)
        or trimOptional(istable(ammoData) and ammoData.name)
        or zcityId

    local amount = math.max(0, math.floor(tonumber(item and item.ammoAmount) or 0))
    if amount <= 0 and hg and istable(hg.ammoents) and ammoName and istable(hg.ammoents[ammoName]) then
        amount = math.max(1, math.floor(tonumber(hg.ammoents[ammoName].Count) or 0))
    end

    local ammoType = resolveAmmoType(ammoName or "")
    if not ammoType then
        ammoType = resolveAmmoType(item and item.class or "")
    end

    if amount <= 0 then
        amount = defaultAmmoAmount(ammoType or ammoName)
    end

    return ammoType, amount
end

local function giveZCityAmmo(ply, item)
    local ammoType, amount = resolveZCityAmmo(item)
    if not ammoType then
        return false, "Could not resolve the Z-City ammo type."
    end

    ply:GiveAmmo(amount, ammoType, true)
    return true
end

local function giveZCityAttachment(ply, item)
    local attachmentId = trimOptional(item and item.attachmentId)
        or trimOptional(item and item.zcityId)
        or stripPrefix(item and item.class, "ent_att_")

    if not attachmentId then
        return false, "Missing Z-City attachment id."
    end

    if addInventoryAttachment(ply, attachmentId) then
        return true
    end

    return false, "Could not store the Z-City attachment in inventory."
end

Core.GiveZCityArmor = giveZCityArmor
Core.GiveZCityAmmo = giveZCityAmmo
Core.GiveZCityAttachment = giveZCityAttachment

local function flattenZCityAttachments(root, callback, pathLabel, seenIds)
    if not istable(root) then
        return
    end

    seenIds = seenIds or {}

    for key, value in pairs(root) do
        if isstring(key) and istable(value) then
            local attachmentName = trimOptional(value.PrintName)
                or trimOptional(value.name)
                or trimOptional(value.displayName)

            if attachmentName then
                if not seenIds[key] then
                    seenIds[key] = true
                    callback(key, value, pathLabel)
                end
            else
                flattenZCityAttachments(value, callback, tostring(key), seenIds)
            end
        end
    end
end

local function extractPrintName(fileContents)
    if not fileContents or fileContents == "" then
        return nil
    end

    local value = fileContents:match('SWEP%.PrintName%s*=%s*"([^"]+)"')
        or fileContents:match("SWEP%.PrintName%s*=%s*'([^']+)'")
        or fileContents:match('PrintName%s*=%s*"([^"]+)"')
        or fileContents:match("PrintName%s*=%s*'([^']+)'")

    value = string.Trim(tostring(value or ""))
    return value ~= "" and value or nil
end

local function detectMountedWeaponName(pathPrefix, className, isSingleFile)
    local filesToCheck

    if isSingleFile then
        filesToCheck = { pathPrefix }
    else
        filesToCheck = {
            pathPrefix .. "/shared.lua",
            pathPrefix .. "/init.lua",
            pathPrefix .. "/cl_init.lua"
        }
    end

    for _, path in ipairs(filesToCheck) do
        if file.Exists(path, "GAME") then
            local detectedName = extractPrintName(file.Read(path, "GAME"))
            if detectedName then
                return detectedName
            end
        end
    end

    return prettifyClassName(className)
end

function Core.IsULXLoaded()
    return ULib ~= nil and ULib.ucl ~= nil
end

function Core.CanManageShop(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        return false, "Player access is required."
    end

    if not Core.IsULXLoaded() then
        return false, "ULX/ULib is required for trader management."
    end

    local group = string.lower((ply.GetUserGroup and ply:GetUserGroup()) or "")
    if Config.AllowedULXGroups[group] then
        return true
    end

    return false, "Only ULX admin or superadmin can manage this trader."
end

function Core.GetManagerGroup(ply)
    if not IsValid(ply) or not ply:IsPlayer() or not ply.GetUserGroup then
        return ""
    end

    return string.lower(ply:GetUserGroup() or "")
end

function Core.FormatMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))

    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(amount)
    end

    return "$" .. tostring(amount)
end

function Core.GetBalance(ply)
    if not IsValid(ply) then return 0 end

    if ply.getDarkRPVar then
        return math.max(0, math.floor(tonumber(ply:getDarkRPVar("money")) or 0))
    end

    return 0
end

function Core.CanAfford(ply, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))

    if not darkRPReady() then
        return false
    end

    if ply.canAfford then
        return ply:canAfford(amount)
    end

    return Core.GetBalance(ply) >= amount
end

function Core.TakeMoney(ply, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))

    if not darkRPReady() then
        return false, "DarkRP is not loaded."
    end

    if not Core.CanAfford(ply, amount) then
        return false, "Not enough money."
    end

    if ply.addMoney then
        ply:addMoney(-amount)
        return true
    end

    return false, "DarkRP money API is unavailable."
end

function Core.RefundMoney(ply, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))

    if darkRPReady() and ply.addMoney then
        ply:addMoney(amount)
    end
end

function Core.LoadCatalog()
    Core.Items = Storage.LoadItems()
    return Core.Items
end

function Core.SaveCatalog(items)
    Core.Items = Storage.SaveItems(items)
    return Core.Items
end

function Core.GetItems()
    return table.Copy(Core.Items or {})
end

function Core.LoadSettings()
    Core.Settings = Storage.LoadSettings()
    return Core.Settings
end

function Core.SaveSettings(settings)
    Core.Settings = Storage.SaveSettings(settings)

    for _, ent in ipairs(ents.FindByClass(Config.NPCClass)) do
        if IsValid(ent) then
            ent:SetNWString("ZCityDarkRPShopNPCName", Core.Settings.npcName or Config.NPCName)
        end
    end

    return Core.Settings
end

function Core.GetNPCName()
    return (Core.Settings and Core.Settings.npcName) or Config.NPCName
end

function Core.LoadNPCs()
    Core.NPCRecords = Storage.LoadNPCRecords()
    return Core.NPCRecords
end

function Core.SaveNPCs(records)
    Core.NPCRecords = Storage.SaveNPCRecords(records)
    return Core.NPCRecords
end

function Core.ApplyNPCSettings(ent)
    if not IsValid(ent) then return end

    ent:SetNWString("ZCityDarkRPShopNPCName", Core.GetNPCName())
end

function Core.SpawnNPC(record, index)
    local ent = ents.Create(Config.NPCClass)
    if not IsValid(ent) then
        return nil
    end

    ent:SetPos(Vector(record.pos.x, record.pos.y, record.pos.z))
    ent:SetAngles(Angle(record.ang.p, record.ang.y, record.ang.r))
    ent.NPCModelOverride = record.model
    ent.ZCityShopRecordIndex = index
    ent.ZCityPersistentShopNPC = true
    ent:Spawn()
    ent:Activate()
    Core.ApplyNPCSettings(ent)

    return ent
end

function Core.ClearSpawnedNPCs()
    for _, ent in ipairs(ents.FindByClass(Config.NPCClass)) do
        if ent.ZCityPersistentShopNPC then
            ent:Remove()
        end
    end
end

function Core.RespawnNPCs()
    Core.ClearSpawnedNPCs()

    for index, record in ipairs(Core.NPCRecords or {}) do
        Core.SpawnNPC(record, index)
    end
end

function Core.AddNPCFromPlayer(ply)
    local allowed, reason = Core.CanManageShop(ply)
    if not allowed then
        return false, reason
    end

    local trace = ply:GetEyeTrace()
    if not trace.Hit then
        return false, "Aim at the floor or a wall first."
    end

    local pos = trace.HitPos + trace.HitNormal * 6
    local ang = Angle(0, ply:EyeAngles().y - 180, 0)

    local record = {
        pos = { x = pos.x, y = pos.y, z = pos.z },
        ang = { p = ang.p, y = ang.y, r = ang.r },
        model = Config.NPCModel
    }

    local records = table.Copy(Core.NPCRecords or {})
    records[#records + 1] = record
    Core.SaveNPCs(records)
    Core.RespawnNPCs()

    return true, "Shop NPC spawned and saved for this map."
end

function Core.RemoveLookedAtNPC(ply)
    local allowed, reason = Core.CanManageShop(ply)
    if not allowed then
        return false, reason
    end

    local trace = ply:GetEyeTrace()
    local ent = trace.Entity

    if not IsValid(ent) or ent:GetClass() ~= Config.NPCClass or not ent.ZCityPersistentShopNPC then
        return false, "Look directly at a shop NPC."
    end

    local index = ent.ZCityShopRecordIndex
    if not index or not Core.NPCRecords[index] then
        return false, "Could not match this NPC to saved data."
    end

    local records = table.Copy(Core.NPCRecords)
    table.remove(records, index)
    Core.SaveNPCs(records)
    Core.RespawnNPCs()

    return true, "Shop NPC removed from this map."
end

function Core.RemoveAllNPCs(ply)
    if IsValid(ply) then
        local allowed, reason = Core.CanManageShop(ply)
        if not allowed then
            return false, reason
        end
    end

    Core.SaveNPCs({})
    Core.RespawnNPCs()

    return true, "All shop NPCs were removed from this map."
end

function Core.FindItem(itemId)
    for _, item in ipairs(Core.Items or {}) do
        if item.id == itemId then
            return item
        end
    end
end

function Core.GivePurchasedItem(ply, item)
    local category = Storage.NormalizeCategory(item.category)

    if category == "armor" then
        if isZCityItem(item, category) then
            local success, reason = giveZCityArmor(ply, item)
            if not success then
                return false, reason
            end

            return true
        end

        local currentArmor = math.max(0, math.floor(tonumber(ply:Armor()) or 0))
        ply:SetArmor(math.Clamp(math.max(currentArmor, 100), 0, 255))
        return true
    end

    if category == "ammo" then
        if isZCityItem(item, category) then
            local success, reason = giveZCityAmmo(ply, item)
            if not success then
                return false, reason
            end

            return true
        end

        local ammoType = resolveAmmoType(item.class)
        if not ammoType then
            return false, "Could not resolve the ammo type for this item."
        end

        ply:GiveAmmo(defaultAmmoAmount(ammoType), ammoType, true)
        return true
    end

    if category == "attachment" then
        if isZCityItem(item, category) then
            local success, reason = giveZCityAttachment(ply, item)
            if not success then
                return false, reason
            end

            return true
        end

        local trace = ply:GetEyeTraceNoCursor()
        local spawnPos = trace.HitPos + trace.HitNormal * 20
        local ent = ents.Create(Config.AttachmentTokenClass)

        if not IsValid(ent) then
            return false, "Could not create the attachment token."
        end

        ent:SetPos(spawnPos)
        ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
        ent:Spawn()
        ent:Activate()

        if ent.SetAttachmentId then
            ent:SetAttachmentId(item.class or "")
        end

        if ent.SetAttachmentName then
            ent:SetAttachmentName(item.name or item.class or "Attachment")
        end

        return true
    end

    if item.kind == "weapon" then
        local weapon = ply:Give(item.class)
        if IsValid(weapon) or ply:HasWeapon(item.class) then
            ply:SelectWeapon(item.class)
            return true
        end

        return false, "Could not give the weapon."
    end

    local trace = ply:GetEyeTraceNoCursor()
    local spawnPos = trace.HitPos + trace.HitNormal * 20
    local ent = ents.Create(item.class)

    if not IsValid(ent) then
        return false, "Could not spawn the entity."
    end

    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ent:Spawn()
    ent:Activate()

    local physicsObject = ent:GetPhysicsObject()
    if IsValid(physicsObject) then
        physicsObject:Wake()
    end

    return true
end

function Core.PurchaseItem(ply, itemId)
    if not IsValid(ply) or not ply:IsPlayer() then
        return false, "Invalid buyer."
    end

    if not darkRPReady() then
        return false, "DarkRP is required for this shop."
    end

    local item = Core.FindItem(itemId)
    if not item then
        return false, "Item not found."
    end

    local taken, reason = Core.TakeMoney(ply, item.price)
    if not taken then
        return false, reason or "Could not take money."
    end

    local success, giveReason = Core.GivePurchasedItem(ply, item)
    if not success then
        Core.RefundMoney(ply, item.price)
        return false, giveReason or "Purchase failed."
    end

    return true, string.format("You bought %s for %s.", item.name, Core.FormatMoney(item.price))
end

function Core.AddCandidate(container, seen, bucket, candidate)
    if not candidate or not bucket or bucket == "misc" then
        return
    end

    local key = string.lower(string.format(
        "%s|%s|%s",
        bucket,
        candidate.class or "",
        candidate.kind or ""
    ))

    if seen[key] then
        return
    end

    seen[key] = true
    candidate.category = bucket
    container[bucket][#container[bucket] + 1] = candidate
end

function Core.ScanLoadedContent()
    local detected = {
        weapon = {},
        armor = {},
        ammo = {},
        attachment = {}
    }

    local seen = {}

    local function addDetected(name, className, kind, source, defaultCategory, importable, metadata)
        local category = classifyCandidate(name, className, defaultCategory)
        local candidate = {
            name = string.Trim(tostring(name or "")) ~= "" and tostring(name) or tostring(className or "Unknown"),
            class = tostring(className or ""),
            kind = kind or "",
            source = tostring(source or "Unknown"),
            importable = importable == true
        }

        addMetadata(candidate, metadata)
        Core.AddCandidate(detected, seen, category, candidate)
    end

    if hg then
        local ammoSeen = {}

        for ammoId, ammoData in pairs((istable(hg.ammotypeshuy) and hg.ammotypeshuy) or {}) do
            if isstring(ammoId) and ammoId ~= "" and not ammoSeen[ammoId] then
                ammoSeen[ammoId] = true
                local ammoName = trimOptional(istable(ammoData) and ammoData.name) or prettifyClassName(ammoId)
                local ammoAmount = hg.ammoents and ammoName and istable(hg.ammoents[ammoName]) and tonumber(hg.ammoents[ammoName].Count) or nil
                addDetected(ammoName, "ent_ammo_" .. ammoId, "entity", "Z-City Ammo", "ammo", true, {
                    sourceType = "zcity",
                    zcityType = "ammo",
                    zcityId = ammoId,
                    ammoType = ammoName,
                    ammoAmount = ammoAmount
                })
            end
        end

        for ammoId, ammoData in pairs((istable(hg.ammotypes) and hg.ammotypes) or {}) do
            if isstring(ammoId) and ammoId ~= "" and not ammoSeen[ammoId] then
                ammoSeen[ammoId] = true
                local ammoName = trimOptional(istable(ammoData) and ammoData.name) or prettifyClassName(ammoId)
                local ammoAmount = hg.ammoents and ammoName and istable(hg.ammoents[ammoName]) and tonumber(hg.ammoents[ammoName].Count) or nil
                addDetected(ammoName, "ent_ammo_" .. ammoId, "entity", "Z-City Ammo", "ammo", true, {
                    sourceType = "zcity",
                    zcityType = "ammo",
                    zcityId = ammoId,
                    ammoType = ammoName,
                    ammoAmount = ammoAmount
                })
            end
        end

        flattenZCityAttachments(hg.validattachments, function(attachmentId, data, bucketName)
            addDetected(
                trimOptional(data.PrintName) or trimOptional(data.name) or trimOptional(data.displayName) or prettifyClassName(attachmentId),
                "ent_att_" .. attachmentId,
                "entity",
                "Z-City Attachment" .. (bucketName and (" / " .. tostring(bucketName)) or ""),
                "attachment",
                true,
                {
                    sourceType = "zcity",
                    zcityType = "attachment",
                    zcityId = attachmentId,
                    attachmentId = attachmentId,
                    model = itemModelFromEntry(data)
                }
            )
        end)
    end

    for _, swep in ipairs(weapons.GetList() or {}) do
        local className = swep.ClassName or swep.Class or swep.Classname
        if className and className ~= "" then
            addDetected(swep.PrintName or className, className, "weapon", swep.Category or "SWEP", "weapon", true, {
                model = itemModelFromEntry(swep)
            })
        end
    end

    local weaponFiles, weaponFolders = file.Find("lua/weapons/*", "GAME")

    for _, folderName in ipairs(weaponFolders or {}) do
        local className = string.Trim(folderName or "")
        if className ~= "" then
                addDetected(
                    detectMountedWeaponName("lua/weapons/" .. className, className, false),
                    className,
                    "weapon",
                    "Mounted lua/weapons",
                    "weapon",
                    true,
                    {}
                )
            end
        end

    for _, fileName in ipairs(weaponFiles or {}) do
        if string.EndsWith(string.lower(fileName or ""), ".lua") then
            local className = string.gsub(fileName, "%.lua$", "")
            className = string.Trim(className or "")

            if className ~= "" then
                addDetected(
                    detectMountedWeaponName("lua/weapons/" .. fileName, className, true),
                    className,
                    "weapon",
                    "Mounted lua/weapons",
                    "weapon",
                    true,
                    {}
                )
            end
        end
    end

    for className, stored in pairs(scripted_ents.GetList() or {}) do
        local entry = istable(stored) and (stored.t or stored) or {}
        local name = entry.PrintName or entry.Base or className
        local loweredClass = string.lower(tostring(className or ""))
        local model = itemModelFromEntry(entry)

        if string.StartWith(loweredClass, "ent_armor_") then
            addDetected(name, className, "entity", "Z-City Armor", "armor", true, {
                sourceType = "zcity",
                zcityType = "armor",
                zcityId = stripPrefix(className, "ent_armor_"),
                armorClass = className,
                model = model
            })
        elseif string.StartWith(loweredClass, "ent_ammo_") then
            local ammoId = stripPrefix(className, "ent_ammo_")
            local ammoData = hg and ((istable(hg.ammotypeshuy) and hg.ammotypeshuy[ammoId]) or (istable(hg.ammotypes) and hg.ammotypes[ammoId])) or nil
            local ammoName = trimOptional(istable(ammoData) and ammoData.name) or ammoId
            local ammoAmount = hg and istable(hg.ammoents) and ammoName and istable(hg.ammoents[ammoName]) and tonumber(hg.ammoents[ammoName].Count) or nil

            addDetected(name, className, "entity", "Z-City Ammo Entity", "ammo", true, {
                sourceType = "zcity",
                zcityType = "ammo",
                zcityId = ammoId,
                ammoType = ammoName,
                ammoAmount = ammoAmount,
                model = model
            })
        elseif string.StartWith(loweredClass, "ent_att_") then
            local attachmentId = stripPrefix(className, "ent_att_")
            addDetected(name, className, "entity", "Z-City Attachment Entity", "attachment", true, {
                sourceType = "zcity",
                zcityType = "attachment",
                zcityId = attachmentId,
                attachmentId = attachmentId,
                model = model
            })
        else
            addDetected(name, className, "entity", entry.Category or "Scripted Entity", nil, true, {
                model = model
            })
        end
    end

    for _, entry in pairs(list.Get("SpawnableEntities") or {}) do
        if istable(entry) and entry.ClassName then
            addDetected(entry.PrintName or entry.ClassName, entry.ClassName, "entity", entry.Category or "Spawnmenu Entity", nil, true, {
                model = itemModelFromEntry(entry)
            })
        end
    end

    for ammoType, ammoData in pairs(list.Get("Ammo") or {}) do
        if ammoType and ammoType ~= "" then
            local ammoName = istable(ammoData) and (ammoData.name or ammoData.displayName or ammoData.PrintName) or nil
            addDetected(ammoName or prettifyClassName(ammoType), ammoType, "entity", "Registered Ammo", "ammo", true, {})
        end
    end

    if ARC9 and ARC9.Attachments then
        for id, att in pairs(ARC9.Attachments) do
            if istable(att) then
                addDetected(att.PrintName or att.CompactName or id, id, "", "ARC9 Attachment", "attachment", false, {
                    model = itemModelFromEntry(att)
                })
            end
        end
    end

    if TFA and TFA.Attachments and TFA.Attachments.Atts then
        for id, att in pairs(TFA.Attachments.Atts) do
            if istable(att) then
                addDetected(att.PrintName or att.Name or id, id, "", "TFA Attachment", "attachment", false, {
                    model = itemModelFromEntry(att)
                })
            end
        end
    end

    if CustomizableWeaponry then
        local attachmentTable = CustomizableWeaponry.registeredAttachmentsSKey or CustomizableWeaponry.registeredAttachments
        if istable(attachmentTable) then
            for id, att in pairs(attachmentTable) do
                if istable(att) then
                    addDetected(att.name or att.displayName or id, id, "", "CW 2.0 Attachment", "attachment", false, {
                        model = itemModelFromEntry(att)
                    })
                end
            end
        end
    end

    sortCandidates(detected.weapon)
    sortCandidates(detected.armor)
    sortCandidates(detected.ammo)
    sortCandidates(detected.attachment)

    Core.DetectedCatalog = detected
    return detected
end

function Core.GetDetectedCatalog(refresh)
    if refresh or not Core.DetectedCatalog then
        return Core.ScanLoadedContent()
    end

    return Core.DetectedCatalog
end

function Core.BuildState(ply)
    local canManage, reason = Core.CanManageShop(ply)

    return {
        items = Core.GetItems(),
        balance = Core.GetBalance(ply),
        balanceText = Core.FormatMoney(Core.GetBalance(ply)),
        canManage = canManage,
        managerGroup = Core.GetManagerGroup(ply),
        manageReason = canManage and "" or reason,
        darkRPReady = darkRPReady(),
        npcCount = #(Core.NPCRecords or {}),
        npcName = Core.GetNPCName()
    }
end
