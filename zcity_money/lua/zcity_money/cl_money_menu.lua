--[[
    ZCityMoney.Menu
    Интеграция с круговым меню (C-меню) через функцию AddPlayerAction.
    Предоставляет интерфейс для перевода денег.
]]

local function GetBalance(ply)
    return ply:GetNWInt("ZCityMoney", ZCityMoney.Config.STARTING_MONEY)
end

-- Функция для создания Derma-окна перевода
local function OpenTransferMenu(targetPly)
    if not IsValid(targetPly) then return end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Перевод денег: " .. targetPly:Nick())
    frame:SetSize(300, 150)
    frame:Center()
    frame:MakePopup()

    local myBalance = GetBalance(LocalPlayer())
    local balanceLabel = vgui.Create("DLabel", frame)
    balanceLabel:SetPos(10, 40)
    balanceLabel:SetText("Ваш баланс: " .. ZCityMoney.Config.CURRENCY_SYMBOL .. myBalance)
    balanceLabel:SizeToContents()

    local amountEntry = vgui.Create("DTextEntry", frame)
    amountEntry:SetPos(10, 70)
    amountEntry:SetSize(280, 25)
    amountEntry:SetPlaceholderText("Введите сумму")
    amountEntry:SetNumeric(true)

    local transferBtn = vgui.Create("DButton", frame)
    transferBtn:SetPos(10, 105)
    transferBtn:SetSize(280, 25)
    transferBtn:SetText("Перевести")

    transferBtn.DoClick = function()
        local amount = tonumber(amountEntry:GetValue())
        if not amount or amount <= 0 then
            Derma_Message("Введите корректную сумму", "Ошибка", "OK")
            return
        end

        -- Отправляем запрос на сервер
        net.Start("ZCityMoney_RequestTransfer")
        net.WriteString(targetPly:SteamID64())
        net.WriteInt(amount, 32)
        net.SendToServer()

        frame:Close()
    end

    -- Отмена по ESC
    frame.OnKeyCodePressed = function(_, code)
        if code == KEY_ESCAPE then
            frame:Close()
        end
    end
end

-- Добавляем пункт в круговое меню (появляется при нажатии C на игроке)
hook.Add("AddPlayerAction", "ZCityMoney_MenuActions", function(ply, actions)
    -- "Перевести деньги"
    actions:AddAction("💰 Перевести деньги", function()
        OpenTransferMenu(ply)
    end, ZCityMoney.Config.MENU_ICON)

    -- "Проверить баланс" (показывает баланс игрока в чат)
    actions:AddAction("💳 Баланс", function()
        local balance = GetBalance(ply)
        chat.AddText(Color(0, 200, 200), "[Баланс] ", Color(255, 255, 255), ply:Nick(), ": ", Color(0, 255, 0), ZCityMoney.Config.CURRENCY_SYMBOL .. balance)
    end, "icon16/coins.png")
end)