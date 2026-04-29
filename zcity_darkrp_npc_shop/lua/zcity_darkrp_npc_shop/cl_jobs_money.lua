ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.JobClient = ZCityDarkRPShop.JobClient or {}

local JobClient = ZCityDarkRPShop.JobClient
local Config = ZCityDarkRPShop.Config

JobClient.State = JobClient.State or {
    jobs = {},
    canManage = false,
    manageReason = "",
    managerGroup = "",
    darkRPReady = false,
    balance = 0,
    balanceText = "$0"
}

local jobsFrame
local adminFrame
local jobSpawnPickerFrame
local selectedJobId
local editorSelectedId
local editorJobs = {}
local editorControls = {}

surface.CreateFont("ZCityJobs.Title", {
    font = "Trebuchet24",
    size = 34,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZCityJobs.Section", {
    font = "Trebuchet24",
    size = 24,
    weight = 800,
    antialias = true
})

surface.CreateFont("ZCityJobs.Body", {
    font = "Tahoma",
    size = 18,
    weight = 600,
    antialias = true
})

surface.CreateFont("ZCityJobs.Small", {
    font = "Tahoma",
    size = 15,
    weight = 500,
    antialias = true
})

local palette = {
    bg = Color(8, 8, 10, 244),
    header = Color(16, 16, 20, 252),
    panel = Color(14, 14, 18, 242),
    panelAlt = Color(10, 10, 14, 236),
    panelLight = Color(24, 24, 30, 248),
    accent = Color(170, 22, 28),
    accentHover = Color(205, 38, 46),
    green = Color(110, 22, 26),
    greenHover = Color(135, 30, 36),
    gold = Color(196, 46, 46),
    text = Color(238, 242, 247),
    textDim = Color(174, 180, 192),
    line = Color(62, 62, 72),
    shadow = Color(0, 0, 0, 120)
}

local function trim(value)
    return string.Trim(tostring(value or ""))
end

local function formatMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))

    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(amount)
    end

    return "$" .. tostring(amount)
end

local function jobColor(job)
    local color = istable(job and job.color) and job.color or {}

    return Color(
        math.Clamp(math.floor(tonumber(color.r) or 0), 0, 255),
        math.Clamp(math.floor(tonumber(color.g) or 107), 0, 255),
        math.Clamp(math.floor(tonumber(color.b) or 0), 0, 255),
        math.Clamp(math.floor(tonumber(color.a) or 255), 120, 255)
    )
end

