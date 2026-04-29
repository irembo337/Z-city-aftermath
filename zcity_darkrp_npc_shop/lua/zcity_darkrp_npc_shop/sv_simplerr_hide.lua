local function removeSimplerrNotifier()
    hook.Remove("onSimplerrError", "DarkRP_Simplerr")
end

timer.Simple(0, removeSimplerrNotifier)
hook.Add("Initialize", "ZCityAftermath.HideSimplerrNotifier", removeSimplerrNotifier)
hook.Add("InitPostEntity", "ZCityAftermath.HideSimplerrNotifierLate", removeSimplerrNotifier)
