ZCityDarkRPShop = ZCityDarkRPShop or {}
ZCityDarkRPShop.Scoreboard = ZCityDarkRPShop.Scoreboard or {}

local Scoreboard = ZCityDarkRPShop.Scoreboard

local panel
local listPanel
local scoreboardVisible = false
local blurMat = Material("pp/blurscreen")
local userMat = Material("icon16/user.png", "smooth")
local adminMat = Material("icon16/shield.png", "smooth")
local superAdminMat = Material("icon16/award_star_gold_1.png", "smooth")
local activeMat = Material("icon16/status_online.png", "smooth")

surface.CreateFont("ZCityScoreboard.Row", {
    font = "Trebuchet24",
    size = 20,
    weight = 800,
    antialias = true
})

local function drawBlur(panelRef, passes)
    local x, y = panelRef:LocalToScreen(0, 0)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(blurMat)

    for i = 1, passes do
        blurMat:SetFloat("$blur", (i / passes) * 5)
        blurMat:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

local function scoreboardKeyCode()
    local bind = input.LookupBinding("+showscores")
    if bind and bind ~= "" then
        local code = input.GetKeyCode(string.upper(bind))
        if code and code >= 0 then
            return code
        end
    end

    return KEY_TAB
end

local function closeForeignScoreboards()
    if FAdmin and FAdmin.ScoreBoard and FAdmin.ScoreBoard.Visible and FAdmin.ScoreBoard.HideScoreBoard then
        FAdmin.ScoreBoard.HideScoreBoard()
    end

    if gui.EnableScreenClicker then
        gui.EnableScreenClicker(false)
    end
end

local function disableForeignScoreboardHooks()
    hook.Remove("ScoreboardShow", "FAdmin_scoreboard")
    hook.Remove("ScoreboardHide", "FAdmin_scoreboard")
end

local function rankMaterial(ply)
    local group = IsValid(ply) and ply.GetUserGroup and string.lower(ply:GetUserGroup() or "") or ""
    if group == "superadmin" then
        return superAdminMat, Color(241, 190, 69)
    end

    if group == "admin" then
        return adminMat, Color(113, 173, 255)
    end

    return userMat, Color(208, 208, 208)
end

local function sortedPlayers()
    local players = player.GetAll()

    table.sort(players, function(left, right)
        if left == LocalPlayer() then return true end
        if right == LocalPlayer() then return false end

        local leftGroup = IsValid(left) and left.GetUserGroup and string.lower(left:GetUserGroup() or "") or ""
        local rightGroup = IsValid(right) and right.GetUserGroup and string.lower(right:GetUserGroup() or "") or ""

        if leftGroup ~= rightGroup then
            local leftWeight = leftGroup == "superadmin" and 0 or (leftGroup == "admin" and 1 or 2)
            local rightWeight = rightGroup == "superadmin" and 0 or (rightGroup == "admin" and 1 or 2)
            if leftWeight ~= rightWeight then
                return leftWeight < rightWeight
            end
        end

        return string.lower(left:Nick() or "") < string.lower(right:Nick() or "")
    end)

    return players
end

