ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.JobRuntime = ZCityDarkRPShop.JobRuntime or {}

local JobRuntime = ZCityDarkRPShop.JobRuntime
local Config = ZCityDarkRPShop.Config
local Storage = ZCityDarkRPShop.Storage
local Core = ZCityDarkRPShop.Core
local Net = ZCityDarkRPShop.Net

JobRuntime.Jobs = JobRuntime.Jobs or {}
JobRuntime.TeamIds = JobRuntime.TeamIds or {}
JobRuntime.CreatedCategories = JobRuntime.CreatedCategories or {}

util.AddNetworkString("ZCityDarkRPShop.RequestJobState")
util.AddNetworkString("ZCityDarkRPShop.JobState")
util.AddNetworkString("ZCityDarkRPShop.SaveJobs")
util.AddNetworkString("ZCityDarkRPShop.ChooseJob")
util.AddNetworkString("ZCityDarkRPShop.DropMoney")
util.AddNetworkString("ZCityDarkRPShop.GiveMoney")

local function copyJobs(jobs)
    local copied = {}

    for _, job in ipairs(jobs or {}) do
        copied[#copied + 1] = table.Copy(job)
    end

    return copied
end

local function jobColor(job)
    local color = istable(job and job.color) and job.color or {}
    return Color(
        math.Clamp(math.floor(tonumber(color.r) or 0), 0, 255),
        math.Clamp(math.floor(tonumber(color.g) or 107), 0, 255),
        math.Clamp(math.floor(tonumber(color.b) or 0), 0, 255),
        255
    )
end

local function notifyPlayer(ply, success, message)
    if not IsValid(ply) then return end

    if Net and Net.Notify then
        Net.Notify(ply, success, message)
        return
    end

    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, success and 0 or 1, 4, message or "")
    end
end

local function broadcastState()
    for _, ply in ipairs(player.GetAll()) do
        JobRuntime.SendState(ply)
    end
end

function JobRuntime.LoadJobsData()
    JobRuntime.Jobs = Storage.LoadJobs()
    return JobRuntime.Jobs
end

function JobRuntime.GetJobs()
    return copyJobs(JobRuntime.Jobs)
end

function JobRuntime.GetJob(jobId)
    for _, job in ipairs(JobRuntime.Jobs or {}) do
        if job.id == jobId then
            return job
        end
    end
end

function JobRuntime.RefreshRuntimeCache()
    JobRuntime.TeamIds = {}

    for teamId, teamTable in pairs(RPExtraTeams or {}) do
        if istable(teamTable) and teamTable.zcityJobId then
            JobRuntime.TeamIds[teamTable.zcityJobId] = teamId
        end
    end
end

local function resolveRuntimeCommand(job, existingTeamId)
    local base = string.lower(string.Trim(tostring((job and job.command) or "")))
    if base == "" then
        base = string.lower(string.Trim(tostring((job and job.id) or "job")))
    end

    base = string.gsub(base, "[^%w_]+", "")
    if base == "" then
        base = "job"
    end

    local function commandInUse(candidate)
        for teamId, teamData in pairs(RPExtraTeams or {}) do
            if teamId ~= existingTeamId and istable(teamData) then
                local teamCommand = string.lower(string.Trim(tostring(teamData.command or "")))
                if teamCommand == candidate then
                    return true
                end
            end
        end

        return false
    end

    local candidate = base
    local suffix = 0

    while commandInUse(candidate) do
        suffix = suffix + 1
        candidate = string.format("%s_aftermath%s", base, suffix > 1 and tostring(suffix) or "")
    end

    return candidate
end

function JobRuntime.FindTeamId(jobId)
    local teamId = tonumber(JobRuntime.TeamIds[jobId] or 0)
    if teamId > 0 and RPExtraTeams and RPExtraTeams[teamId] then
        return teamId
    end

    JobRuntime.RefreshRuntimeCache()

    teamId = tonumber(JobRuntime.TeamIds[jobId] or 0)
    if teamId > 0 and RPExtraTeams and RPExtraTeams[teamId] then
        return teamId
    end
