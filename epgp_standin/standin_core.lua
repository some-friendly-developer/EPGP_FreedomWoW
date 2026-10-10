--[[
    EPGP LootMaster - Stand-In plugin.

    A stand-in maps a raider onto another character's EP/GP for the duration of
    a raid. When "Arthas" is standing in for "Lichking":

      * the master looter window keeps showing "Arthas" so he can be identified
        and whispered, but it is annotated as "Arthas (Lichking)";
      * the EP, GP, PR and min-EP columns show Lichking's numbers, so sorting by
        PR ranks Arthas by Lichking's priority;
      * EP and GP awards made for Arthas are written to Lichking's officer note.

    The mapping is stored account wide so the raid leader keeps his list between
    sessions.

    Implementation note: LootMasterML routes every EP/GP/PR/min-EP lookup of the
    loot window through LootMasterML:GetEPGP(), so a single wrapper on that
    method is enough to move the whole row onto the stand-in's standings.
]]--

EPGPStandIn = LibStub("AceAddon-3.0"):NewAddon(
    "EPGPStandIn", "AceConsole-3.0", "AceEvent-3.0")

local mod           = EPGPStandIn
local VERSION       = "1.0.0"

-- Colour used for the "(Stand-in)" suffix in the master looter window.
local SUFFIX_COLOR  = "|cff82c5ff"

-- Lookup tables, rebuilt from the saved list whenever it changes. byLower is a
-- case insensitive fallback for names typed by hand.
local byName        = {}
local byLower       = {}

local defaults = {
    global = {
        enabled     = true,
        redirectEP  = true,
        redirectGP  = true,
        entries     = {},   -- array of { character = , standin = , enabled = }
    }
}

