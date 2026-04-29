ZCityDarkRPShop = ZCityDarkRPShop or {}

local Config = ZCityDarkRPShop.Config
local frame
local moneyFrame

surface.CreateFont("ZCityAdminHub.Title", {
    font = "Trebuchet24",
    size = 30,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZCityAdminHub.Body", {
    font = "Tahoma",
    size = 17,
    weight = 700,
    antialias = true
})

local colors = {
    bg = Color(8, 8, 10, 246),
    header = Color(18, 18, 22, 252),
    button = Color(28, 28, 35, 248),
    hover = Color(52, 52, 64, 255),
    accent = Color(175, 24, 30),
    text = Color(238, 242, 247),
    dim = Color(170, 176, 188)
}

local function userGroup()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply.GetUserGroup then return "" end
    return string.lower(ply:GetUserGroup() or "")
end

local function canOpenAdminHub()
    local group = userGroup()
    return group == "admin" or group == "superadmin"
end

local function isSuperAdminGroup()
    return userGroup() == "superadmin"
end

local function styleButton(button)
    button:SetFont("ZCityAdminHub.Body")
    button:SetTextColor(colors.text)
    button.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and colors.hover or colors.button)
    end
end

local function addButton(parent, text, x, y, w, h, command, superOnly)
    local button = vgui.Create("DButton", parent)
    button:SetText(text)
    button:SetPos(x, y)
    button:SetSize(w, h)
    styleButton(button)

    if superOnly and not isSuperAdminGroup() then
        button:SetEnabled(false)
        button:SetText(text .. " (superadmin)")
    end

    button.DoClick = function()
        RunConsoleCommand(command)
    end

    return button
end

local function openMoneyTools()
    if not isSuperAdminGroup() then
        notification.AddLegacy("Only superadmin can use money tools.", NOTIFY_ERROR, 4)
        return
    end

    if IsValid(moneyFrame) then
        moneyFrame:MakePopup()
        return
    end

    moneyFrame = vgui.Create("DFrame")
    moneyFrame:SetSize(420, 244)
    moneyFrame:Center()
    moneyFrame:SetTitle("")
    moneyFrame:ShowCloseButton(false)
    moneyFrame:MakePopup()
    moneyFrame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 56, colors.header, true, true, false, false)
        draw.SimpleText("Money Tools", "ZCityAdminHub.Title", 18, 16, colors.text)
        draw.SimpleText("Add or set DarkRP money for an online player.", "ZCityAdminHub.Body", 20, 90, colors.dim)
    end
    moneyFrame.OnClose = function()
        moneyFrame = nil
    end

    local close = vgui.Create("DButton", moneyFrame)
    close:SetText("X")
    close:SetSize(42, 34)
    close:SetPos(moneyFrame:GetWide() - 54, 12)
    styleButton(close)
    close.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(210, 38, 45) or colors.accent)
    end
    close.DoClick = function()
        if IsValid(moneyFrame) then
            moneyFrame:Close()
        end
    end

    local target = vgui.Create("DTextEntry", moneyFrame)
    target:SetPos(20, 122)
    target:SetSize(380, 30)
    target:SetPlaceholderText("Nick or SteamID64")

    local amount = vgui.Create("DTextEntry", moneyFrame)
    amount:SetPos(20, 162)
    amount:SetSize(380, 30)
    amount:SetNumeric(true)
    amount:SetPlaceholderText("Amount")

    local function sendMoneyMessage(messageName)
        local identity = string.Trim(target:GetValue() or "")
        local rawAmount = math.floor(tonumber(amount:GetValue()) or 0)

        if identity == "" then
            notification.AddLegacy("Enter a player nick or SteamID64.", NOTIFY_ERROR, 4)
            return
        end

        if rawAmount <= 0 and messageName == "ZCityAftermath.AdminAddMoney" then
            notification.AddLegacy("Amount must be greater than zero.", NOTIFY_ERROR, 4)
            return
        end

        if rawAmount < 0 then
            rawAmount = 0
        end

        net.Start(messageName)
        net.WriteString(identity)
        net.WriteInt(rawAmount, 32)
        net.SendToServer()
    end

    local addButtonPanel = vgui.Create("DButton", moneyFrame)
    addButtonPanel:SetText("Add Money")
    addButtonPanel:SetPos(20, 202)
    addButtonPanel:SetSize(184, 30)
    styleButton(addButtonPanel)
    addButtonPanel.DoClick = function()
        sendMoneyMessage("ZCityAftermath.AdminAddMoney")
    end

    local setButtonPanel = vgui.Create("DButton", moneyFrame)
    setButtonPanel:SetText("Set Money")
    setButtonPanel:SetPos(216, 202)
    setButtonPanel:SetSize(184, 30)
    styleButton(setButtonPanel)
    setButtonPanel.DoClick = function()
        sendMoneyMessage("ZCityAftermath.AdminSetMoney")
    end
