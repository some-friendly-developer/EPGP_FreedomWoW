--[[
    EPGP - Battlegrounds plugin, reward window.

    Shown to the guild member that was elected to hand out the EP once he is
    teleported out of the battleground.
]]--

local mod = EPGPBattlegrounds

local NUM_ROWS      = 12
local ROW_HEIGHT    = 20
local FRAME_WIDTH   = 520
local LIST_WIDTH    = FRAME_WIDTH - 36

local X_CHECK       = 4
local X_NAME        = 30
local X_RANK        = 160
local X_KB          = 290
local X_HK          = 335
local X_DEATHS      = 380
local X_HONOR       = 425

local EDIT_HEIGHT   = 20

local INPUT_BACKDROP = {
    bgFile      = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile    = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets      = { left = 2, right = 2, top = 2, bottom = 2 }
}

local L = {
    TITLE           = "Battleground EP",
    HINT            = "Click and drag the title bar to move this window.",

    HEAD_NAME       = "Guild member",
    HEAD_RANK       = "Rank",
    HEAD_KB         = "KB",
    HEAD_HK         = "HK",
    HEAD_DEATHS     = "Deaths",
    HEAD_HONOR      = "Honor",

    AMOUNT          = "EP:",
    AMOUNT_DESC     = "How much EP every selected guild member receives.",
    REASON          = "Reason:",
    REASON_DESC     = "Shown in the EPGP log and in the announcement.",

    SELECT_ALL      = "All",
    SELECT_NONE     = "None",
    AWARD           = "Award EP",
    AWARD_DESC      = "Write the EP to the officer notes of every selected guild member.",
    CANCEL          = "Cancel",

    EMPTY           = "No guild member on this scoreboard matches the reward rule.",
    SUMMARY         = "%s  -  %d of %d guild member(s) selected",
    NO_RIGHTS       = "You cannot edit officer notes, so no EP can be written.",
}

local function ShowTooltip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title, 1, 1, 1)
    if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function CreateButton(parent, width, text, onClick, tooltipTitle, tooltipText)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetHeight(22)
    button:SetWidth(width)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    if tooltipTitle then
        button:SetScript("OnEnter", function(self) ShowTooltip(self, tooltipTitle, tooltipText) end)
        button:SetScript("OnLeave", HideTooltip)
    end
    return button
end

local function UpdateInputLook(edit)
    if edit:HasFocus() then
        edit:SetBackdropColor(0.14, 0.14, 0.18, 1)
        edit:SetBackdropBorderColor(1, 0.82, 0, 0.85)
    elseif edit.hovered then
        edit:SetBackdropColor(0.11, 0.11, 0.11, 1)
        edit:SetBackdropBorderColor(0.9, 0.9, 0.9, 0.7)
    else
        edit:SetBackdropColor(0.04, 0.04, 0.04, 1)
        edit:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.55)
    end
end

--[[ InputBoxTemplate builds its border out of textures called "$parentLeft" and
     friends, so nameless boxes share one set of globals and end up stealing
     each other's border. These boxes draw their own frame instead. ]]--
local function CreateEditBox(parent, width, maxLetters, numeric, tooltipTitle, tooltipText)
    local edit = CreateFrame("EditBox", nil, parent)
    edit:EnableMouse(true)
    edit:SetAutoFocus(false)
    edit:SetHeight(EDIT_HEIGHT)
    edit:SetWidth(width)
    edit:SetMaxLetters(maxLetters)
    edit:SetNumeric(numeric and true or false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetTextInsets(6, 6, 0, 0)
    edit:SetBackdrop(INPUT_BACKDROP)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self)
        self.focusedAt = GetTime()
        UpdateInputLook(self)
    end)
    -- Clicking an active box releases it again. The delay ignores the release of
    -- the very click that gave the box focus.
    edit:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self:HasFocus()
           and GetTime() - (self.focusedAt or 0) > 0.3 then
            self:ClearFocus()
        end
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        -- A left over selection makes the box look like it is still being edited.
        self:HighlightText(0, 0)
        UpdateInputLook(self)
    end)
    edit:SetScript("OnEnter", function(self)
        self.hovered = true
        UpdateInputLook(self)
        ShowTooltip(self, tooltipTitle, tooltipText)
    end)
    edit:SetScript("OnLeave", function(self)
        self.hovered = nil
        UpdateInputLook(self)
        HideTooltip()
    end)
    UpdateInputLook(edit)
    return edit