local function rebuildRows()
    if not IsValid(listPanel) then return end

    local players = sortedPlayers()
    listPanel:Clear()

    for _, ply in ipairs(players) do
        local row = vgui.Create("DPanel")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 6)
        row:SetTall(46)
        row.PlayerRef = ply
        row.Paint = function(self, w, h)
            local target = self.PlayerRef
            local isLocal = target == LocalPlayer()
            local leftMat = isLocal and activeMat or userMat
            local rightMat, rightColor = rankMaterial(target)
            local leftColor = isLocal and Color(130, 210, 128) or Color(220, 220, 220)

            draw.RoundedBox(0, 0, 0, w, h, Color(38, 38, 38, 232))
            surface.SetDrawColor(Color(16, 16, 16, 220))
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            surface.SetMaterial(leftMat)
            surface.SetDrawColor(leftColor)
            surface.DrawTexturedRect(14, 15, 16, 16)

            draw.SimpleText(IsValid(target) and target:Nick() or "Connecting...", "ZCityScoreboard.Row", 40, h / 2, Color(244, 244, 244), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            surface.SetMaterial(rightMat)
            surface.SetDrawColor(rightColor)
            surface.DrawTexturedRect(w - 28, 15, 16, 16)
        end

        listPanel:Add(row)
    end

    if IsValid(panel) and IsValid(panel.Wrap) then
        local width = math.min(800, ScrW() - 120)
        local height = math.min(560, math.max(90, (#players * 52)))
        panel.Wrap:SetSize(width, height)
        panel.Wrap:SetPos((ScrW() - width) * 0.5, (ScrH() - height) * 0.5)
    end
end

local function ensurePanel()
    if IsValid(panel) then return end

    panel = vgui.Create("EditablePanel")
    panel:SetSize(ScrW(), ScrH())
    panel:SetPos(0, 0)
    panel:SetVisible(false)
    panel:SetMouseInputEnabled(false)
    panel:SetKeyboardInputEnabled(false)
    panel.NextRefresh = 0
    panel.Paint = function(self, w, h)
        drawBlur(self, 3)
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(0, 0, w, h)
    end
    panel.Think = function(self)
        if not self:IsVisible() then return end
        if CurTime() < (self.NextRefresh or 0) then return end
        self.NextRefresh = CurTime() + 0.75
        rebuildRows()
    end

    local wrap = vgui.Create("DPanel", panel)
    wrap.Paint = nil
    wrap.PerformLayout = function(self, w, h)
        local width = math.min(800, ScrW() - 120)
        local height = math.min(560, math.max(90, (#player.GetAll() * 52)))
        self:SetSize(width, height)
        self:SetPos((ScrW() - width) * 0.5, (ScrH() - height) * 0.5)
    end
    panel.Wrap = wrap

    local scroll = vgui.Create("DScrollPanel", wrap)
    scroll:Dock(FILL)

    local bar = scroll:GetVBar()
    bar:SetWide(0)
    bar.Paint = function() end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function() end

    listPanel = vgui.Create("DListLayout", scroll)
    listPanel:Dock(TOP)

    wrap:InvalidateLayout(true)
end

local function openScoreboard()
    disableForeignScoreboardHooks()
    closeForeignScoreboards()
    ensurePanel()

    if not IsValid(panel) then
        return false
    end

    scoreboardVisible = true
    panel:SetSize(ScrW(), ScrH())
    panel:SetVisible(true)
    panel:MoveToFront()
    if IsValid(panel.Wrap) then
        panel.Wrap:InvalidateLayout(true)
    end
    rebuildRows()
    return false
end

local function hideScoreboard()
    scoreboardVisible = false
    closeForeignScoreboards()

    if IsValid(panel) then
        panel:SetVisible(false)
    end

    return false
end

hook.Add("ScoreboardShow", "ZCityAftermath.ScoreboardShow", function()
    return openScoreboard()
end)

hook.Add("ScoreboardHide", "ZCityAftermath.ScoreboardHide", function()
    return hideScoreboard()
end)

hook.Add("PlayerBindPress", "ZCityAftermath.ScoreboardBindPress", function(_, bind, pressed)
    if not pressed then return end

    if string.find(string.lower(bind or ""), "+showscores", 1, true) then
        openScoreboard()
        return true
    end
end)

hook.Add("Think", "ZCityAftermath.ScoreboardForceClose", function()
    if not scoreboardVisible then return end

    if not input.IsKeyDown(scoreboardKeyCode()) then
        hideScoreboard()
    end
end)

hook.Add("InitPostEntity", "ZCityAftermath.DisableForeignScoreboards", function()
    disableForeignScoreboardHooks()

    timer.Create("ZCityAftermath.DisableForeignScoreboardsTimer", 2, 5, function()
        disableForeignScoreboardHooks()
    end)
end)
