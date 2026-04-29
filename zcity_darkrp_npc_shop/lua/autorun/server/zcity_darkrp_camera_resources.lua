if not SERVER then
    return
end

local files = {
    "materials/models/slusher/tablet/ekran.vmt",
    "materials/models/slusher/tablet/wszystko.vmt",
    "materials/models/slusher/tablet/wszystko.vtf",
    "models/slusher/tablet/c_tablet.dx80.vtx",
    "models/slusher/tablet/c_tablet.dx90.vtx",
    "models/slusher/tablet/c_tablet.mdl",
    "models/slusher/tablet/c_tablet.sw.vtx",
    "models/slusher/tablet/c_tablet.vvd",
    "models/slusher/tablet/w_tablet.dx80.vtx",
    "models/slusher/tablet/w_tablet.dx90.vtx",
    "models/slusher/tablet/w_tablet.mdl",
    "models/slusher/tablet/w_tablet.phy",
    "models/slusher/tablet/w_tablet.sw.vtx",
    "models/slusher/tablet/w_tablet.vvd"
}

for _, filePath in ipairs(files) do
    resource.AddFile(filePath)
end
