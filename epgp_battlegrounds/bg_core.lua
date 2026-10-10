--[[
    EPGP - Battlegrounds plugin.

    When a battleground ends the final scoreboard is snapshotted. After the
    player is teleported out, every client that ran the battleground elects the
    same guild member to hand out the EP:

      * candidates are the guild members on the scoreboard that match the
        configured criteria (an exact guild rank, or a tag in the public note);
      * the alphabetically first candidate on the scoreboard claims the job
        over the guild addon channel and gets the reward window. The order
        of the scoreboard columns is ignored, so two clients cannot pick
        different people by sorting on healing versus killing blows;
      * the next candidate only claims if no claim arrived within a few
        seconds, so a stale roster on one client cannot open two windows;
      * everybody else, other candidates included, gets a chat line naming
        the distributor.

    It only stays consistent as long as the officers share the same criteria,
    which is why the settings are phrased as guild wide policy.
]]--

EPGPBattlegrounds = LibStub("AceAddon-3.0"):NewAddon(
    "EPGPBattlegrounds", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local mod       = EPGPBattlegrounds
local VERSION   = "1.1.0"

-- How long to wait after the loading screen before deciding who rewards, so the
-- guild roster has a chance to arrive.
local SETTLE_DELAY  = 4

-- How often to poll for score data while a decided battleground is winding down.
local WATCH_PERIOD  = 5

-- Every client elects on its own roster cache, which can be stale. Candidates
-- therefore claim the job over the guild channel in scoreboard order, each one
-- waiting this long per place in the queue before claiming.
local CLAIM_PREFIX  = "EPGPBG"
local CLAIM_STEP    = 2
-- Claims older than this belong to an earlier battleground.
local CLAIM_EXPIRY  = 300

local defaults = {
    profile = {
        enabled                 = true,

        -- Who is asked to hand out the EP.
        distributorMode         = 'rank',    -- 'rank' | 'tag'
        distributorRank         = nil,       -- rank index, 0 is the guild master
        distributorTag          = '@pvp',

        -- Who receives the EP.
        recipientMode           = 'rank',    -- 'rank' | 'tag' | 'all'
        recipientRank           = nil,
        recipientTag            = '@pvp',

        amount                  = 150,
        reason                  = 'BG',

        announceResponsible     = true,
        autoOpen                = true,
    },
    global = {
        lastSnapshot            = nil,
    },
}

--[[ Strips a "-Realm" suffix. Cross realm players in a battleground are listed
     as "Name-Realm" and can never be guild mates, so names that carry a realm
     are dropped instead of trimmed. ]]--
local function IsLocalRealmName(name)
    if type(name) ~= 'string' or name == '' then return false end
    return strfind(name, '-', 1, true) == nil
end

function mod:OnInitialize()
    self.version = VERSION

    self.db = LibStub("AceDB-3.0"):New("EPGPBattlegroundsDB", defaults)

    -- Older builds stored a prefix that the map name was appended to.
    local profile = self.db.profile
    if profile.reasonPrefix ~= nil then
        if strtrim(profile.reasonPrefix) ~= '' then
            profile.reason = profile.reasonPrefix
        end
        profile.reasonPrefix = nil
    end

    -- name -> { rank, rankIndex, note, officernote, class, classLocalized }
    self.guildInfo = {}

    self:RegisterChatCommand("bgep", "SlashHandler")

    -- Defined in bg_options.lua, loaded before OnInitialize runs.
    self:SetupOptions()
end

function mod:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD",     "UpdateZoneState")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA",     "UpdateZoneState")
    self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
    self:RegisterEvent("GUILD_ROSTER_UPDATE",       "CacheGuildInfo")
    self:RegisterEvent("CHAT_MSG_ADDON")

    -- The final stats window opening is the most reliable "the battleground is
    -- over" signal we get on this client.
    if WorldStateScoreFrame and not self.scoreFrameHooked then
        WorldStateScoreFrame:HookScript("OnShow", function() mod:OnScoreFrameShown() end)
        self.scoreFrameHooked = true
    end

    GuildRoster()
    self:UpdateZoneState()
end

function mod:IsPluginEnabled()
    return self.db.profile.enabled and true or false
end

--[[----------------------------------------------------------------------------
    Guild roster cache
------------------------------------------------------------------------------]]

