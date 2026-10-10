--[[
    EPGP LootMaster - Stand-In plugin, management window.
]]--

local mod = EPGPStandIn

local NUM_ROWS      = 10
local ROW_HEIGHT    = 24
local FRAME_WIDTH   = 470
local LIST_WIDTH    = FRAME_WIDTH - 36

-- Column offsets inside a row.
local X_CHARACTER   = 6
local X_STANDIN     = 170
local X_ENABLED     = 344
local X_REMOVE      = 382
local EDIT_WIDTH    = 150
local EDIT_HEIGHT   = 20

local INPUT_BACKDROP = {
    bgFile      = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile    = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 8,
    insets      = { left = 2, right = 2, top = 2, bottom = 2 }
}

local L = {
    TITLE               = "EPGP Stand-Ins",
    HINT                = "Click and drag the title bar to move this window.",

    ENABLED             = "Stand-ins active",
    ENABLED_DESC        = "Uncheck to pause every stand-in at once without losing the list.",
    REDIRECT_EP         = "Award EP to the stand-in",
    REDIRECT_EP_DESC    = "EP handed out for a raider is written to his stand-in's officer note.",
    REDIRECT_GP         = "Charge GP to the stand-in",
    REDIRECT_GP_DESC    = "GP charged for loot won by a raider is written to his stand-in's officer note.",

    HEAD_CHARACTER      = "Raider",
    HEAD_STANDIN        = "Stand-in (EP/GP source)",
    HEAD_ENABLED        = "On",

    ADD                 = "Add",
    ADD_DESC            = "Append an empty row to the list.",
    ENABLE_ALL          = "Enable all",
    DISABLE_ALL         = "Disable all",
    CLEAR_ALL           = "Clear all",
    CLEAR_ALL_DESC      = "Remove every stand-in from the list. This cannot be undone.",
    CLOSE               = "Close",
    REMOVE              = "Remove",
    REMOVE_DESC         = "Remove this stand-in from the list.",

    EMPTY               = "No stand-ins yet. Press \"Add\" or right click a candidate in the loot window.",
    COUNT               = "%d stand-in(s), %d active",
    UNKNOWN_STANDIN     = "EPGP has no standings for this name. Check the spelling.",
    CHARACTER_DESC      = "The character that is actually in the raid.",
    STANDIN_DESC        = "The character whose EP/GP should be used instead.",
}

StaticPopupDialogs["EPGP_STANDIN_CLEAR_ALL"] = {
    text        = "Remove every stand-in from the list?",
    button1     = YES,
    button2     = NO,
    OnAccept    = function() mod:ClearEntries() end,
    timeout     = 0,
    whileDead   = 1,
    hideOnEscape = 1,
}

local function ShowTooltip(owner, title, ...)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title, 1, 1, 1)
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then GameTooltip:AddLine(line, nil, nil, nil, true) end
    end
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
     friends, so nameless boxes share one set of globals and rows steal each
     other's border. These boxes draw their own frame instead.
     Set edit.onCommit to be told when the box loses focus. ]]--
local function CreateNameEditBox(parent, width, tooltipTitle, tooltipText)
    local edit = CreateFrame("EditBox", nil, parent)
    edit:EnableMouse(true)
    edit:SetAutoFocus(false)
    edit:SetHeight(EDIT_HEIGHT)
    edit:SetWidth(width)
    edit:SetMaxLetters(24)
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
        -- A left over selection makes the row look like it is still being edited.
        self:HighlightText(0, 0)
        UpdateInputLook(self)
        if self.onCommit then self.onCommit(self) end
    end)
    edit:SetScript("OnEnter", function(self)
        self.hovered = true
        UpdateInputLook(self)
        ShowTooltip(self, tooltipTitle, tooltipText, self.warning)
    end)
    edit:SetScript("OnLeave", function(self)
        self.hovered = nil
        UpdateInputLook(self)
        HideTooltip()
    end)
    UpdateInputLook(edit)
    return edit
end

