ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Cameras = ZCityDarkRPShop.Cameras or {}

local Cameras = ZCityDarkRPShop.Cameras
local Config = ZCityDarkRPShop.Config

local frame
local listPanel
local previewPanel
local statusLabel
local helperLabel
local connectButton
local removeButton

Cameras.ClientEntries = Cameras.ClientEntries or {}
Cameras.SelectedEntity = Cameras.SelectedEntity or nil
Cameras.ActiveEntity = Cameras.ActiveEntity or nil

surface.CreateFont("ZCityCamera.Title", {
    font = "Trebuchet24",
    size = 26,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZCityCamera.Body", {
    font = "Tahoma",
    size = 16,
    weight = 700,
    antialias = true
})

surface.CreateFont("ZCityCamera.Small", {
    font = "Tahoma",
    size = 13,
    weight = 600,
    antialias = true
})

local colors = {
    frame = Color(13, 18, 27, 248),
    header = Color(63, 70, 79, 252),
    panel = Color(5, 10, 18, 244),
    panelSoft = Color(17, 24, 35, 255),
    panelBorder = Color(36, 46, 59, 255),
    row = Color(17, 24, 35, 255),
    rowHover = Color(29, 39, 55, 255),
    rowSelect = Color(49, 62, 80, 255),
    text = Color(242, 245, 249),
    dim = Color(145, 153, 166),
    accent = Color(77, 136, 205),
    accentHover = Color(100, 160, 226),
    danger = Color(185, 76, 76),
    dangerHover = Color(212, 95, 95)
}

local function holdingTablet()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return false
    end

    local weapon = ply:GetActiveWeapon()
    return IsValid(weapon) and Cameras.IsTabletWeapon and Cameras.IsTabletWeapon(weapon:GetClass())
end

local function requestList()
    net.Start("ZCityAftermath.CameraRequestList")
    net.SendToServer()
end

local function requestView(ent)
    net.Start("ZCityAftermath.CameraRequestView")
        net.WriteEntity(ent or NULL)
    net.SendToServer()
end

function Cameras.ClearView()
    Cameras.ActiveEntity = nil

    net.Start("ZCityAftermath.CameraClearView")
    net.SendToServer()
end

function Cameras.HandleReloadAction()
    if IsValid(Cameras.ActiveEntity) then
        Cameras.ClearView()
        return
    end

    Cameras.OpenTabletMenu()
end

local function selectedEntry()
    for _, entry in ipairs(Cameras.ClientEntries or {}) do
        if entry.entity == Cameras.SelectedEntity then
            return entry
        end
    end
end

local function updatePreview()
    local entry = selectedEntry()

    if IsValid(previewPanel) then
        local model = entry and IsValid(entry.entity) and entry.entity:GetModel() or Cameras.GetTabletWorldModel()
        previewPanel:SetModel(model)

        local entity = previewPanel.Entity
        if IsValid(entity) then
            local mins, maxs = entity:GetRenderBounds()
            local center = (mins + maxs) * 0.5
            local size = math.max((maxs - mins):Length(), 24)

            previewPanel:SetLookAt(center)
            previewPanel:SetCamPos(center + Vector(size * 1.8, size * 1.2, size * 0.55))
            previewPanel.LayoutEntity = function(_, ent)
                ent:SetAngles(Angle(0, RealTime() * 25 % 360, 0))
            end
        end
    end

    if IsValid(statusLabel) then
        if entry then
            statusLabel:SetText(entry.name)
        else
            statusLabel:SetText("Select a camera on the left.")
        end
    end

    if IsValid(helperLabel) then
        if entry then
            helperLabel:SetText("LMB: connect  |  RMB/LMB on tablet: switch cameras  |  R: menu / exit")
        else
            helperLabel:SetText("Use the tablet to watch your placed security cameras. R opens the list.")
        end
    end

    if IsValid(connectButton) then
        connectButton:SetEnabled(entry ~= nil)
    end

    if IsValid(removeButton) then
        removeButton:SetEnabled(entry ~= nil)
    end
end

