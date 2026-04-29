if SERVER then
    AddCSLuaFile()
end

local categoryName = "ZCity Other"

if ZCityDarkRPShop and ZCityDarkRPShop.Config and ZCityDarkRPShop.Config.SpawnMenuCategoryName then
    categoryName = tostring(ZCityDarkRPShop.Config.SpawnMenuCategoryName)
end

list.Set("ContentCategoryIcons", categoryName, "icon16/camera.png")

local function registerEntity(className, printName, model)
    list.Set("SpawnableEntities", className, {
        PrintName = printName,
        ClassName = className,
        Category = categoryName,
        NormalOffset = 24,
        DropToFloor = true,
        Author = "Codex",
        AdminOnly = false,
        Model = model
    })
end

local function registerWeaponEntry(className, printName, model, scriptedType)
    list.Set("Weapon", className, {
        ClassName = className,
        PrintName = printName,
        Category = categoryName,
        Spawnable = true,
        AdminOnly = false,
        WorldModel = model,
        ScriptedEntityType = scriptedType
    })
end

registerEntity("zcity_camera_kit", "Security Camera", "models/props_combine/combinecamera001.mdl")
registerEntity("zcity_camera_tablet_pickup", "Camera Tablet", "models/slusher/tablet/w_tablet.mdl")
registerWeaponEntry("zcity_camera_kit", "Security Camera", "models/props_combine/combinecamera001.mdl", "entity")
registerWeaponEntry("weapon_zcity_camera_tablet", "Camera Tablet", "models/slusher/tablet/w_tablet.mdl", "weapon")
