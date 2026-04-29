ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.SpawnClient = ZCityDarkRPShop.SpawnClient or {}

local SpawnClient = ZCityDarkRPShop.SpawnClient
local Config = ZCityDarkRPShop.Config

SpawnClient.State = SpawnClient.State or {
    map = game.GetMap(),
    spawns = {}
}

local frame
local spawnList
local nameEntry

surface.CreateFont("ZCitySpawn.Title", {
    font = "Trebuchet24",
    size = 28,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZCitySpawn.Body", {
    font = "Tahoma",
    size = 16,
    weight = 600,
    antialias = true
})

local colors = {
    bg = Color(8, 8, 10, 245),
    header = Color(18, 18, 22, 252),
    panel = Color(24, 24, 30, 245),
    line = Color(70, 70, 82),
    text = Color(238, 242, 247),
    dim = Color(170, 176, 188),
    accent = Color(175, 24, 30),
    accentHover = Color(210, 38, 45)
}

local function isSpawnAdmin()
    local ply = LocalPlayer()
    return IsValid(ply) and ply.GetUserGroup and string.lower(ply:GetUserGroup() or "") == "superadmin"
end

local function requestState()
    net.Start("ZCityAftermath.RequestSpawnState")
    net.SendToServer()
end

local function sendAction(action, payload)
    net.Start("ZCityAftermath.SpawnAction")
        net.WriteString(action)

        if action == "add" then
            net.WriteString(tostring(payload or ""))
        elseif action == "remove_index" or action == "goto" then
            net.WriteUInt(math.max(0, math.floor(tonumber(payload) or 0)), 16)
        end
    net.SendToServer()

    timer.Simple(0.2, requestState)
end

local function styleButton(button, color)
    button:SetFont("ZCitySpawn.Body")
    button:SetTextColor(colors.text)

    button.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and colors.accentHover or color)
    end
end