function mod:CacheGuildInfo()
    if not IsInGuild() then return end

    local num = GetNumGuildMembers(true)
    for i = 1, num do
        local name, rank, rankIndex, _, classLocalized, _, note, officernote,
              _, _, classFileName = GetGuildRosterInfo(i)
        if name then
            local info = self.guildInfo[name]
            if not info then
                info = {}
                self.guildInfo[name] = info
            end
            info.rank               = rank
            info.rankIndex          = rankIndex or 99
            info.note               = note or ''
            info.officernote        = officernote or ''
            info.class              = classFileName
            info.classLocalized     = classLocalized
        end
    end
end

function mod:GetGuildInfo(name)
    return self.guildInfo[name]
end

--[[ Guild ranks as a { [rankIndex] = "0. Guild Master" } table for dropdowns.
     GuildControl* is only readable by privileged ranks, so fall back to what the
     roster tells us. ]]--
function mod:GetGuildRanks()
    local ranks = {}

    local num = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
    if num and num > 0 then
        for i = 1, num do
            local name = GuildControlGetRankName(i)
            if name and name ~= '' then
                ranks[i - 1] = format("%d. %s", i - 1, name)
            end
        end
    end

    if not next(ranks) then
        for _, info in pairs(self.guildInfo) do
            if info.rankIndex and info.rank then
                ranks[info.rankIndex] = format("%d. %s", info.rankIndex, info.rank)
            end
        end
    end

    if not next(ranks) then
        ranks[0] = "Guild roster not loaded yet"
    end

    return ranks
end

--[[----------------------------------------------------------------------------
    Battleground detection and snapshotting
------------------------------------------------------------------------------]]

function mod:InBattleground()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= 'pvp' then return false end
    if IsActiveBattlefieldArena and IsActiveBattlefieldArena() then return false end
    return true
end

function mod:UpdateZoneState()
    local inBG = self:InBattleground()

    if inBG and not self.inBattleground then
        self.inBattleground = true
        self.bgName          = GetRealZoneText() or "Battleground"
        self.snapshot        = nil
        self.processed       = false
        self.rosterRequested = false
        self:ResetClaim()
        self:StartWatchTimer()

    elseif not inBG and self.inBattleground then
        self.inBattleground = false
        self:StopWatchTimer()
        self:OnBattlegroundLeft()
    end
end

--[[ The final stats window opening is the clearest end-of-battleground signal,
     but another addon can suppress it, so a slow poll runs alongside it. ]]--
function mod:OnScoreFrameShown()
    if not self:IsPluginEnabled() then return end
    if not self.inBattleground then return end

    RequestBattlefieldScoreData()
    self:TakeSnapshot()
    self:ScheduleTimer("TakeSnapshot", 1)
end

function mod:UPDATE_BATTLEFIELD_SCORE()
    if not self:IsPluginEnabled() then return end
    if not self.inBattleground then return end
    if GetBattlefieldWinner() == nil then return end

    self:TakeSnapshot()
end

function mod:StartWatchTimer()
    if self.watchTimer then return end
    self.watchTimer = self:ScheduleRepeatingTimer("WatchBattleground", WATCH_PERIOD)
end

function mod:StopWatchTimer()
    if not self.watchTimer then return end
    self:CancelTimer(self.watchTimer, true)
    self.watchTimer = nil
end

--[[ Keeps asking for score data once the battleground is decided, so the stored
     numbers are the final ones even if the player never opens the scoreboard. ]]--
function mod:WatchBattleground()
    if not self.inBattleground then return self:StopWatchTimer() end
    if not self:IsPluginEnabled() then return end
    if GetBattlefieldWinner() == nil then return end
    RequestBattlefieldScoreData()
end

--[[ Reads the final scoreboard. Called repeatedly while the scoreboard is up so
     the stored numbers are the final ones. ]]--