end

function JobRuntime.EnsureRegisteredTeamId(job)
    if not istable(job) then
        return nil
    end

    local teamId = JobRuntime.FindTeamId(job.id)
    if teamId then
        return teamId
    end

    local ok, createdTeam = JobRuntime.RegisterJob(job)
    if not ok then
        return nil
    end

    JobRuntime.RefreshRuntimeCache()

    local createdId = tonumber(createdTeam or 0)
    if createdId > 0 then
        JobRuntime.TeamIds[job.id] = createdId
        return createdId
    end

    return JobRuntime.FindTeamId(job.id)
end

function JobRuntime.EnsureCategory(name, color, sortOrder)
    if not DarkRP or not DarkRP.createCategory then
        return
    end

    name = string.Trim(tostring(name or "Citizens"))
    if name == "" then
        name = "Citizens"
    end

    if JobRuntime.CreatedCategories[name] then
        return
    end

    JobRuntime.CreatedCategories[name] = true

    DarkRP.createCategory{
        name = name,
        categorises = "jobs",
        startExpanded = true,
        color = color,
        canSee = function()
            return true
        end,
        sortOrder = sortOrder or 100
    }
end

local function buildLoadoutHandler(job)
    local armor = math.Clamp(math.floor(tonumber(job.armor) or 0), 0, 255)
    local armorClass = string.Trim(tostring(job.armorClass or ""))
    local ammo = table.Copy(job.ammo or {})
    local attachments = table.Copy(job.attachments or {})

    return function(ply)
        if armor <= 0 and armorClass == "" and #ammo == 0 and #attachments == 0 then
            return
        end

        timer.Simple(0, function()
            if not IsValid(ply) then return end
            if armor > 0 then
                ply:SetArmor(armor)
            end

            if armorClass ~= "" and Core and Core.GiveZCityArmor then
                Core.GiveZCityArmor(ply, {
                    class = armorClass,
                    armorClass = armorClass,
                    zcityId = armorClass
                })
            end

            for _, rawAmmo in ipairs(ammo) do
                local ammoEntry = string.Trim(tostring(rawAmmo or ""))
                if ammoEntry ~= "" then
                    local ammoId, amount = string.match(ammoEntry, "^([^:|]+)%s*[:|]%s*(%d+)$")
                    ammoId = string.Trim(tostring(ammoId or ammoEntry))
                    amount = math.max(1, math.floor(tonumber(amount) or 60))

                    if Core and Core.GiveZCityAmmo then
                        local success = Core.GiveZCityAmmo(ply, {
                            class = ammoId,
                            zcityId = ammoId,
                            ammoType = ammoId,
                            ammoAmount = amount
                        })

                        if success then
                            goto continueAmmo
                        end
                    end

                    local fallbackAmmo = ammoId
                    if string.StartWith(string.lower(fallbackAmmo), "ent_ammo_") then
                        fallbackAmmo = string.sub(fallbackAmmo, 10)
                    end

                    if game.GetAmmoID and game.GetAmmoID(fallbackAmmo) and game.GetAmmoID(fallbackAmmo) >= 0 then
                        ply:GiveAmmo(amount > 0 and amount or 60, fallbackAmmo, true)
                    end
                end

                ::continueAmmo::
            end

            for _, rawAttachment in ipairs(attachments) do
                local attachmentId = string.Trim(tostring(rawAttachment or ""))
                if attachmentId ~= "" and Core and Core.GiveZCityAttachment then
                    Core.GiveZCityAttachment(ply, {
                        class = attachmentId,
                        attachmentId = attachmentId,
                        zcityId = attachmentId
                    })
                end
            end
        end)
    end
end

local function buildAccessCheck(job)
    local adminLevel = math.Clamp(math.floor(tonumber(job.admin) or 0), 0, 2)
    if adminLevel <= 0 then
        return nil, nil
    end

    if adminLevel == 1 then
        return function(ply)
            return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
        end, "Эта работа доступна только администраторам."
    end

    return function(ply)
        return IsValid(ply) and ply:IsSuperAdmin()
    end, "Эта работа доступна только superadmin."