local function splitMultiline(value, maxEntries)
    local entries = {}
    local seen = {}

    for rawLine in string.gmatch(tostring(value or ""), "[^\r\n,;]+") do
        local text = trim(rawLine)
        if text ~= "" then
            local lowered = string.lower(text)
            if not seen[lowered] then
                seen[lowered] = true
                entries[#entries + 1] = text
            end
        end

        if maxEntries and #entries >= maxEntries then
            break
        end
    end

    return entries
end

local function joinMultiline(entries)
    if not istable(entries) then
        return ""
    end

    return table.concat(entries, "\n")
end

local function localBalance()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return 0
    end

    if ply.getDarkRPVar then
        return math.max(0, math.floor(tonumber(ply:getDarkRPVar("money")) or 0))
    end

    return math.max(0, math.floor(tonumber(JobClient.State.balance) or 0))
end

local function isAllowedManager()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply.GetUserGroup then
        return false
    end

    local group = string.lower(ply:GetUserGroup() or "")
    return Config.AllowedULXGroups[group] == true
end

local function notifyLocal(success, message)
    notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
    surface.PlaySound(success and "buttons/button15.wav" or "buttons/button10.wav")
end

local function styleTextEntry(entry)
    entry:SetFont("ZCityJobs.Body")
    entry:SetTextColor(palette.text)
    entry:SetDrawLanguageID(false)
    entry.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, palette.panelAlt)
        surface.SetDrawColor(palette.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(palette.text, palette.gold, palette.text)
    end
end

local function styleComboBox(combo)
    combo:SetFont("ZCityJobs.Body")
    combo:SetTextColor(palette.text)
    combo.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, palette.panelAlt)
        surface.SetDrawColor(palette.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(self:GetText(), "ZCityJobs.Body", 10, h / 2, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if IsValid(combo.DropButton) then
        combo.DropButton.Paint = function(_, w, h)
            draw.RoundedBoxEx(8, 0, 0, w, h, palette.panelLight, false, true, false, true)
            draw.SimpleText("v", "ZCityJobs.Body", w / 2, h / 2, palette.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end

local function styleButton(button, baseColor, hoverColor)
    button:SetFont("ZCityJobs.Body")
    button:SetTextColor(palette.text)
    button.Paint = function(self, w, h)
        local background = self:IsEnabled() and (self:IsHovered() and hoverColor or baseColor) or palette.line
        draw.RoundedBox(8, 0, 0, w, h, background)
        draw.SimpleText(self:GetText(), "ZCityJobs.Body", w / 2, h / 2, palette.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function styleListView(list)
    list:SetHeaderHeight(30)
    list:SetDataHeight(34)
    list.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, palette.panelAlt)
        surface.SetDrawColor(palette.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    for _, column in ipairs(list.Columns or {}) do
        if IsValid(column.Header) then
            column.Header:SetTextColor(palette.text)
            column.Header.Paint = function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, palette.panelLight)
                draw.SimpleText(self:GetText(), "ZCityJobs.Small", 10, h / 2, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end
end

local function styleListLine(line)
    line.Paint = function(self, w, h)
        local bg = self:IsSelected() and Color(88, 18, 24, 210) or (self:IsHovered() and Color(28, 28, 36, 240) or Color(0, 0, 0, 0))
        draw.RoundedBox(8, 4, 2, w - 8, h - 4, bg)
    end
end

local function addStyledLine(list, ...)
    local line = list:AddLine(...)
    styleListLine(line)
    return line
end

local function paintPanel(_, w, h, color)
    draw.RoundedBox(12, 0, 0, w, h, color)
    surface.SetDrawColor(palette.line)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

local function requestState()
    net.Start("ZCityDarkRPShop.RequestJobState")
    net.SendToServer()
end

local function sendSaveJobs(jobs)
    net.Start("ZCityDarkRPShop.SaveJobs")
    net.WriteString(util.TableToJSON(jobs or {}, true) or "[]")
    net.SendToServer()
end

local function fitModelPanel(panel)
    if not IsValid(panel) or not IsValid(panel.Entity) then
        return
    end

    local entity = panel.Entity
    local mins, maxs = entity:GetModelBounds()
    if mins == maxs then
        mins, maxs = entity:GetRenderBounds()
    end

    local sizeVec = maxs - mins
    local radius = math.max(sizeVec:Length(), 48)
    local height = math.max(sizeVec.z, 32)
    local center = (mins + maxs) * 0.5
    local lookAt = center + Vector(0, 0, math.max(4, height * 0.06))

    panel:SetFOV(20)
    panel:SetLookAt(lookAt)
    panel:SetCamPos(lookAt + Vector(radius * 0.58, radius * 1.55, height * 0.18))
end

local function setPanelModel(panel, modelPath)
    if not IsValid(panel) then
        return
    end

    modelPath = util.IsValidModel(modelPath or "") and modelPath or Config.DefaultJobModel
    panel:SetModel(modelPath)

    timer.Simple(0, function()
        if not IsValid(panel) then return end
        fitModelPanel(panel)
    end)
end

local function chooseJob(job)
    if not istable(job) then
        notifyLocal(false, "Работа не найдена.")
        return
    end

    local command = trim(job.command)
    local jobId = trim(job.id)
    if command == "" and jobId == "" then
        notifyLocal(false, "У работы не задана команда.")
        return
    end

    net.Start("ZCityDarkRPShop.ChooseJob")
    net.WriteString(jobId ~= "" and jobId or command)
    net.SendToServer()

    if IsValid(jobsFrame) then
        jobsFrame:Close()
    end

    timer.Simple(0.35, requestState)
end

local function sendMoney(action, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then
        return
    end

    if action == "give" then
        RunConsoleCommand("darkrp", "give", tostring(amount))
    else
        RunConsoleCommand("darkrp", "dropmoney", tostring(amount))
    end
end

local function getAvailableWeapons()
    local weaponsFound = {}
    local seen = {}

    for _, swep in ipairs(weapons.GetList() or {}) do
        local className = swep.ClassName or swep.Class or swep.Classname
        if className and className ~= "" and not seen[className] then
            seen[className] = true
            weaponsFound[#weaponsFound + 1] = {
                class = className,
                name = swep.PrintName or className
            }
        end
    end

    table.sort(weaponsFound, function(left, right)
        local leftName = string.lower(left.name or left.class or "")
        local rightName = string.lower(right.name or right.class or "")

        if leftName == rightName then
            return string.lower(left.class or "") < string.lower(right.class or "")
        end

        return leftName < rightName
    end)

    return weaponsFound
end

local function getAvailableModels()
    local modelsFound = {}
    local seen = {}

    local function addModel(name, modelPath)
        modelPath = trim(modelPath)
        if modelPath == "" or seen[string.lower(modelPath)] then
            return
        end

        seen[string.lower(modelPath)] = true
        modelsFound[#modelsFound + 1] = {
            name = trim(name) ~= "" and trim(name) or modelPath,
            model = modelPath
        }
    end

    for name, modelPath in pairs(player_manager.AllValidModels() or {}) do
        addModel(name, modelPath)
    end

    for name, modelPath in pairs(list.Get("PlayerOptionsModel") or {}) do
        addModel(name, modelPath)
    end

    table.sort(modelsFound, function(left, right)
        local leftName = string.lower(left.name or left.model or "")
        local rightName = string.lower(right.name or right.model or "")
        if leftName == rightName then
            return string.lower(left.model or "") < string.lower(right.model or "")
        end

        return leftName < rightName
    end)

    return modelsFound
end

local function getAvailableEntitiesByPrefixes(prefixes)
    local found = {}
    local seen = {}

    local function matchesPrefix(className)
        className = string.lower(trim(className))
        for _, prefix in ipairs(prefixes or {}) do
            if string.StartWith(className, string.lower(prefix)) then
                return true
            end
        end

        return false
    end

    local function addEntry(name, className, modelPath)
        className = trim(className)
        if className == "" or seen[string.lower(className)] then
            return
        end

        seen[string.lower(className)] = true
        found[#found + 1] = {
            name = trim(name) ~= "" and trim(name) or className,
            class = className,
            model = trim(modelPath)
        }
    end

    for className, data in pairs(list.Get("SpawnableEntities") or {}) do
        if matchesPrefix(className) then
            addEntry(data.PrintName or data.Name or className, className, data.Model or "")
        end
    end

    for className, stored in pairs(scripted_ents.GetList() or {}) do
        local data = istable(stored) and (stored.t or stored) or {}
        if matchesPrefix(className) then
            addEntry(data.PrintName or data.Name or className, className, data.Model or "")
        end
    end

    table.sort(found, function(left, right)
        local leftName = string.lower(left.name or left.class or "")
        local rightName = string.lower(right.name or right.class or "")
        if leftName == rightName then
            return string.lower(left.class or "") < string.lower(right.class or "")
        end

        return leftName < rightName
    end)

    return found
end

local function getAvailableAmmo()
    return getAvailableEntitiesByPrefixes({ "ent_ammo_" })
end

local function getAvailableAttachments()
    return getAvailableEntitiesByPrefixes({ "ent_att_" })
end

local function getAvailableArmor()
    return getAvailableEntitiesByPrefixes({ "ent_armor_" })
end

local function appendUniqueMultilineValue(entry, rawValue, maxEntries)
    if not IsValid(entry) then
        return
    end

    local value = trim(rawValue)
    if value == "" then
        return
    end

    local existing = splitMultiline(entry:GetValue(), maxEntries)
    for _, current in ipairs(existing) do
        if string.lower(current) == string.lower(value) then
            return
        end
    end

    existing[#existing + 1] = value
    if maxEntries and #existing > maxEntries then
        while #existing > maxEntries do
            table.remove(existing)
        end
    end

    entry:SetText(table.concat(existing, "\n"))
end

local function groupedJobs()
    local jobs = table.Copy(JobClient.State.jobs or {})

    table.sort(jobs, function(left, right)
        local leftCategory = string.lower(left.category or "")
        local rightCategory = string.lower(right.category or "")
        if leftCategory == rightCategory then
            return string.lower(left.name or "") < string.lower(right.name or "")
        end

        return leftCategory < rightCategory
    end)

    local grouped = {}
    for _, job in ipairs(jobs) do
        local category = trim(job.category)
        if category == "" then
            category = "Other"
        end

        grouped[category] = grouped[category] or {}
        grouped[category][#grouped[category] + 1] = job
    end

    return grouped
end

local function findSelectedJob()
    for _, job in ipairs(JobClient.State.jobs or {}) do
        if job.id == selectedJobId then
            return job
        end
    end

    if JobClient.State.jobs and JobClient.State.jobs[1] then
        selectedJobId = JobClient.State.jobs[1].id
        return JobClient.State.jobs[1]
    end
end

local function promptMoney(action)
    local title = action == "give" and "Give Money" or "Drop Money"
    local instructions = action == "give"
        and "Enter amount. Look at a nearby player when confirming."
        or "Enter amount to drop."

    Derma_StringRequest(title, instructions, "", function(value)
        local amount = math.floor(tonumber(value) or 0)
        if amount <= 0 then
            notifyLocal(false, "Нужно ввести сумму больше нуля.")
            return
        end

        sendMoney(action, amount)
        requestState()
    end)
end

local openAdminEditor
local refreshJobsMenu

local function buildJobInfo(infoPanel, actionButton)
    local job = findSelectedJob()
    if not job then
        infoPanel.Title:SetText("Нет доступных работ")
        infoPanel.Subtitle:SetText("Сначала добавь хотя бы одну работу через редактор.")
        infoPanel.Description:SetText("")
        infoPanel.Meta:SetText("")
        infoPanel.Weapons:SetText("")
        setPanelModel(infoPanel.Model, Config.DefaultJobModel)
        actionButton:SetText("Выбрать работу")
        actionButton:SetEnabled(false)
        return
    end

    local teamId = tonumber(job.teamId or 0)
    local teamCount = teamId > 0 and team.NumPlayers(teamId) or 0
    local maxText = tonumber(job.max or 0) == 0 and "∞" or tostring(job.max)
    local firstModel = istable(job.models) and job.models[1] or Config.DefaultJobModel
    local currentTeam = IsValid(LocalPlayer()) and LocalPlayer():Team() or -1

    infoPanel.Title:SetText(job.name or "Unknown")
    infoPanel.Subtitle:SetText(string.format("%s | Команда: /%s", job.category or "Other", job.command or "job"))
    infoPanel.Meta:SetText(string.format(
        "Зарплата: %s\nИгроков: %d/%s\nБроня: %d\nЛицензия: %s\nУвольнение: %s",
        formatMoney(job.salary or 0),
        teamCount,
        maxText,
        math.max(0, math.floor(tonumber(job.armor) or 0)),
        job.hasLicense and "Да" or "Нет",
        job.candemote and "Да" or "Нет"
    ))
    infoPanel.Description:SetText(job.description ~= "" and tostring(job.description) or "Описание пока не задано.")

    local weaponsText = #table.Copy(job.weapons or {}) > 0 and table.concat(job.weapons, ", ") or "Нет стартового оружия"
    infoPanel.Weapons:SetText("Оружие: " .. weaponsText)

    if util.IsValidModel(firstModel or "") then
        setPanelModel(infoPanel.Model, firstModel)
    else
        setPanelModel(infoPanel.Model, Config.DefaultJobModel)
    end

    if trim(job.command or "") == "" then
        actionButton:SetText("Нет команды")
        actionButton:SetEnabled(false)
        return
    end

    if teamId > 0 and currentTeam == teamId then
        actionButton:SetText("Работа уже выбрана")
        actionButton:SetEnabled(false)
        return
    end

    actionButton:SetText(job.vote == true and "Запустить голосование" or "Выбрать работу")
    actionButton:SetEnabled(true)
end

local function rebuildJobsList(listLayout, infoPanel, actionButton)
    listLayout:Clear()

    local grouped = groupedJobs()
    local categoryNames = {}
    for category in pairs(grouped) do
        categoryNames[#categoryNames + 1] = category
    end

    table.sort(categoryNames, function(left, right)
        return string.lower(left) < string.lower(right)
    end)

    if #categoryNames == 0 then
        buildJobInfo(infoPanel, actionButton)
        return
    end

    for _, category in ipairs(categoryNames) do
        local header = listLayout:Add("DPanel")
        header:SetTall(34)
        header.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, palette.green)
            draw.SimpleText(category, "ZCityJobs.Section", 12, h / 2, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        for _, job in ipairs(grouped[category]) do
            local row = listLayout:Add("DButton")
            row:SetTall(72)
            row:SetText("")

            local icon = vgui.Create("SpawnIcon", row)
            icon:SetPos(8, 8)
            icon:SetSize(56, 56)
            icon:SetModel((job.models and job.models[1]) or Config.DefaultJobModel)
            icon:SetTooltip(false)
            icon:SetMouseInputEnabled(false)

            row.Paint = function(self, w, h)
                local active = selectedJobId == job.id
                local background = active and ColorAlpha(jobColor(job), 180) or (self:IsHovered() and palette.panelLight or palette.panelAlt)

                draw.RoundedBox(8, 0, 0, w, h, background)
                surface.SetDrawColor(palette.line)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(job.name or "Unknown", "ZCityJobs.Body", 76, 22, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(
                    string.format("%s | %s", formatMoney(job.salary or 0), "/" .. tostring(job.command or "job")),
                    "ZCityJobs.Small",
                    76,
                    48,
                    palette.textDim,
                    TEXT_ALIGN_LEFT,
                    TEXT_ALIGN_CENTER
                )
            end

            row.DoClick = function()
                selectedJobId = job.id
                buildJobInfo(infoPanel, actionButton)
            end
        end
    end

    buildJobInfo(infoPanel, actionButton)
end

local function buildJobsMenu()
    if IsValid(jobsFrame) then
        jobsFrame:Remove()
    end

    jobsFrame = vgui.Create("DFrame")
    jobsFrame:SetSize(math.min(1320, ScrW() - 90), math.min(800, ScrH() - 100))
    jobsFrame:Center()
    jobsFrame:SetTitle("")
    jobsFrame:ShowCloseButton(false)
    jobsFrame:MakePopup()
    jobsFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, palette.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 64, palette.header, true, true, false, false)
        draw.SimpleText("Работы Aftermath", "ZCityJobs.Title", 22, 22, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Список доступных профессий, модели и стартового снаряжения.", "ZCityJobs.Small", 24, 46, palette.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeButton = vgui.Create("DButton", jobsFrame)
    closeButton:SetText("X")
    closeButton:SetSize(40, 28)
    closeButton:SetPos(jobsFrame:GetWide() - 52, 16)
    styleButton(closeButton, palette.accent, palette.accentHover)
    closeButton.DoClick = function()
        jobsFrame:Close()
    end

    local leftPanel = vgui.Create("DPanel", jobsFrame)
    leftPanel:SetPos(16, 76)
    leftPanel:SetSize(math.floor(jobsFrame:GetWide() * 0.43), jobsFrame:GetTall() - 92)
    leftPanel.Paint = function(self, w, h)
        paintPanel(self, w, h, ColorAlpha(palette.panel, 230))
    end

    local rightPanel = vgui.Create("DPanel", jobsFrame)
    rightPanel:SetPos(leftPanel:GetWide() + 28, 76)
    rightPanel:SetSize(jobsFrame:GetWide() - leftPanel:GetWide() - 44, jobsFrame:GetTall() - 92)
    rightPanel.Paint = function(self, w, h)
        paintPanel(self, w, h, ColorAlpha(palette.panelAlt, 235))
    end

    local balanceLabel = vgui.Create("DLabel", leftPanel)
    balanceLabel:SetFont("ZCityJobs.Body")
    balanceLabel:SetTextColor(palette.green)
    balanceLabel:SetText("Баланс: " .. formatMoney(localBalance()))
    balanceLabel:SetPos(14, 12)
    balanceLabel:SizeToContents()

    local openEditorButton = vgui.Create("DButton", leftPanel)
    openEditorButton:SetText("Редактор работ")
    openEditorButton:SetSize(180, 32)
    openEditorButton:SetPos(leftPanel:GetWide() - 194, 10)
    openEditorButton:SetVisible(JobClient.State.canManage or isAllowedManager())
    styleButton(openEditorButton, palette.gold, Color(238, 200, 75))
    openEditorButton.DoClick = function()
        openAdminEditor()
    end

    local listScroll = vgui.Create("DScrollPanel", leftPanel)
    listScroll:SetPos(12, 56)
    listScroll:SetSize(leftPanel:GetWide() - 24, leftPanel:GetTall() - 68)

    local listLayout = vgui.Create("DListLayout", listScroll)
    listLayout:Dock(TOP)

    local info = vgui.Create("DPanel", rightPanel)
    info:SetPos(14, 14)
    info:SetSize(rightPanel:GetWide() - 28, rightPanel:GetTall() - 90)
    info.Paint = nil

    info.Title = vgui.Create("DLabel", info)
    info.Title:SetFont("ZCityJobs.Title")
    info.Title:SetTextColor(palette.text)

    info.Subtitle = vgui.Create("DLabel", info)
    info.Subtitle:SetFont("ZCityJobs.Small")
    info.Subtitle:SetTextColor(palette.textDim)

    info.ModelCard = vgui.Create("DPanel", info)
    info.ModelCard.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, ColorAlpha(palette.panelLight, 220))
        surface.SetDrawColor(palette.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    info.Model = vgui.Create("DModelPanel", info)
    setPanelModel(info.Model, Config.DefaultJobModel)
    info.Model.LayoutEntity = function(_, entity)
        if not IsValid(entity) then return end
        entity:SetAngles(Angle(0, 28, 0))
        entity:FrameAdvance(RealFrameTime() * 0.5)
    end

    info.MetaCard = vgui.Create("DPanel", info)
    info.MetaCard.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, ColorAlpha(palette.panelLight, 220))
        surface.SetDrawColor(palette.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    info.Meta = vgui.Create("DLabel", info)
    info.Meta:SetFont("ZCityJobs.Body")
    info.Meta:SetTextColor(palette.text)
    info.Meta:SetWrap(true)
    info.Meta:SetAutoStretchVertical(true)

    info.DescriptionTitle = vgui.Create("DLabel", info)
    info.DescriptionTitle:SetFont("ZCityJobs.Small")
    info.DescriptionTitle:SetTextColor(palette.text)
    info.DescriptionTitle:SetText("Описание")

    info.DescriptionCard = vgui.Create("DPanel", info)
    info.DescriptionCard.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, ColorAlpha(palette.panelLight, 220))
        surface.SetDrawColor(palette.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    info.DescriptionScroll = vgui.Create("DScrollPanel", info.DescriptionCard)

    info.Description = vgui.Create("DLabel", info.DescriptionScroll)
    info.Description:SetFont("ZCityJobs.Body")
    info.Description:SetTextColor(palette.textDim)
    info.Description:SetWrap(true)
    info.Description:SetAutoStretchVertical(true)

    info.WeaponsTitle = vgui.Create("DLabel", info)
    info.WeaponsTitle:SetFont("ZCityJobs.Small")
    info.WeaponsTitle:SetTextColor(palette.text)
    info.WeaponsTitle:SetText("Снаряжение")

    info.WeaponsCard = vgui.Create("DPanel", info)
    info.WeaponsCard.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, ColorAlpha(palette.panelLight, 220))
        surface.SetDrawColor(palette.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    info.WeaponsScroll = vgui.Create("DScrollPanel", info.WeaponsCard)

    info.Weapons = vgui.Create("DLabel", info.WeaponsScroll)
    info.Weapons:SetFont("ZCityJobs.Body")
    info.Weapons:SetTextColor(palette.text)
    info.Weapons:SetWrap(true)
    info.Weapons:SetAutoStretchVertical(true)

    local chooseButton = vgui.Create("DButton", rightPanel)
    chooseButton:SetText("Выбрать работу")
    styleButton(chooseButton, palette.accent, palette.accentHover)
    chooseButton.DoClick = function()
        local job = findSelectedJob()
        if not job then
            return
        end

        chooseJob(job)
    end

    info.PerformLayout = function(self, w, h)
        local modelWidth = math.min(300, math.max(240, math.floor(w * 0.42)))
        local cardGap = 16
        local topY = 74
        local modelHeight = 336
        local sideX = modelWidth + cardGap
        local sideWidth = math.max(180, w - sideX)
        local descriptionY = topY + modelHeight + cardGap

        self.Title:SetPos(0, 0)
        self.Title:SetSize(w, 42)

        self.Subtitle:SetPos(0, 44)
        self.Subtitle:SetSize(w, 22)

        self.ModelCard:SetPos(0, topY)
        self.ModelCard:SetSize(modelWidth, modelHeight)

        self.Model:SetPos(10, topY + 10)
        self.Model:SetSize(modelWidth - 20, modelHeight - 20)

        self.MetaCard:SetPos(sideX, topY)
        self.MetaCard:SetSize(sideWidth, modelHeight)

        self.Meta:SetPos(sideX + 16, topY + 16)
        self.Meta:SetSize(sideWidth - 32, modelHeight - 32)

        self.DescriptionTitle:SetPos(0, descriptionY)
        self.DescriptionTitle:SizeToContents()

        self.DescriptionCard:SetPos(0, descriptionY + 26)
        self.DescriptionCard:SetSize(w, 122)

        self.DescriptionScroll:SetPos(12, 12)
        self.DescriptionScroll:SetSize(w - 24, 98)
        self.Description:SetPos(0, 0)
        self.Description:SetWide(math.max(64, self.DescriptionScroll:GetWide() - 12))
        self.Description:SizeToContentsY()

        self.WeaponsTitle:SetPos(0, descriptionY + 158)
        self.WeaponsTitle:SizeToContents()

        self.WeaponsCard:SetPos(0, descriptionY + 184)
        self.WeaponsCard:SetSize(w, 96)

        self.WeaponsScroll:SetPos(12, 12)
        self.WeaponsScroll:SetSize(w - 24, 72)
        self.Weapons:SetPos(0, 0)
        self.Weapons:SetWide(math.max(64, self.WeaponsScroll:GetWide() - 12))
        self.Weapons:SizeToContentsY()
    end

    rightPanel.PerformLayout = function(self, w, h)
        info:SetPos(14, 14)
        info:SetSize(w - 28, h - 90)

        chooseButton:SetPos(12, h - 64)
        chooseButton:SetSize(w - 24, 52)
    end

    rebuildJobsList(listLayout, info, chooseButton)
    return
--[[

    jobsFrame = vgui.Create("DFrame")
    jobsFrame:SetSize(math.min(1460, ScrW() - 70), math.min(860, ScrH() - 80))
    jobsFrame:Center()
    jobsFrame:SetTitle("")
    jobsFrame:ShowCloseButton(false)
    jobsFrame:MakePopup()
    jobsFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, palette.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 62, palette.header, true, true, false, false)
        draw.SimpleText("Работы Aftermath", "ZCityJobs.Title", 22, 20, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Выбор работы и просмотр её снаряжения.", "ZCityJobs.Small", 24, 46, palette.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeButton = vgui.Create("DButton", jobsFrame)
    closeButton:SetText("X")
    closeButton:SetSize(40, 28)
    closeButton:SetPos(jobsFrame:GetWide() - 52, 16)
    styleButton(closeButton, palette.accent, palette.accentHover)
    closeButton.DoClick = function()
        jobsFrame:Close()
    end

    local leftPanel = vgui.Create("DPanel", jobsFrame)
    leftPanel:SetPos(16, 76)
    leftPanel:SetSize(math.floor(jobsFrame:GetWide() * 0.54) - 22, jobsFrame:GetTall() - 92)
    leftPanel.Paint = function(self, w, h)
        paintPanel(self, w, h, ColorAlpha(palette.panel, 230))
    end

    local rightPanel = vgui.Create("DPanel", jobsFrame)
    rightPanel:SetPos(leftPanel:GetWide() + 28, 76)
    rightPanel:SetSize(jobsFrame:GetWide() - leftPanel:GetWide() - 44, jobsFrame:GetTall() - 92)
    rightPanel.Paint = function(self, w, h)
        paintPanel(self, w, h, ColorAlpha(palette.panelAlt, 235))
    end

    local balanceLabel = vgui.Create("DLabel", leftPanel)
    balanceLabel:SetFont("ZCityJobs.Body")
    balanceLabel:SetTextColor(palette.green)
    balanceLabel:SetText("Баланс: " .. formatMoney(localBalance()))
    balanceLabel:SetPos(14, 10)
    balanceLabel:SizeToContents()

    local openEditorButton = vgui.Create("DButton", leftPanel)
    openEditorButton:SetText("Редактор работ")
    openEditorButton:SetSize(180, 32)
    openEditorButton:SetPos(leftPanel:GetWide() - 194, 10)
    openEditorButton:SetVisible(false)
    styleButton(openEditorButton, palette.gold, Color(238, 200, 75))
    openEditorButton.DoClick = function()
        openAdminEditor()
    end

    local listScroll = vgui.Create("DScrollPanel", leftPanel)
    listScroll:SetPos(12, 52)
    listScroll:SetSize(leftPanel:GetWide() - 24, leftPanel:GetTall() - 64)

    local listLayout = vgui.Create("DListLayout", listScroll)
    listLayout:Dock(TOP)

    local infoScroll = vgui.Create("DScrollPanel", rightPanel)
    infoScroll:SetPos(12, 12)
    infoScroll:SetSize(rightPanel:GetWide() - 24, rightPanel:GetTall() - 92)

    local chooseButton = vgui.Create("DButton", rightPanel)
    chooseButton:SetText("Р’С‹Р±СЂР°С‚СЊ СЂР°Р±РѕС‚Сѓ")
    styleButton(chooseButton, palette.accent, palette.accentHover)
    chooseButton.DoClick = function()
        local job = findSelectedJob()
        if not job then
            return
        end

        chooseJob(job)
    end

    local info = vgui.Create("DPanel", infoScroll)
    info:Dock(TOP)
    info:SetTall(660)
    info.Paint = nil

    info.Title = vgui.Create("DLabel", info)
    info.Title:SetFont("ZCityJobs.Title")
    info.Title:SetTextColor(palette.text)

    info.Subtitle = vgui.Create("DLabel", info)
    info.Subtitle:SetFont("ZCityJobs.Small")
    info.Subtitle:SetTextColor(palette.textDim)

    info.Model = vgui.Create("DModelPanel", info)
    setPanelModel(info.Model, Config.DefaultJobModel)
    info.Model.LayoutEntity = function(_, entity)
        if not IsValid(entity) then return end
        entity:SetAngles(Angle(0, 30, 0))
        entity:FrameAdvance(RealFrameTime() * 0.5)
    end

    info.Meta = vgui.Create("DLabel", info)
    info.Meta:SetFont("ZCityJobs.Body")
    info.Meta:SetTextColor(palette.text)
    info.Meta:SetWrap(true)
    info.Meta:SetAutoStretchVertical(true)

    info.Description = vgui.Create("DLabel", info)
    info.Description:SetFont("ZCityJobs.Body")
    info.Description:SetTextColor(palette.textDim)
    info.Description:SetWrap(true)
    info.Description:SetAutoStretchVertical(true)

    info.Weapons = vgui.Create("DLabel", info)
    info.Weapons:SetFont("ZCityJobs.Body")
    info.Weapons:SetTextColor(palette.text)
    info.Weapons:SetWrap(true)
    info.Weapons:SetAutoStretchVertical(true)

    chooseButton:SetParent(rightPanel)
    chooseButton:SetText("Выбрать работу")
    styleButton(chooseButton, palette.accent, palette.accentHover)
    chooseButton.DoClick = function()
        local job = findSelectedJob()
        if not job then
            return
        end

        chooseJob(job)
    end

    info.PerformLayout = function(self, w, h)
        local modelWidth = math.min(math.floor(w * 0.5), 300)
        local modelHeight = 320
        local metaX = modelWidth + 18
        local metaWidth = math.max(120, w - metaX)

        self.Title:SetPos(0, 0)
        self.Title:SetSize(w, 42)

        self.Subtitle:SetPos(0, 44)
        self.Subtitle:SetSize(w, 22)

        self.Model:SetPos(0, 82)
        self.Model:SetSize(modelWidth, modelHeight)

        self.Meta:SetPos(metaX, 92)
        self.Meta:SetSize(metaWidth, 168)

        self.Description:SetPos(0, 420)
        self.Description:SetSize(w, 118)

        self.Weapons:SetPos(0, 546)
        self.Weapons:SetSize(w, 82)

        chooseButton:SetPos(12, rightPanel:GetTall() - 64)
        chooseButton:SetSize(rightPanel:GetWide() - 24, 52)
    end

    rightPanel.PerformLayout = function(self, w, h)
        infoScroll:SetPos(12, 12)
        infoScroll:SetSize(w - 24, h - 92)

        chooseButton:SetPos(12, h - 64)
        chooseButton:SetSize(w - 24, 52)
    end

    rebuildJobsList(listLayout, info, chooseButton)
]]
end

local function editorDefaultJob()
    return {
        id = "",
        name = "",
        description = "",
        command = "",
        category = "Citizens",
        models = { Config.DefaultJobModel },
        weapons = {},
        ammo = {},
        attachments = {},
        armor = 0,
        armorClass = "",
        salary = 45,
        max = 0,
        admin = 0,
        vote = false,
        hasLicense = false,
        candemote = false,
        canDemoteOthers = false,
        spawn = nil,
        color = { r = 0, g = 107, b = 0, a = 255 }
    }
end

local function editorFindJob(jobId)
    for index, job in ipairs(editorJobs or {}) do
        if job.id == jobId then
            return job, index
        end
    end
end

local function editorApplyToForm(job)
    job = job or editorDefaultJob()

    editorControls.name:SetText(job.name or "")
    editorControls.command:SetText(job.command or "")
    editorControls.category:SetText(job.category or "Citizens")
    editorControls.description:SetText(job.description or "")
    editorControls.models:SetText(joinMultiline(job.models or { Config.DefaultJobModel }))
    editorControls.weapons:SetText(joinMultiline(job.weapons or {}))
    editorControls.ammo:SetText(joinMultiline(job.ammo or {}))
    editorControls.attachments:SetText(joinMultiline(job.attachments or {}))
    editorControls.armor:SetText(tostring(job.armor or 0))
    editorControls.armorClass:SetText(job.armorClass or "")
    editorControls.salary:SetText(tostring(job.salary or 45))
    editorControls.maxPlayers:SetText(tostring(job.max or 0))
    editorControls.colorR:SetText(tostring((job.color and job.color.r) or 0))
    editorControls.colorG:SetText(tostring((job.color and job.color.g) or 107))
    editorControls.colorB:SetText(tostring((job.color and job.color.b) or 0))
    editorControls.vote:SetChecked(job.vote == true)
    editorControls.hasLicense:SetChecked(job.hasLicense == true)
    editorControls.candemote:SetChecked(job.candemote == true)
    editorControls.canDemoteOthers:SetChecked(job.canDemoteOthers == true)
    editorControls.adminLevel:ChooseOptionID((math.Clamp(tonumber(job.admin) or 0, 0, 2)) + 1)
    editorControls.spawnRecord = istable(job.spawn) and table.Copy(job.spawn) or nil

    if IsValid(editorControls.spawnStatus) then
        if istable(editorControls.spawnRecord) and istable(editorControls.spawnRecord.pos) then
            local pos = editorControls.spawnRecord.pos
            editorControls.spawnStatus:SetText(string.format(
                "Свой спавн: %.0f %.0f %.0f",
                tonumber(pos.x) or 0,
                tonumber(pos.y) or 0,
                tonumber(pos.z) or 0
            ))
        else
            editorControls.spawnStatus:SetText("Свой спавн: не задан")
        end
    end

    local previewModel = splitMultiline(editorControls.models:GetValue(), 1)[1] or Config.DefaultJobModel
    setPanelModel(editorControls.preview, previewModel)
end

local function editorCollectFromForm()
    local adminIndex = math.max(1, editorControls.adminLevel:GetSelectedID() or 1) - 1

    return {
        id = editorSelectedId or "",
        name = trim(editorControls.name:GetValue()),
        command = trim(editorControls.command:GetValue()),
        category = trim(editorControls.category:GetValue()),
        description = trim(editorControls.description:GetValue()),
        models = splitMultiline(editorControls.models:GetValue(), 8),
        weapons = splitMultiline(editorControls.weapons:GetValue(), 24),
        ammo = splitMultiline(editorControls.ammo:GetValue(), 24),
        attachments = splitMultiline(editorControls.attachments:GetValue(), 24),
        armor = math.max(0, math.floor(tonumber(editorControls.armor:GetValue()) or 0)),
        armorClass = trim(editorControls.armorClass:GetValue()),
        salary = math.max(0, math.floor(tonumber(editorControls.salary:GetValue()) or 45)),
        max = math.max(0, math.floor(tonumber(editorControls.maxPlayers:GetValue()) or 0)),
        admin = adminIndex,
        vote = editorControls.vote:GetChecked(),
        hasLicense = editorControls.hasLicense:GetChecked(),
        candemote = editorControls.candemote:GetChecked(),
        canDemoteOthers = editorControls.canDemoteOthers:GetChecked(),
        spawn = istable(editorControls.spawnRecord) and table.Copy(editorControls.spawnRecord) or nil,
        color = {
            r = math.Clamp(math.floor(tonumber(editorControls.colorR:GetValue()) or 0), 0, 255),
            g = math.Clamp(math.floor(tonumber(editorControls.colorG:GetValue()) or 107), 0, 255),
            b = math.Clamp(math.floor(tonumber(editorControls.colorB:GetValue()) or 0), 0, 255),
            a = 255
        }
    }
end

local function refreshEditorList(list)
    list:Clear()

    table.sort(editorJobs, function(left, right)
        return string.lower(left.name or "") < string.lower(right.name or "")
    end)

    for _, job in ipairs(editorJobs) do
        addStyledLine(list, job.name or "", "/" .. tostring(job.command or ""), job.category or "Other")
    end
end

openAdminEditor = function()
    if not JobClient.State.canManage and not isAllowedManager() then
        notifyLocal(false, JobClient.State.manageReason ~= "" and JobClient.State.manageReason or "Только ULX admin/superadmin может менять работы.")
        return
    end

    if IsValid(adminFrame) then
        adminFrame:MakePopup()
        return
    end

    editorJobs = table.Copy(JobClient.State.jobs or {})
    editorSelectedId = editorJobs[1] and editorJobs[1].id or nil

    adminFrame = vgui.Create("DFrame")
    adminFrame:SetSize(math.min(1540, ScrW() - 50), math.min(920, ScrH() - 50))
    adminFrame:Center()
    adminFrame:SetTitle("")
    adminFrame:ShowCloseButton(false)
    adminFrame:MakePopup()
    adminFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, palette.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 58, palette.header, true, true, false, false)
        draw.SimpleText("Редактор работ", "ZCityJobs.Title", 18, 19, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ULX admin/superadmin может создавать и менять работы прямо в игре.", "ZCityJobs.Small", 20, 44, palette.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeButton = vgui.Create("DButton", adminFrame)
    closeButton:SetText("X")
    closeButton:SetSize(40, 28)
    closeButton:SetPos(adminFrame:GetWide() - 52, 16)
    styleButton(closeButton, palette.accent, palette.accentHover)
    closeButton.DoClick = function()
        adminFrame:Close()
    end

    local jobsListPanel = vgui.Create("DPanel", adminFrame)
    jobsListPanel:SetPos(12, 72)
    jobsListPanel:SetSize(320, adminFrame:GetTall() - 84)
    jobsListPanel.Paint = function(self, w, h)
        paintPanel(self, w, h, palette.panel)
    end

    local listTitle = vgui.Create("DLabel", jobsListPanel)
    listTitle:SetFont("ZCityJobs.Section")
    listTitle:SetTextColor(palette.text)
    listTitle:SetText("Список работ")
    listTitle:SetPos(12, 10)
    listTitle:SizeToContents()

    local jobsList = vgui.Create("DListView", jobsListPanel)
    jobsList:SetPos(10, 44)
    jobsList:SetSize(jobsListPanel:GetWide() - 20, jobsListPanel:GetTall() - 54)
    styleListView(jobsList)
    jobsList:AddColumn("Имя")
    jobsList:AddColumn("Команда")
    jobsList:AddColumn("Категория")
    jobsList.OnRowSelected = function(_, rowIndex)
        local job = editorJobs[rowIndex]
        if not job then
            return
        end

        editorSelectedId = job.id
        editorApplyToForm(job)
    end
    styleListView(jobsList)

    local formPanel = vgui.Create("DScrollPanel", adminFrame)
    formPanel:SetPos(342, 72)
    formPanel:SetSize(440, adminFrame:GetTall() - 84)

    local form = vgui.Create("DPanel", formPanel)
    form:Dock(TOP)
    form:SetTall(1180)
    form.Paint = nil

    local weaponsPanel = vgui.Create("DPanel", adminFrame)
    weaponsPanel:SetPos(792, 72)
    weaponsPanel:SetSize(adminFrame:GetWide() - 804, adminFrame:GetTall() - 84)
    weaponsPanel.Paint = function(self, w, h)
        paintPanel(self, w, h, palette.panelAlt)
    end

    local function makeFieldLabel(parent, text, x, y)
        local label = vgui.Create("DLabel", parent)
        label:SetFont("ZCityJobs.Small")
        label:SetTextColor(palette.textDim)
        label:SetText(text)
        label:SetPos(x, y)
        label:SizeToContents()
        return label
    end

    local function makeEntry(parent, x, y, w, h, multiline)
        local entry = vgui.Create("DTextEntry", parent)
        entry:SetPos(x, y)
        entry:SetSize(w, h)
        entry:SetMultiline(multiline == true)
        styleTextEntry(entry)
        return entry
    end

    local y = 8
    makeFieldLabel(form, "Название работы", 0, y)
    y = y + 20
    editorControls.name = makeEntry(form, 0, y, 420, 34)
    y = y + 48

    makeFieldLabel(form, "Команда (/job)", 0, y)
    y = y + 20
    editorControls.command = makeEntry(form, 0, y, 200, 34)
    makeFieldLabel(form, "Категория", 220, y - 20)
    editorControls.category = makeEntry(form, 220, y, 200, 34)
    y = y + 48

    makeFieldLabel(form, "Описание", 0, y)
    y = y + 20
    editorControls.description = makeEntry(form, 0, y, 420, 120, true)
    y = y + 136

    makeFieldLabel(form, "Модель(и), по одной в строке", 0, y)
    y = y + 20
    editorControls.models = makeEntry(form, 0, y, 420, 96, true)
    y = y + 112

    makeFieldLabel(form, "Оружие, по одному class в строке", 0, y)
    y = y + 20
    editorControls.weapons = makeEntry(form, 0, y, 420, 120, true)
    y = y + 136

    makeFieldLabel(form, "Броня", 0, y)
    editorControls.armor = makeEntry(form, 0, y + 20, 120, 34)
    makeFieldLabel(form, "Зарплата", 150, y)
    editorControls.salary = makeEntry(form, 150, y + 20, 120, 34)
    makeFieldLabel(form, "Макс. игроков (0 = без лимита)", 300, y)
    editorControls.maxPlayers = makeEntry(form, 300, y + 20, 120, 34)
    y = y + 68

    makeFieldLabel(form, "Цвет R", 0, y)
    editorControls.colorR = makeEntry(form, 0, y + 20, 120, 34)
    makeFieldLabel(form, "Цвет G", 150, y)
    editorControls.colorG = makeEntry(form, 150, y + 20, 120, 34)
    makeFieldLabel(form, "Цвет B", 300, y)
    editorControls.colorB = makeEntry(form, 300, y + 20, 120, 34)
    y = y + 70

    makeFieldLabel(form, "Кому доступна работа", 0, y)
    y = y + 22
    editorControls.adminLevel = vgui.Create("DComboBox", form)
    editorControls.adminLevel:SetPos(0, y)
    editorControls.adminLevel:SetSize(420, 32)
    editorControls.adminLevel:SetValue("Игроки")
    editorControls.adminLevel:AddChoice("Игроки", 0)
    editorControls.adminLevel:AddChoice("Только admin", 1)
    editorControls.adminLevel:AddChoice("Только superadmin", 2)
    styleComboBox(editorControls.adminLevel)
    y = y + 52

    editorControls.vote = vgui.Create("DCheckBoxLabel", form)
    editorControls.vote:SetPos(0, y)
    editorControls.vote:SetText("Требуется голосование")
    editorControls.vote:SetTextColor(palette.text)
    editorControls.vote:SizeToContents()

    editorControls.hasLicense = vgui.Create("DCheckBoxLabel", form)
    editorControls.hasLicense:SetPos(0, y + 28)
    editorControls.hasLicense:SetText("Есть лицензия на оружие")
    editorControls.hasLicense:SetTextColor(palette.text)
    editorControls.hasLicense:SizeToContents()

    editorControls.candemote = vgui.Create("DCheckBoxLabel", form)
    editorControls.candemote:SetPos(0, y + 56)
    editorControls.candemote:SetText("Можно уволить")
    editorControls.candemote:SetTextColor(palette.text)
    editorControls.candemote:SizeToContents()
    y = y + 104

    local newButton = vgui.Create("DButton", form)
    newButton:SetText("Новая работа")
    newButton:SetPos(0, y)
    newButton:SetSize(132, 40)
    styleButton(newButton, palette.green, palette.greenHover)

    local saveButton = vgui.Create("DButton", form)
    saveButton:SetText("Сохранить")
    saveButton:SetPos(144, y)
    saveButton:SetSize(132, 40)
    styleButton(saveButton, palette.gold, Color(238, 200, 75))

    local deleteButton = vgui.Create("DButton", form)
    deleteButton:SetText("Удалить")
    deleteButton:SetPos(288, y)
    deleteButton:SetSize(132, 40)
    styleButton(deleteButton, palette.accent, palette.accentHover)

    local previewTitle = vgui.Create("DLabel", weaponsPanel)
    previewTitle:SetFont("ZCityJobs.Section")
    previewTitle:SetTextColor(palette.text)
    previewTitle:SetText("Превью и оружие")
    previewTitle:SetPos(14, 10)
    previewTitle:SizeToContents()

    editorControls.preview = vgui.Create("DModelPanel", weaponsPanel)
    editorControls.preview:SetPos(14, 44)
    editorControls.preview:SetSize(weaponsPanel:GetWide() - 28, 290)
    setPanelModel(editorControls.preview, Config.DefaultJobModel)
    editorControls.preview.LayoutEntity = function(_, entity)
        if not IsValid(entity) then return end
        entity:SetAngles(Angle(0, 28, 0))
        entity:FrameAdvance(RealFrameTime() * 0.5)
    end

    local modelTitle = vgui.Create("DLabel", weaponsPanel)
    modelTitle:SetFont("ZCityJobs.Body")
    modelTitle:SetTextColor(palette.text)
    modelTitle:SetText("Доступные модели")
    modelTitle:SizeToContents()

    local modelSearch = makeEntry(weaponsPanel, 14, 350, weaponsPanel:GetWide() - 28, 32)
    modelSearch:SetPlaceholderText("Поиск модели игрока по имени или пути")

    local modelList = vgui.Create("DListView", weaponsPanel)
    modelList:AddColumn("Имя")
    modelList:AddColumn("Путь модели")
    styleListView(modelList)

    local weaponTitle = vgui.Create("DLabel", weaponsPanel)
    weaponTitle:SetFont("ZCityJobs.Body")
    weaponTitle:SetTextColor(palette.text)
    weaponTitle:SetText("Доступное оружие")
    weaponTitle:SizeToContents()

    local weaponSearch = makeEntry(weaponsPanel, 14, 350, weaponsPanel:GetWide() - 28, 32)
    weaponSearch:SetPlaceholderText("Поиск оружия по названию или class")

    local weaponList = vgui.Create("DListView", weaponsPanel)
    weaponList:AddColumn("Название")
    weaponList:AddColumn("Class")
    styleListView(weaponList)

    weaponsPanel.PerformLayout = function(self, w, h)
        local pad = 14
        local yOffset = 10

        previewTitle:SetPos(pad, yOffset)
        previewTitle:SizeToContents()
        yOffset = yOffset + 34

        editorControls.preview:SetPos(pad, yOffset)
        editorControls.preview:SetSize(w - pad * 2, 260)
        yOffset = yOffset + 274

        modelTitle:SetPos(pad, yOffset)
        modelTitle:SizeToContents()
        yOffset = yOffset + 28

        modelSearch:SetPos(pad, yOffset)
        modelSearch:SetSize(w - pad * 2, 32)
        yOffset = yOffset + 40

        local modelHeight = math.max(120, math.floor((h - yOffset - 124) * 0.42))
        modelList:SetPos(pad, yOffset)
        modelList:SetSize(w - pad * 2, modelHeight)
        yOffset = yOffset + modelHeight + 12

        weaponTitle:SetPos(pad, yOffset)
        weaponTitle:SizeToContents()
        yOffset = yOffset + 28

        weaponSearch:SetPos(pad, yOffset)
        weaponSearch:SetSize(w - pad * 2, 32)
        yOffset = yOffset + 40

        weaponList:SetPos(pad, yOffset)
        weaponList:SetSize(w - pad * 2, h - yOffset - pad)
    end

    local function rebuildModelList()
        local filter = string.lower(trim(modelSearch:GetValue()))
        modelList:Clear()

        for _, modelEntry in ipairs(getAvailableModels()) do
            local haystack = string.lower((modelEntry.name or "") .. " " .. (modelEntry.model or ""))
            if filter == "" or string.find(haystack, filter, 1, true) then
                addStyledLine(modelList, modelEntry.name or modelEntry.model or "", modelEntry.model or "")
            end
        end
    end

    local function rebuildWeaponList()
        local filter = string.lower(trim(weaponSearch:GetValue()))
        weaponList:Clear()

        for _, swep in ipairs(getAvailableWeapons()) do
            local haystack = string.lower((swep.name or "") .. " " .. (swep.class or ""))
            if filter == "" or string.find(haystack, filter, 1, true) then
                addStyledLine(weaponList, swep.name or swep.class or "", swep.class or "")
            end
        end
    end

    modelSearch.OnChange = rebuildModelList
    weaponSearch.OnChange = rebuildWeaponList
    modelList.DoDoubleClick = function(_, _, row)
        if not IsValid(row) then return end

        local modelPath = trim(row:GetColumnText(2))
        if modelPath == "" then return end

        appendUniqueMultilineValue(editorControls.models, modelPath, 8)
    end

    weaponList.DoDoubleClick = function(_, rowIndex, row)
        if not IsValid(row) then return end

        local weaponClass = trim(row:GetColumnText(2))
        if weaponClass == "" then return end

        appendUniqueMultilineValue(editorControls.weapons, weaponClass, 24)
    end

    editorControls.models.OnChange = function()
        local previewModel = splitMultiline(editorControls.models:GetValue(), 1)[1] or Config.DefaultJobModel
        setPanelModel(editorControls.preview, previewModel)
    end

    newButton.DoClick = function()
        editorSelectedId = nil
        editorApplyToForm(editorDefaultJob())
    end

    saveButton.DoClick = function()
        local job = editorCollectFromForm()
        if job.name == "" then
            notifyLocal(false, "У работы должно быть название.")
            return
        end

        if job.command == "" then
            notifyLocal(false, "У работы должна быть команда.")
            return
        end

        if #job.models == 0 then
            job.models = { Config.DefaultJobModel }
        end

        local existingJob, index = editorFindJob(editorSelectedId)
        if existingJob and index then
            editorJobs[index] = job
        else
            editorJobs[#editorJobs + 1] = job
        end

        sendSaveJobs(editorJobs)
    end

    deleteButton.DoClick = function()
        if not editorSelectedId then
            notifyLocal(false, "Сначала выбери работу из списка.")
            return
        end

        local _, index = editorFindJob(editorSelectedId)
        if not index then
            return
        end

        table.remove(editorJobs, index)
        editorSelectedId = editorJobs[1] and editorJobs[1].id or nil
        sendSaveJobs(editorJobs)
    end

    refreshEditorList(jobsList)
    rebuildModelList()
    rebuildWeaponList()
    editorApplyToForm(editorFindJob(editorSelectedId) or editorDefaultJob())
end

buildJobInfo = function(infoPanel, actionButton)
    local job = findSelectedJob()
    if not job then
        infoPanel.Title:SetText("Нет доступных работ")
        infoPanel.Subtitle:SetText("Создай хотя бы одну работу через редактор администратора.")
        infoPanel.Description:SetText("")
        infoPanel.Meta:SetText("")
        infoPanel.Weapons:SetText("")
        setPanelModel(infoPanel.Model, Config.DefaultJobModel)
        actionButton:SetText("Выбрать работу")
        actionButton:SetEnabled(false)
        return
    end

    local teamId = tonumber(job.teamId or 0)
    local teamCount = teamId > 0 and team.NumPlayers(teamId) or 0
    local maxText = tonumber(job.max or 0) == 0 and "∞" or tostring(job.max)
    local firstModel = istable(job.models) and job.models[1] or Config.DefaultJobModel
    local currentTeam = IsValid(LocalPlayer()) and LocalPlayer():Team() or -1
    local equipmentLines = {
        "Оружие: " .. (#(job.weapons or {}) > 0 and table.concat(job.weapons, ", ") or "нет"),
        "Патроны: " .. (#(job.ammo or {}) > 0 and table.concat(job.ammo, ", ") or "нет"),
        "Обвесы: " .. (#(job.attachments or {}) > 0 and table.concat(job.attachments, ", ") or "нет"),
        "Z-City броня: " .. (trim(job.armorClass or "") ~= "" and trim(job.armorClass) or "нет")
    }

    infoPanel.Title:SetText(job.name or "Unknown")
    infoPanel.Subtitle:SetText(string.format("%s | Команда: /%s", job.category or "Other", job.command or "job"))
    infoPanel.Meta:SetText(string.format(
        "Зарплата: %s\nИгроков: %d/%s\nБроня: %d\nЛицензия: %s\nМожно уволить: %s\nМожет увольнять: %s\nСвой спавн: %s",
        formatMoney(job.salary or 0),
        teamCount,
        maxText,
        math.max(0, math.floor(tonumber(job.armor) or 0)),
        job.hasLicense and "Да" or "Нет",
        job.candemote and "Да" or "Нет",
        job.canDemoteOthers and "Да" or "Нет",
        istable(job.spawn) and "Да" or "Нет"
    ))
    infoPanel.Description:SetText(job.description ~= "" and tostring(job.description) or "Описание пока не задано.")
    infoPanel.Weapons:SetText(table.concat(equipmentLines, "\n"))

    if util.IsValidModel(firstModel or "") then
        setPanelModel(infoPanel.Model, firstModel)
    else
        setPanelModel(infoPanel.Model, Config.DefaultJobModel)
    end

    if trim(job.command or "") == "" then
        actionButton:SetText("Нет команды")
        actionButton:SetEnabled(false)
        return
    end

    if teamId > 0 and currentTeam == teamId then
        actionButton:SetText("Работа уже выбрана")
        actionButton:SetEnabled(false)
        return
    end

    actionButton:SetText(job.vote == true and "Запустить голосование" or "Выбрать работу")
    actionButton:SetEnabled(true)
end

editorDefaultJob = function()
    return {
        id = "",
        name = "",
        description = "",
        command = "",
        category = "Гражданские",
        models = { Config.DefaultJobModel },
        weapons = { "keys" },
        ammo = {},
        attachments = {},
        armor = 0,
        armorClass = "",
        salary = 45,
        max = 0,
        admin = 0,
        vote = false,
        hasLicense = false,
        candemote = true,
        canDemoteOthers = false,
        spawn = nil,
        color = { r = 45, g = 120, b = 70, a = 255 }
    }
end

editorApplyToForm = function(job)
    job = job or editorDefaultJob()

    editorControls.name:SetText(job.name or "")
    editorControls.command:SetText(job.command or "")
    editorControls.category:SetText(job.category or "Гражданские")
    editorControls.description:SetText(job.description or "")
    editorControls.models:SetText(joinMultiline(job.models or { Config.DefaultJobModel }))
    editorControls.weapons:SetText(joinMultiline(job.weapons or {}))
    editorControls.ammo:SetText(joinMultiline(job.ammo or {}))
    editorControls.attachments:SetText(joinMultiline(job.attachments or {}))
    editorControls.armor:SetText(tostring(job.armor or 0))
    editorControls.armorClass:SetText(job.armorClass or "")
    editorControls.salary:SetText(tostring(job.salary or 45))
    editorControls.maxPlayers:SetText(tostring(job.max or 0))
    editorControls.colorR:SetText(tostring((job.color and job.color.r) or 45))
    editorControls.colorG:SetText(tostring((job.color and job.color.g) or 120))
    editorControls.colorB:SetText(tostring((job.color and job.color.b) or 70))
    editorControls.vote:SetChecked(job.vote == true)
    editorControls.hasLicense:SetChecked(job.hasLicense == true)
    editorControls.candemote:SetChecked(job.candemote == true)
    editorControls.canDemoteOthers:SetChecked(job.canDemoteOthers == true)
    editorControls.adminLevel:ChooseOptionID((math.Clamp(tonumber(job.admin) or 0, 0, 2)) + 1)
    editorControls.spawnRecord = istable(job.spawn) and table.Copy(job.spawn) or nil

    if IsValid(editorControls.spawnStatus) then
        if istable(editorControls.spawnRecord) and istable(editorControls.spawnRecord.pos) then
            local pos = editorControls.spawnRecord.pos
            editorControls.spawnStatus:SetText(string.format("Свой спавн: %.0f %.0f %.0f", tonumber(pos.x) or 0, tonumber(pos.y) or 0, tonumber(pos.z) or 0))
        else
            editorControls.spawnStatus:SetText("Свой спавн: не задан")
        end
    end

    local previewModel = splitMultiline(editorControls.models:GetValue(), 1)[1] or Config.DefaultJobModel
    setPanelModel(editorControls.preview, previewModel)
end

editorCollectFromForm = function()
    local adminIndex = math.max(1, editorControls.adminLevel:GetSelectedID() or 1) - 1
    local rawId = trim(editorSelectedId or "")
    if rawId == "" then
        rawId = trim(editorControls.command:GetValue())
    end
    if rawId == "" then
        rawId = trim(editorControls.name:GetValue())
    end
    rawId = string.lower(string.gsub(rawId, "[^%w_%-]+", "_"))

    return {
        id = rawId,
        name = trim(editorControls.name:GetValue()),
        command = trim(editorControls.command:GetValue()),
        category = trim(editorControls.category:GetValue()),
        description = trim(editorControls.description:GetValue()),
        models = splitMultiline(editorControls.models:GetValue(), 8),
        weapons = splitMultiline(editorControls.weapons:GetValue(), 24),
        ammo = splitMultiline(editorControls.ammo:GetValue(), 24),
        attachments = splitMultiline(editorControls.attachments:GetValue(), 24),
        armor = math.max(0, math.floor(tonumber(editorControls.armor:GetValue()) or 0)),
        armorClass = trim(editorControls.armorClass:GetValue()),
        salary = math.max(0, math.floor(tonumber(editorControls.salary:GetValue()) or 45)),
        max = math.max(0, math.floor(tonumber(editorControls.maxPlayers:GetValue()) or 0)),
        admin = adminIndex,
        vote = editorControls.vote:GetChecked(),
        hasLicense = editorControls.hasLicense:GetChecked(),
        candemote = editorControls.candemote:GetChecked(),
        canDemoteOthers = editorControls.canDemoteOthers:GetChecked(),
        spawn = istable(editorControls.spawnRecord) and table.Copy(editorControls.spawnRecord) or nil,
        color = {
            r = math.Clamp(math.floor(tonumber(editorControls.colorR:GetValue()) or 45), 0, 255),
            g = math.Clamp(math.floor(tonumber(editorControls.colorG:GetValue()) or 120), 0, 255),
            b = math.Clamp(math.floor(tonumber(editorControls.colorB:GetValue()) or 70), 0, 255),
            a = 255
        }
    }
end

refreshEditorList = function(list)
    list:Clear()

    table.sort(editorJobs, function(left, right)
        local leftName = string.lower(left.name or "")
        local rightName = string.lower(right.name or "")
        if leftName == rightName then
            return string.lower(left.command or "") < string.lower(right.command or "")
        end

        return leftName < rightName
    end)

    for _, job in ipairs(editorJobs) do
        addStyledLine(list, job.name or "", "/" .. tostring(job.command or ""), job.category or "Other")
    end
end

openAdminEditor = function()
    if not JobClient.State.canManage and not isAllowedManager() then
        notifyLocal(false, JobClient.State.manageReason ~= "" and JobClient.State.manageReason or "Только ULX admin/superadmin может менять работы.")
        return
    end

    if IsValid(adminFrame) then
        adminFrame:MakePopup()
        return
    end

    editorJobs = table.Copy(JobClient.State.jobs or {})
    editorSelectedId = editorJobs[1] and editorJobs[1].id or nil

    adminFrame = vgui.Create("DFrame")
    adminFrame:SetSize(math.min(1620, ScrW() - 40), math.min(940, ScrH() - 40))
    adminFrame:Center()
    adminFrame:SetTitle("")
    adminFrame:ShowCloseButton(false)
    adminFrame:MakePopup()
    adminFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, palette.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 58, palette.header, true, true, false, false)
        draw.SimpleText("Редактор работ", "ZCityJobs.Title", 18, 19, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ULX admin/superadmin может создавать и менять работы прямо в игре.", "ZCityJobs.Small", 20, 44, palette.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeButton = vgui.Create("DButton", adminFrame)
    closeButton:SetText("X")
    closeButton:SetSize(40, 28)
    closeButton:SetPos(adminFrame:GetWide() - 52, 16)
    styleButton(closeButton, palette.accent, palette.accentHover)
    closeButton.DoClick = function()
        adminFrame:Close()
    end

    local jobsListPanel = vgui.Create("DPanel", adminFrame)
    jobsListPanel:SetPos(12, 72)
    jobsListPanel:SetSize(320, adminFrame:GetTall() - 84)
    jobsListPanel.Paint = function(self, w, h)
        paintPanel(self, w, h, palette.panel)
    end

    local listTitle = vgui.Create("DLabel", jobsListPanel)
    listTitle:SetFont("ZCityJobs.Section")
    listTitle:SetTextColor(palette.text)
    listTitle:SetText("Список работ")
    listTitle:SetPos(12, 10)
    listTitle:SizeToContents()

    local jobsList = vgui.Create("DListView", jobsListPanel)
    jobsList:SetPos(10, 44)
    jobsList:SetSize(jobsListPanel:GetWide() - 20, jobsListPanel:GetTall() - 54)
    styleListView(jobsList)
    jobsList:AddColumn("Имя")
    jobsList:AddColumn("Команда")
    jobsList:AddColumn("Категория")
    jobsList.OnRowSelected = function(_, rowIndex)
        local job = editorJobs[rowIndex]
        if not job then
            return
        end

        editorSelectedId = job.id
        editorApplyToForm(job)
    end
    editorControls.jobsList = jobsList

    local formPanel = vgui.Create("DScrollPanel", adminFrame)
    formPanel:SetPos(342, 72)
    formPanel:SetSize(470, adminFrame:GetTall() - 84)
    editorControls.formPanel = formPanel

    local form = vgui.Create("DPanel", formPanel)
    form:Dock(TOP)
    form:SetTall(1560)
    form.Paint = nil

    local assetsPanel = vgui.Create("DPanel", adminFrame)
    assetsPanel:SetPos(822, 72)
    assetsPanel:SetSize(adminFrame:GetWide() - 834, adminFrame:GetTall() - 84)
    assetsPanel.Paint = function(self, w, h)
        paintPanel(self, w, h, palette.panelAlt)
    end

    local function makeFieldLabel(parent, text, x, y)
        local label = vgui.Create("DLabel", parent)
        label:SetFont("ZCityJobs.Small")
        label:SetTextColor(palette.textDim)
        label:SetText(text)
        label:SetPos(x, y)
        label:SizeToContents()
        return label
    end

    local function makeEntry(parent, x, y, w, h, multiline)
        local entry = vgui.Create("DTextEntry", parent)
        entry:SetPos(x, y)
        entry:SetSize(w, h)
        entry:SetMultiline(multiline == true)
        styleTextEntry(entry)
        return entry
    end

    local y = 8
    makeFieldLabel(form, "Название работы", 0, y)
    y = y + 20
    editorControls.name = makeEntry(form, 0, y, 450, 34)
    y = y + 48

    makeFieldLabel(form, "Команда (/job)", 0, y)
    y = y + 20
    editorControls.command = makeEntry(form, 0, y, 214, 34)
    makeFieldLabel(form, "Категория", 236, y - 20)
    editorControls.category = makeEntry(form, 236, y, 214, 34)
    y = y + 48

    makeFieldLabel(form, "Описание", 0, y)
    y = y + 20
    editorControls.description = makeEntry(form, 0, y, 450, 110, true)
    y = y + 126

    makeFieldLabel(form, "Модели, по одной в строке", 0, y)
    y = y + 20
    editorControls.models = makeEntry(form, 0, y, 450, 84, true)
    y = y + 98

    makeFieldLabel(form, "Оружие, по одному class в строке", 0, y)
    y = y + 20
    editorControls.weapons = makeEntry(form, 0, y, 450, 90, true)
    y = y + 104

    makeFieldLabel(form, "Патроны, по одному id или id:amount", 0, y)
    y = y + 20
    editorControls.ammo = makeEntry(form, 0, y, 450, 82, true)
    y = y + 96

    makeFieldLabel(form, "Обвесы, по одному id в строке", 0, y)
    y = y + 20
    editorControls.attachments = makeEntry(form, 0, y, 450, 82, true)
    y = y + 96

    makeFieldLabel(form, "Числовая броня", 0, y)
    editorControls.armor = makeEntry(form, 0, y + 20, 130, 34)
    makeFieldLabel(form, "Z-City класс брони", 156, y)
    editorControls.armorClass = makeEntry(form, 156, y + 20, 294, 34)
    y = y + 68

    makeFieldLabel(form, "Зарплата", 0, y)
    editorControls.salary = makeEntry(form, 0, y + 20, 130, 34)
    makeFieldLabel(form, "Макс. игроков (0 = без лимита)", 156, y)
    editorControls.maxPlayers = makeEntry(form, 156, y + 20, 130, 34)
    y = y + 68

    makeFieldLabel(form, "Цвет R", 0, y)
    editorControls.colorR = makeEntry(form, 0, y + 20, 130, 34)
    makeFieldLabel(form, "Цвет G", 156, y)
    editorControls.colorG = makeEntry(form, 156, y + 20, 130, 34)
    makeFieldLabel(form, "Цвет B", 312, y)
    editorControls.colorB = makeEntry(form, 312, y + 20, 138, 34)
    y = y + 68

    makeFieldLabel(form, "Кому доступна работа", 0, y)
    y = y + 22
    editorControls.adminLevel = vgui.Create("DComboBox", form)
    editorControls.adminLevel:SetPos(0, y)
    editorControls.adminLevel:SetSize(450, 32)
    editorControls.adminLevel:SetValue("Игроки")
    editorControls.adminLevel:AddChoice("Игроки", 0)
    editorControls.adminLevel:AddChoice("Только admin", 1)
    editorControls.adminLevel:AddChoice("Только superadmin", 2)
    styleComboBox(editorControls.adminLevel)
    y = y + 48

    editorControls.vote = vgui.Create("DCheckBoxLabel", form)
    editorControls.vote:SetPos(0, y)
    editorControls.vote:SetText("Требуется голосование")
    editorControls.vote:SetTextColor(palette.text)
    editorControls.vote:SizeToContents()

    editorControls.hasLicense = vgui.Create("DCheckBoxLabel", form)
    editorControls.hasLicense:SetPos(0, y + 28)
    editorControls.hasLicense:SetText("Есть лицензия на оружие")
    editorControls.hasLicense:SetTextColor(palette.text)
    editorControls.hasLicense:SizeToContents()

    editorControls.candemote = vgui.Create("DCheckBoxLabel", form)
    editorControls.candemote:SetPos(0, y + 56)
    editorControls.candemote:SetText("Можно уволить")
    editorControls.candemote:SetTextColor(palette.text)
    editorControls.candemote:SizeToContents()

    editorControls.canDemoteOthers = vgui.Create("DCheckBoxLabel", form)
    editorControls.canDemoteOthers:SetPos(0, y + 84)
    editorControls.canDemoteOthers:SetText("Может увольнять других")
    editorControls.canDemoteOthers:SetTextColor(palette.text)
    editorControls.canDemoteOthers:SizeToContents()
    y = y + 126

    makeFieldLabel(form, "Свой спавн работы", 0, y)
    y = y + 24
    editorControls.spawnStatus = vgui.Create("DLabel", form)
    editorControls.spawnStatus:SetFont("ZCityJobs.Body")
    editorControls.spawnStatus:SetTextColor(palette.text)
    editorControls.spawnStatus:SetText("Свой спавн: не задан")
    editorControls.spawnStatus:SetPos(0, y)
    editorControls.spawnStatus:SetSize(450, 26)
    y = y + 34

    local setSpawnButton = vgui.Create("DButton", form)
    setSpawnButton:SetText("Сохранить мою позицию")
    setSpawnButton:SetPos(0, y)
    setSpawnButton:SetSize(220, 38)
    styleButton(setSpawnButton, palette.green, palette.greenHover)

    local clearSpawnButton = vgui.Create("DButton", form)
    clearSpawnButton:SetText("Очистить спавн")
    clearSpawnButton:SetPos(230, y)
    clearSpawnButton:SetSize(220, 38)
    styleButton(clearSpawnButton, palette.accent, palette.accentHover)
    y = y + 54

    local newButton = vgui.Create("DButton", form)
    newButton:SetText("Новая работа")
    newButton:SetPos(0, y)
    newButton:SetSize(140, 42)
    styleButton(newButton, palette.green, palette.greenHover)

    local saveButton = vgui.Create("DButton", form)
    saveButton:SetText("Сохранить")
    saveButton:SetPos(154, y)
    saveButton:SetSize(140, 42)
    styleButton(saveButton, palette.gold, Color(238, 200, 75))

    local deleteButton = vgui.Create("DButton", form)
    deleteButton:SetText("Удалить")
    deleteButton:SetPos(308, y)
    deleteButton:SetSize(142, 42)
    styleButton(deleteButton, palette.accent, palette.accentHover)

    local previewTitle = vgui.Create("DLabel", assetsPanel)
    previewTitle:SetFont("ZCityJobs.Section")
    previewTitle:SetTextColor(palette.text)
    previewTitle:SetText("Превью и списки")
    previewTitle:SetPos(14, 10)
    previewTitle:SizeToContents()

    editorControls.preview = vgui.Create("DModelPanel", assetsPanel)
    setPanelModel(editorControls.preview, Config.DefaultJobModel)
    editorControls.preview.LayoutEntity = function(_, entity)
        if not IsValid(entity) then return end
        entity:SetAngles(Angle(0, 28, 0))
        entity:FrameAdvance(RealFrameTime() * 0.5)
    end

    local sheet = vgui.Create("DPropertySheet", assetsPanel)
    editorControls.assetSheet = sheet

    local function createAssetTab(title, placeholder, columns)
        local panel = vgui.Create("DPanel", sheet)
        panel.Paint = nil

        local search = makeEntry(panel, 0, 0, 100, 32)
        search:SetPlaceholderText(placeholder)

        local list = vgui.Create("DListView", panel)
        styleListView(list)
        for _, columnName in ipairs(columns) do
            list:AddColumn(columnName)
        end

        panel.PerformLayout = function(self, w, h)
            search:SetPos(0, 0)
            search:SetSize(w, 32)
            list:SetPos(0, 40)
            list:SetSize(w, h - 40)
        end

        sheet:AddSheet(title, panel, "icon16/application_view_list.png")
        return search, list
    end

    local modelSearch, modelList = createAssetTab("Модели", "Поиск модели игрока", { "Имя", "Путь" })
    local weaponSearch, weaponList = createAssetTab("Оружие", "Поиск оружия", { "Название", "Class" })
    local ammoSearch, ammoList = createAssetTab("Патроны", "Поиск патронов", { "Название", "Class" })
    local attachmentSearch, attachmentList = createAssetTab("Обвесы", "Поиск обвесов", { "Название", "Class" })
    local armorSearch, armorList = createAssetTab("Броня", "Поиск брони", { "Название", "Class" })

    assetsPanel.PerformLayout = function(self, w, h)
        previewTitle:SetPos(14, 10)
        previewTitle:SizeToContents()
        editorControls.preview:SetPos(14, 44)
        editorControls.preview:SetSize(w - 28, 250)
        sheet:SetPos(14, 308)
        sheet:SetSize(w - 28, h - 322)
    end

    local function rebuildGenericList(searchEntry, listView, provider)
        local filter = string.lower(trim(searchEntry:GetValue()))
        listView:Clear()

        for _, entry in ipairs(provider()) do
            local haystack = string.lower((entry.name or "") .. " " .. (entry.class or entry.model or ""))
            if filter == "" or string.find(haystack, filter, 1, true) then
                addStyledLine(listView, entry.name or entry.class or entry.model or "", entry.class or entry.model or "")
            end
        end
    end

    local function rebuildModelList()
        local filter = string.lower(trim(modelSearch:GetValue()))
        modelList:Clear()

        for _, modelEntry in ipairs(getAvailableModels()) do
            local haystack = string.lower((modelEntry.name or "") .. " " .. (modelEntry.model or ""))
            if filter == "" or string.find(haystack, filter, 1, true) then
                addStyledLine(modelList, modelEntry.name or modelEntry.model or "", modelEntry.model or "")
            end
        end
    end

    modelSearch.OnChange = rebuildModelList
    weaponSearch.OnChange = function()
        rebuildGenericList(weaponSearch, weaponList, getAvailableWeapons)
    end
    ammoSearch.OnChange = function()
        rebuildGenericList(ammoSearch, ammoList, getAvailableAmmo)
    end
    attachmentSearch.OnChange = function()
        rebuildGenericList(attachmentSearch, attachmentList, getAvailableAttachments)
    end
    armorSearch.OnChange = function()
        rebuildGenericList(armorSearch, armorList, getAvailableArmor)
    end

    modelList.DoDoubleClick = function(_, _, row)
        if not IsValid(row) then return end
        local modelPath = trim(row:GetColumnText(2))
        if modelPath == "" then return end
        appendUniqueMultilineValue(editorControls.models, modelPath, 8)
    end

    weaponList.DoDoubleClick = function(_, _, row)
        if not IsValid(row) then return end
        local className = trim(row:GetColumnText(2))
        if className == "" then return end
        appendUniqueMultilineValue(editorControls.weapons, className, 24)
    end

    ammoList.DoDoubleClick = function(_, _, row)
        if not IsValid(row) then return end
        local className = trim(row:GetColumnText(2))
        if className == "" then return end
        appendUniqueMultilineValue(editorControls.ammo, className .. ":60", 24)
    end

    attachmentList.DoDoubleClick = function(_, _, row)
        if not IsValid(row) then return end
        local className = trim(row:GetColumnText(2))
        if className == "" then return end
        appendUniqueMultilineValue(editorControls.attachments, className, 24)
    end

    armorList.DoDoubleClick = function(_, _, row)
        if not IsValid(row) then return end
        local className = trim(row:GetColumnText(2))
        if className == "" then return end
        editorControls.armorClass:SetText(className)
    end

    editorControls.models.OnChange = function()
        local previewModel = splitMultiline(editorControls.models:GetValue(), 1)[1] or Config.DefaultJobModel
        setPanelModel(editorControls.preview, previewModel)
    end

    setSpawnButton.DoClick = function()
        local ply = LocalPlayer()
        if not IsValid(ply) then
            return
        end

        local pos = ply:GetPos()
        local ang = ply:EyeAngles()
        editorControls.spawnRecord = {
            name = trim(editorControls.name:GetValue()),
            pos = { x = pos.x, y = pos.y, z = pos.z },
            ang = { p = 0, y = ang.y, r = 0 }
        }
        editorControls.spawnStatus:SetText(string.format("Свой спавн: %.0f %.0f %.0f", pos.x, pos.y, pos.z))
    end

    clearSpawnButton.DoClick = function()
        editorControls.spawnRecord = nil
        editorControls.spawnStatus:SetText("Свой спавн: не задан")
    end

    newButton.DoClick = function()
        editorSelectedId = nil
        editorApplyToForm(editorDefaultJob())
    end

    saveButton.DoClick = function()
        local job = editorCollectFromForm()
        if job.name == "" then
            notifyLocal(false, "У работы должно быть название.")
            return
        end

        if job.command == "" then
            notifyLocal(false, "У работы должна быть команда.")
            return
        end

        if #job.models == 0 then
            job.models = { Config.DefaultJobModel }
        end

        local existingJob, index = editorFindJob(editorSelectedId)
        if existingJob and index then
            editorJobs[index] = job
        else
            editorJobs[#editorJobs + 1] = job
            editorSelectedId = job.id
        end

        if IsValid(editorControls.jobsList) then
            refreshEditorList(editorControls.jobsList)
        end

        editorApplyToForm(job)
        sendSaveJobs(editorJobs)
    end

    deleteButton.DoClick = function()
        if not editorSelectedId then
            notifyLocal(false, "Сначала выбери работу из списка.")
            return
        end

        local _, index = editorFindJob(editorSelectedId)
        if not index then
            return
        end

        table.remove(editorJobs, index)
        editorSelectedId = editorJobs[1] and editorJobs[1].id or nil
        if IsValid(editorControls.jobsList) then
            refreshEditorList(editorControls.jobsList)
        end
        editorApplyToForm(editorFindJob(editorSelectedId) or editorDefaultJob())
        sendSaveJobs(editorJobs)
    end

    refreshEditorList(jobsList)
    rebuildModelList()
    rebuildGenericList(weaponSearch, weaponList, getAvailableWeapons)
    rebuildGenericList(ammoSearch, ammoList, getAvailableAmmo)
    rebuildGenericList(attachmentSearch, attachmentList, getAvailableAttachments)
    rebuildGenericList(armorSearch, armorList, getAvailableArmor)
    editorApplyToForm(editorFindJob(editorSelectedId) or editorDefaultJob())
end

local function saveCurrentPositionForJob(jobId, clearSpawn)
    local jobs = table.Copy(JobClient.State.jobs or {})
    local targetJob

    for _, job in ipairs(jobs) do
        if trim(job.id) == trim(jobId) then
            targetJob = job
            break
        end
    end

    if not targetJob then
        notifyLocal(false, "Could not find the selected job.")
        return
    end

    if clearSpawn then
        targetJob.spawn = nil
        sendSaveJobs(jobs)
        notifyLocal(true, "Job spawn cleared.")
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then
        return
    end

    local pos = ply:GetPos()
    local ang = ply:EyeAngles()
    targetJob.spawn = {
        name = trim(targetJob.name),
        pos = { x = pos.x, y = pos.y, z = pos.z },
        ang = { p = 0, y = ang.y, r = 0 }
    }

    sendSaveJobs(jobs)
    notifyLocal(true, "Job spawn saved.")
end

local function openJobSpawnPicker()
    if not JobClient.State.canManage and not isAllowedManager() then
        notifyLocal(false, JobClient.State.manageReason ~= "" and JobClient.State.manageReason or "Only ULX admin/superadmin can edit job spawns.")
        return
    end

    local jobs = table.Copy(JobClient.State.jobs or {})
    if #jobs == 0 then
        notifyLocal(false, "The jobs list is empty.")
        return
    end

    if IsValid(jobSpawnPickerFrame) then
        jobSpawnPickerFrame:MakePopup()
        return
    end

    local selectedId = trim((jobs[1] and jobs[1].id) or "")

    jobSpawnPickerFrame = vgui.Create("DFrame")
    jobSpawnPickerFrame:SetSize(560, 520)
    jobSpawnPickerFrame:Center()
    jobSpawnPickerFrame:SetTitle("")
    jobSpawnPickerFrame:ShowCloseButton(false)
    jobSpawnPickerFrame:MakePopup()
    jobSpawnPickerFrame.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, palette.bg)
        draw.RoundedBoxEx(12, 0, 0, w, 58, palette.header, true, true, false, false)
        draw.SimpleText("Job Spawn Picker", "ZCityJobs.Title", 18, 20, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Pick a job and save your current position as its spawn.", "ZCityJobs.Small", 20, 42, palette.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeButton = vgui.Create("DButton", jobSpawnPickerFrame)
    closeButton:SetText("X")
    closeButton:SetSize(40, 28)
    closeButton:SetPos(jobSpawnPickerFrame:GetWide() - 52, 16)
    styleButton(closeButton, palette.accent, palette.accentHover)
    closeButton.DoClick = function()
        jobSpawnPickerFrame:Close()
    end

    local jobsList = vgui.Create("DListView", jobSpawnPickerFrame)
    jobsList:SetPos(16, 74)
    jobsList:SetSize(jobSpawnPickerFrame:GetWide() - 32, 330)
    styleListView(jobsList)
    jobsList:AddColumn("Name")
    jobsList:AddColumn("Command")
    jobsList:AddColumn("Category")

    table.sort(jobs, function(left, right)
        local leftName = string.lower(left.name or "")
        local rightName = string.lower(right.name or "")
        if leftName == rightName then
            return string.lower(left.command or "") < string.lower(right.command or "")
        end

        return leftName < rightName
    end)

    for _, job in ipairs(jobs) do
        local row = addStyledLine(jobsList, job.name or "", "/" .. tostring(job.command or ""), job.category or "Other")
        row.jobId = trim(job.id)
        row.DoClick = function()
            selectedId = row.jobId
        end
    end

    local setButton = vgui.Create("DButton", jobSpawnPickerFrame)
    setButton:SetText("Save My Position")
    setButton:SetPos(16, 420)
    setButton:SetSize(258, 42)
    styleButton(setButton, palette.green, palette.greenHover)
    setButton.DoClick = function()
        if selectedId == "" then
            notifyLocal(false, "Select a job first.")
            return
        end

        saveCurrentPositionForJob(selectedId, false)
    end

    local clearButton = vgui.Create("DButton", jobSpawnPickerFrame)
    clearButton:SetText("Clear Job Spawn")
    clearButton:SetPos(286, 420)
    clearButton:SetSize(258, 42)
    styleButton(clearButton, palette.accent, palette.accentHover)
    clearButton.DoClick = function()
        if selectedId == "" then
            notifyLocal(false, "Select a job first.")
            return
        end

        saveCurrentPositionForJob(selectedId, true)
    end
end

refreshJobsMenu = function()
    if IsValid(jobsFrame) then
        jobsFrame:Remove()
        buildJobsMenu()
    end

    if IsValid(adminFrame) then
        editorJobs = table.Copy(JobClient.State.jobs or {})

        if IsValid(editorControls.jobsList) then
            refreshEditorList(editorControls.jobsList)
        end

        if editorSelectedId and not editorFindJob(editorSelectedId) then
            editorSelectedId = editorJobs[1] and editorJobs[1].id or nil
            editorApplyToForm(editorFindJob(editorSelectedId) or editorDefaultJob())
        end
    end
end

net.Receive("ZCityDarkRPShop.JobState", function()
    local decoded = util.JSONToTable(net.ReadString() or "")
    if not istable(decoded) then
        return
    end

    JobClient.State.jobs = decoded.jobs or {}
    JobClient.State.canManage = decoded.canManage == true
    JobClient.State.manageReason = decoded.manageReason or ""
    JobClient.State.managerGroup = decoded.managerGroup or ""
    JobClient.State.darkRPReady = decoded.darkRPReady == true
    JobClient.State.balance = math.floor(tonumber(decoded.balance) or 0)
    JobClient.State.balanceText = decoded.balanceText or formatMoney(JobClient.State.balance)

    if not selectedJobId and JobClient.State.jobs[1] then
        selectedJobId = JobClient.State.jobs[1].id
    end

    refreshJobsMenu()
end)

concommand.Add(Config.JobMenuCommand, function()
    requestState()
    buildJobsMenu()
end)

concommand.Add(Config.JobAdminCommand, function()
    requestState()
    timer.Simple(0.15, function()
        if not IsValid(LocalPlayer()) then return end
        openAdminEditor()
    end)
end)

concommand.Add(Config.JobSpawnPickerCommand, function()
    requestState()
    timer.Simple(0.15, function()
        if not IsValid(LocalPlayer()) then return end
        openJobSpawnPicker()
    end)
end)

concommand.Add("zcity_jobs_menu", function()
    RunConsoleCommand(Config.JobMenuCommand)
end)

concommand.Add("zcity_jobs_editor", function()
    RunConsoleCommand(Config.JobAdminCommand)
end)

hook.Add("OnPlayerChat", "ZCityDarkRPShop.JobChatCommands", function(ply, text)
    if ply ~= LocalPlayer() then return end

    local command = string.lower(trim(text))
    local target = Config.ChatCommands[command]
    if not target then return end

    if target == "jobs" then
        RunConsoleCommand(Config.JobMenuCommand)
        return true
    end

    if target == "jobs_admin" then
        RunConsoleCommand(Config.JobAdminCommand)
        return true
    end
end)

hook.Add("PlayerBindPress", "ZCityDarkRPShop.OpenJobsMenuWithF4", function(_, bind, pressed)
    if not pressed then
        return
    end

    bind = string.lower(tostring(bind or ""))
    if not string.find(bind, "gm_showspare2", 1, true) then
        return
    end

    RunConsoleCommand(Config.JobMenuCommand)
    return true
end)

hook.Add("ShowSpare2", "ZCityDarkRPShop.OpenJobsMenuWithShowSpare2", function()
    RunConsoleCommand(Config.JobMenuCommand)
    return true
end)

local f4WasDown = false
local darkRPF4Overridden = false

hook.Add("Think", "ZCityDarkRPShop.OverrideLegacyF4", function()
    if DarkRP and not darkRPF4Overridden then
        darkRPF4Overridden = true
        DarkRP.openF4Menu = function()
            RunConsoleCommand(Config.JobMenuCommand)
        end

        DarkRP.closeF4Menu = function()
            if IsValid(jobsFrame) then
                jobsFrame:Close()
            end
        end
    end

    if gui.IsGameUIVisible() or (vgui.CursorVisible() and IsValid(vgui.GetKeyboardFocus())) then
        f4WasDown = input.IsKeyDown(KEY_F4)
        return
    end

    local isDown = input.IsKeyDown(KEY_F4)
    if isDown and not f4WasDown then
        RunConsoleCommand(Config.JobMenuCommand)
    end

    f4WasDown = isDown
end)

local nextMoneyStateRequest = 0

hook.Add("Think", "ZCityDarkRPShop.MoneyStateFallback", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return
    end

    if ply.getDarkRPVar and ply:getDarkRPVar("money") ~= nil then
        return
    end

    if RealTime() < nextMoneyStateRequest then
        return
    end

    nextMoneyStateRequest = RealTime() + 2
    requestState()
end)


if false then hook.Add("radialOptions", "ZCityDarkRPShop.RadialMoneyJobs", function()
    hg = hg or {}
    hg.radialOptions = hg.radialOptions or {}

    for index = #hg.radialOptions, 1, -1 do
        local option = hg.radialOptions[index]
        local label = tostring(istable(option) and option[2] or "")
        if string.find(label, "Balance:", 1, true)
            or string.find(label, "Drop Money", 1, true)
            or string.find(label, "Give Money", 1, true)
            or string.find(label, "Баланс:", 1, true)
            or string.find(label, "Выкинуть деньги", 1, true)
            or string.find(label, "Передать деньги", 1, true)
            or string.find(label, "Работы", 1, true)
            or string.find(label, "Редактор работ", 1, true) then
            table.remove(hg.radialOptions, index)
        end
    end

    table.insert(hg.radialOptions, 1, {
        function()
            promptMoney("give")
        end,
        "Give Money"
    })

    table.insert(hg.radialOptions, 1, {
        function()
            promptMoney("drop")
        end,
        "Drop Money"
    })

    table.insert(hg.radialOptions, 1, {
        function()
            requestState()
            notifyLocal(true, "Balance: " .. formatMoney(localBalance()))
        end,
        "Balance: " .. formatMoney(localBalance())
    })
end) end