local function styleEntry(entry)
    entry:SetFont("ZCitySpawn.Body")
    entry:SetTextColor(colors.text)
    entry:SetDrawLanguageID(false)
    entry.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.panel)
        surface.SetDrawColor(colors.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(colors.text, colors.accent, colors.text)
    end
end

local function selectedIndex()
    if not IsValid(spawnList) then return nil end

    local selected = spawnList:GetSelectedLine()
    if not selected then return nil end

    local line = spawnList:GetLine(selected)
    if not IsValid(line) then return nil end

    return tonumber(line:GetColumnText(1))
end

local function refreshList()
    if not IsValid(spawnList) then return end

    spawnList:Clear()

    for index, record in ipairs(SpawnClient.State.spawns or {}) do
        local pos = record.pos or {}
        local ang = record.ang or {}
        spawnList:AddLine(
            index,
            tostring(record.name or ("Spawn " .. index)),
            string.format("%.0f %.0f %.0f", tonumber(pos.x) or 0, tonumber(pos.y) or 0, tonumber(pos.z) or 0),
            string.format("%.0f", tonumber(ang.y) or 0)
        )
    end
end

function SpawnClient.OpenMenu()
    if not isSpawnAdmin() then
        notification.AddLegacy("Only superadmin can edit spawns.", NOTIFY_ERROR, 4)
        return
    end

    if IsValid(frame) then
        frame:MakePopup()
        requestState()
        return
    end

    frame = vgui.Create("DFrame")
    frame:SetSize(math.min(ScrW() - 80, 820), math.min(ScrH() - 80, 560))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 58, colors.header, true, true, false, false)
        draw.SimpleText("Z-City Spawn Manager", "ZCitySpawn.Title", 22, 14, colors.text)
        draw.SimpleText("Map: " .. tostring(SpawnClient.State.map or game.GetMap()), "ZCitySpawn.Body", 260, 22, colors.dim)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("X")
    close:SetSize(42, 34)
    close:SetPos(frame:GetWide() - 54, 12)
    styleButton(close, colors.accent)
    close.DoClick = function()
        frame:Close()
    end

    local topPanel = vgui.Create("DPanel", frame)
    topPanel:SetPos(16, 72)
    topPanel:SetSize(frame:GetWide() - 32, 58)
    topPanel.Paint = nil

    nameEntry = vgui.Create("DTextEntry", topPanel)
    nameEntry:SetPos(0, 10)
    nameEntry:SetSize(topPanel:GetWide() - 500, 38)
    nameEntry:SetPlaceholderText("Spawn name")
    styleEntry(nameEntry)

    local addButton = vgui.Create("DButton", topPanel)
    addButton:SetText("Add Current Position")
    addButton:SetPos(topPanel:GetWide() - 488, 10)
    addButton:SetSize(170, 38)
    styleButton(addButton, Color(55, 130, 80))
    addButton.DoClick = function()
        sendAction("add", IsValid(nameEntry) and nameEntry:GetValue() or "")
    end

    local removeNearestButton = vgui.Create("DButton", topPanel)
    removeNearestButton:SetText("Remove Nearest")
    removeNearestButton:SetPos(topPanel:GetWide() - 306, 10)
    removeNearestButton:SetSize(140, 38)
    styleButton(removeNearestButton, Color(150, 80, 35))
    removeNearestButton.DoClick = function()
        sendAction("remove_nearest")
    end

    local refreshButton = vgui.Create("DButton", topPanel)
    refreshButton:SetText("Refresh")
    refreshButton:SetPos(topPanel:GetWide() - 154, 10)
    refreshButton:SetSize(70, 38)
    styleButton(refreshButton, Color(70, 80, 100))
    refreshButton.DoClick = requestState

    local clearButton = vgui.Create("DButton", topPanel)
    clearButton:SetText("Clear")
    clearButton:SetPos(topPanel:GetWide() - 74, 10)
    clearButton:SetSize(74, 38)
    styleButton(clearButton, colors.accent)
    clearButton.DoClick = function()
        Derma_Query(
            "Remove all custom spawns for this map?",
            "Confirm",
            "Clear", function() sendAction("clear") end,
            "Cancel"
        )
    end

    spawnList = vgui.Create("DListView", frame)
    spawnList:SetPos(16, 144)
    spawnList:SetSize(frame:GetWide() - 32, frame:GetTall() - 206)
    spawnList:SetMultiSelect(false)
    spawnList:AddColumn("#"):SetFixedWidth(45)
    spawnList:AddColumn("Name")
    spawnList:AddColumn("Position")
    spawnList:AddColumn("Yaw"):SetFixedWidth(70)
    spawnList:SetDataHeight(28)
    spawnList.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.panel)
    end

    local bottom = vgui.Create("DPanel", frame)
    bottom:SetPos(16, frame:GetTall() - 50)
    bottom:SetSize(frame:GetWide() - 32, 38)
    bottom.Paint = nil

    local gotoButton = vgui.Create("DButton", bottom)
    gotoButton:SetText("Teleport To Selected")
    gotoButton:SetSize(180, 38)
    gotoButton:SetPos(0, 0)
    styleButton(gotoButton, Color(70, 90, 145))
    gotoButton.DoClick = function()
        local index = selectedIndex()
        if index then sendAction("goto", index) end
    end

    local removeButton = vgui.Create("DButton", bottom)
    removeButton:SetText("Remove Selected")
    removeButton:SetSize(160, 38)
    removeButton:SetPos(192, 0)
    styleButton(removeButton, colors.accent)
    removeButton.DoClick = function()
        local index = selectedIndex()
        if index then sendAction("remove_index", index) end
    end

    refreshList()
    requestState()
end

net.Receive("ZCityAftermath.SpawnState", function()
    SpawnClient.State.map = net.ReadString()
    SpawnClient.State.spawns = net.ReadTable() or {}
    refreshList()
end)

net.Receive("ZCityAftermath.OpenSpawnMenu", function()
    SpawnClient.OpenMenu()
end)

concommand.Add(Config.SpawnMenuCommand, function()
    SpawnClient.OpenMenu()
end)