end

function JobRuntime.BuildRuntimeJob(job)
    local models = table.Copy(job.models or {})
    local modelField = #models == 1 and models[1] or models
    local accessCheck, failMessage = buildAccessCheck(job)
    local runtimeCommand = string.Trim(tostring(job.runtimeCommand or job.command or ""))

    return {
        color = jobColor(job),
        model = modelField,
        description = tostring(job.description or ""),
        weapons = table.Copy(job.weapons or {}),
        ammo = table.Copy(job.ammo or {}),
        attachments = table.Copy(job.attachments or {}),
        armorClass = string.Trim(tostring(job.armorClass or "")),
        command = runtimeCommand,
        max = math.max(0, math.floor(tonumber(job.max) or 0)),
        salary = math.max(0, math.floor(tonumber(job.salary) or 45)),
        admin = math.Clamp(math.floor(tonumber(job.admin) or 0), 0, 2),
        vote = job.vote == true,
        hasLicense = job.hasLicense == true,
        candemote = job.candemote == true,
        canDemoteOthers = job.canDemoteOthers == true,
        category = tostring(job.category or "Citizens"),
        PlayerLoadout = buildLoadoutHandler(job),
        customCheck = accessCheck,
        CustomCheckFailMsg = failMessage,
        spawn = istable(job.spawn) and table.Copy(job.spawn) or nil,
        zcityJobId = job.id
    }
end

local function syncPlayersInTeam(teamId, job)
    if not teamId then
        return
    end

    local runtime = RPExtraTeams and RPExtraTeams[teamId]
    if not runtime then
        return
    end

    for _, ply in ipairs(team.GetPlayers(teamId) or {}) do
        if IsValid(ply) then
            if ply.updateJob then
                ply:updateJob(job.name)
            elseif ply.setDarkRPVar then
                ply:setDarkRPVar("job", job.name)
            end

            if ply.setSelfDarkRPVar then
                ply:setSelfDarkRPVar("salary", runtime.salary)
            end

            if runtime.hasLicense and ply.setDarkRPVar then
                ply:setDarkRPVar("HasGunlicense", true)
            end

            if ply:Alive() and GAMEMODE then
                hook.Call("PlayerSetModel", GAMEMODE, ply)
                hook.Call("PlayerLoadout", GAMEMODE, ply)
            end
        end
    end
end

function JobRuntime.UpdateRuntimeJob(teamId, job)
    local runtimeTeam = RPExtraTeams and RPExtraTeams[teamId]
    if not runtimeTeam then
        return false
    end

    job.runtimeCommand = resolveRuntimeCommand(job, teamId)
    local runtime = JobRuntime.BuildRuntimeJob(job)

    runtimeTeam.name = job.name
    runtimeTeam.command = runtime.command
    runtimeTeam.color = runtime.color
    runtimeTeam.model = runtime.model
    runtimeTeam.description = runtime.description
    runtimeTeam.weapons = table.Copy(runtime.weapons)
    runtimeTeam.ammo = table.Copy(runtime.ammo or {})
    runtimeTeam.attachments = table.Copy(runtime.attachments or {})
    runtimeTeam.armorClass = runtime.armorClass
    runtimeTeam.max = runtime.max
    runtimeTeam.salary = runtime.salary
    runtimeTeam.admin = runtime.admin
    runtimeTeam.vote = runtime.vote
    runtimeTeam.hasLicense = runtime.hasLicense
    runtimeTeam.candemote = runtime.candemote
    runtimeTeam.canDemoteOthers = runtime.canDemoteOthers
    runtimeTeam.category = runtime.category
    runtimeTeam.PlayerLoadout = runtime.PlayerLoadout
    runtimeTeam.customCheck = runtime.customCheck
    runtimeTeam.CustomCheckFailMsg = runtime.CustomCheckFailMsg
    runtimeTeam.spawn = runtime.spawn
    runtimeTeam.zcityJobId = job.id

    team.SetUp(teamId, job.name, runtime.color, true)
    _G["TEAM_" .. string.upper(runtime.command)] = teamId

    syncPlayersInTeam(teamId, job)

    return true
