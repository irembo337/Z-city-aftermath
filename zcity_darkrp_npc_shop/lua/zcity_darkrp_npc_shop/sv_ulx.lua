ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.ULX = ZCityDarkRPShop.ULX or {}

local ULXBridge = ZCityDarkRPShop.ULX
local Core = ZCityDarkRPShop.Core

local registered = false

util.AddNetworkString("ZCityAftermath.AdminAddMoney")
util.AddNetworkString("ZCityAftermath.AdminSetMoney")

local function resolveIdentityTarget(identity)
    local query = string.Trim(tostring(identity or ""))
    if query == "" then
        return nil
    end

    local lowered = string.lower(query)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            if ply:SteamID64() == query then
                return ply
            end

            if string.lower(ply:SteamID() or "") == lowered then
                return ply
            end

            if string.find(string.lower(ply:Nick() or ""), lowered, 1, true) then
                return ply
            end
        end
    end
end

local function ensureMoneyAPIs(target)
    return IsValid(target) and target.addMoney ~= nil
end

local function addMoneyToTarget(target, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return false, "Amount must be greater than zero."
    end

    if not ensureMoneyAPIs(target) then
        return false, "DarkRP money API is not available for this player."
    end

    target:addMoney(amount)
    return true, amount
end

local function setMoneyForTarget(target, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if not ensureMoneyAPIs(target) then
        return false, "DarkRP money API is not available for this player."
    end

    local current = Core.GetBalance(target)
    target:addMoney(amount - current)
    return true, amount
end

local function canUseMoneyAdmin(ply)
    return IsValid(ply) and ply:IsPlayer() and ply:IsSuperAdmin()
end

local function logMoneyAction(callingPly, actionText, target, amount)
    local formatted = Core and Core.FormatMoney and Core.FormatMoney(amount) or ("$" .. tostring(amount))
    ulx.fancyLogAdmin(callingPly, "#A " .. actionText .. " #T by #s", target, formatted)
end

local function registerULXCommands()
    if registered or not ulx or not ULib or not ULib.cmds then
        return
    end

    registered = true

    function ulx.zcityaddmoney(callingPly, target, amount)
        local success, result = addMoneyToTarget(target, amount)
        if not success then
            ULib.tsayError(callingPly, result, true)
            return
        end

        logMoneyAction(callingPly, "added money to", target, result)
    end

    local addMoneyCmd = ulx.command("Z-City Aftermath", "ulx zcityaddmoney", ulx.zcityaddmoney, "!zcityaddmoney")
    addMoneyCmd:addParam{ type = ULib.cmds.PlayerArg }
    addMoneyCmd:addParam{ type = ULib.cmds.NumArg, min = 1, hint = "amount" }
    addMoneyCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    addMoneyCmd:help("Add DarkRP money to an online player.")

    function ulx.zcitysetmoney(callingPly, target, amount)
        local success, result = setMoneyForTarget(target, amount)
        if not success then
            ULib.tsayError(callingPly, result, true)
            return
        end

        local formatted = Core and Core.FormatMoney and Core.FormatMoney(result) or ("$" .. tostring(result))
        ulx.fancyLogAdmin(callingPly, "#A set #T money to #s", target, formatted)
    end

    local setMoneyCmd = ulx.command("Z-City Aftermath", "ulx zcitysetmoney", ulx.zcitysetmoney, "!zcitysetmoney")
    setMoneyCmd:addParam{ type = ULib.cmds.PlayerArg }
    setMoneyCmd:addParam{ type = ULib.cmds.NumArg, min = 0, hint = "amount" }
    setMoneyCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    setMoneyCmd:help("Set DarkRP money for an online player.")

    function ulx.zcityaddmoneyid(callingPly, identity, amount)
        local target = resolveIdentityTarget(identity)
        if not IsValid(target) then
            ULib.tsayError(callingPly, "Player not found by nick or SteamID64. The target must be online.", true)
            return
        end

        ulx.zcityaddmoney(callingPly, target, amount)
    end

    local addMoneyIdCmd = ulx.command("Z-City Aftermath", "ulx zcityaddmoneyid", ulx.zcityaddmoneyid, "!zcityaddmoneyid")
    addMoneyIdCmd:addParam{ type = ULib.cmds.StringArg, hint = "nick or SteamID64" }
    addMoneyIdCmd:addParam{ type = ULib.cmds.NumArg, min = 1, hint = "amount" }
    addMoneyIdCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    addMoneyIdCmd:help("Add DarkRP money using a partial nick or SteamID64 for an online player.")

    function ulx.zcitysetmoneyid(callingPly, identity, amount)
        local target = resolveIdentityTarget(identity)
        if not IsValid(target) then
            ULib.tsayError(callingPly, "Player not found by nick or SteamID64. The target must be online.", true)
            return
        end

        ulx.zcitysetmoney(callingPly, target, amount)
    end

    local setMoneyIdCmd = ulx.command("Z-City Aftermath", "ulx zcitysetmoneyid", ulx.zcitysetmoneyid, "!zcitysetmoneyid")
    setMoneyIdCmd:addParam{ type = ULib.cmds.StringArg, hint = "nick or SteamID64" }
    setMoneyIdCmd:addParam{ type = ULib.cmds.NumArg, min = 0, hint = "amount" }
    setMoneyIdCmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
    setMoneyIdCmd:help("Set DarkRP money using a partial nick or SteamID64 for an online player.")
end

timer.Simple(0, registerULXCommands)
hook.Add("Initialize", "ZCityAftermath.RegisterULXMoneyCommands", registerULXCommands)
hook.Add("InitPostEntity", "ZCityAftermath.RegisterULXMoneyCommandsLate", registerULXCommands)

local function handleAdminMoneyRequest(ply, setter)
    if not canUseMoneyAdmin(ply) then
        if ULib and ULib.tsayError then
            ULib.tsayError(ply, "Only superadmin can use the money admin panel.", true)
        end
        return
    end

    local identity = net.ReadString()
    local amount = tonumber(net.ReadInt(32)) or 0
    local target = resolveIdentityTarget(identity)

    if not IsValid(target) then
        if ULib and ULib.tsayError then
            ULib.tsayError(ply, "Player not found by nick or SteamID64. The target must be online.", true)
        end
        return
    end

    if setter then
        ulx.zcitysetmoney(ply, target, amount)
    else
        ulx.zcityaddmoney(ply, target, amount)
    end
end

net.Receive("ZCityAftermath.AdminAddMoney", function(_, ply)
    handleAdminMoneyRequest(ply, false)
end)

net.Receive("ZCityAftermath.AdminSetMoney", function(_, ply)
    handleAdminMoneyRequest(ply, true)
end)
