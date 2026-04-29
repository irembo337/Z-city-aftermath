ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.SafeZoneClient = ZCityDarkRPShop.SafeZoneClient or {}

local SafeZoneClient = ZCityDarkRPShop.SafeZoneClient
local Config = ZCityDarkRPShop.Config

SafeZoneClient.State = SafeZoneClient.State or {
    map = game.GetMap(),
    zones = {}
}

local frame
local zoneList
local nameEntry
local radiusEntry

surface.CreateFont("ZCitySafe.Title", {
    font = "Trebuchet24",
    size = 28,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZCitySafe.Body", {
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
    green = Color(45, 125, 76)
}

local function isSuperAdmin()
    local ply = LocalPlayer()
    return IsValid(ply) and ply.GetUserGroup and string.lower(ply:GetUserGroup() or "") == "superadmin"
end

local function requestState()
    net.Start("ZCityAftermath.RequestSafeZoneState")
    net.SendToServer()
end

local function sendAction(action, payloadA, payloadB)
    net.Start("ZCityAftermath.SafeZoneAction")
        net.WriteString(action)

        if action == "add" then
            net.WriteUInt(math.Clamp(math.floor(tonumber(payloadA) or Config.DefaultSafeZoneRadius), 64, 8192), 16)
            net.WriteString(tostring(payloadB or ""))
        elseif action == "remove_index" then
            net.WriteUInt(math.max(0, math.floor(tonumber(payloadA) or 0)), 16)
        end
    net.SendToServer()

    timer.Simple(0.2, requestState)
end

local function styleButton(button, color)
    button:SetFont("ZCitySafe.Body")
    button:SetTextColor(colors.text)
    button.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(210, 38, 45) or color)
    end
end

local function styleEntry(entry)
    entry:SetFont("ZCitySafe.Body")
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
    if not IsValid(zoneList) then return nil end

    local selected = zoneList:GetSelectedLine()
    if not selected then return nil end

    local line = zoneList:GetLine(selected)
    if not IsValid(line) then return nil end

    return tonumber(line:GetColumnText(1))
end

local function refreshList()
    if not IsValid(zoneList) then return end

    zoneList:Clear()

    for index, zone in ipairs(SafeZoneClient.State.zones or {}) do
        local pos = zone.pos or {}
        zoneList:AddLine(
            index,
            tostring(zone.name or ("Safe Zone " .. index)),
            tostring(zone.radius or Config.DefaultSafeZoneRadius),
            string.format("%.0f %.0f %.0f", tonumber(pos.x) or 0, tonumber(pos.y) or 0, tonumber(pos.z) or 0)
        )
    end
end

function SafeZoneClient.OpenMenu()
    if not isSuperAdmin() then
        notification.AddLegacy("Only ULX superadmin can edit safe zones.", NOTIFY_ERROR, 4)
        return
    end

    if IsValid(frame) then
        frame:MakePopup()
        requestState()
        return
    end

    frame = vgui.Create("DFrame")
    frame:SetSize(math.min(ScrW() - 80, 860), math.min(ScrH() - 80, 560))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 58, colors.header, true, true, false, false)
        draw.SimpleText("Z-City Safe Zones", "ZCitySafe.Title", 22, 14, colors.text)
        draw.SimpleText("Map: " .. tostring(SafeZoneClient.State.map or game.GetMap()), "ZCitySafe.Body", 280, 22, colors.dim)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("X")
    close:SetSize(42, 34)
    close:SetPos(frame:GetWide() - 54, 12)
    styleButton(close, colors.accent)
    close.DoClick = function() frame:Close() end

    nameEntry = vgui.Create("DTextEntry", frame)
    nameEntry:SetPos(16, 78)
    nameEntry:SetSize(frame:GetWide() - 520, 36)
    nameEntry:SetPlaceholderText("Zone name")
    styleEntry(nameEntry)

    radiusEntry = vgui.Create("DTextEntry", frame)
    radiusEntry:SetPos(frame:GetWide() - 492, 78)
    radiusEntry:SetSize(100, 36)
    radiusEntry:SetText(tostring(Config.DefaultSafeZoneRadius))
    radiusEntry:SetNumeric(true)
    styleEntry(radiusEntry)

    local addButton = vgui.Create("DButton", frame)
    addButton:SetText("Add Here")
    addButton:SetPos(frame:GetWide() - 382, 78)
    addButton:SetSize(110, 36)
    styleButton(addButton, colors.green)
    addButton.DoClick = function()
        sendAction("add", radiusEntry:GetValue(), nameEntry:GetValue())
    end

    local removeNearest = vgui.Create("DButton", frame)
    removeNearest:SetText("Remove Nearest")
    removeNearest:SetPos(frame:GetWide() - 262, 78)
    removeNearest:SetSize(140, 36)
    styleButton(removeNearest, Color(150, 80, 35))
    removeNearest.DoClick = function() sendAction("remove_nearest") end

    local clear = vgui.Create("DButton", frame)
    clear:SetText("Clear")
    clear:SetPos(frame:GetWide() - 112, 78)
    clear:SetSize(96, 36)
    styleButton(clear, colors.accent)
    clear.DoClick = function()
        Derma_Query("Remove all safe zones for this map?", "Confirm", "Clear", function() sendAction("clear") end, "Cancel")
    end

    zoneList = vgui.Create("DListView", frame)
    zoneList:SetPos(16, 130)
    zoneList:SetSize(frame:GetWide() - 32, frame:GetTall() - 190)
    zoneList:SetMultiSelect(false)
    zoneList:AddColumn("#"):SetFixedWidth(45)
    zoneList:AddColumn("Name")
    zoneList:AddColumn("Radius"):SetFixedWidth(90)
    zoneList:AddColumn("Position")
    zoneList:SetDataHeight(28)
    zoneList.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.panel)
    end

    local removeSelected = vgui.Create("DButton", frame)
    removeSelected:SetText("Remove Selected")
    removeSelected:SetPos(16, frame:GetTall() - 48)
    removeSelected:SetSize(160, 36)
    styleButton(removeSelected, colors.accent)
    removeSelected.DoClick = function()
        local index = selectedIndex()
        if index then sendAction("remove_index", index) end
    end

    local refresh = vgui.Create("DButton", frame)
    refresh:SetText("Refresh")
    refresh:SetPos(188, frame:GetTall() - 48)
    refresh:SetSize(100, 36)
    styleButton(refresh, Color(70, 80, 100))
    refresh.DoClick = requestState

    refreshList()
    requestState()
end

net.Receive("ZCityAftermath.SafeZoneState", function()
    SafeZoneClient.State.map = net.ReadString()
    SafeZoneClient.State.zones = net.ReadTable() or {}
    refreshList()
end)

net.Receive("ZCityAftermath.OpenSafeZoneMenu", function()
    SafeZoneClient.OpenMenu()
end)

concommand.Add(Config.SafeZoneMenuCommand, function()
    SafeZoneClient.OpenMenu()
end)

hook.Add("HUDPaint", "ZCityAftermath.SafeZoneHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNWBool("ZCityAftermath.InSafeZone", false) then return end

    draw.SimpleText("SAFE ZONE", "ZCitySafe.Body", ScrW() * 0.5, ScrH() - 92, Color(120, 255, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
