ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.BackpackClient = ZCityDarkRPShop.BackpackClient or {}

local BackpackClient = ZCityDarkRPShop.BackpackClient
local Config = ZCityDarkRPShop.Config

BackpackClient.Items = BackpackClient.Items or {}

local backdrop
local frame
local grid
local countLabel
local emptyLabel
local closeHeld = false

local blurMat = Material("pp/blurscreen")

surface.CreateFont("ZCityBackpack.Title", {
    font = "Trebuchet24",
    size = 24,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZCityBackpack.Body", {
    font = "Tahoma",
    size = 16,
    weight = 700,
    antialias = true
})

surface.CreateFont("ZCityBackpack.Small", {
    font = "Tahoma",
    size = 13,
    weight = 600,
    antialias = true
})

local colors = {
    overlay = Color(0, 0, 0, 188),
    frame = Color(13, 18, 27, 244),
    header = Color(63, 70, 79, 252),
    panel = Color(5, 10, 18, 244),
    panelBorder = Color(36, 46, 59, 255),
    slot = Color(17, 24, 35, 255),
    slotHover = Color(30, 39, 53, 255),
    slotFilled = Color(23, 31, 44, 255),
    text = Color(242, 245, 249),
    dim = Color(145, 153, 166),
    accent = Color(205, 77, 77)
}

local function drawBlur(panel, passes)
    local x, y = panel:LocalToScreen(0, 0)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(blurMat)

    for i = 1, passes do
        blurMat:SetFloat("$blur", (i / passes) * 5)
        blurMat:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

local function requestBackpack()
    net.Start("ZCityAftermath.RequestBackpack")
    net.SendToServer()
end

local function formatMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))

    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(amount)
    end

    return "$" .. tostring(amount)
end

local function localBalance()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return 0
    end

    if ply.getDarkRPVar then
        return math.max(0, math.floor(tonumber(ply:getDarkRPVar("money")) or 0))
    end

    return 0
end

local function sendDarkRPMoney(action, amount)
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

local function promptMoney(action)
    local title = action == "give" and "Give Money" or "Drop Money"
    local instructions = action == "give"
        and "Enter amount. Look at a nearby player before confirming."
        or "Enter amount to drop."

    Derma_StringRequest(title, instructions, "", function(value)
        local amount = math.floor(tonumber(value) or 0)
        if amount <= 0 then
            notification.AddLegacy("Enter an amount greater than zero.", NOTIFY_ERROR, 4)
            surface.PlaySound("buttons/button10.wav")
            return
        end

        sendDarkRPMoney(action, amount)
    end)
end

local function sendAction(action, index)
    net.Start("ZCityAftermath.BackpackAction")
        net.WriteString(action)
        if index then
            net.WriteUInt(math.max(0, math.floor(tonumber(index) or 0)), 8)
        end
    net.SendToServer()

    timer.Simple(0.15, requestBackpack)
end

local function closeBackpack()
    if IsValid(backdrop) then
        backdrop:Remove()
    end
end

local function getItemModel(item)
    local model = tostring(item and item.model or "")
    if model ~= "" and util.IsValidModel(model) then
        return model
    end

    return "models/weapons/w_pistol.mdl"
end

local function slotLabel(item)
    local text = tostring(item and (item.name or item.class) or "")
    if #text > 18 then
        text = string.sub(text, 1, 18) .. "..."
    end

    return text
end

local function openItemMenu(index)
    local item = BackpackClient.Items[index]
    if not item then return end

    local menu = DermaMenu()
    menu:AddOption("Взять", function()
        sendAction("take", index)
    end)
    menu:AddOption("Выбросить", function()
        sendAction("drop", index)
    end)
    menu:Open()
end