function mod:TakeSnapshot()
    if not self.inBattleground then return end
    if GetBattlefieldWinner() == nil then return end

    local total = GetNumBattlefieldScores()
    if total == 0 then return end

    local players = {}
    for i = 1, total do
        local name, killingBlows, honorableKills, deaths, honorGained, faction =
            GetBattlefieldScore(i)

        -- Only same realm players can be guild mates, everybody else is noise.
        if IsLocalRealmName(name) then
            tinsert(players, {
                name            = name,
                faction         = faction,
                killingBlows    = killingBlows or 0,
                honorableKills  = honorableKills or 0,
                deaths          = deaths or 0,
                honor           = honorGained or 0,
            })
        end
    end

    if #players == 0 then return end

    -- GetBattlefieldScore follows the column the player last clicked, so two
    -- clients can see the same battleground in different orders. Name order is
    -- the same on every client.
    table.sort(players, function(a, b)
        return strlower(a.name) < strlower(b.name)
    end)

    self.snapshot = {
        map         = self.bgName or GetRealZoneText() or "Battleground",
        winner      = GetBattlefieldWinner(),
        finished    = time(),
        players     = players,
    }

    -- Keep it around so a disconnect between the scoreboard and the reward
    -- window does not lose the raid.
    self.db.global.lastSnapshot = self.snapshot

    -- Make sure the roster is fresh before we have to elect anybody. The
    -- scoreboard refreshes every few seconds, the roster does not need to.
    if not self.rosterRequested then
        self.rosterRequested = true
        GuildRoster()
    end

    -- Claim while still inside, so a later candidate who leaves first does not
    -- take over. The delay lets the roster requested above arrive.
    if not self.earlyClaimTimer then
        self.earlyClaimTimer = self:ScheduleTimer("EarlyClaim", SETTLE_DELAY)
    end
end

function mod:OnBattlegroundLeft()
    if not self:IsPluginEnabled() then return end
    if not self.snapshot then return end
    if self.processed then return end

    self.processed = true
    GuildRoster()
    self:ScheduleTimer("ProcessSnapshot", SETTLE_DELAY)
end

--[[----------------------------------------------------------------------------
    Electing the distributor
------------------------------------------------------------------------------]]

local function NoteHasTag(note, tag)
    if not note or note == '' then return false end
    if not tag then return false end
    tag = strtrim(tag)
    if tag == '' then return false end
    return strfind(strlower(note), strlower(tag), 1, true) ~= nil
end
--[[ True once the distributor rule can actually match somebody. ]]--
function mod:IsConfigured()
    if self.db.profile.distributorMode == 'tag' then
        return strtrim(self.db.profile.distributorTag or '') ~= ''
    end
    return self.db.profile.distributorRank ~= nil
end

function mod:MatchesDistributor(info)
    if not info then return false end
    if self.db.profile.distributorMode == 'tag' then
        return NoteHasTag(info.note, self.db.profile.distributorTag)
    end
    return info.rankIndex ~= nil and info.rankIndex == self.db.profile.distributorRank
end

function mod:MatchesRecipient(info)
    if not info then return false end
    local mode = self.db.profile.recipientMode
    if mode == 'all' then
        return true
    elseif mode == 'tag' then
        return NoteHasTag(info.note, self.db.profile.recipientTag)
    end
    return info.rankIndex ~= nil and info.rankIndex == self.db.profile.recipientRank
end

--[[ Guild members matching the distributor rule, in alphabetical order. ]]--
function mod:FindDistributorCandidates(snapshot)
    snapshot = snapshot or self.snapshot
    local candidates = {}
    if not snapshot then return candidates end

    for _, player in ipairs(snapshot.players) do
        local info = self.guildInfo[player.name]
        if info and self:MatchesDistributor(info) then
            tinsert(candidates, player.name)
        end
    end

    return candidates
end

--[[ The alphabetically first match. Once somebody has claimed the
     battleground over the guild channel, that claim wins. ]]--
function mod:FindDistributor(snapshot)
    if self.claimedBy then return self.claimedBy end
    return self:FindDistributorCandidates(snapshot)[1]
end

--[[ The guild members on the scoreboard that should be rewarded, sorted by
     guild rank and then by name. ]]--
function mod:FindRecipients(snapshot)
    snapshot = snapshot or self.snapshot
    if not snapshot then return {} end

    local recipients = {}

    for _, player in ipairs(snapshot.players) do
        local info = self.guildInfo[player.name]
        if info and self:MatchesRecipient(info) then
            tinsert(recipients, {
                name            = player.name,
                rank            = info.rank or '',
                rankIndex       = info.rankIndex or 99,
                class           = info.class,
                killingBlows    = player.killingBlows,
                honorableKills  = player.honorableKills,
                deaths          = player.deaths,
                honor           = player.honor,
            })
        end
    end

    table.sort(recipients, function(a, b)
        if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
        return a.name < b.name
    end)

    return recipients
