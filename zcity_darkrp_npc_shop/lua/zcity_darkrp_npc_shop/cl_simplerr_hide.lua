hook.Remove("onSimplerrError", "DarkRP_Simplerr")

net.Receive("DarkRP_simplerrError", function()
    -- Intentionally swallow DarkRP simplerr UI notifications.
end)

timer.Simple(0, function()
    hook.Remove("onSimplerrError", "DarkRP_Simplerr")
end)

hook.Add("InitPostEntity", "ZCityAftermath.HideSimplerrUI", function()
    hook.Remove("onSimplerrError", "DarkRP_Simplerr")
end)
