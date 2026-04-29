ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Cameras = ZCityDarkRPShop.Cameras or {}

local Cameras = ZCityDarkRPShop.Cameras
local Config = ZCityDarkRPShop.Config or {}

local function validModel(model)
    model = string.Trim(tostring(model or ""))
    if model == "" or string.lower(model) == "models/error.mdl" then
        return false
    end

    return util.IsValidModel(model)
end

function Cameras.ResolveFirstValidModel(candidates, fallback)
    for _, model in ipairs(candidates or {}) do
        if validModel(model) then
            return model
        end
    end

    if validModel(fallback) then
        return fallback
    end

    return "models/items/boxmrounds.mdl"
end

function Cameras.GetTabletWorldModel()
    return Cameras.ResolveFirstValidModel({
        Config.CameraTabletWorldModel,
        "models/slusher/tablet/w_tablet.mdl"
    }, "models/weapons/w_pistol.mdl")
end

function Cameras.GetTabletViewModel()
    return Cameras.ResolveFirstValidModel({
        Config.CameraTabletViewModel,
        "models/slusher/tablet/c_tablet.mdl",
        Config.CameraTabletWorldModel
    }, Cameras.GetTabletWorldModel())
end

function Cameras.GetCameraModel()
    local candidates = {}

    for _, model in ipairs(Config.CameraFallbackModels or {}) do
        candidates[#candidates + 1] = model
    end

    candidates[#candidates + 1] = Cameras.GetTabletWorldModel()

    return Cameras.ResolveFirstValidModel(candidates, Cameras.GetTabletWorldModel())
end

function Cameras.IsCameraItemClass(className)
    return string.Trim(tostring(className or "")) == string.Trim(tostring(Config.CameraKitClass or "zcity_camera_kit"))
end

function Cameras.IsTabletWeapon(className)
    return string.Trim(tostring(className or "")) == string.Trim(tostring(Config.CameraTabletWeapon or "weapon_zcity_camera_tablet"))
end

function Cameras.IsTabletPickupClass(className)
    return string.Trim(tostring(className or "")) == string.Trim(tostring(Config.CameraTabletPickupClass or "zcity_camera_tablet_pickup"))
end

function Cameras.IsAttachmentTokenClass(className)
    return string.Trim(tostring(className or "")) == string.Trim(tostring(Config.AttachmentTokenClass or "zcity_attachment_token"))
end

function Cameras.FormatName(index)
    index = math.max(1, math.floor(tonumber(index) or 1))
    return string.format("Camera #%d", index)
end