local function rebuildList()
    if not IsValid(listPanel) then
        return
    end

    listPanel:Clear()

    for _, entry in ipairs(Cameras.ClientEntries or {}) do
        local row = listPanel:Add("DButton")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 8)
        row:SetTall(40)
        row:SetText("")
        row.Entry = entry
        row.Paint = function(self, w, h)
            local bg = colors.row
            if Cameras.SelectedEntity == self.Entry.entity then
                bg = colors.rowSelect
            elseif self:IsHovered() then
                bg = colors.rowHover
            end

            draw.RoundedBox(8, 0, 0, w, h, bg)
            surface.SetDrawColor(colors.panelBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(self.Entry.name or "Camera", "ZCityCamera.Body", 14, h / 2, colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            Cameras.SelectedEntity = row.Entry.entity
            updatePreview()
        end
        row.DoDoubleClick = function()
            Cameras.SelectedEntity = row.Entry.entity
            requestView(row.Entry.entity)
            updatePreview()
        end
    end

    if not IsValid(Cameras.SelectedEntity) and Cameras.ClientEntries[1] then
        Cameras.SelectedEntity = Cameras.ClientEntries[1].entity
    end

    updatePreview()
end

function Cameras.OpenTabletMenu()
    requestList()

    if IsValid(frame) then
        frame:MakePopup()
        updatePreview()
        return
    end

    frame = vgui.Create("DFrame")
    frame:SetSize(math.min(900, ScrW() - 80), math.min(520, ScrH() - 80))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, colors.frame)
        draw.RoundedBoxEx(10, 10, 10, w - 20, 28, colors.header, true, true, true, true)
        draw.SimpleText("Camera Tablet", "ZCityCamera.Title", w / 2, 24, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    frame.OnRemove = function()
        frame = nil
        listPanel = nil
        previewPanel = nil
        statusLabel = nil
        helperLabel = nil
        connectButton = nil
        removeButton = nil
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("x")
    close:SetFont("ZCityCamera.Body")
    close:SetTextColor(colors.text)
    close:SetSize(24, 24)
    close:SetPos(frame:GetWide() - 36, 12)
    close.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and colors.danger or Color(96, 102, 110))
    end
    close.DoClick = function()
        if IsValid(frame) then
            frame:Close()
        end
    end

    local left = vgui.Create("DScrollPanel", frame)
    left:SetPos(16, 50)
    left:SetSize(math.floor(frame:GetWide() * 0.48), frame:GetTall() - 66)
    left.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.panel)
        surface.SetDrawColor(colors.panelBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local bar = left:GetVBar()
    bar:SetWide(8)
    bar.Paint = function() end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(72, 79, 88))
    end

    listPanel = vgui.Create("DListLayout", left)
    listPanel:Dock(TOP)
    listPanel:DockMargin(10, 10, 10, 10)

    local right = vgui.Create("DPanel", frame)
    right:SetPos(left:GetX() + left:GetWide() + 14, 50)
    right:SetSize(frame:GetWide() - left:GetWide() - 46, frame:GetTall() - 66)
    right.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.panel)
        surface.SetDrawColor(colors.panelBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    previewPanel = vgui.Create("DModelPanel", right)
    previewPanel:SetPos(12, 12)
    previewPanel:SetSize(right:GetWide() - 24, 240)
    previewPanel:SetFOV(26)

    statusLabel = vgui.Create("DLabel", right)
    statusLabel:SetFont("ZCityCamera.Title")
    statusLabel:SetTextColor(colors.text)
    statusLabel:SetContentAlignment(4)
    statusLabel:SetPos(14, 260)
    statusLabel:SetSize(right:GetWide() - 28, 28)

    helperLabel = vgui.Create("DLabel", right)
    helperLabel:SetFont("ZCityCamera.Small")
    helperLabel:SetTextColor(colors.dim)
    helperLabel:SetWrap(true)
    helperLabel:SetContentAlignment(7)
    helperLabel:SetPos(14, 296)
    helperLabel:SetSize(right:GetWide() - 28, 72)

    connectButton = vgui.Create("DButton", right)
    connectButton:SetText("Connect")
    connectButton:SetFont("ZCityCamera.Body")
    connectButton:SetTextColor(colors.text)
    connectButton:SetSize(right:GetWide() - 28, 42)
    connectButton:SetPos(14, right:GetTall() - 102)
    connectButton.Paint = function(self, w, h)
        local bg = self:IsEnabled() and (self:IsHovered() and colors.accentHover or colors.accent) or Color(70, 76, 83)
        draw.RoundedBox(8, 0, 0, w, h, bg)
    end
    connectButton.DoClick = function()
        local entry = selectedEntry()
        if entry then
            requestView(entry.entity)
        end
    end

    removeButton = vgui.Create("DButton", right)
    removeButton:SetText("Delete Camera")
    removeButton:SetFont("ZCityCamera.Body")
    removeButton:SetTextColor(colors.text)
    removeButton:SetSize(right:GetWide() - 28, 36)
    removeButton:SetPos(14, right:GetTall() - 54)
    removeButton.Paint = function(self, w, h)
        local bg = self:IsEnabled() and (self:IsHovered() and colors.dangerHover or colors.danger) or Color(70, 76, 83)
        draw.RoundedBox(8, 0, 0, w, h, bg)
    end
    removeButton.DoClick = function()
        local entry = selectedEntry()
        if not entry then
            return
        end

        net.Start("ZCityAftermath.CameraRemove")
            net.WriteEntity(entry.entity)
        net.SendToServer()
    end

    rebuildList()
end

function Cameras.SelectNextCamera()
    local entries = Cameras.ClientEntries or {}
    if #entries == 0 then
        requestList()
        notification.AddLegacy("You have no placed cameras.", NOTIFY_ERROR, 4)
        surface.PlaySound("buttons/button10.wav")
        return
    end

    local currentIndex = 0
    for index, entry in ipairs(entries) do
        if entry.entity == Cameras.ActiveEntity then
            currentIndex = index
            break
        end
    end

    local nextIndex = currentIndex + 1
    if nextIndex > #entries then
        nextIndex = 1
    end

    Cameras.SelectedEntity = entries[nextIndex].entity
    requestView(entries[nextIndex].entity)
end

function Cameras.SelectPreviousCamera()
    local entries = Cameras.ClientEntries or {}
    if #entries == 0 then
        requestList()
        notification.AddLegacy("You have no placed cameras.", NOTIFY_ERROR, 4)
        surface.PlaySound("buttons/button10.wav")
        return
    end

    local currentIndex = 0
    for index, entry in ipairs(entries) do
        if entry.entity == Cameras.ActiveEntity then
            currentIndex = index
            break
        end
    end

    if currentIndex == 0 then
        currentIndex = 1
    end

    local previousIndex = currentIndex - 1
    if previousIndex < 1 then
        previousIndex = #entries
    end

    Cameras.SelectedEntity = entries[previousIndex].entity
    requestView(entries[previousIndex].entity)
end

net.Receive("ZCityAftermath.CameraList", function()
    local count = net.ReadUInt(8)
    local entries = {}

    for index = 1, count do
        entries[#entries + 1] = {
            entity = net.ReadEntity(),
            name = net.ReadString()
        }
    end

    Cameras.ClientEntries = entries

    if IsValid(Cameras.SelectedEntity) then
        local stillExists = false
        for _, entry in ipairs(entries) do
            if entry.entity == Cameras.SelectedEntity then
                stillExists = true
                break
            end
        end

        if not stillExists then
            Cameras.SelectedEntity = nil
        end
    end

    rebuildList()
end)

net.Receive("ZCityAftermath.CameraSetView", function()
    local ent = net.ReadEntity()
    Cameras.ActiveEntity = IsValid(ent) and ent or nil
end)

concommand.Add(Config.CameraMenuCommand, function()
    Cameras.OpenTabletMenu()
end)

hook.Add("CalcView", "ZCityAftermath.CameraTabletView", function(_, origin, angles, fov)
    if not holdingTablet() then
        return
    end

    local ent = Cameras.ActiveEntity
    if not IsValid(ent) then
        return
    end

    local viewOrigin, viewAngles
    if ent.GetCameraFeedPos then
        viewOrigin, viewAngles = ent:GetCameraFeedPos()
    else
        viewOrigin = ent:GetPos() + ent:GetForward() * 6 + ent:GetUp() * 4
        viewAngles = ent:GetAngles()
    end

    return {
        origin = viewOrigin or origin,
        angles = viewAngles or angles,
        fov = 70,
        drawviewer = true
    }
end)

hook.Add("HUDPaint", "ZCityAftermath.CameraTabletHUD", function()
    if not holdingTablet() or not IsValid(Cameras.ActiveEntity) then
        return
    end

    draw.RoundedBox(8, 18, 18, 300, 62, Color(8, 12, 18, 220))
    draw.SimpleText(Cameras.ActiveEntity:GetNWString("ZCityCameraName", "Camera"), "ZCityCamera.Title", 30, 26, colors.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText("LMB - next  |  RMB - previous  |  R - menu / exit", "ZCityCamera.Small", 30, 56, colors.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)

hook.Add("Think", "ZCityAftermath.CameraTabletCleanup", function()
    if Cameras.ActiveEntity ~= nil and not IsValid(Cameras.ActiveEntity) then
        Cameras.ActiveEntity = nil
    end
end)
