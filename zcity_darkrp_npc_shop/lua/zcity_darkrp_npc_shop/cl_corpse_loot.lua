ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.CorpseLootClient = ZCityDarkRPShop.CorpseLootClient or {}

local CorpseLootClient = ZCityDarkRPShop.CorpseLootClient

local frame
local state = {
    entity = nil,
    loot = {}
}

local function sendTake(bucket, index)
    if not IsValid(state.entity) then
        return
    end

    net.Start("ZCityAftermath.CorpseLootTake")
        net.WriteEntity(state.entity)
        net.WriteString(bucket or "")
        net.WriteUInt(math.max(0, math.floor(tonumber(index) or 0)), 8)
    net.SendToServer()
end

local function closeLoot()
    if IsValid(frame) then
        frame:Remove()
    end
end

local function itemButton(parent, text, doClick)
    local button = vgui.Create("DButton", parent)
    button:Dock(TOP)
    button:DockMargin(0, 0, 0, 6)
    button:SetTall(28)
    button:SetText(text)
    button:SetFont("DermaDefaultBold")
    button:SetTextColor(Color(255, 255, 255))
    button.Paint = function(self, w, h)
        local color = self:IsHovered() and Color(45, 50, 58, 240) or Color(22, 26, 32, 235)
        draw.RoundedBox(6, 0, 0, w, h, color)
        surface.SetDrawColor(64, 72, 84, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    button.DoClick = doClick
    return button
end

local function sectionTitle(parent, text)
    local label = vgui.Create("DLabel", parent)
    label:Dock(TOP)
    label:DockMargin(0, 6, 0, 6)
    label:SetTall(18)
    label:SetText(text)
    label:SetFont("DermaLarge")
    label:SetTextColor(Color(255, 255, 255))
    return label
end

local function rebuildLoot()
    if not IsValid(frame) then
        return
    end

    local scroll = frame.ScrollPanel
    if not IsValid(scroll) then
        return
    end

    local canvas = scroll:GetCanvas()
    if not IsValid(canvas) then
        return
    end

    canvas:Clear()

    local loot = state.loot or {}
    local owner = string.Trim(tostring(loot.owner or ""))
    if owner ~= "" then
        local subtitle = vgui.Create("DLabel", canvas)
        subtitle:Dock(TOP)
        subtitle:DockMargin(0, 0, 0, 8)
        subtitle:SetTall(18)
        subtitle:SetText("Труп: " .. owner)
        subtitle:SetFont("DermaDefaultBold")
        subtitle:SetTextColor(Color(188, 198, 214))
    end

    itemButton(canvas, "Забрать всё", function()
        sendTake("all", 0)
    end)

    local anyItems = false

    if istable(loot.weapons) and #loot.weapons > 0 then
        anyItems = true
        sectionTitle(canvas, "Оружие")
        for index, item in ipairs(loot.weapons) do
            local label = string.format("%s [%s]", tostring(item.name or item.class or "Weapon"), tostring(item.class or ""))
            itemButton(canvas, label, function()
                sendTake("weapon", index)
            end)
        end
    end

    if istable(loot.ammo) and #loot.ammo > 0 then
        anyItems = true
        sectionTitle(canvas, "Патроны")
        for index, item in ipairs(loot.ammo) do
            local label = string.format("%s x%d", tostring(item.ammoType or "Ammo"), math.max(0, math.floor(tonumber(item.amount) or 0)))
            itemButton(canvas, label, function()
                sendTake("ammo", index)
            end)
        end
    end

    if istable(loot.attachments) and #loot.attachments > 0 then
        anyItems = true
        sectionTitle(canvas, "Обвесы")
        for index, item in ipairs(loot.attachments) do
            itemButton(canvas, tostring(item), function()
                sendTake("attachment", index)
            end)
        end
    end

    if not anyItems then
        local empty = vgui.Create("DLabel", canvas)
        empty:Dock(TOP)
        empty:DockMargin(0, 12, 0, 0)
        empty:SetTall(22)
        empty:SetText("На трупе ничего нет.")
        empty:SetFont("DermaLarge")
        empty:SetTextColor(Color(200, 200, 200))
    end
end

function CorpseLootClient.Open(entity, loot)
    state.entity = entity
    state.loot = istable(loot) and loot or {}

    if IsValid(frame) then
        rebuildLoot()
        frame:MakePopup()
        return
    end

    frame = vgui.Create("DFrame")
    frame:SetSize(520, 440)
    frame:Center()
    frame:SetTitle("Corpse Loot")
    frame:MakePopup()
    frame:ShowCloseButton(true)
    frame.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(10, 12, 16, 245))
        draw.RoundedBoxEx(10, 0, 0, w, 30, Color(28, 32, 40, 255), true, true, false, false)
    end
    frame.OnRemove = function()
        frame = nil
        state.entity = nil
        state.loot = {}
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(12, 38)
    scroll:SetSize(frame:GetWide() - 24, frame:GetTall() - 50)
    frame.ScrollPanel = scroll

    rebuildLoot()
end

net.Receive("ZCityAftermath.CorpseLootState", function()
    local entity = net.ReadEntity()
    local decoded = util.JSONToTable(net.ReadString() or "{}")
    CorpseLootClient.Open(entity, istable(decoded) and decoded or {})
end)
