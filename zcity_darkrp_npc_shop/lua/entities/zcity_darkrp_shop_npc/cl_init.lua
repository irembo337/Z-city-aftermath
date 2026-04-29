include("shared.lua")

surface.CreateFont("ZCityDarkRPShopNPC", {
    font = "Trebuchet24",
    size = 28,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZCityDarkRPShopNPCSub", {
    font = "Tahoma",
    size = 18,
    weight = 600,
    antialias = true
})

function ENT:Draw()
    self:DrawModel()

    local eyeAngles = LocalPlayer():EyeAngles()
    local position = self:GetPos() + Vector(0, 0, 82)
    local angles = Angle(0, eyeAngles.y - 90, 90)
    local npcName = self:GetNWString("ZCityDarkRPShopNPCName", "Gun Dealer")

    cam.Start3D2D(position, angles, 0.08)
        draw.RoundedBox(10, -130, -18, 260, 60, Color(18, 22, 30, 210))
        draw.RoundedBox(10, -130, -18, 8, 60, Color(234, 110, 58, 255))
        draw.SimpleTextOutlined(npcName, "ZCityDarkRPShopNPC", 0, 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
        draw.SimpleTextOutlined("Press E to open shop", "ZCityDarkRPShopNPCSub", 0, 24, Color(220, 224, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
    cam.End3D2D()
end