end

--[[----------------------------------------------------------------------------
    Claiming the job
------------------------------------------------------------------------------]]

function mod:ResetClaim()
    if self.claimTimer then
        self:CancelTimer(self.claimTimer, true)
        self.claimTimer = nil
    end
    if self.earlyClaimTimer then
        self:CancelTimer(self.earlyClaimTimer, true)
        self.earlyClaimTimer = nil
    end
    self.claimedBy  = nil
    self.claimedAt  = nil
    self.announced  = nil
end

--[[ A claim from another client belongs to this battleground if it arrived
     around the time we left it. ]]--
function mod:HasFreshClaim()
    return self.claimedBy ~= nil
       and self.claimedAt ~= nil
       and GetTime() - self.claimedAt < CLAIM_EXPIRY
end

function mod:AnnounceDistributor(name, map)
    if self.announced == name then return end
    self.announced = name
    if self.db.profile.announceResponsible then
        self:Print(format("|cff82c5ff%s|r is responsible for EP distribution after %s.",
                          name, map or 'the battleground'))
    end
end

function mod:CHAT_MSG_ADDON(_, prefix, message, _, sender)
    if prefix ~= CLAIM_PREFIX then return end
    if not self:IsPluginEnabled() then return end

    local command, name = strsplit("\t", message or '')
    if command ~= "CLAIM" or not name or name == '' then return end

    local me = UnitName('player')
    if name == me then return end

    -- Claims from people who were not on our final scoreboard are about
    -- another battleground.
    local snapshot = self.snapshot
    if not snapshot then return end
    local present = false
    for _, player in ipairs(snapshot.players) do
        if player.name == name then
            present = true
            break
        end
    end
    if not present then return end

    -- Several claims: the alphabetically first name wins, which is the same
    -- order the snapshot was stored in. A later match cannot take the job
    -- from an earlier one.
    if self:HasFreshClaim() and self.claimedBy ~= name then
        if not (strlower(name) < strlower(self.claimedBy)) then return end
        if self.claimedBy == me then
            self:HideRewardWindow()
        end
    end

    if self.claimTimer then
        self:CancelTimer(self.claimTimer, true)
        self.claimTimer = nil
    end
    self.claimedBy = name
    self.claimedAt = GetTime()

    self:AnnounceDistributor(name, snapshot.map)
end

function mod:SendClaim()
    local me = UnitName('player')
    self.claimedBy = me
    self.claimedAt = GetTime()
    if IsInGuild() then
        SendAddonMessage(CLAIM_PREFIX, "CLAIM\t"..me, "GUILD")
    end
end

--[[ Runs inside the battleground once the final scoreboard is in. Only the
     first match claims here, the window still opens after leaving. ]]--
function mod:EarlyClaim()
    if not self.inBattleground or not self.snapshot then return end
    if not self:IsConfigured() or self:HasFreshClaim() then return end

    self:CacheGuildInfo()
    if self:FindDistributorCandidates(self.snapshot)[1] == UnitName('player') then
        self:SendClaim()
    end
end

function mod:ClaimDistribution(snapshot)
    self.claimTimer = nil
    local me = UnitName('player')
    if self:HasFreshClaim() and self.claimedBy ~= me then
        return self:AnnounceDistributor(self.claimedBy, snapshot.map)
    end

    self:SendClaim()

    self:Print(format("You are responsible for EP distribution after %s.",
                      snapshot.map or 'the battleground'))
    if self.db.profile.autoOpen then
        self:ShowRewardWindow(snapshot)
    end
end