--[[ Writes both name boxes of a row back into the saved list. ]]--
local function CommitRow(row)
    local index = row.entryIndex
    if not index then return end

    local entry = mod:GetEntry(index)
    if not entry then return end

    local character = mod:ResolveRosterName(row.character:GetText()) or ''
    local standin   = mod:ResolveRosterName(row.standin:GetText()) or ''

    if entry.character == character and entry.standin == standin then
        -- Nothing changed, just normalise what is on screen.
        row.character:SetText(character)
        row.standin:SetText(standin)
        return
    end

    entry.character = character
    entry.standin   = standin
    mod:Changed()
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetWidth(LIST_WIDTH)

    -- Banding every other row makes a long list easier to read across.
    if index % 2 == 0 then
        local stripe = row:CreateTexture(nil, "BACKGROUND")
        stripe:SetPoint("TOPLEFT", row, "TOPLEFT", 3, 0)
        stripe:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, 0)
        stripe:SetTexture(1, 1, 1, 0.03)
    end

    local character = CreateNameEditBox(row, EDIT_WIDTH, L.HEAD_CHARACTER, L.CHARACTER_DESC)
    character:SetPoint("LEFT", row, "LEFT", X_CHARACTER, 0)
    character.onCommit = function() CommitRow(row) end

    local standin = CreateNameEditBox(row, EDIT_WIDTH, L.HEAD_STANDIN, L.STANDIN_DESC)
    standin:SetPoint("LEFT", row, "LEFT", X_STANDIN, 0)
    standin.onCommit = function() CommitRow(row) end

    character:SetScript("OnTabPressed", function() standin:SetFocus() end)
    standin:SetScript("OnTabPressed", function() character:SetFocus() end)

    local enabled = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    enabled:SetHeight(24)
    enabled:SetWidth(24)
    enabled:SetPoint("LEFT", row, "LEFT", X_ENABLED, 0)
    enabled:SetScript("OnClick", function(self)
        -- Read the box first, releasing a name box redraws the list and would
        -- put the old state back.
        local checked = self:GetChecked()
        mod:ClearRowFocus()
        if row.entryIndex then
            mod:SetEntryEnabled(row.entryIndex, checked)
        end
    end)
    enabled:SetScript("OnEnter", function(self) ShowTooltip(self, L.HEAD_ENABLED, L.ENABLED_DESC) end)
    enabled:SetScript("OnLeave", HideTooltip)

    local remove = CreateButton(row, 24, "X", function()
        if row.entryIndex then
            row.character:ClearFocus()
            row.standin:ClearFocus()
            mod:RemoveEntry(row.entryIndex)
        end
    end, L.REMOVE, L.REMOVE_DESC)
    remove:SetPoint("LEFT", row, "LEFT", X_REMOVE, 0)

    row.character   = character
    row.standin     = standin
    row.enabled     = enabled
    row.remove      = remove

    return row
end

