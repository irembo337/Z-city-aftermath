local hiddenDarkRPHud = {
    DarkRP_HUD = true,
    DarkRP_EntityDisplay = true,
    DarkRP_ZombieInfo = true,
    DarkRP_LocalPlayerHUD = true,
    DarkRP_Hungermod = true,
    DarkRP_Agenda = true,
    DarkRP_LockdownHUD = true,
    DarkRP_ArrestedHUD = true,
    DarkRP_ChatReceivers = true
}

hook.Add("HUDShouldDraw", "ZCityAftermath.HideDarkRPHud", function(name)
    if hiddenDarkRPHud[name] then
        return false
    end
end)