end

hook.Add("PlayerSpawn", "ZCityDarkRPShop.ApplyJobSpawn", function(ply)
    timer.Simple(0.05, function()
        if not IsValid(ply) or not ply:Alive() then
            return
        end

        if not ply.ZCityAftermathPendingSpawnMove then
            return
        end

        local runtimeTeam = RPExtraTeams and RPExtraTeams[ply:Team()]
        local jobId = runtimeTeam and runtimeTeam.zcityJobId
        if not jobId then
            return
        end

        local job = JobRuntime.GetJob(jobId)
        local spawn = job and job.spawn
        local pos = spawn and spawn.pos or {}
        local ang = spawn and spawn.ang or {}

        local x = tonumber(pos.x)
        local y = tonumber(pos.y)
        local z = tonumber(pos.z)

        if not x or not y or not z then
            return
        end

        ply:SetPos(Vector(x, y, z) + Vector(0, 0, 4))
        ply:SetEyeAngles(Angle(0, tonumber(ang.y) or 0, 0))
        ply.ZCityAftermathPendingSpawnMove = nil
        ply.ZCityAftermathUsedJobSpawn = true
    end)
end)

function JobRuntime.RegisterJob(job)
    if not DarkRP or not DarkRP.createJob then
        return false, "DarkRP is not ready."
    end

    JobRuntime.EnsureCategory(job.category, jobColor(job), 100)

    local teamId = JobRuntime.FindTeamId(job.id)
    if teamId then
        JobRuntime.UpdateRuntimeJob(teamId, job)
        JobRuntime.TeamIds[job.id] = teamId
        return true, teamId
    end

    job.runtimeCommand = resolveRuntimeCommand(job, nil)
    local createdTeam = DarkRP.createJob(job.name, JobRuntime.BuildRuntimeJob(job))
    if not createdTeam then
        return false, "Could not register the DarkRP job."
    end

    if RPExtraTeams and RPExtraTeams[createdTeam] then
        RPExtraTeams[createdTeam].zcityJobId = job.id
    end

    _G["TEAM_" .. string.upper(tostring(job.runtimeCommand or job.command or ""))] = createdTeam
    JobRuntime.TeamIds[job.id] = createdTeam

    return true, createdTeam
end

function JobRuntime.DisableRemovedJob(jobId)
    local teamId = JobRuntime.FindTeamId(jobId)
    local runtimeTeam = teamId and RPExtraTeams and RPExtraTeams[teamId]

    if not runtimeTeam then
        return
    end

    runtimeTeam.customCheck = function()
        return false
    end
    runtimeTeam.CustomCheckFailMsg = "Эта работа удалена. Снова открой меню или смени карту."
    runtimeTeam.category = "Removed Jobs"

    team.SetUp(teamId, "[Removed] " .. tostring(runtimeTeam.name or "Job"), runtimeTeam.color or Color(90, 90, 90), true)

    local defaultTeam = GAMEMODE and GAMEMODE.DefaultTeam
    if defaultTeam and RPExtraTeams and RPExtraTeams[defaultTeam] then
        for _, ply in ipairs(team.GetPlayers(teamId) or {}) do
            if IsValid(ply) then
                ply:changeTeam(defaultTeam, true, true)
            end
        end
    end
end

function JobRuntime.EnsureDefaultTeam()
    if not GAMEMODE then
        return
    end

    local fallbackTeamId

    for _, job in ipairs(JobRuntime.Jobs or {}) do
        if math.floor(tonumber(job.admin) or 0) <= 0 then
            local teamId = JobRuntime.EnsureRegisteredTeamId(job)
            if teamId then
                if job.id == "citizen" or string.lower(tostring(job.command or "")) == "citizen" then
                    GAMEMODE.DefaultTeam = teamId
                    return
                end

                fallbackTeamId = fallbackTeamId or teamId
            end
        end
    end

    if fallbackTeamId then
        GAMEMODE.DefaultTeam = fallbackTeamId
    end
