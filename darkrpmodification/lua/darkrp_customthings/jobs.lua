--[[---------------------------------------------------------------------------
DarkRP custom jobs
---------------------------------------------------------------------------
This file contains your custom jobs.
This file should also contain jobs from DarkRP that you edited.

Note: If you want to edit a default DarkRP job, first disable it in darkrp_config/disabled_defaults.lua
      Once you've done that, copy and paste the job to this file and edit it.

The default jobs can be found here:
https://github.com/FPtje/DarkRP/blob/master/gamemode/config/jobrelated.lua

For examples and explanation please visit this wiki page:
https://darkrp.miraheze.org/wiki/DarkRP:CustomJobFields

Add your custom jobs under the following line:
---------------------------------------------------------------------------]]



--[[---------------------------------------------------------------------------
Define which team joining players spawn into and what team you change to if demoted
---------------------------------------------------------------------------]]
GAMEMODE.DefaultTeam = TEAM_CITIZEN
--[[---------------------------------------------------------------------------
Define which teams belong to civil protection
Civil protection can set warrants, make people wanted and do some other police related things
---------------------------------------------------------------------------]]
GAMEMODE.CivilProtection = {
    [TEAM_POLICE] = true,
    [TEAM_CHIEF] = true,
    [TEAM_MAYOR] = true,
}
--[[---------------------------------------------------------------------------
Jobs that are hitmen (enables the hitman menu)
---------------------------------------------------------------------------]]
DarkRP.addHitmanTeam(TEAM_MOB)

local function ZCityAftermathRegisterPersistedJobs()
    if not ZCityDarkRPShop or not ZCityDarkRPShop.JobRuntime or not ZCityDarkRPShop.JobRuntime.RegisterPersistedJobs then
        return false
    end

    ZCityDarkRPShop.JobRuntime.RegisterPersistedJobs()
    return true
end

if SERVER and not ZCityAftermathRegisterPersistedJobs() then
    hook.Add("InitPostEntity", "ZCityAftermath.DarkRPJobsBridge", function()
        if ZCityAftermathRegisterPersistedJobs() then
            hook.Remove("InitPostEntity", "ZCityAftermath.DarkRPJobsBridge")
        end
    end)
end