function mod:GetWindow()
    if self.frame then return self.frame end

    local frame = CreateFrame("Frame", "EPGPStandInFrame", UIParent)
    frame:Hide()
    frame:SetWidth(FRAME_WIDTH)
    frame:SetHeight(188 + NUM_ROWS * ROW_HEIGHT)
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
    frame:SetScript("OnHide", function() mod:OnWindowHidden() end)
    -- Clicking next to the boxes, the list background included, releases them.
    frame:SetScript("OnMouseDown", function() mod:ClearRowFocus() end)

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

    -- Settings --------------------------------------------------------------
    local enabledCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enabledCheck:SetHeight(26)
    enabledCheck:SetWidth(26)
    enabledCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -16)
    enabledCheck:SetScript("OnClick", function(self) mod:SetPluginEnabled(self:GetChecked()) end)
    enabledCheck:SetScript("OnEnter", function(self) ShowTooltip(self, L.ENABLED, L.ENABLED_DESC) end)
    enabledCheck:SetScript("OnLeave", HideTooltip)

    local enabledLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enabledLabel:SetPoint("LEFT", enabledCheck, "RIGHT", 2, 0)
    enabledLabel:SetText(L.ENABLED)

    local epCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    epCheck:SetHeight(22)
    epCheck:SetWidth(22)
    epCheck:SetPoint("TOPLEFT", enabledCheck, "BOTTOMLEFT", 2, -2)
    epCheck:SetScript("OnClick", function(self)
        mod.db.global.redirectEP = self:GetChecked() and true or false
    end)
    epCheck:SetScript("OnEnter", function(self) ShowTooltip(self, L.REDIRECT_EP, L.REDIRECT_EP_DESC) end)
    epCheck:SetScript("OnLeave", HideTooltip)

    local epLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    epLabel:SetPoint("LEFT", epCheck, "RIGHT", 2, 0)
    epLabel:SetText(L.REDIRECT_EP)

    local gpCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    gpCheck:SetHeight(22)
    gpCheck:SetWidth(22)
    gpCheck:SetPoint("LEFT", epLabel, "RIGHT", 16, 0)
    gpCheck:SetScript("OnClick", function(self)
        mod.db.global.redirectGP = self:GetChecked() and true or false
    end)
    gpCheck:SetScript("OnEnter", function(self) ShowTooltip(self, L.REDIRECT_GP, L.REDIRECT_GP_DESC) end)
    gpCheck:SetScript("OnLeave", HideTooltip)

    local gpLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gpLabel:SetPoint("LEFT", gpCheck, "RIGHT", 2, 0)
    gpLabel:SetText(L.REDIRECT_GP)

    -- Column headers --------------------------------------------------------
    local headerFrame = CreateFrame("Frame", nil, frame)
    headerFrame:SetHeight(18)
    headerFrame:SetWidth(LIST_WIDTH)
    headerFrame:SetPoint("TOPLEFT", epCheck, "BOTTOMLEFT", -2, -10)

    local headCharacter = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headCharacter:SetPoint("LEFT", headerFrame, "LEFT", X_CHARACTER + 6, 0)
    headCharacter:SetText(L.HEAD_CHARACTER)

    local headStandin = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headStandin:SetPoint("LEFT", headerFrame, "LEFT", X_STANDIN + 6, 0)
    headStandin:SetText(L.HEAD_STANDIN)

    local headEnabled = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headEnabled:SetPoint("LEFT", headerFrame, "LEFT", X_ENABLED, 0)
    headEnabled:SetText(L.HEAD_ENABLED)

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
        local row = CreateRow(listFrame, i)
        row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -4 - ((i - 1) * ROW_HEIGHT))
        rows[i] = row
    end

    local scroll = CreateFrame("ScrollFrame", "EPGPStandInScrollFrame", listFrame, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -26, 4)
    scroll:EnableMouse(false)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        -- Committing here keeps a half edited row from scrolling out of view.
        mod:ClearRowFocus()
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function() mod:RefreshUI() end)
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

    -- Footer ----------------------------------------------------------------
    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 4, -6)

    local addButton = CreateButton(frame, 70, L.ADD, function() mod:AddBlankEntry() end, L.ADD, L.ADD_DESC)
    addButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)

    local enableAll = CreateButton(frame, 84, L.ENABLE_ALL, function() mod:SetAllEnabled(true) end)
    enableAll:SetPoint("LEFT", addButton, "RIGHT", 6, 0)

    local disableAll = CreateButton(frame, 84, L.DISABLE_ALL, function() mod:SetAllEnabled(false) end)
    disableAll:SetPoint("LEFT", enableAll, "RIGHT", 6, 0)

    local clearAll = CreateButton(frame, 74, L.CLEAR_ALL, function()
        StaticPopup_Show("EPGP_STANDIN_CLEAR_ALL")
    end, L.CLEAR_ALL, L.CLEAR_ALL_DESC)
    clearAll:SetPoint("LEFT", disableAll, "RIGHT", 6, 0)

    local closeButton = CreateButton(frame, 76, L.CLOSE, function() mod:HideWindow() end)
    closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)

    frame.rows      = rows
    frame.scroll    = scroll
    frame.emptyText = emptyText
    frame.countText = countText
    frame.enabledCheck = enabledCheck
    frame.epCheck   = epCheck
    frame.gpCheck   = gpCheck

    self.frame = frame

    -- Let escape close the window like any other dialog.
    tinsert(UISpecialFrames, "EPGPStandInFrame")

    return frame
end