local function rebuildGrid()
    if not IsValid(grid) then return end

    grid:Clear()

    local maxItems = math.max(1, tonumber(Config.MaxBackpackItems) or 16)
    local count = #(BackpackClient.Items or {})

    if IsValid(countLabel) then
        countLabel:SetText(string.format("%d/%d", count, maxItems))
    end

    if IsValid(emptyLabel) then
        emptyLabel:SetVisible(count == 0)
    end

    for index = 1, maxItems do
        local item = BackpackClient.Items[index]

        local slot = grid:Add("DButton")
        slot:SetText("")
        slot:SetSize(104, 94)
        slot.ItemData = item
        slot.Paint = function(self, w, h)
            local bg = self:IsHovered() and colors.slotHover or colors.slot
            if self.ItemData then
                bg = self:IsHovered() and Color(34, 45, 60) or colors.slotFilled
            end

            draw.RoundedBox(6, 0, 0, w, h, bg)
            surface.SetDrawColor(colors.panelBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        slot.DoClick = function(self)
            if self.ItemData then
                sendAction("take", index)
            end
        end
        slot.DoRightClick = function(self)
            if self.ItemData then
                openItemMenu(index)
            end
        end

        if item then
            local icon = vgui.Create("SpawnIcon", slot)
            icon:SetPos(8, 8)
            icon:SetSize(88, 56)
            icon:SetModel(getItemModel(item))
            icon:SetTooltip(false)
            icon:SetMouseInputEnabled(false)
            icon:SetKeyboardInputEnabled(false)

            local name = vgui.Create("DLabel", slot)
            name:SetFont("ZCityBackpack.Small")
            name:SetTextColor(colors.text)
            name:SetText(slotLabel(item))
            name:SetContentAlignment(5)
            name:SetPos(6, 68)
            name:SetSize(92, 16)
        end
    end
end

function BackpackClient.Open()
    if IsValid(backdrop) then
        backdrop:MakePopup()
        requestBackpack()
        return
    end

    backdrop = vgui.Create("EditablePanel")
    backdrop:SetSize(ScrW(), ScrH())
    backdrop:MakePopup()
    backdrop:SetKeyboardInputEnabled(true)
    backdrop:SetMouseInputEnabled(true)
    backdrop.Paint = function(self, w, h)
        drawBlur(self, 3)
        surface.SetDrawColor(colors.overlay)
        surface.DrawRect(0, 0, w, h)
    end
    backdrop.Think = function()
        local pressed = input.IsKeyDown(KEY_R)
        if pressed and not closeHeld then
            closeBackpack()
        end
        closeHeld = pressed
    end
    backdrop.OnRemove = function()
        backdrop = nil
        frame = nil
        grid = nil
        countLabel = nil
        emptyLabel = nil
        closeHeld = false
    end

    frame = vgui.Create("DPanel", backdrop)
    frame:SetSize(math.min(640, ScrW() - 60), math.min(420, ScrH() - 80))
    frame:Center()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.frame)
        draw.RoundedBoxEx(8, 10, 10, w - 20, 24, colors.header, true, true, true, true)
        draw.SimpleText("Backpack", "ZCityBackpack.Body", w / 2, 22, colors.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("x")
    close:SetFont("ZCityBackpack.Body")
    close:SetTextColor(colors.text)
    close:SetSize(22, 22)
    close:SetPos(frame:GetWide() - 32, 11)
    close.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and colors.accent or Color(96, 102, 110))
    end
    close.DoClick = closeBackpack

    countLabel = vgui.Create("DLabel", frame)
    countLabel:SetFont("ZCityBackpack.Small")
    countLabel:SetTextColor(colors.dim)
    countLabel:SetContentAlignment(6)
    countLabel:SetPos(frame:GetWide() - 92, 12)
    countLabel:SetSize(48, 20)

    local content = vgui.Create("DPanel", frame)
    content:SetPos(18, 46)
    content:SetSize(frame:GetWide() - 36, frame:GetTall() - 86)
    content.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, colors.panel)
        surface.SetDrawColor(colors.panelBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local scroll = vgui.Create("DScrollPanel", content)
    scroll:SetPos(8, 8)
    scroll:SetSize(content:GetWide() - 16, content:GetTall() - 16)

    local bar = scroll:GetVBar()
    bar:SetWide(8)
    bar.Paint = function() end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function(_, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(72, 79, 88))
    end

    grid = vgui.Create("DIconLayout", scroll)
    grid:Dock(TOP)
    grid:SetSpaceX(8)
    grid:SetSpaceY(8)
    grid:SetBorder(4)

    emptyLabel = vgui.Create("DLabel", content)
    emptyLabel:SetFont("ZCityBackpack.Body")
    emptyLabel:SetTextColor(colors.dim)
    emptyLabel:SetText("Рюкзак пуст")
    emptyLabel:SetContentAlignment(5)
    emptyLabel:SetSize(content:GetWide(), 24)
    emptyLabel:SetPos(0, math.floor(content:GetTall() / 2) - 12)

    local footer = vgui.Create("DLabel", frame)
    footer:SetFont("ZCityBackpack.Small")
    footer:SetTextColor(colors.dim)
    footer:SetText("R - Закрыть | LMB - Взять | RMB - Меню предметов")
    footer:SetContentAlignment(5)
    footer:SetPos(16, frame:GetTall() - 28)
    footer:SetSize(frame:GetWide() - 32, 18)

    rebuildGrid()
    requestBackpack()
end

net.Receive("ZCityAftermath.BackpackState", function()
    BackpackClient.Items = net.ReadTable() or {}
    rebuildGrid()
end)

concommand.Add(Config.BackpackCommand, function()
    BackpackClient.Open()
end)

concommand.Add(Config.BackpackPutCommand, function()
    sendAction("put")
end)

hook.Add("radialOptions", "ZCityAftermath.BackpackRadial", function()
    hg = hg or {}
    hg.radialOptions = hg.radialOptions or {}

    for index = #hg.radialOptions, 1, -1 do
        local option = hg.radialOptions[index]
        local label = tostring(istable(option) and option[2] or "")
        if string.find(label, "Balance:", 1, true)
            or string.find(label, "Drop Money", 1, true)
            or string.find(label, "Give Money", 1, true) then
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
            notification.AddLegacy("Balance: " .. formatMoney(localBalance()), NOTIFY_GENERIC, 4)
            surface.PlaySound("buttons/button15.wav")
        end,
        "Balance: " .. formatMoney(localBalance())
    })

    hg.radialOptions[#hg.radialOptions + 1] = {
        function()
            sendAction("put")
        end,
        "Put In Backpack"
    }

    hg.radialOptions[#hg.radialOptions + 1] = {
        function()
            BackpackClient.Open()
        end,
        "Open Backpack"
    }
end)
