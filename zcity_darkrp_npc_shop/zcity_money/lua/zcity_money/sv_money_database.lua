--[[
    ZCityMoney.Database
    Уровень доступа к данным (Data Access Layer). Работает с SQLite.
    Соблюдает принцип единственной ответственности (SOLID).
]]

ZCityMoney.Database = ZCityMoney.Database or {}
local DB = ZCityMoney.Database

-- Инициализация БД: создает таблицу, если её нет
function DB.Initialize()
    if not sql.TableExists("zcity_money") then
        local query = [[
            CREATE TABLE zcity_money (
                steamid64 TEXT PRIMARY KEY,
                money INTEGER NOT NULL DEFAULT ]] .. ZCityMoney.Config.STARTING_MONEY .. [[
            );
        ]]
        local result = sql.Query(query)
        if result == false then
            ErrorNoHalt("[ZCity-Money] Ошибка создания таблицы: " .. sql.LastError() .. "\n")
            return false
        end
        if ZCityMoney.Config.LOG_ENABLED then
            print("[ZCity-Money] Таблица 'zcity_money' создана.")
        end
    end
    return true
end

-- Загружает баланс игрока по SteamID64
function DB.LoadPlayerMoney(steamid64)
    if not steamid64 or steamid64 == "" then return ZCityMoney.Config.STARTING_MONEY end

    local query = "SELECT money FROM zcity_money WHERE steamid64 = " .. sql.SQLStr(steamid64)
    local result = sql.Query(query)

    if result and result[1] then
        local money = tonumber(result[1].money) or ZCityMoney.Config.STARTING_MONEY
        if ZCityMoney.Config.LOG_ENABLED then
            print("[ZCity-Money] Баланс загружен для " .. steamid64 .. ": " .. money)
        end
        return money
    else
        -- Игрок не найден, создаем запись со стартовым балансом
        DB.SavePlayerMoney(steamid64, ZCityMoney.Config.STARTING_MONEY)
        return ZCityMoney.Config.STARTING_MONEY
    end
end

-- Сохраняет баланс игрока
function DB.SavePlayerMoney(steamid64, amount)
    if not steamid64 or steamid64 == "" then return false end
    amount = math.floor(tonumber(amount) or 0)

    -- UPSERT: вставить или обновить
    local query = [[
        INSERT OR REPLACE INTO zcity_money (steamid64, money)
        VALUES (]] .. sql.SQLStr(steamid64) .. ", " .. amount .. [[);
    ]]
    local result = sql.Query(query)

    if result == false then
        ErrorNoHalt("[ZCity-Money] Ошибка сохранения баланса для " .. steamid64 .. ": " .. sql.LastError() .. "\n")
        return false
    end

    if ZCityMoney.Config.LOG_ENABLED then
        print("[ZCity-Money] Баланс сохранен для " .. steamid64 .. ": " .. amount)
    end
    return true
end

-- Получает общее количество денег в системе (для отладки)
function DB.GetTotalMoney()
    local query = "SELECT SUM(money) as total FROM zcity_money"
    local result = sql.Query(query)
    if result and result[1] then
        return tonumber(result[1].total) or 0
    end
    return 0
end