function mod:ProcessSnapshot(snapshot)
    snapshot = snapshot or self.snapshot
    if not snapshot then return end

    self:CacheGuildInfo()

    if not self:IsConfigured() then
        return self:Print("No EP distributor rule is set yet, so nobody was asked to reward "..
                          "the battleground. Type /bgep to pick a guild rank or a public note tag.")
    end

    if self:HasFreshClaim() then
        if self.claimedBy == UnitName('player') then
            return self:ClaimDistribution(snapshot)
        end
        return self:AnnounceDistributor(self.claimedBy, snapshot.map)
    end

    local candidates = self:FindDistributorCandidates(snapshot)
    local me = UnitName('player')

    if #candidates == 0 then
        if self.db.profile.announceResponsible then
            self:Print(format(
                "Nobody on the %s scoreboard matches the EP distributor rule, so no EP was handed out. "..
                "Use /bgep show to open the reward window anyway.",
                snapshot.map or 'battleground'))
        end
        return
    end

    local myPlace
    for i, name in ipairs(candidates) do
        if name == me then
            myPlace = i
            break
        end
    end

    if not myPlace then
        -- Not a candidate: name the first match now, a claim may correct it.
        return self:AnnounceDistributor(candidates[1], snapshot.map)
    end

    -- The first match claims at once, the next one only if nobody has claimed
    -- by the time its turn comes, and so on.
    local delay = (myPlace - 1) * CLAIM_STEP
    if delay == 0 then
        self:ClaimDistribution(snapshot)
    else
        self.claimTimer = self:ScheduleTimer(function() mod:ClaimDistribution(snapshot) end, delay)
    end
end

--[[----------------------------------------------------------------------------
    Awarding
------------------------------------------------------------------------------]]

function mod:GetDefaultReason(snapshot)
    local reason = strtrim(self.db.profile.reason or '')
    if reason == '' then return 'BG' end
    return reason
end

--[[ Writes the EP. Individual awards are flagged as mass awards so the announce
     module stays quiet, then a single MassEPAward is fired for one summary line
     in chat and one entry per player in the EPGP log. ]]--
function mod:AwardEP(names, reason, amount)
    amount = tonumber(amount)
    reason = strtrim(reason or '')

    if not EPGP or not EPGP.IncEPBy then
        self:Print("EPGP is not loaded, no EP was awarded.")
        return false
    end

    if not names or #names == 0 then
        self:Print("Nobody was selected, no EP was awarded.")
        return false
    end

    if not EPGP:CanIncEPBy(reason, amount) then
        self:Print("EPGP refused the award. Check that you can edit officer notes, "..
                   "that the guild cache has finished loading, and that the amount and reason are valid.")
        return false
    end

    local awarded, count = {}, 0
    for _, name in ipairs(names) do
        local ep = EPGP:GetEPGP(name)
        if ep then
            EPGP:IncEPBy(name, reason, amount, true)
            awarded[name] = true
            count = count + 1
        else
            self:Print(format("Skipped %s, EPGP has no standings for that character.", name))
        end
    end

    if count > 0 and EPGP.callbacks then
        EPGP.callbacks:Fire("MassEPAward", awarded, reason, amount)
    end

    self:Print(format("Awarded %d EP (%s) to %d guild member(s).", amount, reason, count))
    return true
end

--[[----------------------------------------------------------------------------
    Slash commands
------------------------------------------------------------------------------]]

function mod:SlashHandler(input)
    local command = strlower(strtrim(input or ''))

    if command == '' or command == 'config' or command == 'options' then

        InterfaceOptionsFrame_OpenToCategory("EPGP Battlegrounds")

    elseif command == 'show' then

        local snapshot = self.snapshot or self.db.global.lastSnapshot
        if not snapshot then
            return self:Print("No battleground scoreboard has been recorded yet.")
        end
        self:CacheGuildInfo()
        self:ShowRewardWindow(snapshot)

    elseif command == 'who' then

        local snapshot = self.snapshot or self.db.global.lastSnapshot
        if not snapshot then
            return self:Print("No battleground scoreboard has been recorded yet.")
        end
        self:CacheGuildInfo()
        local distributor = self:FindDistributor(snapshot)
        self:Print(format("%s: %s is responsible, %d guild member(s) would be rewarded.",
                          snapshot.map or 'Battleground',
                          distributor or 'nobody',
                          #self:FindRecipients(snapshot)))

    elseif command == 'on' then

        self.db.profile.enabled = true
        self:Print("Battleground EP rewards are on.")

    elseif command == 'off' then

        self.db.profile.enabled = false
        self:Print("Battleground EP rewards are off.")

    elseif command == 'forget' then

        self.snapshot = nil
        self.db.global.lastSnapshot = nil
        self:Print("Stored battleground scoreboard discarded.")

    else

        self:Print(format("Battlegrounds %s", self.version))
        self:Print("/bgep - open the settings")
        self:Print("/bgep show - open the reward window for the last battleground")
        self:Print("/bgep who - print who would hand out the EP")
        self:Print("/bgep on|off - enable or disable the plugin")
        self:Print("/bgep forget - discard the stored scoreboard")

    end
end
