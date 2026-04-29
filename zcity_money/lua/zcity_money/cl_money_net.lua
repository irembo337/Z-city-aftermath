--[[
    ZCityMoney.Network (Client)
    Получение данных от сервера, обновление локального баланса.
]]

-- Прием обновления баланса от сервера
net.Receive("ZCityMoney_UpdateBalance", function(len)
    local newBalance = net.ReadInt(32)
    LocalPlayer():SetNWInt("ZCityMoney", newBalance)
    -- Дополнительно можно обновить HUD
    chat.AddText(Color(0, 255, 0), "[Z-City] Ваш баланс обновлен: ", Color(255, 255, 255), ZCityMoney.Config.CURRENCY_SYMBOL .. newBalance)
end)

-- Прием результата перевода
net.Receive("ZCityMoney_TransferResult", function(len)
    local success = net.ReadBool()
    local message = net.ReadString()

    if success then
        chat.AddText(Color(0, 255, 0), "[Z-City] ", Color(255, 255, 255), message)
    else
        chat.AddText(Color(255, 0, 0), "[Z-City] Ошибка: ", Color(255, 255, 255), message)
    end
end)