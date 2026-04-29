ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Storage = ZCityDarkRPShop.Storage or {}

local Storage = ZCityDarkRPShop.Storage
local Config = ZCityDarkRPShop.Config

local function trimText(value, maxLength)
    local text = string.Trim(tostring(value or ""))
    if maxLength then
        text = string.sub(text, 1, maxLength)
    end

    return text
end

local function optionalText(value, maxLength, lower)
    local text = trimText(value, maxLength)
    if lower then
        text = string.lower(text)
    end

    return text ~= "" and text or nil
end

local function normalizeId(rawId, seed)
    local id = string.lower(trimText(rawId, 64))
    id = string.gsub(id, "[^%w_%-]+", "_")

    if id == "" then
        id = "item_" .. util.CRC(seed or tostring(SysTime()))
    end

    return id
end

local function clampWholeNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if value == nil then
        return fallback
    end

    return math.Clamp(math.floor(value), minValue, maxValue)
end

local function splitList(value, maxEntries, maxLength)
    local entries = {}
    local seen = {}

    local function addEntry(rawText)
        local text = trimText(rawText, maxLength)
        if text == "" then
            return
        end

        local lowered = string.lower(text)
        if seen[lowered] then
            return
        end

        seen[lowered] = true
        entries[#entries + 1] = text
    end

    if istable(value) then
        for _, rawText in ipairs(value) do
            addEntry(rawText)
            if #entries >= maxEntries then
                break
            end
        end
    else
        for rawText in string.gmatch(tostring(value or ""), "[^\r\n,;]+") do
            addEntry(rawText)
            if #entries >= maxEntries then
                break
            end
        end
    end

    return entries
end

local function sanitizeCommand(rawCommand, seed)
    local command = string.lower(trimText(rawCommand, 24))
    command = string.gsub(command, "[^%w_]+", "")

    if command == "" then
        command = "job" .. string.sub(util.CRC(seed or tostring(SysTime())), 1, 8)
    end

    return command
end

local function mapNPCFile()
    return string.format("%s/%s.json", Config.NPCDir, game.GetMap())
end

local function mapSpawnFile()
    return string.format("%s/%s.json", Config.SpawnDir, game.GetMap())
end

local function mapSafeZoneFile()
    return string.format("%s/%s.json", Config.SafeZoneDir, game.GetMap())
end

local function mapDoorFile()
    return string.format("%s/%s.json", Config.DoorDir, game.GetMap())
end

function Storage.Initialize()
    file.CreateDir(Config.DataDir)
    file.CreateDir(Config.NPCDir)
    file.CreateDir(Config.SpawnDir)
    file.CreateDir(Config.SafeZoneDir)
    file.CreateDir(Config.DoorDir)
end

function Storage.NormalizeCategory(category)
    category = string.lower(trimText(category, 24))

    if Config.ItemCategories[category] then
        return category
    end

    return "misc"
end

function Storage.SanitizeItem(rawItem, seed)
    if not istable(rawItem) then return nil end

    local item = {
        id = normalizeId(rawItem.id, seed),
        name = trimText(rawItem.name, 48),
        class = trimText(rawItem.class, 96),
        model = trimText(rawItem.model, 128),
        kind = string.lower(trimText(rawItem.kind, 16)),
        category = Storage.NormalizeCategory(rawItem.category),
        price = math.max(0, math.floor(tonumber(rawItem.price) or 0))
    }

    item.source = optionalText(rawItem.source, 48, false)
    item.sourceType = optionalText(rawItem.sourceType, 16, true)
    item.zcityType = optionalText(rawItem.zcityType, 16, true)
    item.zcityId = optionalText(rawItem.zcityId, 64, false)
    item.armorClass = optionalText(rawItem.armorClass, 96, false)
    item.attachmentId = optionalText(rawItem.attachmentId, 64, false)
    item.ammoType = optionalText(rawItem.ammoType, 64, false)

    local ammoAmount = clampWholeNumber(rawItem.ammoAmount, 1, 9999, 0)
    if ammoAmount > 0 then
        item.ammoAmount = ammoAmount
    end

    if item.name == "" or item.class == "" then
        return nil
    end

    if item.kind ~= "weapon" and item.kind ~= "entity" then
        return nil
    end

    return item
end

function Storage.NormalizeItems(rawItems)
    local items = {}
    local seenIds = {}

    for index, rawItem in ipairs(rawItems or {}) do
        local seed = string.format(
            "%s_%s_%s_%s_%s_%s_%d",
            rawItem.id or "",
            rawItem.name or "",
            rawItem.class or "",
            rawItem.model or "",
            rawItem.kind or "",
            rawItem.category or "",
            index
        )

        local item = Storage.SanitizeItem(rawItem, seed)

        if item then
            while seenIds[item.id] do
                item.id = normalizeId(item.id .. "_" .. index, seed .. "_" .. item.id)
            end

            seenIds[item.id] = true
            items[#items + 1] = item
        end

        if #items >= Config.MaxItems then
            break
        end
    end

    return items
end

local function itemSignature(item)
    return string.lower(string.format(
        "%s|%s",
        trimText(item and item.class, 96),
        trimText(item and item.kind, 16)
    ))
end

function Storage.MergeRequiredItems(items)
    local merged = Storage.NormalizeItems(items)
    local seen = {}

    for _, item in ipairs(merged) do
        seen[itemSignature(item)] = true
    end

    for index, rawItem in ipairs(Config.RequiredItems or {}) do
        local required = Storage.SanitizeItem(rawItem, string.format("required_item_%d", index))
        if required then
            local signature = itemSignature(required)
            if not seen[signature] then
                merged[#merged + 1] = required
                seen[signature] = true
            end
        end
    end

    return Storage.NormalizeItems(merged)
end

function Storage.LoadItems()
    Storage.Initialize()

    if not file.Exists(Config.ItemsFile, "DATA") then
        return Storage.NormalizeItems(table.Copy(Config.DefaultItems))
    end

    local decoded = util.JSONToTable(file.Read(Config.ItemsFile, "DATA") or "")
    if not istable(decoded) then
        return Storage.NormalizeItems(table.Copy(Config.DefaultItems))
    end

    local items = Storage.NormalizeItems(decoded)
    if #items == 0 then
        items = Storage.NormalizeItems(table.Copy(Config.DefaultItems))
    end

    return Storage.MergeRequiredItems(items)
end

function Storage.SaveItems(items)
    Storage.Initialize()

    local normalized = Storage.MergeRequiredItems(items)
    if #normalized == 0 then
        normalized = Storage.NormalizeItems(table.Copy(Config.DefaultItems))
    end

    file.Write(Config.ItemsFile, util.TableToJSON(normalized, true))
    return normalized
end

function Storage.SanitizeNPCRecord(rawRecord)
    if not istable(rawRecord) then return nil end
    if not istable(rawRecord.pos) or not istable(rawRecord.ang) then return nil end

    local model = trimText(rawRecord.model, 128)
    if model == "" then
        model = Config.NPCModel
    end

    return {
        pos = {
            x = tonumber(rawRecord.pos.x) or 0,
            y = tonumber(rawRecord.pos.y) or 0,
            z = tonumber(rawRecord.pos.z) or 0
        },
        ang = {
            p = tonumber(rawRecord.ang.p) or 0,
            y = tonumber(rawRecord.ang.y) or 0,
            r = tonumber(rawRecord.ang.r) or 0
        },
        model = model
    }
end

function Storage.LoadNPCRecords()
    Storage.Initialize()

    local npcFile = mapNPCFile()
    if not file.Exists(npcFile, "DATA") then
        return {}
    end

    local decoded = util.JSONToTable(file.Read(npcFile, "DATA") or "")
    if not istable(decoded) then
        return {}
    end

    local records = {}
    for _, rawRecord in ipairs(decoded) do
        local record = Storage.SanitizeNPCRecord(rawRecord)
        if record then
            records[#records + 1] = record
        end
    end

    return records
end

function Storage.SaveNPCRecords(records)
    Storage.Initialize()

    local sanitized = {}
    for _, rawRecord in ipairs(records or {}) do
        local record = Storage.SanitizeNPCRecord(rawRecord)
        if record then
            sanitized[#sanitized + 1] = record
        end
    end

    file.Write(mapNPCFile(), util.TableToJSON(sanitized, true))
    return sanitized
end

function Storage.SanitizeSpawnRecord(rawRecord)
    if not istable(rawRecord) then return nil end
    if not istable(rawRecord.pos) or not istable(rawRecord.ang) then return nil end

    return {
        pos = {
            x = tonumber(rawRecord.pos.x) or 0,
            y = tonumber(rawRecord.pos.y) or 0,
            z = tonumber(rawRecord.pos.z) or 0
        },
        ang = {
            p = tonumber(rawRecord.ang.p) or 0,
            y = tonumber(rawRecord.ang.y) or 0,
            r = tonumber(rawRecord.ang.r) or 0
        },
        name = trimText(rawRecord.name, 48)
    }
end

function Storage.LoadSpawnRecords()
    Storage.Initialize()

    local spawnFile = mapSpawnFile()
    if not file.Exists(spawnFile, "DATA") then
        return {}
    end

    local decoded = util.JSONToTable(file.Read(spawnFile, "DATA") or "")
    if not istable(decoded) then
        return {}
    end

    local records = {}
    for _, rawRecord in ipairs(decoded) do
        local record = Storage.SanitizeSpawnRecord(rawRecord)
        if record then
            records[#records + 1] = record
        end

        if #records >= Config.MaxSpawns then
            break
        end
    end

    return records
end

function Storage.SaveSpawnRecords(records)
    Storage.Initialize()

    local sanitized = {}
    for _, rawRecord in ipairs(records or {}) do
        local record = Storage.SanitizeSpawnRecord(rawRecord)
        if record then
            sanitized[#sanitized + 1] = record
        end

        if #sanitized >= Config.MaxSpawns then
            break
        end
    end

    file.Write(mapSpawnFile(), util.TableToJSON(sanitized, true))
    return sanitized
end

function Storage.SanitizeSafeZoneRecord(rawRecord)
    if not istable(rawRecord) then return nil end
    if not istable(rawRecord.pos) then return nil end

    local radius = math.Clamp(math.floor(tonumber(rawRecord.radius) or Config.DefaultSafeZoneRadius), 64, 8192)

    return {
        pos = {
            x = tonumber(rawRecord.pos.x) or 0,
            y = tonumber(rawRecord.pos.y) or 0,
            z = tonumber(rawRecord.pos.z) or 0
        },
        radius = radius,
        name = trimText(rawRecord.name, 48)
    }
end

function Storage.LoadSafeZoneRecords()
    Storage.Initialize()

    if not file.Exists(mapSafeZoneFile(), "DATA") then
        return {}
    end

    local decoded = util.JSONToTable(file.Read(mapSafeZoneFile(), "DATA") or "")
    if not istable(decoded) then
        return {}
    end

    local records = {}
    for _, rawRecord in ipairs(decoded) do
        local record = Storage.SanitizeSafeZoneRecord(rawRecord)
        if record then
            records[#records + 1] = record
        end

        if #records >= Config.MaxSafeZones then
            break
        end
    end

    return records
end

function Storage.SaveSafeZoneRecords(records)
    Storage.Initialize()

    local sanitized = {}
    for _, rawRecord in ipairs(records or {}) do
        local record = Storage.SanitizeSafeZoneRecord(rawRecord)
        if record then
            sanitized[#sanitized + 1] = record
        end

        if #sanitized >= Config.MaxSafeZones then
            break
        end
    end

    file.Write(mapSafeZoneFile(), util.TableToJSON(sanitized, true))
    return sanitized
end

function Storage.SanitizeDoorRecord(rawRecord)
    if not istable(rawRecord) then return nil end

    local mapId = math.floor(tonumber(rawRecord.mapId) or 0)
    if mapId <= 0 then return nil end

    return {
        mapId = mapId,
        price = math.max(0, math.floor(tonumber(rawRecord.price) or Config.DefaultDoorPrice)),
        name = trimText(rawRecord.name, 48),
        enabled = rawRecord.enabled ~= false
    }
end

function Storage.LoadDoorRecords()
    Storage.Initialize()

    if not file.Exists(mapDoorFile(), "DATA") then
        return {}
    end

    local decoded = util.JSONToTable(file.Read(mapDoorFile(), "DATA") or "")
    if not istable(decoded) then
        return {}
    end

    local records = {}
    for _, rawRecord in pairs(decoded) do
        local record = Storage.SanitizeDoorRecord(rawRecord)
        if record then
            records[tostring(record.mapId)] = record
        end
    end

    return records
end

function Storage.SaveDoorRecords(records)
    Storage.Initialize()

    local sanitized = {}
    for _, rawRecord in pairs(records or {}) do
        local record = Storage.SanitizeDoorRecord(rawRecord)
        if record then
            sanitized[tostring(record.mapId)] = record
        end
    end

    file.Write(mapDoorFile(), util.TableToJSON(sanitized, true))
    return sanitized
end

function Storage.SanitizeSettings(rawSettings)
    rawSettings = istable(rawSettings) and rawSettings or {}

    return {
        npcName = trimText(rawSettings.npcName, 48) ~= "" and trimText(rawSettings.npcName, 48) or Config.NPCName
    }
end

function Storage.LoadSettings()
    Storage.Initialize()

    if not file.Exists(Config.SettingsFile, "DATA") then
        return Storage.SanitizeSettings(table.Copy(Config.DefaultSettings))
    end

    local decoded = util.JSONToTable(file.Read(Config.SettingsFile, "DATA") or "")
    return Storage.SanitizeSettings(decoded)
end

function Storage.SaveSettings(settings)
    Storage.Initialize()

    local sanitized = Storage.SanitizeSettings(settings)
    file.Write(Config.SettingsFile, util.TableToJSON(sanitized, true))
    return sanitized
end

local function sanitizeJobSpawn(rawSpawn)
    if not istable(rawSpawn) then
        return nil
    end

    local pos = rawSpawn.pos or rawSpawn.position or {}
    local ang = rawSpawn.ang or rawSpawn.angle or {}

    local x = tonumber(pos.x)
    local y = tonumber(pos.y)
    local z = tonumber(pos.z)

    if not x or not y or not z then
        return nil
    end

    return {
        name = trimText(rawSpawn.name, 64),
        pos = {
            x = x,
            y = y,
            z = z
        },
        ang = {
            p = clampWholeNumber(ang.p, -89, 89, 0),
            y = clampWholeNumber(ang.y, -360, 360, 0),
            r = clampWholeNumber(ang.r, -180, 180, 0)
        }
    }
end

function Storage.SanitizeJob(rawJob, seed)
    if not istable(rawJob) then return nil end

    local color = istable(rawJob.color) and rawJob.color or {}
    local models = splitList(rawJob.models or rawJob.model, 8, 128)
    local weapons = splitList(rawJob.weapons, 24, 96)
    local ammo = splitList(rawJob.ammo, 24, 96)
    local attachments = splitList(rawJob.attachments, 24, 96)
    local name = trimText(rawJob.name, 48)
    local category = trimText(rawJob.category, 48)

    if #models == 0 then
        models = { Config.DefaultJobModel }
    end

    local job = {
        id = normalizeId(rawJob.id, seed),
        name = name,
        description = trimText(rawJob.description, 768),
        command = sanitizeCommand(rawJob.command, seed),
        category = category ~= "" and category or "Citizens",
        models = models,
        weapons = weapons,
        ammo = ammo,
        attachments = attachments,
        armor = clampWholeNumber(rawJob.armor, 0, 255, 0),
        armorClass = trimText(rawJob.armorClass, 96),
        salary = clampWholeNumber(rawJob.salary, 0, 100000000, 45),
        max = clampWholeNumber(rawJob.max, 0, 128, 0),
        admin = clampWholeNumber(rawJob.admin, 0, 2, 0),
        vote = tobool(rawJob.vote),
        hasLicense = tobool(rawJob.hasLicense),
        candemote = tobool(rawJob.candemote),
        canDemoteOthers = tobool(rawJob.canDemoteOthers),
        spawn = sanitizeJobSpawn(rawJob.spawn),
        color = {
            r = clampWholeNumber(color.r, 0, 255, 0),
            g = clampWholeNumber(color.g, 0, 255, 107),
            b = clampWholeNumber(color.b, 0, 255, 0),
            a = 255
        }
    }

    if job.name == "" then
        return nil
    end

    return job
end

function Storage.NormalizeJobs(rawJobs)
    local jobs = {}
    local seenIds = {}
    local seenCommands = {}

    for index, rawJob in ipairs(rawJobs or {}) do
        local seed = string.format(
            "%s_%s_%s_%s_%s_%d",
            rawJob.id or "",
            rawJob.name or "",
            rawJob.command or "",
            rawJob.category or "",
            rawJob.salary or "",
            index
        )

        local job = Storage.SanitizeJob(rawJob, seed)
        if job then
            while seenIds[job.id] do
                job.id = normalizeId(job.id .. "_" .. index, seed .. "_" .. job.id)
            end

            while seenCommands[job.command] do
                job.command = sanitizeCommand(job.command .. index, seed .. "_" .. job.command)
            end

            seenIds[job.id] = true
            seenCommands[job.command] = true
            jobs[#jobs + 1] = job
        end

        if #jobs >= Config.MaxJobs then
            break
        end
    end

    return jobs
end

function Storage.LoadJobs()
    Storage.Initialize()

    if not file.Exists(Config.JobsFile, "DATA") then
        return Storage.NormalizeJobs(table.Copy(Config.DefaultJobs))
    end

    local decoded = util.JSONToTable(file.Read(Config.JobsFile, "DATA") or "")
    if not istable(decoded) then
        return Storage.NormalizeJobs(table.Copy(Config.DefaultJobs))
    end

    local normalized = Storage.NormalizeJobs(decoded)
    if #normalized == 0 then
        return Storage.NormalizeJobs(table.Copy(Config.DefaultJobs))
    end

    return normalized
end

function Storage.SaveJobs(jobs)
    Storage.Initialize()

    local normalized = Storage.NormalizeJobs(jobs)
    if #normalized == 0 then
        normalized = Storage.NormalizeJobs(table.Copy(Config.DefaultJobs))
    end

    file.Write(Config.JobsFile, util.TableToJSON(normalized, true))
    return normalized
end
