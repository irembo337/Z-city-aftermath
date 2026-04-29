ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Cameras = ZCityDarkRPShop.Cameras or {}

local Cameras = ZCityDarkRPShop.Cameras
local Config = ZCityDarkRPShop.Config
local Net = ZCityDarkRPShop.Net

util.AddNetworkString("ZCityAftermath.CameraRequestList")
util.AddNetworkString("ZCityAftermath.CameraList")
util.AddNetworkString("ZCityAftermath.CameraRequestView")
util.AddNetworkString("ZCityAftermath.CameraSetView")
util.AddNetworkString("ZCityAftermath.CameraClearView")
util.AddNetworkString("ZCityAftermath.CameraRemove")

local function notifyPlayer(ply, success, message)
    if not IsValid(ply) then return end

    if Net and Net.Notify then
        Net.Notify(ply, success, message)
    elseif DarkRP and DarkRP.notify then
        DarkRP.notify(ply, success and 0 or 1, 4, message or "")
    else
        ply:ChatPrint(message or "")
    end
end

local function canUseCameraUtilities(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        return false
    end

    if ply:IsAdmin() or ply:IsSuperAdmin() then
        return true
    end

    local group = string.lower((ply.GetUserGroup and ply:GetUserGroup()) or "")
    return group == "admin" or group == "superadmin"
end

local function ownerKey(ply)
    if not IsValid(ply) then
        return ""
    end

    local key = string.Trim(tostring(ply:SteamID64() or ""))
    if key ~= "" and key ~= "0" then
        return key
    end

    return string.Trim(tostring(ply:SteamID() or ""))
end

local function computeCameraPlacement(trace, ply)
    local hitNormal = IsValid(ply) and trace and trace.HitNormal or vector_up
    if not isvector(hitNormal) or hitNormal:LengthSqr() <= 0.0001 then
        hitNormal = vector_up
    end

    local feedAngles = IsValid(ply) and ply:EyeAngles() or Angle(0, 0, 0)
    feedAngles = Angle(feedAngles.p, feedAngles.y, 0)

    local facingDirection = -hitNormal
    local modelAngles = facingDirection:Angle()

    return modelAngles, feedAngles
end

function Cameras.PlayerOwnsCamera(ply, ent)
    return IsValid(ply)
        and IsValid(ent)
        and ent:GetClass() == Config.CameraEntityClass
        and string.Trim(tostring(ent.ZCityCameraOwnerKey or "")) == ownerKey(ply)
end

function Cameras.GetOwnedCameras(ply)
    local owned = {}
    local key = ownerKey(ply)
    if key == "" then
        return owned
    end

    for _, ent in ipairs(ents.FindByClass(Config.CameraEntityClass)) do
        if IsValid(ent) and string.Trim(tostring(ent.ZCityCameraOwnerKey or "")) == key then
            owned[#owned + 1] = ent
        end
    end

    table.sort(owned, function(left, right)
        return left:EntIndex() < right:EntIndex()
    end)

    return owned
end

function Cameras.RefreshNames(ply)
    for index, ent in ipairs(Cameras.GetOwnedCameras(ply)) do
        ent.ZCityCameraIndex = index
        ent:SetNWString("ZCityCameraName", Cameras.FormatName(index))
        ent:SetNWString("ZCityCameraOwnerName", IsValid(ply) and ply:Nick() or "")
    end
end

function Cameras.SendList(ply)
    if not IsValid(ply) then return end

    local owned = Cameras.GetOwnedCameras(ply)

    net.Start("ZCityAftermath.CameraList")
        net.WriteUInt(#owned, 8)
        for index, ent in ipairs(owned) do
            net.WriteEntity(ent)
            net.WriteString(ent:GetNWString("ZCityCameraName", Cameras.FormatName(index)))
        end
    net.Send(ply)
end

local function clearView(ply)
    net.Start("ZCityAftermath.CameraSetView")
        net.WriteEntity(NULL)
    net.Send(ply)
end

function Cameras.CanPlaceCamera(ply)
    local maxPerPlayer = math.max(1, math.floor(tonumber(Config.CameraMaxPerPlayer) or 6))
    if #Cameras.GetOwnedCameras(ply) >= maxPerPlayer then
        return false, string.format("Camera limit reached (%d).", maxPerPlayer)
    end

    return true
end

function Cameras.PlaceCamera(ply, pos, modelAngles, feedAngles)
    if not IsValid(ply) then
        return false, "Invalid player."
    end

    local allowed, reason = Cameras.CanPlaceCamera(ply)
    if not allowed then
        return false, reason
    end

    local ent = ents.Create(Config.CameraEntityClass)
    if not IsValid(ent) then
        return false, "Could not create the camera."
    end

    ent:SetPos(pos)
    ent:SetAngles(modelAngles or Angle(0, 0, 0))
    ent:Spawn()
    ent:Activate()
    ent.ZCityCameraOwnerKey = ownerKey(ply)
    ent.ZCityCameraFeedAngle = feedAngles or Angle(0, 0, 0)
    ent:SetNWAngle("ZCityCameraFeedAngle", ent.ZCityCameraFeedAngle)
    ent:SetNWEntity("ZCityCameraOwner", ply)
    ent:SetNWString("ZCityCameraOwnerName", ply:Nick())

    Cameras.RefreshNames(ply)
    Cameras.SendList(ply)

    timer.Simple(0, function()
        if IsValid(ply) and not ply:HasWeapon(Config.CameraTabletWeapon) then
            ply:Give(Config.CameraTabletWeapon)
        end
    end)

    return true, "Security camera placed.", ent
end

function Cameras.DeployFromKit(kit, ply)
    if not IsValid(kit) then
        return false, "Camera kit is missing."
    end

    if not IsValid(ply) or not ply:IsPlayer() then
        return false, "Only players can place cameras."
    end

    local trace = ply:GetEyeTraceNoCursor()
    if not trace.Hit then
        return false, "Look at a wall, ceiling, or floor first."
    end

    local pos = trace.HitPos + trace.HitNormal * 6
    local modelAngles, feedAngles = computeCameraPlacement(trace, ply)
    local success, message = Cameras.PlaceCamera(ply, pos, modelAngles, feedAngles)
    if not success then
        return false, message
    end

    if IsValid(kit) then
        kit:Remove()
    end

    return true, "Camera placed. Use the tablet to watch it."
end

net.Receive("ZCityAftermath.CameraRequestList", function(_, ply)
    Cameras.SendList(ply)
end)

net.Receive("ZCityAftermath.CameraRequestView", function(_, ply)
    local ent = net.ReadEntity()
    if not Cameras.PlayerOwnsCamera(ply, ent) then
        notifyPlayer(ply, false, "You can only access your own cameras.")
        return
    end

    net.Start("ZCityAftermath.CameraSetView")
        net.WriteEntity(ent)
    net.Send(ply)
end)

net.Receive("ZCityAftermath.CameraClearView", function(_, ply)
    clearView(ply)
end)

net.Receive("ZCityAftermath.CameraRemove", function(_, ply)
    local ent = net.ReadEntity()
    if not Cameras.PlayerOwnsCamera(ply, ent) then
        notifyPlayer(ply, false, "You can only remove your own cameras.")
        return
    end

    ent:Remove()
    Cameras.RefreshNames(ply)
    Cameras.SendList(ply)
    clearView(ply)
    notifyPlayer(ply, true, "Camera removed.")
end)

hook.Add("PlayerSpawn", "ZCityAftermath.CameraTabletRespawn", function(ply)
    timer.Simple(0.25, function()
        if not IsValid(ply) then
            return
        end

        if #Cameras.GetOwnedCameras(ply) > 0 and not ply:HasWeapon(Config.CameraTabletWeapon) then
            ply:Give(Config.CameraTabletWeapon)
        end
    end)
end)

concommand.Add(Config.GiveCameraTabletCommand, function(ply)
    if not canUseCameraUtilities(ply) then
        notifyPlayer(ply, false, "Only admin or superadmin can use this.")
        return
    end

    ply:Give(Config.CameraTabletWeapon)
    notifyPlayer(ply, true, "Camera tablet issued.")
end)

concommand.Add(Config.SpawnCameraKitCommand, function(ply)
    if not canUseCameraUtilities(ply) then
        notifyPlayer(ply, false, "Only admin or superadmin can use this.")
        return
    end

    local trace = ply:GetEyeTraceNoCursor()
    local spawnPos = trace.HitPos + trace.HitNormal * 18
    local ent = ents.Create(Config.CameraKitClass)
    if not IsValid(ent) then
        notifyPlayer(ply, false, "Could not spawn the camera kit.")
        return
    end

    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ent:Spawn()
    ent:Activate()
    notifyPlayer(ply, true, "Camera kit spawned.")
end)