end

function JobRuntime.ApplyJobsRuntime(previousJobs)
    JobRuntime.RefreshRuntimeCache()

    local previousIds = {}
    for _, job in ipairs(previousJobs or {}) do
        previousIds[job.id] = true
    end

    local currentIds = {}
    for _, job in ipairs(JobRuntime.Jobs or {}) do
        currentIds[job.id] = true
        JobRuntime.RegisterJob(job)
    end

    JobRuntime.EnsureDefaultTeam()

    for oldId in pairs(previousIds) do
        if not currentIds[oldId] then
            JobRuntime.DisableRemovedJob(oldId)
        end
    end

    JobRuntime.RefreshRuntimeCache()
end

function JobRuntime.RegisterPersistedJobs()
    JobRuntime.LoadJobsData()
    JobRuntime.ApplyJobsRuntime()
end

function JobRuntime.BuildState(ply)
    local canManage, reason = Core.CanManageShop(ply)
    local jobs = JobRuntime.GetJobs()

    for _, job in ipairs(jobs) do
        job.teamId = JobRuntime.EnsureRegisteredTeamId(job)
    end

    return {
        jobs = jobs,
        canManage = canManage,
        manageReason = canManage and "" or tostring(reason or ""),
        managerGroup = Core.GetManagerGroup(ply),
        darkRPReady = DarkRP ~= nil and DarkRP.createJob ~= nil,
        balance = Core.GetBalance(ply),
        balanceText = Core.FormatMoney(Core.GetBalance(ply))
    }
end

function JobRuntime.SendState(ply)
    if not IsValid(ply) then return end

    net.Start("ZCityDarkRPShop.JobState")
    net.WriteString(util.TableToJSON(JobRuntime.BuildState(ply)) or "{}")
    net.Send(ply)
end

function JobRuntime.TryChooseJob(ply, jobId)
    if not IsValid(ply) or not ply:IsPlayer() then
        return false, "Invalid player."
    end

    if not DarkRP then
        return false, "DarkRP is not loaded."
    end

    local job = JobRuntime.GetJob(jobId)
    if not job then
        return false, "Работа не найдена."
    end

    local teamId = JobRuntime.EnsureRegisteredTeamId(job)
    if not teamId then
        return false, "Работа ещё не зарегистрирована. Смените карту или перезапустите сервер."
    end

    ply.ZCityAftermathPendingSpawnMove = true
    ply.ZCityAftermathUsedJobSpawn = nil

    local success = ply:changeTeam(teamId, false)
    if not success then
        ply.ZCityAftermathPendingSpawnMove = nil
        return false, "DarkRP отклонил смену работы."
    end

    return true, string.format("Теперь твоя работа: %s.", job.name)
end

local function normalizeMoneyAmount(rawAmount)
    local amount = math.floor(tonumber(rawAmount) or 0)

    if amount < 1 then
        return nil, "Укажи сумму больше нуля."
    end

    if amount >= 2147483647 then
        return nil, "Слишком большая сумма."
    end

    return amount
end