--[[ Strips surrounding whitespace and an optional "-Realm" suffix. Returns nil
     for anything that isn't a usable name. ]]--
local function CleanName(name)
    if type(name) ~= 'string' then return nil end
    name = strtrim(name)
    if name == '' then return nil end
    name = strsplit('-', name)
    name = strtrim(name or '')
    if name == '' then return nil end
    return name
end
mod.CleanName = function(self, name) return CleanName(name) end

function mod:OnInitialize()
    self.version = VERSION

    self.db = LibStub("AceDB-3.0"):New("EPGPStandInDB", defaults)

    -- Entries written by older builds may be missing fields, normalise them.
    for _, entry in ipairs(self.db.global.entries) do
        entry.character = entry.character or ''
        entry.standin   = entry.standin or ''
        if entry.enabled == nil then entry.enabled = true end
    end

    self:RebuildLookup()

    self:RegisterChatCommand("standin", "SlashHandler")
    self:RegisterChatCommand("epgpstandin", "SlashHandler")

    -- Defined in standin_options.lua, which is loaded before OnInitialize runs.
    self:SetupOptions()

    self:InstallHooks()
end

function mod:OnEnable()
    -- epgp_lootmaster_ml is a separate addon and may load after us when the
    -- user reorders addons, so try again here.
    self:InstallHooks()
end

--[[----------------------------------------------------------------------------
    Stand-in resolution
------------------------------------------------------------------------------]]

function mod:RebuildLookup()
    wipe(byName)
    wipe(byLower)

    if not self.db.global.enabled then return end

    for _, entry in ipairs(self.db.global.entries) do
        local character = CleanName(entry.character)
        local standin   = CleanName(entry.standin)
        if entry.enabled and character and standin and character ~= standin then
            byName[character] = standin
            byLower[strlower(character)] = standin
        end
    end
end

--[[ Returns the stand-in for a character, or nil when the character plays for
     himself. ]]--
function mod:GetStandIn(name)
    name = CleanName(name)
    if not name then return nil end
    return byName[name] or byLower[strlower(name)]
end

--[[ Returns the name to display plus the stand-in it resolved to (nil when
     there is none). ]]--
function mod:GetDisplayName(name)
    local standin = self:GetStandIn(name)
    if not standin then return name, nil end
    return format("%s %s(%s)|r", name, SUFFIX_COLOR, standin), standin
end

--[[ True when EPGP has standings for this character. Used to warn the raid
     leader about typos before the loot window is up. ]]--
function mod:HasEPGP(name)
    name = CleanName(name)
    if not name then return false end
    if not EPGP or not EPGP.GetEPGP then return true end
    local ok, ep = pcall(EPGP.GetEPGP, EPGP, name)
    return (ok and ep) and true or false
end

--[[ Corrects the capitalisation of a hand typed name against the raid and the
     guild roster. Returns the name unchanged when it isn't found. ]]--
function mod:ResolveRosterName(name)
    name = CleanName(name)
    if not name then return nil end

    local lname = strlower(name)

    local num = GetNumRaidMembers()
    for i = 1, num do
        local rName = GetRaidRosterInfo(i)
        if rName and (rName == name or strlower(rName) == lname) then return rName end
    end

    if IsInGuild() then
        num = GetNumGuildMembers(true)
        for i = 1, num do
            local gName = GetGuildRosterInfo(i)
            if gName and (gName == name or strlower(gName) == lname) then return gName end
        end
    end

    return name
end

--[[----------------------------------------------------------------------------
    The stand-in list
------------------------------------------------------------------------------]]

function mod:GetNumEntries()
    return #self.db.global.entries
end

function mod:GetEntry(index)
    return self.db.global.entries[index]
end

--[[ Returns the index of the entry for this character, or nil. ]]--
function mod:FindEntry(character)
    character = CleanName(character)
    if not character then return nil end
    local lname = strlower(character)
    for index, entry in ipairs(self.db.global.entries) do
        local entryName = CleanName(entry.character)
        if entryName and strlower(entryName) == lname then return index end
    end
end

function mod:AddEntry(character, standin, enabled)
    if enabled == nil then enabled = true end
    tinsert(self.db.global.entries, {
        character   = self:ResolveRosterName(character) or '',
        standin     = self:ResolveRosterName(standin) or '',
        enabled     = enabled and true or false,
    })
    self:Changed()
    return #self.db.global.entries
end

function mod:UpdateEntry(index, character, standin)
    local entry = self.db.global.entries[index]
    if not entry then return end
    entry.character = self:ResolveRosterName(character) or ''
    entry.standin   = self:ResolveRosterName(standin) or ''
    self:Changed()
end

function mod:SetEntryEnabled(index, enabled)
    local entry = self.db.global.entries[index]
    if not entry then return end
    entry.enabled = enabled and true or false
    self:Changed()
end

function mod:RemoveEntry(index)
    if not index or not self.db.global.entries[index] then return end
    tremove(self.db.global.entries, index)
    self:Changed()
end

function mod:SetAllEnabled(enabled)
    for _, entry in ipairs(self.db.global.entries) do
        entry.enabled = enabled and true or false
    end
    self:Changed()
end

function mod:ClearEntries()
    wipe(self.db.global.entries)
    self:Changed()
end

function mod:SetPluginEnabled(enabled)
    self.db.global.enabled = enabled and true or false
    self:Changed()
end

function mod:IsPluginEnabled()
    return self.db.global.enabled and true or false
end

--[[ Called after every change to the list or to the plugin settings. ]]--
function mod:Changed()
    self:RebuildLookup()
    self:RefreshUI()
    self:RefreshLootWindow()
end

--[[ Re-sorts and redraws the master looter window so new PR values take effect
     immediately instead of after the next candidate response. ]]--
function mod:RefreshLootWindow()
    if not LootMasterML or not LootMasterML.UpdateUI then return end
    if not LootMasterML.IsShown or not LootMasterML:IsShown() then return end
    LootMasterML:UpdateUI()
end

--[[----------------------------------------------------------------------------
    Hooks into epgp_lootmaster_ml and EPGP
------------------------------------------------------------------------------]]

local hookedML      = false
local hookedEPGP    = false

--[[ lib-st calls userDraw as func(nil, cell, unpack(args)), hence the leading
     placeholder argument. ]]--
local function DrawCandidateNameCell(_, cell, candidate)
    if not cell or not cell.text then return end
    local display = mod:GetDisplayName(candidate)
    cell.text:SetText(display)
end

--[[ Replaces the plain name value of a candidate row with a renderer that
     appends the stand-in. The raw value is left alone so lib-st keeps sorting
     the column by the real character name, and so lootmaster's own
     GetCandidateData(..., 'name') lookups keep working. ]]--
function mod:DecorateCandidateRow(ml, itemID, candidate)
    local loot = ml.lootTable and ml.lootTable[itemID]
    if not loot or not loot.candidates or not loot.rowdata then return end

    local rowID = loot.candidates[candidate]
    if not rowID then return end

    local row = loot.rowdata[rowID]
    if not row or not row.cols then return end

    for i = 1, #row.cols do
        local col = row.cols[i]
        if col and col.name == 'name' then
            col.userDraw = DrawCandidateNameCell
            col.args     = { candidate }
            return
        end
    end
end

function mod:InstallHooks()
    if not hookedML and LootMasterML and LootMasterML.GetEPGP and LootMasterML.AddCandidate then

        -- Every EP/GP/PR/min-EP cell of the loot window funnels through here.
        local GetEPGP = LootMasterML.GetEPGP
        LootMasterML.GetEPGP = function(ml, player)
            return GetEPGP(ml, mod:GetStandIn(player) or player)
        end

        -- Annotate the candidate name as soon as the row is created.
        local AddCandidate = LootMasterML.AddCandidate
        LootMasterML.AddCandidate = function(ml, loot, candidate)
            local itemID = AddCandidate(ml, loot, candidate)
            if itemID then
                mod:DecorateCandidateRow(ml, itemID, candidate)
            end
            return itemID
        end

        -- Offer "set stand-in" straight from the candidate right click menu.
        if LootMasterML.CandidateDropDownInitialize then
            local CandidateDropDownInitialize = LootMasterML.CandidateDropDownInitialize
            LootMasterML.CandidateDropDownInitialize = function(ml, frame, level, menuList)
                CandidateDropDownInitialize(ml, frame, level, menuList)
                mod:AppendCandidateDropDownEntry(ml)
            end
        end

        hookedML = true
    end

    if not hookedEPGP and EPGP and EPGP.IncEPBy and EPGP.IncGPBy then

        local IncEPBy = EPGP.IncEPBy
        EPGP.IncEPBy = function(epgp, name, reason, amount, mass, undo)
            if mod.db.global.redirectEP then
                name = mod:GetStandIn(name) or name
            end
            return IncEPBy(epgp, name, reason, amount, mass, undo)
        end

        local IncGPBy = EPGP.IncGPBy
        EPGP.IncGPBy = function(epgp, name, reason, amount, mass, undo)
            if mod.db.global.redirectGP then
                name = mod:GetStandIn(name) or name
            end
            return IncGPBy(epgp, name, reason, amount, mass, undo)
        end

        hookedEPGP = true
    end
end

function mod:AppendCandidateDropDownEntry(ml)
    if UIDROPDOWNMENU_MENU_LEVEL ~= 1 then return end

    local dropdown = ml.CandidateDropDown
    if not dropdown or not dropdown.selectedCandidate then return end
    if not ml:GetLoot(dropdown.selectedLink) then return end

    local candidate = dropdown.selectedCandidate
    local standin   = self:GetStandIn(candidate)

    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable   = 1
    info.isTitle        = false
    info.disabled       = false
    info.text           = standin
                          and format("Stand-in: %s (change)", standin)
                          or "Set stand-in..."
    info.tooltipTitle   = "Stand-in"
    info.tooltipText    = "Use another character's EP/GP for this raider."
    info.func           = function()
                              CloseDropDownMenus()
                              mod:ShowWindowFor(candidate)
                          end
    UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL)
end

--[[----------------------------------------------------------------------------
    Slash commands
------------------------------------------------------------------------------]]

function mod:SlashHandler(input)
    local command, rest = strmatch(strtrim(input or ''), "^(%S*)%s*(.-)$")
    command = strlower(command or '')

    if command == '' or command == 'show' or command == 'toggle' then

        self:ToggleWindow()

    elseif command == 'hide' or command == 'close' then

        self:HideWindow()

    elseif command == 'on' then

        self:SetPluginEnabled(true)
        self:Print("Stand-ins are active.")

    elseif command == 'off' then

        self:SetPluginEnabled(false)
        self:Print("Stand-ins are paused, everyone uses their own EP/GP.")

    elseif command == 'add' then

        local character, standin = strmatch(rest, "^(%S+)%s+(%S+)$")
        if not character then
            return self:Print("Usage: /standin add <raider> <stand-in>")
        end
        self:AddEntry(character, standin, true)
        self:Print(format("%s now uses %s's EP/GP.", character, standin))

    elseif command == 'remove' or command == 'del' then

        local index = self:FindEntry(rest)
        if not index then
            return self:Print(format("No stand-in found for %s.", rest))
        end
        self:RemoveEntry(index)
        self:Print(format("Removed the stand-in for %s.", rest))

    elseif command == 'clear' then

        self:ClearEntries()
        self:Print("Stand-in list cleared.")

    elseif command == 'list' then

        local entries = self.db.global.entries
        if #entries == 0 then
            return self:Print("The stand-in list is empty.")
        end
        self:Print(format("%d stand-in(s), plugin is %s:",
                          #entries,
                          self.db.global.enabled and "active" or "paused"))
        for _, entry in ipairs(entries) do
            self:Print(format("  %s -> %s [%s]",
                              entry.character ~= '' and entry.character or '?',
                              entry.standin ~= '' and entry.standin or '?',
                              entry.enabled and "on" or "off"))
        end

    else

        self:Print(format("Stand-In %s", self.version))
        self:Print("/standin - open the stand-in window")
        self:Print("/standin on|off - activate or pause every stand-in")
        self:Print("/standin add <raider> <stand-in> - add a mapping")
        self:Print("/standin remove <raider> - drop a mapping")
        self:Print("/standin clear - empty the list")
        self:Print("/standin list - print the list")

    end
end
