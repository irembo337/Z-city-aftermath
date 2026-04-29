ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Client = ZCityDarkRPShop.Client or {}

local Client = ZCityDarkRPShop.Client
local Config = ZCityDarkRPShop.Config

Client.State = Client.State or {
    items = {},
    balance = 0,
    balanceText = "$0",
    canManage = false,
    managerGroup = "",
    manageReason = "",
    darkRPReady = false,
    npcCount = 0,
    npcName = Config.NPCName
}

Client.DetectedCatalog = Client.DetectedCatalog or {
    weapon = {},
    armor = {},
    ammo = {},
    attachment = {}
}

surface.CreateFont("ZCityShop.Title", {
    font = "Trebuchet24",
    size = 34,
    weight = 900,
    antialias = true
})

surface.CreateFont("ZCityShop.Section", {
    font = "Trebuchet24",
    size = 24,
    weight = 800,
    antialias = true
})

surface.CreateFont("ZCityShop.Body", {
    font = "Tahoma",
    size = 17,
    weight = 600,
    antialias = true
})

surface.CreateFont("ZCityShop.Small", {
    font = "Tahoma",
    size = 15,
    weight = 500,
    antialias = true
})

local palette = {
    bg = Color(13, 17, 24),
    header = Color(17, 24, 36),
    panel = Color(24, 31, 43),
    panelSoft = Color(29, 38, 52),
    panelAlt = Color(18, 24, 35),
    line = Color(55, 67, 89),
    accent = Color(237, 118, 58),
    accentSoft = Color(255, 151, 94),
    success = Color(81, 178, 119),
    successSoft = Color(106, 201, 145),
    danger = Color(195, 82, 82),
    dangerSoft = Color(223, 104, 104),
    text = Color(240, 244, 249),
    textDim = Color(156, 167, 185),
    chip = Color(35, 44, 60),
    hover = Color(43, 53, 69),
    select = Color(59, 73, 96)
}

local frame
local Main = {
    navButtons = {},
    sections = {}
}

local Buyer = {}
local Manager = {}

local catalogItems = {}
local catalogDirty = false
local activeSection = "shop"
local activeAvailableCategory = "armor"
local autoLoadAvailableOnRefresh = false

local selectedShopId
local selectedShopItem
local selectedAvailableItem
local selectedCatalogId
local selectedCatalogItem

local lastDetectedRequest = 0

local redrawShopList
local redrawAvailableList
local redrawCatalogList
local refreshAll
local switchSection
local populateEditorFromItem
local resizeFrameForSection

local function categoryLabel(category)
    return Config.ItemCategories[category] or Config.ItemCategories.misc
end

local function deliveryLabel(kind)
    return kind == "entity" and "Entity" or "Weapon"
end

local function normalizeKind(item)
    local kind = string.lower(tostring(item and item.kind or ""))
    if kind == "weapon" or kind == "entity" then
        return kind
    end

    return string.lower(tostring(item and item.category or "")) == "weapon" and "weapon" or "entity"
end

local function formatMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))

    if DarkRP and DarkRP.formatMoney then
        return DarkRP.formatMoney(amount)
    end

    return "$" .. tostring(amount)
end

local function trim(value)
    return string.Trim(tostring(value or ""))
end

local function duplicateItems(items)
    return table.Copy(items or {})
end

local function sortItems(items)
    table.sort(items, function(left, right)
        local leftName = string.lower(left.name or "")
        local rightName = string.lower(right.name or "")

        if leftName == rightName then
            return tonumber(left.price or 0) < tonumber(right.price or 0)
        end

        return leftName < rightName
    end)
end

local function findItem(items, itemId)
    for index, item in ipairs(items or {}) do
        if item.id == itemId then
            return item, index
        end
    end
end

local function findCatalogByClass(className, kind)
    className = string.lower(trim(className))
    kind = string.lower(trim(kind))

    for index, item in ipairs(catalogItems or {}) do
        if string.lower(item.class or "") == className and string.lower(item.kind or "") == kind then
            return item, index
        end
    end
end

local metadataFields = {
    "source",
    "sourceType",
    "zcityType",
    "zcityId",
    "armorClass",
    "attachmentId",
    "ammoType",
    "ammoAmount"
}

local function copyItemMetadata(source, target)
    if not istable(source) or not istable(target) then
        return target
    end

    for _, field in ipairs(metadataFields) do
        local value = source[field]
        if value ~= nil and value ~= "" then
            target[field] = value
        end
    end

    return target
end

local function matchFilter(filter, ...)
    filter = string.lower(trim(filter))
    if filter == "" then
        return true
    end

    for index = 1, select("#", ...) do
        local value = string.lower(tostring(select(index, ...) or ""))
        if string.find(value, filter, 1, true) then
            return true
        end
    end

    return false
end

local function requestState()
    net.Start("ZCityDarkRPShop.RequestState")
    net.SendToServer()
end

local function requestDetectedCatalog()
    if not Client.State.canManage then
        return
    end

    if RealTime() - lastDetectedRequest < 0.75 then
        return
    end

    lastDetectedRequest = RealTime()

    net.Start("ZCityDarkRPShop.RequestDetectedCatalog")
    net.SendToServer()
end

local function notifyLocal(success, message)
    notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
    surface.PlaySound(success and "buttons/button15.wav" or "buttons/button10.wav")
end

local function paintRoundedPanel(_, w, h, color)
    draw.RoundedBox(14, 0, 0, w, h, color)
    surface.SetDrawColor(palette.line)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

