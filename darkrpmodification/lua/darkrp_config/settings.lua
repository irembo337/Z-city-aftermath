GM = GM or GAMEMODE
GM.Config = GM.Config or {}

-- Keep vehicle spawning available in DarkRP and remove restrictive prop/property blacklists.
GM.Config.allowvehicleowning = true
GM.Config.adminvehicles = false
GM.Config.propspawning = true
GM.Config.PocketBlacklist = {}
GM.Config.allowedProperties = {
    remover = true,
    ignite = true,
    extinguish = true,
    keepupright = true,
    gravity = true,
    collision = true,
    skin = true,
    bodygroups = true
}