end

local function CreateLabel(parent, x, width, justify, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", parent, "LEFT", x, 0)
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    if text then fs:SetText(text) end
    return fs
end

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetWidth(LIST_WIDTH)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetHeight(20)
    check:SetWidth(20)
    check:SetPoint("LEFT", row, "LEFT", X_CHECK, 0)
    check:SetScript("OnClick", function(self)
        mod:ClearInputFocus()
        if row.playerName then
            mod:SetSelected(row.playerName, self:GetChecked())
        end
    end)

    row.check   = check
    row.name    = CreateLabel(row, X_NAME,   125, "LEFT")
    row.rank    = CreateLabel(row, X_RANK,   125, "LEFT")
    row.kb      = CreateLabel(row, X_KB,      38, "RIGHT")
    row.hk      = CreateLabel(row, X_HK,      38, "RIGHT")
    row.deaths  = CreateLabel(row, X_DEATHS,  38, "RIGHT")
    row.honor   = CreateLabel(row, X_HONOR,   58, "RIGHT")

    row:SetScript("OnClick", function()
        mod:ClearInputFocus()
        if not row.playerName then return end
        mod:SetSelected(row.playerName, not mod:IsSelected(row.playerName))
    end)

    return row
end

function mod:GetRewardWindow()
    if self.rewardFrame then return self.rewardFrame end

    local frame = CreateFrame("Frame", "EPGPBattlegroundsRewardFrame", UIParent)
    frame:Hide()
    frame:SetWidth(FRAME_WIDTH)
    frame:SetHeight(200 + NUM_ROWS * ROW_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetBackdrop({
        bgFile      = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
        edgeFile    = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 64, edgeSize = 16,
        insets      = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(1, 0, 0, 1)
    -- Clicking next to the boxes, the list background included, releases them.
    frame:SetScript("OnMouseDown", function() mod:ClearInputFocus() end)

    -- Title bar -------------------------------------------------------------
    local titleFrame = CreateFrame("Frame", nil, frame)
    titleFrame:SetBackdrop({
        bgFile      = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile    = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 64, edgeSize = 8,
        insets      = { left = 2, right = 1, top = 2, bottom = 2 }
    })
    titleFrame:SetBackdropColor(0, 0, 0, 1)
    titleFrame:SetHeight(22)
    titleFrame:SetPoint("LEFT", frame, "TOPLEFT", 20, 0)
    titleFrame:SetPoint("RIGHT", frame, "TOPRIGHT", -20, 0)
    titleFrame:EnableMouse(true)
    titleFrame:SetScript("OnMouseDown", function() frame:StartMoving() end)
    titleFrame:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)
    titleFrame:SetScript("OnEnter", function(self) ShowTooltip(self, L.TITLE, L.HINT) end)
    titleFrame:SetScript("OnLeave", HideTooltip)

    local titleText = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("CENTER", titleFrame, "CENTER", 0, 1)
    titleText:SetText(format("%s %s", L.TITLE, mod.version or ''))

    -- Summary ---------------------------------------------------------------
    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -18)
    summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -18)
    summary:SetJustifyH("LEFT")

    local warning = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    warning:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -2)
    warning:SetPoint("TOPRIGHT", summary, "BOTTOMRIGHT", 0, -2)
    warning:SetJustifyH("LEFT")
    warning:SetText(L.NO_RIGHTS)
    warning:Hide()

    -- Column headers --------------------------------------------------------
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetHeight(16)
    headerFrame:SetWidth(LIST_WIDTH)
    headerFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -52)

    CreateLabel(headerFrame, X_NAME,   125, "LEFT",  L.HEAD_NAME)
    CreateLabel(headerFrame, X_RANK,   125, "LEFT",  L.HEAD_RANK)
    CreateLabel(headerFrame, X_KB,      38, "RIGHT", L.HEAD_KB)
    CreateLabel(headerFrame, X_HK,      38, "RIGHT", L.HEAD_HK)
    CreateLabel(headerFrame, X_DEATHS,  38, "RIGHT", L.HEAD_DEATHS)
    CreateLabel(headerFrame, X_HONOR,   58, "RIGHT", L.HEAD_HONOR)

    -- Row list --------------------------------------------------------------
    local listFrame = CreateFrame("Frame", nil, frame)
    listFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -4)
    listFrame:SetWidth(LIST_WIDTH)
    listFrame:SetHeight(NUM_ROWS * ROW_HEIGHT + 8)
    listFrame:SetBackdrop({
        bgFile      = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile    = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets      = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    listFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    listFrame:SetBackdropBorderColor(1, 1, 1, 0.3)

    local rows = {}
    for i = 1, NUM_ROWS do
        local row = CreateRow(listFrame)
        row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -4 - ((i - 1) * ROW_HEIGHT))
        rows[i] = row
    end

    local scroll = CreateFrame("ScrollFrame", "EPGPBattlegroundsScrollFrame", listFrame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -26, 4)
    scroll:EnableMouse(false)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() mod:RefreshRewardWindow() end)
    end)

    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollBar = getglobal(scroll:GetName() .. "ScrollBar")
        if not scrollBar then return end
        scrollBar:SetValue(scrollBar:GetValue() - delta * ROW_HEIGHT)
    end)

    local emptyText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 10, -10)
    emptyText:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -10, -10)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText(L.EMPTY)

    -- Selection buttons -----------------------------------------------------
    local selectAll = CreateButton(frame, 50, L.SELECT_ALL, function() mod:SelectAll(true) end)
    selectAll:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 0, -6)

    local selectNone = CreateButton(frame, 50, L.SELECT_NONE, function() mod:SelectAll(false) end)
    selectNone:SetPoint("LEFT", selectAll, "RIGHT", 6, 0)

    -- Award inputs ----------------------------------------------------------
    local amountLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    amountLabel:SetPoint("TOPLEFT", selectAll, "BOTTOMLEFT", 0, -14)
    amountLabel:SetText(L.AMOUNT)

    local amount = CreateEditBox(frame, 60, 5, true, L.AMOUNT, L.AMOUNT_DESC)
    amount:SetPoint("LEFT", amountLabel, "RIGHT", 10, 0)

    local reasonLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reasonLabel:SetPoint("LEFT", amount, "RIGHT", 16, 0)
    reasonLabel:SetText(L.REASON)

    local reason = CreateEditBox(frame, 200, 60, false, L.REASON, L.REASON_DESC)
    reason:SetPoint("LEFT", reasonLabel, "RIGHT", 10, 0)

    -- Footer ----------------------------------------------------------------
    local cancel = CreateButton(frame, 90, L.CANCEL, function() mod:HideRewardWindow() end)
    cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)

    local award = CreateButton(frame, 110, L.AWARD, function() mod:OnAwardClicked() end,
                               L.AWARD, L.AWARD_DESC)
    award:SetPoint("RIGHT", cancel, "LEFT", -8, 0)

    frame.rows      = rows
    frame.scroll    = scroll
    frame.summary   = summary
    frame.warning   = warning
    frame.emptyText = emptyText
    frame.amount    = amount
    frame.reason    = reason
    frame.award     = award

    self.rewardFrame = frame

    tinsert(UISpecialFrames, "EPGPBattlegroundsRewardFrame")

    return frame