end

local function openHub()
    if not canOpenAdminHub() then
        notification.AddLegacy("Only ULX admin and superadmin can open this menu.", NOTIFY_ERROR, 4)
        return
    end

    if IsValid(frame) then
        frame:MakePopup()
        return
    end

    frame = vgui.Create("DFrame")
    frame:SetSize(520, 552)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 64, colors.header, true, true, false, false)
        draw.SimpleText("Z-City Admin", "ZCityAdminHub.Title", 22, 16, colors.text)
        draw.SimpleText("Group: " .. userGroup(), "ZCityAdminHub.Body", 300, 24, colors.dim)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("X")
    close:SetSize(42, 34)
    close:SetPos(frame:GetWide() - 54, 14)
    styleButton(close)
    close.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(210, 38, 45) or colors.accent)
    end
    close.DoClick = function() frame:Close() end

    local y = 88
    local gap = 12
    addButton(frame, "Jobs Editor", 22, y, 226, 48, "zcity_jobs_editor", false)
    addButton(frame, "Shop Manager", 272, y, 226, 48, Config.AdminMenuCommand, false)

    y = y + 48 + gap
    addButton(frame, "Job Spawn Picker", 22, y, 226, 48, Config.JobSpawnPickerCommand, false)
    addButton(frame, "Spawn Manager", 272, y, 226, 48, Config.SpawnMenuCommand, true)

    y = y + 48 + gap
    addButton(frame, "Safe Zones", 22, y, 226, 48, Config.SafeZoneMenuCommand, true)
    addButton(frame, "Door Manager", 272, y, 226, 48, Config.DoorAdminMenuCommand, true)

    y = y + 48 + gap
    addButton(frame, "Remove All Traders", 22, y, 226, 48, Config.RemoveAllNPCsCommand, true)
    addButton(frame, "Add Trader NPC", 272, y, 226, 48, Config.SpawnNPCCommand, false)

    y = y + 48 + gap
    addButton(frame, "Remove Looked NPC", 22, y, 226, 48, Config.RemoveNPCCommand, false)

    local moneyTools = vgui.Create("DButton", frame)
    moneyTools:SetText("Money Tools")
    moneyTools:SetPos(272, y)
    moneyTools:SetSize(226, 48)
    styleButton(moneyTools)
    if not isSuperAdminGroup() then
        moneyTools:SetEnabled(false)
        moneyTools:SetText("Money Tools (superadmin)")
    end
    moneyTools.DoClick = openMoneyTools

    local hint = vgui.Create("DLabel", frame)
    hint:SetFont("ZCityAdminHub.Body")
    hint:SetTextColor(colors.dim)
    hint:SetText("Command: zcity_admin_menu")
    hint:SetPos(22, frame:GetTall() - 52)
    hint:SizeToContents()
end

concommand.Add(Config.AdminHubCommand, openHub)

hook.Add("OnPlayerChat", "ZCityAftermath.AdminHubChat", function(ply, text)
    if ply ~= LocalPlayer() then return end

    text = string.lower(string.Trim(tostring(text or "")))
    if text ~= "!zadmin" and text ~= "/zadmin" then return end

    openHub()
    return true
end)
