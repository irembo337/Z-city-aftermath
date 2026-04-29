--[[
    ZCityMoney.Network (Server)
    Обработка сетевых сообщений. Проверка безопасности, валидация, вызов Core.
]]

util.AddNetworkString("ZCityMoney_RequestTransfer")
util.AddNetworkString("ZCityMoney_TransferResult")
util.AddNetworkString("ZCityMoney_UpdateBalance")

-- Получение запроса на перевод от клиента
net.Receive("ZCityMoney_RequestTransfer", function(len, ply)
    -- Защита от спама/взлома: проверяем, что игрок валиден
    if not IsValid(ply) then return end

    -- Читаем данные
    local targetSteamID = net.ReadString()
    local amount = net.ReadInt(32)

    -- Поиск цели по SteamID64
    local targetPly = player.GetBySteamID64(targetSteamID)
    if not IsValid(targetPly) then
        net.Start("ZCityMoney_TransferResult")
        net.WriteBool(false)
        net.WriteString("Игрок не найден или вышел из игры")
        net.Send(ply)
        return
    end

    -- Вызов бизнес-логики
    local success, message = ZCityMoney.Core.TransferMoney(ply, targetPly, amount)

    -- Отправка результата отправителю
    net.Start("ZCityMoney_TransferResult")
    net.WriteBool(success)
    net.WriteString(message)
    net.Send(ply)

    -- Если успешно, обновить баланс у обоих участников
    if success then
        -- Отправителю
        net.Start("ZCityMoney_UpdateBalance")
        net.WriteInt(ZCityMoney.Core.GetMoney(ply), 32)
        net.Send(ply)

        -- Получателю
        net.Start("ZCityMoney_UpdateBalance")
        net.WriteInt(ZCityMoney.Core.GetMoney(targetPly), 32)
        net.Send(targetPly)
    end
end)

-- Админская команда для выдачи денег (опционально)
concommand.Add("zcity_money_give", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then
        print("Требуются права администратора.")
        return
    end

    local target = args[1]
    local amount = tonumber(args[2])

    if not target or not amount then
        print("Использование: zcity_money_give <steamid/name> <amount>")
        return
    end

    local targetPly = player.GetBySteamID(target) or player.GetByName(target)
    if not IsValid(targetPly) then
        print("Игрок не найден.")
        return
    end

    ZCityMoney.Core.AddMoney(targetPly, amount)
    print("Выдано " .. amount .. " игроку " .. targetPly:Nick())
end)