local function styleButton(button, baseColor, hoverColor)
    button:SetTextColor(palette.text)
    button:SetFont("ZCityShop.Body")
    button.Paint = function(self, w, h)
        local color = self:IsEnabled() and (self:IsHovered() and hoverColor or baseColor) or palette.line
        draw.RoundedBox(12, 0, 0, w, h, color)
        draw.SimpleText(self:GetText(), "ZCityShop.Body", w / 2, h / 2, palette.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function styleNavButton(button)
    button:SetTextColor(palette.text)
    button:SetFont("ZCityShop.Body")
    button.Paint = function(self, w, h)
        local active = self.IsActive == true
        local bg = active and palette.accent or (self:IsHovered() and palette.hover or palette.panelAlt)
        local bar = active and palette.accentSoft or palette.line

        draw.RoundedBox(12, 0, 0, w, h, bg)
        draw.RoundedBox(12, 0, 0, 6, h, bar)
        draw.SimpleText(self:GetText(), "ZCityShop.Body", 18, h / 2, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function styleTextEntry(entry)
    entry:SetFont("ZCityShop.Body")
    entry:SetTextColor(palette.text)
    entry:SetDrawLanguageID(false)
    entry.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, palette.panelAlt)
        surface.SetDrawColor(palette.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(palette.text, palette.accent, palette.text)
    end
end

local function styleComboBox(combo)
    combo:SetFont("ZCityShop.Body")
    combo:SetTextColor(palette.text)
    combo.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, palette.panelAlt)
        surface.SetDrawColor(palette.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(self:GetText(), "ZCityShop.Body", 12, h / 2, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function styleListView(list)
    list:SetHeaderHeight(30)
    list:SetDataHeight(34)
    list.Paint = function(self, w, h)
        paintRoundedPanel(self, w, h, palette.panelAlt)
    end

    for _, column in ipairs(list.Columns or {}) do
        column.Header:SetTextColor(palette.text)
        column.Header.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, palette.panelSoft)
            draw.SimpleText(self:GetText(), "ZCityShop.Small", 10, h / 2, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

local function styleListLine(line)
    line.Paint = function(self, w, h)
        local bg = self:IsSelected() and palette.select or (self:IsHovered() and palette.hover or Color(0, 0, 0, 0))
        draw.RoundedBox(10, 4, 2, w - 8, h - 4, bg)
    end
end

local function addStyledLine(list, ...)
    local line = list:AddLine(...)
    styleListLine(line)
    return line
end

local function createLabel(parent, font, color, text, alignment)
    local label = vgui.Create("DLabel", parent)
    label:SetFont(font)
    label:SetTextColor(color)
    label:SetText(text or "")
    label:SetContentAlignment(alignment or 4)
    return label
end

local function createCard(parent, color)
    local panel = vgui.Create("DPanel", parent)
    panel.Paint = function(self, w, h)
        paintRoundedPanel(self, w, h, color or palette.panel)
    end
    return panel
end

local function computeFrameSize(sectionName)
    if sectionName == "shop" then
        local width = math.floor(ScrW() * 0.64)
        local height = math.floor(ScrH() * 0.74)

        width = math.min(width, 1040)
        height = math.min(height, 760)
        width = math.max(width, 820)
        height = math.max(height, 620)

        width = math.min(width, ScrW() - 40)
        height = math.min(height, ScrH() - 40)

        return width, height
    end

    local width = math.floor(ScrW() * 0.9)
    local height = math.floor(ScrH() * 0.9)

    width = math.min(width, 1600)
    height = math.min(height, 940)
    width = math.max(width, 1180)
    height = math.max(height, 760)

    width = math.min(width, ScrW() - 24)
    height = math.min(height, ScrH() - 24)

    return width, height
end

local function validModel(model)
    if model == nil or model == "" then
        return false
    end

    local lowered = string.lower(tostring(model))
    if lowered == "models/error.mdl" then
        return false
    end

    return util.IsValidModel(model)
end

local function resolveWeaponModel(className)
    local stored = weapons.GetStored and weapons.GetStored(className) or nil
    stored = stored or (weapons.Get and weapons.Get(className) or nil)

    if not istable(stored) then
        return nil
    end

    return stored.WorldModel or stored.WModel or stored.ViewModel or nil
end

local function resolveEntityModel(className)
    local stored = scripted_ents.GetStored and scripted_ents.GetStored(className) or nil
    local entry = stored and (stored.t or stored) or nil
    if istable(entry) then
        return entry.Model or entry.WorldModel or nil
    end

    local spawnable = list.Get("SpawnableEntities")
    spawnable = istable(spawnable) and spawnable[className] or nil
    if istable(spawnable) then
        return spawnable.Model or nil
    end

    return nil
end

local function resolveItemModel(item)
    if not item then
        return "models/props_junk/cardboard_box004a.mdl"
    end

    if validModel(item.model) then
        return item.model
    end

    local className = item.class or ""
    local kind = normalizeKind(item)
    local model

    if kind == "weapon" then
        model = resolveWeaponModel(className)
    end

    if not validModel(model) then
        model = resolveEntityModel(className)
    end

    if validModel(model) then
        return model
    end

    if kind == "weapon" then
        return "models/weapons/w_rif_ar2.mdl"
    end

    return "models/items/boxmrounds.mdl"
end

local function applyModelToPanel(panel, item)
    if not IsValid(panel) then return end

    local model = resolveItemModel(item)
    panel.CurrentModel = model
    panel:SetModel(model)

    local entity = panel.Entity
    if not IsValid(entity) then
        return
    end

    local mins, maxs = entity:GetRenderBounds()
    local size = math.max(
        math.abs(mins.x) + math.abs(maxs.x),
        math.abs(mins.y) + math.abs(maxs.y),
        math.abs(mins.z) + math.abs(maxs.z),
        32
    )
    local center = (mins + maxs) * 0.5

    panel:SetFOV(24)
    panel:SetLookAt(center)
    panel:SetCamPos(center + Vector(size * 2.15, size * 1.55, size * 0.72))
    panel.LayoutEntity = function(self, ent)
        if not IsValid(ent) then return end
        ent:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
    end
end

local function selectListLineByValue(list, fieldName, fieldValue)
    if not IsValid(list) or not fieldValue then return end

    for _, line in ipairs(list:GetLines() or {}) do
        if line[fieldName] == fieldValue then
            if list.SelectItem then
                list:SelectItem(line)
            else
                line:SetSelected(true)
            end
            return
        end
    end
end

local function setComboChoice(combo, data)
    if not IsValid(combo) then return end

    for index, optionData in ipairs(combo.Data or {}) do
        if optionData == data then
            combo:ChooseOptionID(index)
            combo.SelectedData = data
            return
        end
    end
end

local function updateStatCards()
    if IsValid(Main.walletValue) then
        Main.walletValue:SetText(Client.State.balanceText or "$0")
    end

    if IsValid(Main.walletSubtitle) then
        Main.walletSubtitle:SetText(Client.State.darkRPReady and "DarkRP wallet balance" or "DarkRP not detected")
    end

    if IsValid(Main.controlValue) then
        Main.controlValue:SetText(string.format("%d NPC", tonumber(Client.State.npcCount) or 0))
    end

    if IsValid(Main.controlSubtitle) then
        if Client.State.canManage then
            Main.controlSubtitle:SetText("ULX: " .. string.upper(Client.State.managerGroup or "admin"))
        else
            Main.controlSubtitle:SetText(Client.State.manageReason ~= "" and Client.State.manageReason or "Player access only")
        end
    end
end

local function updateBuyerDetails()
    if not IsValid(Buyer.nameValue) then return end

    if IsValid(Buyer.balanceValue) then
        Buyer.balanceValue:SetText("Your balance: " .. (Client.State.balanceText or "$0"))
    end

    local item = selectedShopItem

    if not item then
        Buyer.nameValue:SetText("Select an item")
        Buyer.priceValue:SetText("No selection")
        if IsValid(Buyer.categoryValue) then
            Buyer.categoryValue:SetText("Trader Items")
        end
        Buyer.deliveryValue:SetText("Delivery: -")
        Buyer.classValue:SetText("Class: -")
        Buyer.helperValue:SetText("Choose an item on the left to inspect it before buying.")
        Buyer.buyButton:SetEnabled(false)
        applyModelToPanel(Buyer.modelPanel, nil)
        return
    end

    Buyer.nameValue:SetText(item.name or "Unknown Item")
    Buyer.priceValue:SetText(formatMoney(item.price))
    if IsValid(Buyer.categoryValue) then
        Buyer.categoryValue:SetText(categoryLabel(item.category))
    end
    Buyer.deliveryValue:SetText("Delivery: " .. deliveryLabel(normalizeKind(item)))
    Buyer.classValue:SetText("Class: " .. tostring(item.class or "-"))
    Buyer.helperValue:SetText("Preview the item here, then buy it directly or use the NPC in-world with E.")
    Buyer.buyButton:SetEnabled(true)

    applyModelToPanel(Buyer.modelPanel, item)
end

local function updateManagerStatus()
    if not IsValid(Manager.noticeLabel) then return end

    if Client.State.canManage then
        Manager.noticeLabel:SetText("ULX access confirmed. Select an addon item, set a price, and save it into the trader catalog.")
    else
        Manager.noticeLabel:SetText(Client.State.manageReason ~= "" and Client.State.manageReason or "Only ULX admin and superadmin can manage this trader.")
    end

    if IsValid(Manager.catalogStatusLabel) then
        local count = #(catalogItems or {})
        local suffix = catalogDirty and "Unsaved local changes." or "Catalog is synced with the server."
        Manager.catalogStatusLabel:SetText(string.format("%d catalog items. %s", count, suffix))
    end

    if IsValid(Manager.npcNameEntry) then
        if not Manager.npcNameEntry:HasFocus() then
            Manager.npcNameEntry:SetText(Client.State.npcName or Config.NPCName)
        end
    end
end

local function updateEditorButtons()
    if not IsValid(Manager.addButton) then return end

    local hasCatalogSelection = selectedCatalogId ~= nil
    Manager.removeButton:SetEnabled(hasCatalogSelection)
end

populateEditorFromItem = function(item, sourceText)
    if not IsValid(Manager.nameEntry) then return end

    local working = item and table.Copy(item) or {
        id = nil,
        name = "",
        class = "",
        model = "",
        kind = activeAvailableCategory == "weapon" and "weapon" or "entity",
        category = activeAvailableCategory or "armor",
        price = 0
    }

    selectedCatalogId = working.id
    selectedCatalogItem = selectedCatalogId and working or nil

    Manager.nameEntry:SetText(working.name or "")
    Manager.classEntry:SetText(working.class or "")
    Manager.priceEntry:SetText(item and tostring(tonumber(working.price) or 0) or "")
    setComboChoice(Manager.categoryCombo, working.category or "armor")
    setComboChoice(Manager.kindCombo, normalizeKind(working))

    if IsValid(Manager.sourceLabel) then
        Manager.sourceLabel:SetText(sourceText or "Create a custom item or select one from the addon list.")
    end

    applyModelToPanel(Manager.previewModel, working)
    updateEditorButtons()
end

local function selectShopItem(itemId)
    selectedShopId = itemId
    selectedShopItem = findItem(Client.State.items, itemId)
    updateBuyerDetails()
end

local function selectAvailableItem(item)
    selectedAvailableItem = item
    autoLoadAvailableOnRefresh = false

    if not item then
        populateEditorFromItem(nil, "Select an addon item or click New Empty Item.")
        return
    end

    local kind = normalizeKind(item)
    local existing = findCatalogByClass(item.class or "", kind)
    local editorItem
    local sourceText

    if existing then
        editorItem = table.Copy(existing)
        editorItem.model = editorItem.model or item.model or resolveItemModel(item)
        copyItemMetadata(item, editorItem)
        sourceText = "Loaded from addon list. This class already exists in the shop catalog."
    else
        editorItem = {
            id = nil,
            name = item.name or item.class or "Unknown Item",
            class = item.class or "",
            model = item.model or resolveItemModel(item),
            kind = kind,
            category = item.category or activeAvailableCategory,
            price = 0
        }
        copyItemMetadata(item, editorItem)
        sourceText = item.importable == false
            and "Reference entry detected. Check class and delivery type manually before saving."
            or "Loaded from addon list. Set a price and add it to the shop catalog."
    end

    populateEditorFromItem(editorItem, sourceText)
end

local function selectCatalogItem(itemId)
    selectedCatalogId = itemId
    selectedCatalogItem = findItem(catalogItems, itemId)
    autoLoadAvailableOnRefresh = false

    if selectedCatalogItem then
        populateEditorFromItem(table.Copy(selectedCatalogItem), "Loaded from current shop catalog.")
    else
        populateEditorFromItem(nil, "Select an addon item or click New Empty Item.")
    end
end

local function buildEditorItem()
    local name = trim(IsValid(Manager.nameEntry) and Manager.nameEntry:GetValue() or "")
    local className = trim(IsValid(Manager.classEntry) and Manager.classEntry:GetValue() or "")
    local price = math.floor(tonumber(IsValid(Manager.priceEntry) and Manager.priceEntry:GetValue() or "") or -1)
    local category = IsValid(Manager.categoryCombo) and (Manager.categoryCombo.SelectedData or "armor") or "armor"
    local kind = IsValid(Manager.kindCombo) and (Manager.kindCombo.SelectedData or "weapon") or "weapon"

    if name == "" then
        return nil, "Set a display name first."
    end

    if className == "" then
        return nil, "Set a class name first."
    end

    if price < 0 then
        return nil, "Set a valid non-negative price."
    end

    local existing, index = selectedCatalogId and findItem(catalogItems, selectedCatalogId) or findCatalogByClass(className, kind)
    local itemId = existing and existing.id or ("item_" .. util.CRC(name .. className .. kind .. category .. tostring(price) .. tostring(SysTime())))
    local previewModel = resolveItemModel({
        class = className,
        kind = kind,
        category = category,
        model = existing and existing.model or nil
    })

    local item = {
        id = itemId,
        name = name,
        class = className,
        model = previewModel,
        kind = kind,
        category = category,
        price = price
    }

    copyItemMetadata(selectedCatalogItem, item)
    copyItemMetadata(selectedAvailableItem, item)
    copyItemMetadata(existing, item)

    return item, nil, index
end

local function saveEditorItem()
    local item, errorText, existingIndex = buildEditorItem()
    if not item then
        notifyLocal(false, errorText or "Could not build the catalog item.")
        return
    end

    if existingIndex then
        catalogItems[existingIndex] = item
    else
        catalogItems[#catalogItems + 1] = item
    end

    catalogDirty = true
    selectedCatalogId = item.id
    selectedCatalogItem = table.Copy(item)

    redrawCatalogList()
    selectCatalogItem(item.id)
    notifyLocal(true, "Catalog item updated locally. Use Save Catalog To Server when you are done.")
end

local function clearEditor()
    selectedAvailableItem = nil
    selectedCatalogId = nil
    selectedCatalogItem = nil
    autoLoadAvailableOnRefresh = true
    populateEditorFromItem(nil, "Create a custom item or select an addon item.")
end

local function removeCatalogItem()
    if not selectedCatalogId then
        notifyLocal(false, "Select a catalog item to remove.")
        return
    end

    local _, index = findItem(catalogItems, selectedCatalogId)
    if not index then
        notifyLocal(false, "Could not find the selected catalog item.")
        return
    end

    table.remove(catalogItems, index)
    catalogDirty = true
    selectedCatalogId = nil
    selectedCatalogItem = nil

    redrawCatalogList()
    clearEditor()
    notifyLocal(true, "Catalog item removed locally. Use Save Catalog To Server to apply it on the server.")
end

local function saveCatalogToServer()
    net.Start("ZCityDarkRPShop.SaveCatalog")
    net.WriteString(util.TableToJSON(catalogItems) or "[]")
    net.SendToServer()
end

local function saveNPCName()
    net.Start("ZCityDarkRPShop.SaveSettings")
    net.WriteString(util.TableToJSON({
        npcName = trim(IsValid(Manager.npcNameEntry) and Manager.npcNameEntry:GetValue() or "")
    }) or "{}")
    net.SendToServer()
end

local function createStatCard(parent, title)
    local panel = createCard(parent, palette.panel)
    panel.Title = title
    panel.PerformLayout = function(self, w, h)
        if IsValid(self.TitleLabel) then
            self.TitleLabel:SetPos(20, 16)
            self.TitleLabel:SetSize(w - 40, 18)
        end

        if IsValid(self.ValueLabel) then
            self.ValueLabel:SetPos(20, 38)
            self.ValueLabel:SetSize(w - 40, 34)
        end

        if IsValid(self.SubtitleLabel) then
            self.SubtitleLabel:SetPos(20, 72)
            self.SubtitleLabel:SetSize(w - 40, 18)
        end
    end
    panel.PaintOver = function(self, w, h)
        draw.RoundedBox(14, 0, 0, 7, h, palette.accent)
    end

    panel.TitleLabel = createLabel(panel, "ZCityShop.Small", palette.textDim, title, 4)
    panel.ValueLabel = createLabel(panel, "ZCityShop.Title", palette.text, "", 4)
    panel.SubtitleLabel = createLabel(panel, "ZCityShop.Small", palette.textDim, "", 4)

    return panel
end

local function createBuyerSection(parent)
    local panel = vgui.Create("DPanel", parent)
    panel.Paint = function(self, w, h)
        draw.RoundedBox(18, 0, 0, w, h, Color(0, 0, 0, 90))
    end

    Buyer.modalCard = createCard(panel, Color(26, 31, 49, 236))
    Buyer.modalCard.Paint = function(self, w, h)
        draw.RoundedBox(14, 0, 0, w, h, Color(26, 31, 49, 236))
        draw.RoundedBoxEx(14, 0, 0, w, 32, Color(53, 58, 112, 235), true, true, false, false)
        surface.SetDrawColor(Color(84, 90, 160, 120))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText((Client.State.npcName or Config.NPCName) .. " - Shop", "ZCityShop.Body", w / 2, 16, Color(255, 221, 109), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    Buyer.balanceValue = createLabel(Buyer.modalCard, "ZCityShop.Small", Color(96, 255, 120), "", 4)
    Buyer.categoryValue = createLabel(Buyer.modalCard, "ZCityShop.Body", Color(255, 217, 84), "Weapons", 4)
    Buyer.searchEntry = vgui.Create("DTextEntry", Buyer.modalCard)
    styleTextEntry(Buyer.searchEntry)
    Buyer.searchEntry:SetPlaceholderText("Search item")
    Buyer.searchEntry.OnValueChange = function()
        redrawShopList()
    end

    Buyer.listCard = createCard(Buyer.modalCard, Color(18, 22, 34, 110))
    Buyer.listScroll = vgui.Create("DScrollPanel", Buyer.listCard)
    Buyer.listLayout = vgui.Create("DListLayout", Buyer.listScroll)
    Buyer.listLayout:Dock(TOP)

    Buyer.previewCard = createCard(Buyer.modalCard, Color(17, 22, 35, 120))
    Buyer.previewTitle = createLabel(Buyer.previewCard, "ZCityShop.Body", palette.text, "Selected Item", 5)
    Buyer.modelPanel = vgui.Create("DModelPanel", Buyer.previewCard)
    Buyer.modelPanel:SetFOV(24)
    Buyer.modelPanel:SetAnimated(true)
    Buyer.nameValue = createLabel(Buyer.previewCard, "ZCityShop.Section", palette.text, "Select an item", 5)
    Buyer.priceValue = createLabel(Buyer.previewCard, "ZCityShop.Title", Color(255, 112, 112), "No selection", 5)
    Buyer.deliveryValue = createLabel(Buyer.previewCard, "ZCityShop.Small", palette.textDim, "Delivery: -", 5)
    Buyer.classValue = createLabel(Buyer.previewCard, "ZCityShop.Small", palette.textDim, "Class: -", 5)
    Buyer.helperValue = createLabel(Buyer.previewCard, "ZCityShop.Small", palette.textDim, "Pick an item on the left or press the buy button in its row.", 5)
    Buyer.helperValue:SetWrap(true)
    Buyer.buyButton = vgui.Create("DButton", Buyer.previewCard)
    Buyer.buyButton:SetText("Buy Selected Item")
    styleButton(Buyer.buyButton, palette.accent, palette.accentSoft)
    Buyer.buyButton:SetEnabled(false)
    Buyer.buyButton.DoClick = function()
        if not selectedShopId then
            notifyLocal(false, "Select an item first.")
            return
        end

        net.Start("ZCityDarkRPShop.BuyItem")
        net.WriteString(selectedShopId)
        net.SendToServer()
    end

    Buyer.listCard.PerformLayout = function(self, w, h)
        Buyer.listScroll:SetPos(0, 0)
        Buyer.listScroll:SetSize(w, h)
        Buyer.listLayout:SetWide(w - 18)
    end

    Buyer.previewCard.PerformLayout = function(self, w, h)
        local pad = 14
        local modelHeight = math.min(240, math.max(150, h - 230))

        Buyer.previewTitle:SetPos(pad, 12)
        Buyer.previewTitle:SetSize(w - pad * 2, 20)
        Buyer.modelPanel:SetPos(pad, 40)
        Buyer.modelPanel:SetSize(w - pad * 2, modelHeight)
        Buyer.nameValue:SetPos(pad, 48 + modelHeight)
        Buyer.nameValue:SetSize(w - pad * 2, 24)
        Buyer.priceValue:SetPos(pad, 74 + modelHeight)
        Buyer.priceValue:SetSize(w - pad * 2, 30)
        Buyer.deliveryValue:SetPos(pad, 108 + modelHeight)
        Buyer.deliveryValue:SetSize(w - pad * 2, 18)
        Buyer.classValue:SetPos(pad, 130 + modelHeight)
        Buyer.classValue:SetSize(w - pad * 2, 18)
        Buyer.helperValue:SetPos(pad, 154 + modelHeight)
        Buyer.helperValue:SetSize(w - pad * 2, 34)
        Buyer.buyButton:SetPos(pad, h - 48)
        Buyer.buyButton:SetSize(w - pad * 2, 34)
    end

    panel.PerformLayout = function(self, w, h)
        local modalWidth = math.min(980, math.max(820, w - 60))
        local modalHeight = math.min(690, math.max(560, h - 50))
        local leftWidth = math.floor(modalWidth * 0.6)
        local rightWidth = modalWidth - leftWidth - 18

        Buyer.modalCard:SetSize(modalWidth, modalHeight)
        Buyer.modalCard:Center()

        Buyer.balanceValue:SetPos(14, 44)
        Buyer.balanceValue:SetSize(240, 18)
        Buyer.categoryValue:SetPos(14, 76)
        Buyer.categoryValue:SetSize(180, 20)
        Buyer.searchEntry:SetPos(14, 102)
        Buyer.searchEntry:SetSize(leftWidth - 28, 34)

        Buyer.listCard:SetPos(14, 144)
        Buyer.listCard:SetSize(leftWidth - 14, modalHeight - 158)

        Buyer.previewCard:SetPos(leftWidth + 4, 44)
        Buyer.previewCard:SetSize(rightWidth, modalHeight - 58)
    end

    return panel
end

local function createCategoryButton(parent, label, categoryKey)
    local button = vgui.Create("DButton", parent)
    button:SetText(label)
    styleNavButton(button)
    button.DoClick = function()
        activeAvailableCategory = categoryKey
        autoLoadAvailableOnRefresh = true
        redrawAvailableList()
    end
    return button
end

local function updateCategoryButtons()
    for key, button in pairs(Manager.categoryButtons or {}) do
        if IsValid(button) then
            button.IsActive = key == activeAvailableCategory
        end
    end
end

local function createManagerSection(parent)
    local panel = createCard(parent, palette.panel)

    Manager.titleLabel = createLabel(panel, "ZCityShop.Section", palette.text, "Trader Manager", 4)
    Manager.subtitleLabel = createLabel(panel, "ZCityShop.Small", palette.textDim, "Manage addon items, price them, and keep the trader catalog organized in one screen.", 4)
    Manager.noticeLabel = createLabel(panel, "ZCityShop.Small", palette.textDim, "", 4)
    Manager.noticeLabel:SetWrap(true)

    Manager.availableCard = createCard(panel, palette.panelSoft)
    Manager.availableTitle = createLabel(Manager.availableCard, "ZCityShop.Body", palette.text, "Available Addon Items", 4)
    Manager.availableInfo = createLabel(Manager.availableCard, "ZCityShop.Small", palette.textDim, "Pick a class from your loaded addons, then set a price in the editor.", 4)
    Manager.availableSearchEntry = vgui.Create("DTextEntry", Manager.availableCard)
    styleTextEntry(Manager.availableSearchEntry)
    Manager.availableSearchEntry:SetPlaceholderText("Search detected addon content")
    Manager.availableSearchEntry.OnValueChange = function()
        redrawAvailableList()
    end
    Manager.availableCount = createLabel(Manager.availableCard, "ZCityShop.Small", palette.textDim, "0 detected", 6)
    Manager.categoryRow = vgui.Create("DPanel", Manager.availableCard)
    Manager.categoryRow.Paint = nil
    Manager.categoryButtons = {
        armor = createCategoryButton(Manager.categoryRow, "Armor", "armor"),
        attachment = createCategoryButton(Manager.categoryRow, "Attachments", "attachment")
    }
    Manager.availableList = vgui.Create("DListView", Manager.availableCard)
    Manager.availableList:SetMultiSelect(false)
    Manager.availableList:AddColumn("Name")
    Manager.availableList:AddColumn("Class / ID")
    Manager.availableList:AddColumn("Source")
    styleListView(Manager.availableList)
    Manager.availableList.OnRowSelected = function(_, _, line)
        selectAvailableItem(line.DetectedItem)
    end
    Manager.availableList.DoDoubleClick = function(_, _, line)
        selectAvailableItem(line.DetectedItem)
    end

    Manager.editorCard = createCard(panel, palette.panelSoft)
    Manager.editorTitle = createLabel(Manager.editorCard, "ZCityShop.Body", palette.text, "Catalog Editor", 4)
    Manager.sourceLabel = createLabel(Manager.editorCard, "ZCityShop.Small", palette.textDim, "Select an addon item or create a custom entry.", 4)
    Manager.sourceLabel:SetWrap(true)
    Manager.previewModel = vgui.Create("DModelPanel", Manager.editorCard)
    Manager.previewModel:SetFOV(24)
    Manager.previewModel:SetAnimated(true)

    Manager.nameLabel = createLabel(Manager.editorCard, "ZCityShop.Small", palette.textDim, "Display Name", 4)
    Manager.nameEntry = vgui.Create("DTextEntry", Manager.editorCard)
    styleTextEntry(Manager.nameEntry)

    Manager.classLabel = createLabel(Manager.editorCard, "ZCityShop.Small", palette.textDim, "Class Name", 4)
    Manager.classEntry = vgui.Create("DTextEntry", Manager.editorCard)
    styleTextEntry(Manager.classEntry)

    Manager.priceLabel = createLabel(Manager.editorCard, "ZCityShop.Small", palette.textDim, "Price", 4)
    Manager.priceEntry = vgui.Create("DTextEntry", Manager.editorCard)
    Manager.priceEntry:SetNumeric(true)
    styleTextEntry(Manager.priceEntry)

    Manager.categoryLabel = createLabel(Manager.editorCard, "ZCityShop.Small", palette.textDim, "Category", 4)
    Manager.categoryCombo = vgui.Create("DComboBox", Manager.editorCard)
    Manager.categoryCombo:AddChoice("Armor", "armor")
    Manager.categoryCombo:AddChoice("Attachment", "attachment")
    Manager.categoryCombo:AddChoice("Misc", "misc")
    Manager.categoryCombo.SelectedData = "armor"
    Manager.categoryCombo.OnSelect = function(_, _, _, data)
        Manager.categoryCombo.SelectedData = data
    end
    styleComboBox(Manager.categoryCombo)

    Manager.kindLabel = createLabel(Manager.editorCard, "ZCityShop.Small", palette.textDim, "Delivery Type", 4)
    Manager.kindCombo = vgui.Create("DComboBox", Manager.editorCard)
    Manager.kindCombo:AddChoice("Weapon SWEP", "weapon")
    Manager.kindCombo:AddChoice("Entity", "entity")
    Manager.kindCombo.SelectedData = "weapon"
    Manager.kindCombo.OnSelect = function(_, _, _, data)
        Manager.kindCombo.SelectedData = data
    end
    styleComboBox(Manager.kindCombo)

    Manager.addButton = vgui.Create("DButton", Manager.editorCard)
    Manager.addButton:SetText("Add Or Update Catalog Item")
    styleButton(Manager.addButton, palette.accent, palette.accentSoft)
    Manager.addButton.DoClick = saveEditorItem

    Manager.newButton = vgui.Create("DButton", Manager.editorCard)
    Manager.newButton:SetText("New Empty Item")
    styleButton(Manager.newButton, palette.panel, palette.hover)
    Manager.newButton.DoClick = clearEditor

    Manager.removeButton = vgui.Create("DButton", Manager.editorCard)
    Manager.removeButton:SetText("Remove Selected Catalog Item")
    styleButton(Manager.removeButton, palette.danger, palette.dangerSoft)
    Manager.removeButton.DoClick = removeCatalogItem

    Manager.editorScroll = vgui.Create("DScrollPanel", Manager.editorCard)
    Manager.editorCanvas = Manager.editorScroll:GetCanvas()

    for _, child in ipairs({
        Manager.editorTitle,
        Manager.sourceLabel,
        Manager.previewModel,
        Manager.nameLabel,
        Manager.nameEntry,
        Manager.classLabel,
        Manager.classEntry,
        Manager.priceLabel,
        Manager.priceEntry,
        Manager.categoryLabel,
        Manager.categoryCombo,
        Manager.kindLabel,
        Manager.kindCombo,
        Manager.addButton,
        Manager.newButton,
        Manager.removeButton
    }) do
        child:SetParent(Manager.editorCanvas)
    end

    Manager.catalogCard = createCard(panel, palette.panelSoft)
    Manager.catalogTitle = createLabel(Manager.catalogCard, "ZCityShop.Body", palette.text, "Current Shop Catalog", 4)
    Manager.catalogInfo = createLabel(Manager.catalogCard, "ZCityShop.Small", palette.textDim, "Select a catalog row to edit or remove it.", 4)
    Manager.catalogSearchEntry = vgui.Create("DTextEntry", Manager.catalogCard)
    styleTextEntry(Manager.catalogSearchEntry)
    Manager.catalogSearchEntry:SetPlaceholderText("Search current catalog")
    Manager.catalogSearchEntry.OnValueChange = function()
        redrawCatalogList()
    end
    Manager.catalogList = vgui.Create("DListView", Manager.catalogCard)
    Manager.catalogList:SetMultiSelect(false)
    Manager.catalogList:AddColumn("Name")
    Manager.catalogList:AddColumn("Category")
    Manager.catalogList:AddColumn("Price")
    styleListView(Manager.catalogList)
    Manager.catalogList.OnRowSelected = function(_, _, line)
        selectCatalogItem(line.ItemId)
    end
    Manager.catalogStatusLabel = createLabel(Manager.catalogCard, "ZCityShop.Small", palette.textDim, "", 4)
    Manager.catalogStatusLabel:SetWrap(true)
    Manager.saveCatalogButton = vgui.Create("DButton", Manager.catalogCard)
    Manager.saveCatalogButton:SetText("Save Catalog To Server")
    styleButton(Manager.saveCatalogButton, palette.success, palette.successSoft)
    Manager.saveCatalogButton.DoClick = saveCatalogToServer

    Manager.npcCard = createCard(panel, palette.panelSoft)
    Manager.npcTitle = createLabel(Manager.npcCard, "ZCityShop.Body", palette.text, "NPC Settings", 4)
    Manager.npcInfo = createLabel(Manager.npcCard, "ZCityShop.Small", palette.textDim, "Rename the trader and manage NPC spawns for the current map.", 4)
    Manager.npcNameLabel = createLabel(Manager.npcCard, "ZCityShop.Small", palette.textDim, "NPC Name", 4)
    Manager.npcNameEntry = vgui.Create("DTextEntry", Manager.npcCard)
    styleTextEntry(Manager.npcNameEntry)
    Manager.saveNPCButton = vgui.Create("DButton", Manager.npcCard)
    Manager.saveNPCButton:SetText("Save NPC Name")
    styleButton(Manager.saveNPCButton, palette.accent, palette.accentSoft)
    Manager.saveNPCButton.DoClick = saveNPCName
    Manager.spawnNPCButton = vgui.Create("DButton", Manager.npcCard)
    Manager.spawnNPCButton:SetText("Spawn NPC At Crosshair")
    styleButton(Manager.spawnNPCButton, palette.success, palette.successSoft)
    Manager.spawnNPCButton.DoClick = function()
        RunConsoleCommand(Config.SpawnNPCCommand)
    end
    Manager.removeNPCButton = vgui.Create("DButton", Manager.npcCard)
    Manager.removeNPCButton:SetText("Remove Looked-At NPC")
    styleButton(Manager.removeNPCButton, palette.danger, palette.dangerSoft)
    Manager.removeNPCButton.DoClick = function()
        RunConsoleCommand(Config.RemoveNPCCommand)
    end
    Manager.removeAllNPCsButton = vgui.Create("DButton", Manager.npcCard)
    Manager.removeAllNPCsButton:SetText("Remove All Traders On Map")
    styleButton(Manager.removeAllNPCsButton, palette.danger, palette.dangerSoft)
    Manager.removeAllNPCsButton.DoClick = function()
        RunConsoleCommand(Config.RemoveAllNPCsCommand)
    end

    Manager.availableCard.PerformLayout = function(self, w, h)
        local pad = 16
        Manager.availableTitle:SetPos(pad, 14)
        Manager.availableTitle:SetSize(w - pad * 2, 22)
        Manager.availableInfo:SetPos(pad, 38)
        Manager.availableInfo:SetSize(w - pad * 2, 18)
        Manager.availableSearchEntry:SetPos(pad, 68)
        Manager.availableSearchEntry:SetSize(w - pad * 2 - 120, 34)
        Manager.availableCount:SetPos(w - 108, 74)
        Manager.availableCount:SetSize(92, 18)
        Manager.categoryRow:SetPos(pad, 114)
        Manager.categoryRow:SetSize(w - pad * 2, 36)

        local categoryWidth = math.floor((Manager.categoryRow:GetWide() - 6) / 2)
        local x = 0
        for _, key in ipairs({ "armor", "attachment" }) do
            local button = Manager.categoryButtons[key]
            button:SetPos(x, 0)
            button:SetSize(categoryWidth, 36)
            x = x + categoryWidth + 6
        end

        Manager.availableList:SetPos(pad, 162)
        Manager.availableList:SetSize(w - pad * 2, h - 178)
    end

    Manager.editorCard.PerformLayout = function(self, w, h)
        local pad = 16
        local contentWidth = w - pad * 2 - 8
        local y = 14

        Manager.editorScroll:SetPos(0, 0)
        Manager.editorScroll:SetSize(w, h)

        Manager.editorTitle:SetPos(pad, y)
        Manager.editorTitle:SetSize(contentWidth, 22)
        y = y + 26

        Manager.sourceLabel:SetPos(pad, y)
        Manager.sourceLabel:SetSize(contentWidth, 44)
        y = y + 52

        Manager.previewModel:SetPos(pad, y)
        Manager.previewModel:SetSize(contentWidth, 152)
        y = y + 164

        Manager.nameLabel:SetPos(pad, y)
        Manager.nameLabel:SetSize(contentWidth, 18)
        y = y + 20
        Manager.nameEntry:SetPos(pad, y)
        Manager.nameEntry:SetSize(contentWidth, 34)
        y = y + 46

        Manager.classLabel:SetPos(pad, y)
        Manager.classLabel:SetSize(contentWidth, 18)
        y = y + 20
        Manager.classEntry:SetPos(pad, y)
        Manager.classEntry:SetSize(contentWidth, 34)
        y = y + 46

        Manager.priceLabel:SetPos(pad, y)
        Manager.priceLabel:SetSize(contentWidth, 18)
        y = y + 20
        Manager.priceEntry:SetPos(pad, y)
        Manager.priceEntry:SetSize(contentWidth, 34)
        y = y + 46

        Manager.categoryLabel:SetPos(pad, y)
        Manager.categoryLabel:SetSize(contentWidth, 18)
        y = y + 20
        Manager.categoryCombo:SetPos(pad, y)
        Manager.categoryCombo:SetSize(contentWidth, 34)
        y = y + 46

        Manager.kindLabel:SetPos(pad, y)
        Manager.kindLabel:SetSize(contentWidth, 18)
        y = y + 20
        Manager.kindCombo:SetPos(pad, y)
        Manager.kindCombo:SetSize(contentWidth, 34)
        y = y + 52

        Manager.addButton:SetPos(pad, y)
        Manager.addButton:SetSize(contentWidth, 38)
        y = y + 46

        Manager.newButton:SetPos(pad, y)
        Manager.newButton:SetSize(contentWidth, 34)
        y = y + 42

        Manager.removeButton:SetPos(pad, y)
        Manager.removeButton:SetSize(contentWidth, 34)
        y = y + 46

        Manager.editorCanvas:SetWide(w - 8)
        Manager.editorCanvas:SetTall(y)
    end

    Manager.catalogCard.PerformLayout = function(self, w, h)
        local pad = 16
        Manager.catalogTitle:SetPos(pad, 14)
        Manager.catalogTitle:SetSize(w - pad * 2, 22)
        Manager.catalogInfo:SetPos(pad, 38)
        Manager.catalogInfo:SetSize(w - pad * 2, 18)
        Manager.catalogSearchEntry:SetPos(pad, 68)
        Manager.catalogSearchEntry:SetSize(w - pad * 2, 34)
        Manager.catalogList:SetPos(pad, 114)
        Manager.catalogList:SetSize(w - pad * 2, h - 204)
        Manager.catalogStatusLabel:SetPos(pad, h - 82)
        Manager.catalogStatusLabel:SetSize(w - pad * 2, 34)
        Manager.saveCatalogButton:SetPos(pad, h - 42)
        Manager.saveCatalogButton:SetSize(w - pad * 2, 34)
    end

    Manager.npcCard.PerformLayout = function(self, w, h)
        local pad = 16
        local halfWidth = math.floor((w - pad * 2 - 8) * 0.5)
        Manager.npcTitle:SetPos(pad, 14)
        Manager.npcTitle:SetSize(w - pad * 2, 22)
        Manager.npcInfo:SetPos(pad, 38)
        Manager.npcInfo:SetSize(w - pad * 2, 18)
        Manager.npcNameLabel:SetPos(pad, 68)
        Manager.npcNameLabel:SetSize(w - pad * 2, 18)
        Manager.npcNameEntry:SetPos(pad, 90)
        Manager.npcNameEntry:SetSize(w - pad * 2, 34)
        Manager.saveNPCButton:SetPos(pad, 136)
        Manager.saveNPCButton:SetSize(w - pad * 2, 36)
        Manager.spawnNPCButton:SetPos(pad, 180)
        Manager.spawnNPCButton:SetSize(halfWidth, 36)
        Manager.removeNPCButton:SetPos(pad + halfWidth + 8, 180)
        Manager.removeNPCButton:SetSize(halfWidth, 36)
        Manager.removeAllNPCsButton:SetPos(pad, 224)
        Manager.removeAllNPCsButton:SetSize(w - pad * 2, 36)
    end

    panel.PerformLayout = function(self, w, h)
        local pad = 20
        local gap = 16
        local columnsTop = 142
        local leftWidth = math.floor((w - pad * 2 - gap * 2) * 0.38)
        local middleWidth = math.floor((w - pad * 2 - gap * 2) * 0.25)
        local rightWidth = w - pad * 2 - gap * 2 - leftWidth - middleWidth
        local mainHeight = h - columnsTop - pad
        local catalogHeight = math.min(math.floor(mainHeight * 0.58), math.max(220, mainHeight - 280))
        local npcHeight = mainHeight - catalogHeight - gap

        Manager.titleLabel:SetPos(pad, 18)
        Manager.titleLabel:SetSize(w - pad * 2, 26)
        Manager.subtitleLabel:SetPos(pad, 48)
        Manager.subtitleLabel:SetSize(w - pad * 2, 20)
        Manager.noticeLabel:SetPos(pad, 76)
        Manager.noticeLabel:SetSize(w - pad * 2, 46)

        Manager.availableCard:SetPos(pad, columnsTop)
        Manager.availableCard:SetSize(leftWidth, mainHeight)

        Manager.editorCard:SetPos(pad + leftWidth + gap, columnsTop)
        Manager.editorCard:SetSize(middleWidth, mainHeight)

        Manager.catalogCard:SetPos(pad + leftWidth + gap + middleWidth + gap, columnsTop)
        Manager.catalogCard:SetSize(rightWidth, catalogHeight)

        Manager.npcCard:SetPos(pad + leftWidth + gap + middleWidth + gap, columnsTop + catalogHeight + gap)
        Manager.npcCard:SetSize(rightWidth, npcHeight)
    end

    return panel
end

resizeFrameForSection = function()
    if not IsValid(frame) or not IsValid(Main.body) then return end

    local width, height = computeFrameSize(activeSection)
    frame:SetSize(width, height)
    frame:Center()

    if activeSection == "shop" then
        Main.body:DockMargin(10, 38, 10, 10)
    else
        Main.body:DockMargin(18, 106, 18, 18)
    end

    frame:InvalidateLayout(true)
end

switchSection = function(sectionName)
    if sectionName == "manager" and not Client.State.canManage then
        sectionName = "shop"
    end

    activeSection = sectionName

    for key, panel in pairs(Main.sections) do
        if IsValid(panel) then
            panel:SetVisible(key == sectionName)
        end
    end

    for key, button in pairs(Main.navButtons) do
        if IsValid(button) then
            local shouldShow = key ~= "manager" or Client.State.canManage
            button:SetVisible(shouldShow)
            button.IsActive = shouldShow and key == sectionName
        end
    end

    if sectionName == "manager" then
        requestDetectedCatalog()
    end

    if IsValid(frame) then
        resizeFrameForSection()
        frame:InvalidateLayout(true)
    end
end

redrawShopList = function()
    if not IsValid(Buyer.listLayout) then return end

    local items = duplicateItems(Client.State.items)
    local filter = trim(IsValid(Buyer.searchEntry) and Buyer.searchEntry:GetValue() or "")
    local firstVisibleId
    local visibleSelected = false

    sortItems(items)
    Buyer.listLayout:Clear()

    for _, item in ipairs(items) do
        if matchFilter(filter, item.name, item.class, item.category, categoryLabel(item.category)) then
            local row = vgui.Create("DButton")
            local buyButton
            row:SetText("")
            row:SetTall(78)
            row:DockMargin(0, 0, 0, 8)
            row.ItemId = item.id
            row.ItemData = item
            row.Paint = function(self, w, h)
                local selected = selectedShopId == self.ItemId
                local bg = selected and Color(43, 49, 84, 210) or (self:IsHovered() and Color(34, 38, 66, 205) or Color(32, 36, 58, 188))
                draw.RoundedBox(10, 0, 0, w, h, bg)
                surface.SetDrawColor(Color(68, 74, 124, 130))
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            row.DoClick = function(self)
                selectShopItem(self.ItemId)
            end
            row.PerformLayout = function(self, w, h)
                if IsValid(buyButton) then
                    buyButton:SetPos(w - 122, 14)
                    buyButton:SetSize(108, 50)
                end
            end

            local icon = vgui.Create("SpawnIcon", row)
            icon:SetPos(10, 10)
            icon:SetSize(58, 58)
            icon:SetModel(resolveItemModel(item))
            icon:SetTooltip(false)
            icon.DoClick = function()
                row:DoClick()
            end

            local nameLabel = createLabel(row, "ZCityShop.Body", palette.text, item.name or "Unknown Item", 4)
            nameLabel:SetPos(82, 14)
            nameLabel:SetSize(240, 20)

            local categoryLabelView = createLabel(row, "ZCityShop.Small", palette.textDim, categoryLabel(item.category), 4)
            categoryLabelView:SetPos(82, 34)
            categoryLabelView:SetSize(140, 18)

            local priceLabel = createLabel(row, "ZCityShop.Body", Color(255, 106, 106), formatMoney(item.price), 4)
            priceLabel:SetPos(82, 52)
            priceLabel:SetSize(180, 18)

            buyButton = vgui.Create("DButton", row)
            buyButton:SetText("Buy")
            buyButton:SetPos(row:GetWide() - 122, 14)
            buyButton:SetSize(108, 50)
            styleButton(buyButton, Color(65, 62, 180), Color(84, 82, 215))
            buyButton.DoClick = function()
                selectShopItem(item.id)
                net.Start("ZCityDarkRPShop.BuyItem")
                net.WriteString(item.id)
                net.SendToServer()
            end

            Buyer.listLayout:Add(row)

            if not firstVisibleId then
                firstVisibleId = item.id
            end

            if selectedShopId == item.id then
                visibleSelected = true
            end
        end
    end

    if not visibleSelected then
        selectedShopId = firstVisibleId
    end

    selectedShopItem = selectedShopId and findItem(Client.State.items, selectedShopId) or nil
    updateBuyerDetails()
end

redrawAvailableList = function()
    if not IsValid(Manager.availableList) then return end

    local items = Client.DetectedCatalog[activeAvailableCategory] or {}
    local filter = trim(IsValid(Manager.availableSearchEntry) and Manager.availableSearchEntry:GetValue() or "")
    local firstVisible
    local visibleSelected = false
    local count = 0

    Manager.availableList:Clear()

    for _, item in ipairs(items) do
        if matchFilter(filter, item.name, item.class, item.source, item.category) then
            local line = addStyledLine(
                Manager.availableList,
                item.name or item.class or "Unknown",
                item.class or "-",
                item.source or "-"
            )
            line.DetectedItem = item

            if not firstVisible then
                firstVisible = item
            end

            if selectedAvailableItem and selectedAvailableItem.class == item.class and normalizeKind(selectedAvailableItem) == normalizeKind(item) then
                visibleSelected = true
            end

            count = count + 1
        end
    end

    if IsValid(Manager.availableCount) then
        Manager.availableCount:SetText(string.format("%d shown", count))
    end

    updateCategoryButtons()

    if not visibleSelected then
        selectedAvailableItem = firstVisible
    end

    if autoLoadAvailableOnRefresh and selectedAvailableItem and not selectedCatalogId then
        selectAvailableItem(selectedAvailableItem)
    end

    selectListLineByValue(Manager.availableList, "DetectedItem", selectedAvailableItem)
end

redrawCatalogList = function()
    if not IsValid(Manager.catalogList) then return end

    local items = duplicateItems(catalogItems)
    local filter = trim(IsValid(Manager.catalogSearchEntry) and Manager.catalogSearchEntry:GetValue() or "")
    local firstVisibleId
    local visibleSelected = false

    sortItems(items)
    Manager.catalogList:Clear()

    for _, item in ipairs(items) do
        if matchFilter(filter, item.name, item.class, item.category, categoryLabel(item.category)) then
            local line = addStyledLine(
                Manager.catalogList,
                item.name,
                categoryLabel(item.category),
                formatMoney(item.price)
            )
            line.ItemId = item.id

            if not firstVisibleId then
                firstVisibleId = item.id
            end

            if selectedCatalogId == item.id then
                visibleSelected = true
            end
        end
    end

    if selectedCatalogId and not visibleSelected then
        selectedCatalogId = nil
        selectedCatalogItem = nil
    end

    updateManagerStatus()
    updateEditorButtons()

    if selectedCatalogId then
        selectListLineByValue(Manager.catalogList, "ItemId", selectedCatalogId)
    end
end

refreshAll = function()
    if not catalogDirty then
        catalogItems = duplicateItems(Client.State.items)
    end

    updateStatCards()
    updateManagerStatus()
    redrawShopList()
    redrawCatalogList()
    redrawAvailableList()

    if activeSection == "manager" and not Client.State.canManage then
        switchSection("shop")
    else
        switchSection(activeSection or "shop")
    end
end

local function openMenu(targetSection)
    local desiredSection = targetSection or activeSection or "shop"

    if IsValid(frame) then
        frame:MakePopup()
        switchSection(desiredSection)
        requestState()
        return
    end

    local width, height = computeFrameSize(desiredSection)

    frame = vgui.Create("DFrame")
    frame:SetSize(width, height)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(true)
    frame:SetSizable(true)
    frame:SetScreenLock(true)
    frame:MakePopup()
    frame.Paint = function(self, w, h)
        if activeSection == "shop" then
            draw.RoundedBox(14, 0, 0, w, h, Color(12, 16, 28, 225))
            draw.RoundedBoxEx(14, 0, 0, w, 30, Color(51, 57, 110, 240), true, true, false, false)
            surface.SetDrawColor(Color(86, 95, 170, 120))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            return
        end

        draw.RoundedBox(18, 0, 0, w, h, palette.bg)
        draw.RoundedBoxEx(18, 0, 0, w, 96, palette.header, true, true, false, false)
        draw.SimpleText("Z-City DarkRP Trader", "ZCityShop.Title", 28, 30, palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Bigger shop layout, clearer catalog editor, and 3D item preview.", "ZCityShop.Body", 28, 66, palette.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    frame.OnRemove = function()
        frame = nil
        selectedAvailableItem = nil
        selectedCatalogId = nil
        selectedCatalogItem = nil
        selectedShopItem = nil
    end

    local closeButton = vgui.Create("DButton", frame)
    Main.closeButton = closeButton
    closeButton:SetText("X")
    closeButton:SetSize(46, 34)
    styleButton(closeButton, palette.danger, palette.dangerSoft)
    closeButton.DoClick = function()
        frame:Close()
    end

    local body = vgui.Create("DPanel", frame)
    body.Paint = nil
    Main.body = body

    Main.walletCard = createStatCard(body, "Wallet")
    Main.walletValue = Main.walletCard.ValueLabel
    Main.walletSubtitle = Main.walletCard.SubtitleLabel

    Main.controlCard = createStatCard(body, "Trader Control")
    Main.controlValue = Main.controlCard.ValueLabel
    Main.controlSubtitle = Main.controlCard.SubtitleLabel

    Main.navCard = createCard(body, palette.panel)
    Main.navTitle = createLabel(Main.navCard, "ZCityShop.Section", palette.text, "Menu", 4)
    Main.navInfo = createLabel(Main.navCard, "ZCityShop.Small", palette.textDim, "Use Shop to buy items and Trader Manager to curate the catalog.", 4)
    Main.navInfo:SetWrap(true)

    Main.navButtons.shop = vgui.Create("DButton", Main.navCard)
    Main.navButtons.shop:SetText("Shop")
    styleNavButton(Main.navButtons.shop)
    Main.navButtons.shop.DoClick = function()
        switchSection("shop")
    end

    Main.navButtons.manager = vgui.Create("DButton", Main.navCard)
    Main.navButtons.manager:SetText("Trader Manager")
    styleNavButton(Main.navButtons.manager)
    Main.navButtons.manager.DoClick = function()
        switchSection("manager")
    end

    Main.sectionWrap = vgui.Create("DPanel", body)
    Main.sectionWrap.Paint = nil

    Main.sections.shop = createBuyerSection(Main.sectionWrap)
    Main.sections.manager = createManagerSection(Main.sectionWrap)

    body.PerformLayout = function(self, w, h)
        local managerMode = activeSection == "manager"

        if managerMode then
            local pad = 18
            local gap = 14
            local navWidth = 210
            local statWidth = math.floor((w - pad * 2 - gap) / 2)

            closeButton:SetSize(46, 34)
            closeButton:SetPos(frame:GetWide() - 62, 28)

            Main.walletCard:SetVisible(true)
            Main.controlCard:SetVisible(true)
            Main.navCard:SetVisible(true)

            Main.walletCard:SetPos(pad, 0)
            Main.walletCard:SetSize(statWidth, 98)
            Main.controlCard:SetPos(pad + statWidth + gap, 0)
            Main.controlCard:SetSize(statWidth, 98)

            Main.navCard:SetPos(pad, 114)
            Main.navCard:SetSize(navWidth, h - 114)
            Main.navTitle:SetPos(16, 14)
            Main.navTitle:SetSize(navWidth - 32, 24)
            Main.navInfo:SetPos(16, 42)
            Main.navInfo:SetSize(navWidth - 32, 42)
            Main.navButtons.shop:SetPos(16, 98)
            Main.navButtons.shop:SetSize(navWidth - 32, 40)
            Main.navButtons.manager:SetPos(16, 146)
            Main.navButtons.manager:SetSize(navWidth - 32, 40)

            Main.sectionWrap:SetPos(pad + navWidth + gap, 114)
            Main.sectionWrap:SetSize(w - pad * 2 - navWidth - gap, h - 114)
        else
            closeButton:SetSize(38, 24)
            closeButton:SetPos(frame:GetWide() - 46, 4)

            Main.walletCard:SetVisible(false)
            Main.controlCard:SetVisible(false)
            Main.navCard:SetVisible(false)
            Main.sectionWrap:SetPos(0, 0)
            Main.sectionWrap:SetSize(w, h)
        end

        for _, section in pairs(Main.sections) do
            if IsValid(section) then
                section:SetPos(0, 0)
                section:SetSize(Main.sectionWrap:GetWide(), Main.sectionWrap:GetTall())
            end
        end
    end

    body:Dock(FILL)
    body:DockMargin(18, 106, 18, 18)

    updateStatCards()
    clearEditor()
    switchSection(desiredSection)
    resizeFrameForSection()
    requestState()
end

net.Receive("ZCityDarkRPShop.State", function()
    local payload = util.JSONToTable(net.ReadString() or "")
    if not istable(payload) then return end

    Client.State.items = payload.items or {}
    Client.State.balance = math.floor(tonumber(payload.balance) or 0)
    Client.State.balanceText = payload.balanceText or "$0"
    Client.State.canManage = payload.canManage == true
    Client.State.managerGroup = payload.managerGroup or ""
    Client.State.manageReason = payload.manageReason or ""
    Client.State.darkRPReady = payload.darkRPReady == true
    Client.State.npcCount = math.max(0, math.floor(tonumber(payload.npcCount) or 0))
    Client.State.npcName = payload.npcName or Config.NPCName

    refreshAll()
end)

net.Receive("ZCityDarkRPShop.DetectedCatalog", function()
    local length = net.ReadUInt(32)
    local data = net.ReadData(length)
    local json = util.Decompress(data or "")
    if not json then return end

    local payload = util.JSONToTable(json)
    if not istable(payload) then return end

    Client.DetectedCatalog.weapon = payload.weapon or {}
    Client.DetectedCatalog.armor = payload.armor or {}
    Client.DetectedCatalog.ammo = payload.ammo or {}
    Client.DetectedCatalog.attachment = payload.attachment or {}

    redrawAvailableList()
end)

net.Receive("ZCityDarkRPShop.Notify", function()
    local success = net.ReadBool()
    local message = trim(net.ReadString())
    if message == "" then
        message = success and "The action completed." or "The server returned an empty error. Check the server console for details."
    end

    if success and string.find(message or "", "Catalog saved", 1, true) then
        catalogDirty = false
        requestState()
    end

    if success and string.find(message or "", "NPC settings saved", 1, true) then
        requestState()
    end

    notification.AddLegacy(message, success and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
    surface.PlaySound(success and "buttons/button15.wav" or "buttons/button10.wav")
end)

net.Receive("ZCityDarkRPShop.OpenMenu", function()
    openMenu(net.ReadString() or "shop")
end)

if trim(Config.MenuCommand) ~= "" then
    concommand.Add(Config.MenuCommand, function()
        openMenu("shop")
    end)
end

concommand.Add(Config.AdminMenuCommand, function()
    if not Client.State.canManage then
        requestState()
        timer.Simple(0.15, function()
            if not IsValid(LocalPlayer()) then return end

            if Client.State.canManage then
                openMenu("manager")
                requestDetectedCatalog()
            else
                notifyLocal(false, Client.State.manageReason ~= "" and Client.State.manageReason or "ULX admin or superadmin is required.")
            end
        end)
        return
    end

    openMenu("manager")
    requestDetectedCatalog()
end)

hook.Add("OnPlayerChat", "ZCityDarkRPShop.ChatCommands", function(ply, text)
    if ply ~= LocalPlayer() then return end

    local command = string.lower(trim(text))
    local target = Config.ChatCommands[command]
    if not target then return end

    if target == "admin" then
        RunConsoleCommand(Config.AdminMenuCommand)
        return true
    end
end)

hook.Add("PopulateToolMenu", "ZCityDarkRPShop.ToolMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Z-City", "ZCityDarkRPShop", "DarkRP NPC Shop", "", "", function(panel)
        panel:ClearControls()
        panel:Help("Standalone NPC shop for DarkRP with ULX-based trader management.")
        if Client.State.canManage then
            panel:Button("Open Trader Manager", Config.AdminMenuCommand)
            panel:Button("Spawn NPC At Crosshair", Config.SpawnNPCCommand)
            panel:Button("Remove Looked-At NPC", Config.RemoveNPCCommand)
            panel:Button("Remove All Traders On Map", Config.RemoveAllNPCsCommand)
        else
            panel:Help("Trader management is limited to ULX admin and superadmin.")
        end
    end)
end)
