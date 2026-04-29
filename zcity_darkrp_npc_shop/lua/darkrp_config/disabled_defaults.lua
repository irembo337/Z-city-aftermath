DarkRP = DarkRP or {}
DarkRP.disabledDefaults = DarkRP.disabledDefaults or {}
DarkRP.disabledDefaults["modules"] = DarkRP.disabledDefaults["modules"] or {}
DarkRP.disabledDefaults["jobs"] = DarkRP.disabledDefaults["jobs"] or {}

DarkRP.disabledDefaults["modules"]["f4menu"] = true

for _, jobCommand in ipairs({
    "citizen",
    "hobo",
    "cook",
    "medic",
    "gundealer",
    "gun",
    "gangster",
    "gang",
    "mobboss",
    "mob",
    "mayor",
    "chief",
    "police"
}) do
    DarkRP.disabledDefaults["jobs"][jobCommand] = true
end
