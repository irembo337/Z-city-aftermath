ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.HousingClient = ZCityDarkRPShop.HousingClient or {}

local HousingClient = ZCityDarkRPShop.HousingClient
local Config = ZCityDarkRPShop.Config

HousingClient.State = HousingClient.State or {
    map = game.GetMap(),
    doors = {}
}

local frame
local doorMenu
local priceEntry
local nameEntry
local doorList

surface.CreateFont("ZCityDoor.Title", {
    font = "Trebuchet24",
    size = 28,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZCityDoor.Body", {
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
    net.Start("ZCityAftermath.RequestDoorState")
    net.SendToServer()
end

local function requestLookedDoor()
    net.Start("ZCityAftermath.RequestLookedDoor")
    net.SendToServer()
end

local function sendAction(action, payloadA, payloadB)
    net.Start("ZCityAftermath.DoorAction")
        net.WriteString(action)

        if action == "set_price" then
            net.WriteUInt(math.max(0, math.floor(tonumber(payloadA) or Config.DefaultDoorPrice)), 32)
            net.WriteString(tostring(payloadB or ""))
        end
    net.SendToServer()

    timer.Simple(0.25, requestState)
end

local function formatMoney(amount)
    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(amount)
    end

    return "$" .. tostring(amount)
end

local function styleButton(button, color)
    button:SetFont("ZCityDoor.Body")
    button:SetTextColor(colors.text)
    button.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and Color(210, 38, 45) or color)
    end
end

local function styleEntry(entry)
    entry:SetFont("ZCityDoor.Body")
    entry:SetTextColor(colors.text)
    entry:SetDrawLanguageID(false)
    entry.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.panel)
        surface.SetDrawColor(colors.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(colors.text, colors.accent, colors.text)
    end
end

local function refreshList()
    if not IsValid(doorList) then return end

    doorList:Clear()

    for _, record in pairs(HousingClient.State.doors or {}) do
        doorList:AddLine(
            tostring(record.mapId or ""),
            tostring(record.name or ""),
            formatMoney(tonumber(record.price) or Config.DefaultDoorPrice),
            record.enabled == false and "No" or "Yes"
        )
    end
end

function HousingClient.OpenAdmin()
    if not isSuperAdmin() then
        notification.AddLegacy("Only ULX superadmin can edit doors.", NOTIFY_ERROR, 4)
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
        draw.SimpleText("Z-City Door Manager", "ZCityDoor.Title", 22, 14, colors.text)
        draw.SimpleText("Look at a door before saving price", "ZCityDoor.Body", 300, 22, colors.dim)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("X")
    close:SetSize(42, 34)
    close:SetPos(frame:GetWide() - 54, 12)
    styleButton(close, colors.accent)
    close.DoClick = function() frame:Close() end

    priceEntry = vgui.Create("DTextEntry", frame)
    priceEntry:SetPos(16, 78)
    priceEntry:SetSize(120, 36)
    priceEntry:SetNumeric(true)
    priceEntry:SetText(tostring(Config.DefaultDoorPrice))
    styleEntry(priceEntry)

    nameEntry = vgui.Create("DTextEntry", frame)
    nameEntry:SetPos(148, 78)
    nameEntry:SetSize(frame:GetWide() - 482, 36)
    nameEntry:SetPlaceholderText("Door or house name")
    styleEntry(nameEntry)

    local setPrice = vgui.Create("DButton", frame)
    setPrice:SetText("Save Looked Door")
    setPrice:SetPos(frame:GetWide() - 322, 78)
    setPrice:SetSize(150, 36)
    styleButton(setPrice, colors.green)
    setPrice.DoClick = function()
        sendAction("set_price", priceEntry:GetValue(), nameEntry:GetValue())
    end

    local clear = vgui.Create("DButton", frame)
    clear:SetText("Clear Looked Door")
    clear:SetPos(frame:GetWide() - 162, 78)
    clear:SetSize(146, 36)
    styleButton(clear, colors.accent)
    clear.DoClick = function()
        sendAction("clear")
    end

    doorList = vgui.Create("DListView", frame)
    doorList:SetPos(16, 130)
    doorList:SetSize(frame:GetWide() - 32, frame:GetTall() - 190)
    doorList:SetMultiSelect(false)
    doorList:AddColumn("Map ID"):SetFixedWidth(90)
    doorList:AddColumn("Name")
    doorList:AddColumn("Price"):SetFixedWidth(120)
    doorList:AddColumn("Enabled"):SetFixedWidth(90)
    doorList:SetDataHeight(28)
    doorList.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.panel)
    end

    local refresh = vgui.Create("DButton", frame)
    refresh:SetText("Refresh")
    refresh:SetPos(16, frame:GetTall() - 48)
    refresh:SetSize(100, 36)
    styleButton(refresh, Color(70, 80, 100))
    refresh.DoClick = requestState

    refreshList()
    requestState()