end

--[[----------------------------------------------------------------------------
    Selection
------------------------------------------------------------------------------]]

function mod:IsSelected(name)
    return self.selected and self.selected[name] and true or false
end

function mod:SetSelected(name, selected)
    if not self.selected then self.selected = {} end
    self.selected[name] = selected and true or nil
    self:RefreshRewardWindow()
end

function mod:SelectAll(selected)
    if not self.selected then self.selected = {} end
    wipe(self.selected)
    if selected then
        for _, recipient in ipairs(self.recipients or {}) do
            self.selected[recipient.name] = true
        end
    end
    self:RefreshRewardWindow()
end

function mod:GetSelectedNames()
    local names = {}
    for _, recipient in ipairs(self.recipients or {}) do
        if self:IsSelected(recipient.name) then
            tinsert(names, recipient.name)
        end
    end
    return names
end

--[[----------------------------------------------------------------------------
    Window plumbing
------------------------------------------------------------------------------]]

function mod:ShowRewardWindow(snapshot)
    snapshot = snapshot or self.snapshot or self.db.global.lastSnapshot
    if not snapshot then
        return self:Print("No battleground scoreboard has been recorded yet.")
    end

    self.rewardSnapshot = snapshot
    self.recipients     = self:FindRecipients(snapshot)

    -- Everyone who was there is rewarded unless the officer says otherwise.
    self.selected = {}
    for _, recipient in ipairs(self.recipients) do
        self.selected[recipient.name] = true
    end

    local frame = self:GetRewardWindow()
    frame.amount:SetNumber(tonumber(self.db.profile.amount) or 0)
    frame.reason:SetText(self:GetDefaultReason(snapshot))
    frame:Show()

    self:RefreshRewardWindow()
