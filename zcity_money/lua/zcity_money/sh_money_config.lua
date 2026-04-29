--[[
    ZCityMoney.Config
    Централизованная конфигурация системы. Изменяйте значения здесь.
]]

ZCityMoney = ZCityMoney or {}
ZCityMoney.Config = ZCityMoney.Config or {}

-- Настройки баланса
ZCityMoney.Config.STARTING_MONEY = 500               -- Стартовый баланс
ZCityMoney.Config.CURRENCY_SYMBOL = "₽"              -- Символ валюты (рубль)
ZCityMoney.Config.MIN_TRANSFER_AMOUNT = 1            -- Мин. сумма перевода
ZCityMoney.Config.MAX_TRANSFER_AMOUNT = 1000000      -- Макс. сумма перевода (анти-дуп)

-- Настройки логирования
ZCityMoney.Config.LOG_ENABLED = true                 -- Включить логирование в консоль
ZCityMoney.Config.LOG_FILE_ENABLED = false           -- Запись логов в файл (опционально)

-- Настройки БД
ZCityMoney.Config.DB_FILE = "zcity_money"            -- Имя БД SQLite (файл sv.db)

-- Настройки кругового меню
ZCityMoney.Config.MENU_CATEGORY = "Z-City Финансы"   -- Категория в C-меню
ZCityMoney.Config.MENU_ICON = "icon16/money.png"     -- Иконка для пунктов меню