end

net.Receive("ZCityAftermath.DoorState", function()
    HousingClient.State.map = net.ReadString()
    HousingClient.State.doors = net.ReadTable() or {}
    refreshList()
end)

net.Receive("ZCityAftermath.OpenDoorAdmin", function()
    HousingClient.OpenAdmin()
end)

concommand.Add(Config.DoorAdminMenuCommand, function()
    HousingClient.OpenAdmin()
end)

local function openDoorMenu(info)
    if IsValid(doorMenu) then
        doorMenu:Remove()
    end

    doorMenu = vgui.Create("DFrame")
    doorMenu:SetSize(420, 300)
    doorMenu:Center()
    doorMenu:SetTitle("")
    doorMenu:ShowCloseButton(false)
    doorMenu:MakePopup()
    doorMenu.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 56, colors.header, true, true, false, false)
        draw.SimpleText("Door", "ZCityDoor.Title", 20, 14, colors.text)
    end

    local close = vgui.Create("DButton", doorMenu)
    close:SetText("X")
    close:SetSize(38, 30)
    close:SetPos(doorMenu:GetWide() - 50, 13)
    styleButton(close, colors.accent)
    close.DoClick = function() doorMenu:Close() end

    if not info.valid then
        local label = vgui.Create("DLabel", doorMenu)
        label:SetFont("ZCityDoor.Body")
        label:SetTextColor(colors.dim)
        label:SetText("Look at a buyable door.")
        label:SetPos(22, 88)
        label:SizeToContents()
        return
    end

    local name = vgui.Create("DLabel", doorMenu)
    name:SetFont("ZCityDoor.Title")
    name:SetTextColor(colors.text)
    name:SetText(info.name)
    name:SetPos(22, 76)
    name:SetSize(doorMenu:GetWide() - 44, 34)

    local meta = vgui.Create("DLabel", doorMenu)
    meta:SetFont("ZCityDoor.Body")
    meta:SetTextColor(colors.dim)
    meta:SetText("Price: " .. formatMoney(info.price) .. "\nOwner: " .. (info.owner ~= "" and info.owner or "none"))
    meta:SetPos(22, 116)
    meta:SetSize(doorMenu:GetWide() - 44, 56)

    local primary = vgui.Create("DButton", doorMenu)
    primary:SetSize(doorMenu:GetWide() - 44, 42)
    primary:SetPos(22, 184)
    styleButton(primary, info.ownedByMe and colors.accent or colors.green)

    if info.ownedByMe then
        primary:SetText("Sell Door")
        primary.DoClick = function()
            sendAction("sell")
            doorMenu:Close()
        end
    elseif info.owned then
        primary:SetText("Already Owned")
        primary:SetEnabled(false)
    else
        primary:SetText("Buy Door")
        primary.DoClick = function()
            sendAction("buy")
            doorMenu:Close()
        end
    end

    local lock = vgui.Create("DButton", doorMenu)
    lock:SetSize((doorMenu:GetWide() - 54) / 2, 38)
    lock:SetPos(22, 238)
    lock:SetText("Lock")
    styleButton(lock, Color(70, 80, 100))
    lock:SetEnabled(info.ownedByMe)
    lock.DoClick = function() sendAction("lock") end

    local unlock = vgui.Create("DButton", doorMenu)
    unlock:SetSize((doorMenu:GetWide() - 54) / 2, 38)
    unlock:SetPos(32 + lock:GetWide(), 238)
    unlock:SetText("Unlock")
    styleButton(unlock, Color(70, 80, 100))
    unlock:SetEnabled(info.ownedByMe)
    unlock.DoClick = function() sendAction("unlock") end
end

net.Receive("ZCityAftermath.LookedDoorInfo", function()
    local info = {
        valid = net.ReadBool()
    }

    if info.valid then
        info.mapId = net.ReadUInt(32)
        info.name = net.ReadString()
        info.price = net.ReadUInt(32)
        info.owned = net.ReadBool()
        info.owner = net.ReadString()
        info.ownedByMe = net.ReadBool()
        info.locked = net.ReadBool()
    end

    openDoorMenu(info)
end)

concommand.Add(Config.DoorMenuCommand, function()
    requestLookedDoor()
end)

concommand.Add(Config.DoorBuyCommand, function()
    sendAction("buy")
end)

concommand.Add(Config.DoorSellCommand, function()
    sendAction("sell")
end)

concommand.Add(Config.DoorLockCommand, function()
    sendAction("lock")
end)

concommand.Add(Config.DoorUnlockCommand, function()
    sendAction("unlock")
end)