function JobRuntime.DropMoney(ply, rawAmount)
    if not IsValid(ply) or not ply:IsPlayer() then
        return false, "Invalid player."
    end

    if not DarkRP or not DarkRP.createMoneyBag then
        return false, "DarkRP money API is unavailable."
    end

    local amount, reason = normalizeMoneyAmount(rawAmount)
    if not amount then
        return false, reason
    end

    if not ply.canAfford or not ply:canAfford(amount) then
        return false, "Недостаточно денег."
    end

    local moneyTable = {
        cmd = "dropmoney",
        max = GAMEMODE and GAMEMODE.Config and GAMEMODE.Config.maxMoneyPiles or 5
    }

    if ply.customEntityLimitReached and ply:customEntityLimitReached(moneyTable) then
        return false, "Достигнут лимит пачек денег."
    end

    if ply.addCustomEntity then
        ply:addCustomEntity(moneyTable)
    end

    ply:addMoney(-amount)
    ply:DoAnimationEvent(ACT_GMOD_GESTURE_ITEM_DROP)

    timer.Simple(0.9, function()
        if not IsValid(ply) then return end

        local trace = {
            start = ply:EyePos(),
            endpos = ply:EyePos() + ply:GetAimVector() * 85,
            filter = ply
        }

        local tr = util.TraceLine(trace)
        local moneyBag = DarkRP.createMoneyBag(tr.HitPos, amount)

        if IsValid(moneyBag) then
            moneyBag.DarkRPItem = moneyTable
            moneyBag.SID = ply:UserID()

            if DarkRP.placeEntity then
                DarkRP.placeEntity(moneyBag, tr, ply)
            end

            hook.Call("playerDroppedMoney", nil, ply, amount, moneyBag)
        end
    end)

    return true, string.format("Ты выкинул %s.", Core.FormatMoney(amount))
end

function JobRuntime.GiveMoney(ply, rawAmount)
    if not IsValid(ply) or not ply:IsPlayer() then
        return false, "Invalid player."
    end

    if not DarkRP or not DarkRP.payPlayer then
        return false, "DarkRP money API is unavailable."
    end

    local amount, reason = normalizeMoneyAmount(rawAmount)
    if not amount then
        return false, reason
    end

    local trace = ply:GetEyeTrace()
    local target = trace.Entity

    if not IsValid(target) or not target:IsPlayer() or target:GetPos():DistToSqr(ply:GetPos()) >= 22500 then
        return false, "Смотри на игрока рядом с тобой."
    end

    if not ply.canAfford or not ply:canAfford(amount) then
        return false, "Недостаточно денег."
    end

    ply:DoAnimationEvent(ACT_GMOD_GESTURE_ITEM_GIVE)
    DarkRP.payPlayer(ply, target, amount)
    hook.Call("playerGaveMoney", nil, ply, target, amount)

    notifyPlayer(target, true, string.format("%s передал тебе %s.", ply:Nick(), Core.FormatMoney(amount)))

    return true, string.format("Ты передал %s игроку %s.", Core.FormatMoney(amount), target:Nick())
end

net.Receive("ZCityDarkRPShop.RequestJobState", function(_, ply)
    JobRuntime.SendState(ply)
end)

net.Receive("ZCityDarkRPShop.SaveJobs", function(_, ply)
    local allowed, reason = Core.CanManageShop(ply)
    if not allowed then
        notifyPlayer(ply, false, reason)
        return
    end

    local decoded = util.JSONToTable(net.ReadString() or "")
    if not istable(decoded) then
        notifyPlayer(ply, false, "Не удалось прочитать данные работ.")
        return
    end

    local previousJobs = JobRuntime.GetJobs()
    JobRuntime.Jobs = Storage.SaveJobs(decoded)
    JobRuntime.ApplyJobsRuntime(previousJobs)

    notifyPlayer(ply, true, string.format("Работы сохранены (%d шт.).", #JobRuntime.Jobs))
    broadcastState()
end)

net.Receive("ZCityDarkRPShop.ChooseJob", function(_, ply)
    local success, message = JobRuntime.TryChooseJob(ply, net.ReadString())
    notifyPlayer(ply, success, message)
    JobRuntime.SendState(ply)
end)

net.Receive("ZCityDarkRPShop.DropMoney", function(_, ply)
    local success, message = JobRuntime.DropMoney(ply, net.ReadInt(32))
    notifyPlayer(ply, success, message)
    JobRuntime.SendState(ply)
end)

net.Receive("ZCityDarkRPShop.GiveMoney", function(_, ply)
    local success, message = JobRuntime.GiveMoney(ply, net.ReadInt(32))
    notifyPlayer(ply, success, message)
    JobRuntime.SendState(ply)
end)

hook.Add("InitPostEntity", "ZCityDarkRPShop.JobRuntimeBootstrap", function()
    if not DarkRP then
        return
    end

    JobRuntime.RegisterPersistedJobs()
end)