end

function mod:HideRewardWindow()
    if self.rewardFrame then self.rewardFrame:Hide() end
end

--[[ Releases the EP and reason boxes so the keyboard goes back to the game. ]]--
function mod:ClearInputFocus()
    local frame = self.rewardFrame
    if not frame then return end
    frame.amount:ClearFocus()
    frame.reason:ClearFocus()
end

function mod:RefreshRewardWindow()
    local frame = self.rewardFrame
    if not frame or not frame:IsShown() then return end

    local recipients    = self.recipients or {}
    local total         = #recipients
    local selectedCount = #self:GetSelectedNames()

    FauxScrollFrame_Update(frame.scroll, total, NUM_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.scroll)

    for i = 1, NUM_ROWS do
        local row       = frame.rows[i]
        local recipient = recipients[offset + i]

        if recipient then
            row.playerName = recipient.name
            row.check:SetChecked(self:IsSelected(recipient.name))

            row.name:SetText(recipient.name)
            local color = recipient.class and RAID_CLASS_COLORS[recipient.class]
            if color then
                row.name:SetTextColor(color.r, color.g, color.b)
            else
                row.name:SetTextColor(1, 1, 1)
            end

            row.rank:SetText(recipient.rank or '')
            row.kb:SetText(recipient.killingBlows or 0)
            row.hk:SetText(recipient.honorableKills or 0)
            row.deaths:SetText(recipient.deaths or 0)
            row.honor:SetText(recipient.honor or 0)

            row:Show()
        else
            row.playerName = nil
            row:Hide()
        end
    end

    if total == 0 then
        frame.emptyText:Show()
    else
        frame.emptyText:Hide()
    end

    frame.summary:SetText(format(L.SUMMARY,
                                 (self.rewardSnapshot and self.rewardSnapshot.map) or '',
                                 selectedCount, total))

    if CanEditOfficerNote() then
        frame.warning:Hide()
        frame.award:Enable()
    else
        frame.warning:Show()
        frame.award:Disable()
    end
end

function mod:OnAwardClicked()
    local frame = self.rewardFrame
    if not frame then return end

    self:ClearInputFocus()

    local amount = tonumber(frame.amount:GetNumber()) or 0
    local reason = strtrim(frame.reason:GetText() or '')
    local names  = self:GetSelectedNames()

    -- Remember the amount so the next battleground starts from it.
    if amount > 0 then self.db.profile.amount = amount end

    if self:AwardEP(names, reason, amount) then
        self:HideRewardWindow()
    end
end
