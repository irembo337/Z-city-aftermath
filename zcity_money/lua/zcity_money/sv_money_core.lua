--[[
    ZCityMoney.Core
    Бизнес-логика системы денег. Обрабатывает переводы, проверки, безопасность.
]]

ZCityMoney.Core = ZCityMoney.Core or {}
local Core = ZCityMoney.Core

-- Хранилище балансов в памяти для быстрого доступа (кэш)
Core.PlayerMoneyCache = Core.PlayerMoneyCache or {}

-- Загружает баланс игрока в кэш (вызывается при входе)
function Core.LoadPlayer(ply)
    if not IsValid(ply) then return false end
    local steamid64 = ply:SteamID64()
    local money = ZCityMoney.Database.LoadPlayerMoney(steamid64)
    Core.PlayerMoneyCache[steamid64] = money
    ply:SetNWInt("ZCityMoney", money)
    return true
end

-- Сохраняет баланс игрока из кэша в БД
function Core.SavePlayer(ply)
    if not IsValid(ply) then return false end
    local steamid64 = ply:SteamID64()
    local money = Core.PlayerMoneyCache[steamid64] or ZCityMoney.Config.STARTING_MONEY
    return ZCityMoney.Database.SavePlayerMoney(steamid64, money)
end

-- Получить текущий баланс игрока (из кэша)
function Core.GetMoney(ply)
    if not IsValid(ply) then return 0 end
    local steamid64 = ply:SteamID64()
    return Core.PlayerMoneyCache[steamid64] or ZCityMoney.Config.STARTING_MONEY
end

-- Установить баланс игрока (админ-функция, проверка прав в сетевом слое)
function Core.SetMoney(ply, amount)
    if not IsValid(ply) then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 0 then amount = 0 end

    local steamid64 = ply:SteamID64()
    Core.PlayerMoneyCache[steamid64] = amount
    ply:SetNWInt("ZCityMoney", amount)
    Core.SavePlayer(ply)
    return true
end

-- Добавить деньги игроку (например, зарплата)
function Core.AddMoney(ply, amount)
    if not IsValid(ply) then return false end
    local current = Core.GetMoney(ply)
    local newAmount = current + math.floor(amount)
    return Core.SetMoney(ply, newAmount)
end

-- Основная функция перевода денег от одного игрока другому
function Core.TransferMoney(fromPly, toPly, amount)
    -- Проверка валидности
    if not IsValid(fromPly) or not IsValid(toPly) then
        return false, "Неверный отправитель или получатель"
    end
    if fromPly == toPly then
        return false, "Нельзя перевести деньги самому себе"
    end
    amount = math.floor(tonumber(amount) or 0)
    if amount < ZCityMoney.Config.MIN_TRANSFER_AMOUNT then
        return false, "Сумма слишком мала"
    end
    if amount > ZCityMoney.Config.MAX_TRANSFER_AMOUNT then
        return false, "Сумма превышает лимит"
    end

    local fromMoney = Core.GetMoney(fromPly)
    if fromMoney < amount then
        return false, "Недостаточно средств"
    end

    -- Атомарная операция (в рамках одного тика)
    Core.SetMoney(fromPly, fromMoney - amount)
    Core.AddMoney(toPly, amount)

    -- Логирование
    if ZCityMoney.Config.LOG_ENABLED then
        local msg = string.format("[ПЕРЕВОД] %s (%s) -> %s (%s): %d %s",
            fromPly:Nick(), fromPly:SteamID64(),
            toPly:Nick(), toPly:SteamID64(),
            amount, ZCityMoney.Config.CURRENCY_SYMBOL)
        print(msg)
        -- Здесь можно добавить запись в файл, если LOG_FILE_ENABLED = true
    end

    return true, "Перевод выполнен успешно"
end

-- Сохранить всех игроков (вызывается при ShutDown)
function Core.SaveAllPlayers()
    for _, ply in ipairs(player.GetAll()) do
        Core.SavePlayer(ply)
    end
    if ZCityMoney.Config.LOG_ENABLED then
        print("[ZCity-Money] Сохранены данные всех игроков.")
    end
end

-- Загрузить всех текущих игроков (вызывается при старте)
function Core.LoadAllPlayers()
    for _, ply in ipairs(player.GetAll()) do
        Core.LoadPlayer(ply)
    end
end

-- Хук при первом спавне игрока
hook.Add("PlayerInitialSpawn", "ZCityMoney_PlayerJoin", function(ply)
    Core.LoadPlayer(ply)
end)

-- Хук при отключении игрока
hook.Add("PlayerDisconnected", "ZCityMoney_PlayerLeave", function(ply)
    Core.SavePlayer(ply)
    local steamid64 = ply:SteamID64()
    Core.PlayerMoneyCache[steamid64] = nil -- очистка кэша
end)