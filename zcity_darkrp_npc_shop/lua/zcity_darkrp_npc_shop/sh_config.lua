ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Config = ZCityDarkRPShop.Config or {}

local Config = ZCityDarkRPShop.Config

Config.DataDir = "zcity_darkrp_shop"
Config.ItemsFile = Config.DataDir .. "/items.json"
Config.SettingsFile = Config.DataDir .. "/settings.json"
Config.JobsFile = Config.DataDir .. "/jobs.json"
Config.NPCDir = Config.DataDir .. "/npcs"
Config.SpawnDir = Config.DataDir .. "/spawns"
Config.SafeZoneDir = Config.DataDir .. "/safezones"
Config.DoorDir = Config.DataDir .. "/doors"
Config.MaxItems = 256
Config.MaxJobs = 128
Config.MaxSpawns = 64
Config.MaxSafeZones = 64
Config.MaxBackpackItems = 16
Config.AutoRespawnDelay = 5
Config.DefaultSafeZoneRadius = 360
Config.DefaultDoorPrice = 500

Config.MenuCommand = ""
Config.AdminHubCommand = "zcity_admin_menu"
Config.AdminMenuCommand = "zcity_darkrp_shop_admin"
Config.SpawnNPCCommand = "zcity_darkrp_shop_spawn_npc"
Config.RemoveNPCCommand = "zcity_darkrp_shop_remove_npc"
Config.RemoveAllNPCsCommand = "zcity_darkrp_shop_remove_all_npcs"
Config.ReloadNPCCommand = "zcity_darkrp_shop_reload_npcs"
Config.JobMenuCommand = "zcity_darkrp_jobs"
Config.JobAdminCommand = "zcity_darkrp_jobs_admin"
Config.JobSpawnPickerCommand = "zcity_job_spawn_picker"
Config.SpawnMenuCommand = "zcity_spawn_menu"
Config.SpawnAddCommand = "zcity_spawn_add"
Config.SpawnRemoveNearestCommand = "zcity_spawn_remove_nearest"
Config.SpawnClearCommand = "zcity_spawn_clear"
Config.SafeZoneMenuCommand = "zcity_safezone_menu"
Config.SafeZoneAddCommand = "zcity_safezone_add"
Config.SafeZoneRemoveNearestCommand = "zcity_safezone_remove_nearest"
Config.SafeZoneClearCommand = "zcity_safezone_clear"
Config.DoorBuyCommand = "zcity_door_buy"
Config.DoorSellCommand = "zcity_door_sell"
Config.DoorLockCommand = "zcity_door_lock"
Config.DoorUnlockCommand = "zcity_door_unlock"
Config.DoorMenuCommand = "zcity_door_menu"
Config.DoorAdminMenuCommand = "zcity_door_admin"
Config.DoorSetPriceCommand = "zcity_door_set_price"
Config.DoorClearCommand = "zcity_door_clear"
Config.BackpackCommand = "zcity_backpack"
Config.BackpackPutCommand = "zcity_backpack_put"
Config.CameraMenuCommand = "zcity_camera_tablet"
Config.CameraKitClass = "zcity_camera_kit"
Config.CameraEntityClass = "zcity_security_camera"
Config.CameraTabletWeapon = "weapon_zcity_camera_tablet"
Config.CameraTabletPickupClass = "zcity_camera_tablet_pickup"
Config.AttachmentTokenClass = "zcity_attachment_token"
Config.GiveCameraTabletCommand = "zcity_give_camera_tablet"
Config.SpawnCameraKitCommand = "zcity_spawn_camera_kit"
Config.SpawnMenuCategoryName = "ZCity Other"
Config.CameraMaxPerPlayer = 6
Config.CameraTabletWorldModel = "models/slusher/tablet/w_tablet.mdl"
Config.CameraTabletViewModel = "models/slusher/tablet/c_tablet.mdl"
Config.CameraFallbackModels = {
    "models/props_combine/combinecamera001.mdl",
    "models/props_lab/securitycamera.mdl"
}

Config.NPCClass = "zcity_darkrp_shop_npc"
Config.NPCModel = "models/Humans/Group01/male_07.mdl"
Config.NPCName = "Gun Dealer"
Config.NPCUseDistance = 160
Config.DefaultJobModel = "models/player/Group01/male_07.mdl"

Config.ChatCommands = {
    ["!shopadmin"] = "admin",
    ["/shopadmin"] = "admin",
    ["!jobs"] = "jobs",
    ["/jobs"] = "jobs",
    ["!jobmenu"] = "jobs",
    ["/jobmenu"] = "jobs",
    ["!jobsadmin"] = "jobs_admin",
    ["/jobsadmin"] = "jobs_admin",
    ["!jobeditor"] = "jobs_admin",
    ["/jobeditor"] = "jobs_admin"
}

Config.AllowedULXGroups = {
    admin = true,
    superadmin = true
}

Config.DefaultSettings = {
    npcName = Config.NPCName
}

Config.ItemCategories = {
    weapon = "Weapon",
    armor = "Armor",
    ammo = "Ammo",
    attachment = "Attachment",
    misc = "Misc"
}

Config.DefaultItems = {
    {
        id = "weapon_crowbar",
        name = "Crowbar",
        class = "weapon_crowbar",
        kind = "weapon",
        category = "weapon",
        price = 100
    },
    {
        id = "weapon_pistol",
        name = "Pistol",
        class = "weapon_pistol",
        kind = "weapon",
        category = "weapon",
        price = 250
    },
    {
        id = "weapon_shotgun",
        name = "Shotgun",
        class = "weapon_shotgun",
        kind = "weapon",
        category = "weapon",
        price = 700
    },
    {
        id = "item_healthkit",
        name = "Health Kit",
        class = "item_healthkit",
        kind = "entity",
        category = "misc",
        price = 175
    },
    {
        id = "item_zcity_camera_kit",
        name = "Security Camera",
        class = Config.CameraKitClass,
        kind = "entity",
        category = "misc",
        model = "models/props_combine/combinecamera001.mdl",
        price = 1500
    },
    {
        id = "weapon_zcity_camera_tablet",
        name = "Camera Tablet",
        class = Config.CameraTabletWeapon,
        kind = "weapon",
        category = "misc",
        model = Config.CameraTabletWorldModel,
        price = 900
    }
}

Config.RequiredItems = {
    {
        id = "item_zcity_camera_kit",
        name = "Security Camera",
        class = Config.CameraKitClass,
        kind = "entity",
        category = "misc",
        model = "models/props_combine/combinecamera001.mdl",
        price = 1500
    },
    {
        id = "weapon_zcity_camera_tablet",
        name = "Camera Tablet",
        class = Config.CameraTabletWeapon,
        kind = "weapon",
        category = "misc",
        model = Config.CameraTabletWorldModel,
        price = 900
    }
}

Config.DefaultJobs = {
    {
        id = "citizen",
        name = "Гражданский",
        description = "Базовая работа для мирных жителей Z-City.",
        command = "citizen",
        category = "Гражданские",
        models = { Config.DefaultJobModel },
        weapons = { "keys" },
        ammo = {},
        attachments = {},
        armor = 0,
        armorClass = "",
        salary = 45,
        max = 0,
        admin = 0,
        vote = false,
        hasLicense = false,
        candemote = true,
        canDemoteOthers = false,
        spawn = nil,
        color = {
            r = 45,
            g = 120,
            b = 70,
            a = 255
        }
    }
}