function mod:RefreshUI()
    local frame = self.frame
    if not frame or not frame:IsShown() then return end

    local entries   = self.db.global.entries
    local total     = #entries
    local active    = 0
    for _, entry in ipairs(entries) do
        if entry.enabled then active = active + 1 end
    end

    frame.enabledCheck:SetChecked(self.db.global.enabled)
    frame.epCheck:SetChecked(self.db.global.redirectEP)
    frame.gpCheck:SetChecked(self.db.global.redirectGP)

    FauxScrollFrame_Update(frame.scroll, total, NUM_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(frame.scroll)

    for i = 1, NUM_ROWS do
        local row   = frame.rows[i]
        local index = offset + i
        local entry = entries[index]

        if entry then
            row.entryIndex = index

            if not row.character:HasFocus() then
                row.character:SetText(entry.character or '')
            end
            if not row.standin:HasFocus() then
                row.standin:SetText(entry.standin or '')
            end

            row.enabled:SetChecked(entry.enabled)

            -- Warn about names EPGP doesn't know, that is almost always a typo.
            if entry.standin and entry.standin ~= '' and not self:HasEPGP(entry.standin) then
                row.standin:SetTextColor(1, 0.35, 0.35)
                row.standin.warning = L.UNKNOWN_STANDIN
            else
                row.standin:SetTextColor(1, 1, 1)
                row.standin.warning = nil
            end

            if entry.character and entry.character ~= '' and not self:HasEPGP(entry.character) then
                row.character:SetTextColor(0.8, 0.8, 0.8)
            else
                row.character:SetTextColor(1, 1, 1)
            end

            row:Show()
        else
            -- Dropping the index first keeps the commit from writing the old
            -- name into whatever entry now sits at that position.
            row.entryIndex = nil
            row.character:ClearFocus()
            row.standin:ClearFocus()
            row.character:SetText('')
            row.standin:SetText('')
            row:Hide()
        end
    end

    if total == 0 then
        frame.emptyText:Show()
    else
        frame.emptyText:Hide()
    end

    frame.countText:SetText(format(L.COUNT, total, active))
end

--[[ Appends an empty row and puts the cursor in it. ]]--
function mod:AddBlankEntry(character, standin)
    local index = self:AddEntry(character, standin, true)
    self:ShowWindow()
    self:ScrollTo(index)
    local row = self:GetRowForEntry(index)
    if row then
        if character and character ~= '' then
            row.standin:SetFocus()
        else
            row.character:SetFocus()
        end
    end
    return index
end

function mod:GetRowForEntry(index)
    local frame = self.frame
    if not frame then return nil end
    for i = 1, NUM_ROWS do
        if frame.rows[i].entryIndex == index then return frame.rows[i] end
    end
end

function mod:ScrollTo(index)
    local frame = self.frame
    if not frame then return end

    local total     = self:GetNumEntries()
    local maxOffset = math.max(total - NUM_ROWS, 0)
    local offset    = math.min(math.max(index - NUM_ROWS, 0), maxOffset)

    FauxScrollFrame_SetOffset(frame.scroll, offset)
    local scrollBar = getglobal(frame.scroll:GetName() .. "ScrollBar")
    if scrollBar then scrollBar:SetValue(offset * ROW_HEIGHT) end
    self:RefreshUI()
end

function mod:ShowWindow()
    local frame = self:GetWindow()
    frame:Show()
    self:RefreshUI()
end

function mod:HideWindow()
    if self.frame then self.frame:Hide() end
end

function mod:ToggleWindow()
    if self.frame and self.frame:IsShown() then
        self:HideWindow()
    else
        self:ShowWindow()
    end
end

--[[ Releases whatever name box is being edited, which commits it. ]]--
function mod:ClearRowFocus()
    if not self.frame then return end
    for i = 1, NUM_ROWS do
        self.frame.rows[i].character:ClearFocus()
        self.frame.rows[i].standin:ClearFocus()
    end
end

function mod:OnWindowHidden()
    -- Editing a name and closing with escape should still save the name.
    self:ClearRowFocus()
end

--[[ Opens the window on the entry for this character, creating one when it is
     missing. Used by the loot window right click menu. ]]--
function mod:ShowWindowFor(character)
    self:ShowWindow()

    local index = self:FindEntry(character)
    if not index then
        return self:AddBlankEntry(character)
    end

    self:ScrollTo(index)
    local row = self:GetRowForEntry(index)
    if row then row.standin:SetFocus() end
end
