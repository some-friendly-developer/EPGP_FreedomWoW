--[[
    EPGP - Battlegrounds plugin, Blizzard interface options panel.
]]--

local mod = EPGPBattlegrounds

local function Get(info)
    return mod.db.profile[info[#info]]
end

local function Set(info, value)
    mod.db.profile[info[#info]] = value
end

local function GuildRanks()
    return mod:GetGuildRanks()
end

local MODE_VALUES = {
    rank = "A guild rank",
    tag  = "A tag in the public note",
}

local RECIPIENT_MODE_VALUES = {
    rank = "A guild rank",
    tag  = "A tag in the public note",
    all  = "Every guild member on the scoreboard",
}

local options = {
    name = "EPGP Battlegrounds",
    type = "group",
    get  = Get,
    set  = Set,
    args = {
        help = {
            order = 1,
            type  = "description",
            name  = "When a battleground ends this plugin records the final scoreboard. "..
                    "After you are teleported out, one guild member is asked to hand out the EP "..
                    "and everybody else is told who that is.\n\n"..
                    "|cffffd200Every officer must use the same rules below, otherwise different "..
                    "people will be asked to reward the same battleground.|r",
        },

        enabled = {
            order = 10,
            type  = "toggle",
            width = "full",
            name  = "Enable battleground EP",
            desc  = "Record battleground scoreboards and hand out EP afterwards.",
        },

        distributor = {
            order = 20,
            type  = "group",
            guiInline = true,
            name  = "Who hands out the EP",
            disabled = function() return not mod.db.profile.enabled end,
            args  = {
                help = {
                    order = 1,
                    type  = "description",
                    name  = "The alphabetically first match on the scoreboard hands out the EP. "..
                            "Sorting the scoreboard by a column does not change who is picked. "..
                            "The other matches only get a chat line naming that person. "..
                            "Make sure this rule only matches people who may edit officer notes.",
                },
                distributorMode = {
                    order = 2,
                    type  = "select",
                    width = "double",
                    name  = "Identify the responsible player by",
                    values = MODE_VALUES,
                },
                distributorRank = {
                    order = 3,
                    type  = "select",
                    width = "double",
                    name  = "Guild rank",
                    desc  = "Only members of this exact rank are asked to hand out the EP.",
                    values = GuildRanks,
                    hidden = function() return mod.db.profile.distributorMode ~= 'rank' end,
                },
                distributorTag = {
                    order = 4,
                    type  = "input",
                    width = "double",
                    name  = "Public note tag",
                    desc  = "Members whose public note contains this text are asked to hand out the EP. "..
                            "The match is case insensitive, for example @pvp.",
                    hidden = function() return mod.db.profile.distributorMode ~= 'tag' end,
                },
            },
        },

        recipients = {
            order = 30,
            type  = "group",
            guiInline = true,
            name  = "Who receives the EP",
            disabled = function() return not mod.db.profile.enabled end,
            args  = {
                help = {
                    order = 1,
                    type  = "description",
                    name  = "Guild members on the scoreboard that match this rule are listed in the "..
                            "reward window, pre-selected. You can still deselect people before awarding.",
                },
                recipientMode = {
                    order = 2,
                    type  = "select",
                    width = "double",
                    name  = "Identify guild members to reward by",
                    values = RECIPIENT_MODE_VALUES,
                },
                recipientRank = {
                    order = 3,
                    type  = "select",
                    width = "double",
                    name  = "Guild rank",
                    desc  = "Only members of this exact rank are rewarded.",
                    values = GuildRanks,
                    hidden = function() return mod.db.profile.recipientMode ~= 'rank' end,
                },
                recipientTag = {
                    order = 4,
                    type  = "input",
                    width = "double",
                    name  = "Public note tag",
                    desc  = "Members whose public note contains this text are rewarded. "..
                            "The match is case insensitive, for example @pvp.",
                    hidden = function() return mod.db.profile.recipientMode ~= 'tag' end,
                },
            },
        },

        award = {
            order = 40,
            type  = "group",
            guiInline = true,
            name  = "Award",
            disabled = function() return not mod.db.profile.enabled end,
            args  = {
                amount = {
                    order = 1,
                    type  = "range",
                    width = "double",
                    name  = "Default EP",
                    desc  = "Pre-filled amount in the reward window. It can still be changed there.",
                    min = 1, max = 500, step = 1,
                },
                reason = {
                    order = 2,
                    type  = "input",
                    width = "double",
                    name  = "Reason",
                    desc  = "Pre-filled reason in the reward window and the EPGP log, for example \"BG\".",
                },
                autoOpen = {
                    order = 3,
                    type  = "toggle",
                    width = "full",
                    name  = "Open the reward window automatically",
                    desc  = "Uncheck to only get a chat reminder. You can open the window with /bgep show.",
                },
                announceResponsible = {
                    order = 4,
                    type  = "toggle",
                    width = "full",
                    name  = "Tell me who is responsible",
                    desc  = "Print a chat line naming the guild member that is handing out the EP.",
                },
            },
        },

        tools = {
            order = 50,
            type  = "group",
            guiInline = true,
            name  = "Last battleground",
            args  = {
                status = {
                    order = 1,
                    type  = "description",
                    name  = function()
                                local snapshot = mod.snapshot or mod.db.global.lastSnapshot
                                if not snapshot then
                                    return "No battleground scoreboard has been recorded yet."
                                end
                                mod:CacheGuildInfo()
                                return format("%s, recorded %s.\nResponsible: %s. Guild members to reward: %d.",
                                              snapshot.map or 'Battleground',
                                              date("%Y-%m-%d %H:%M", snapshot.finished or time()),
                                              mod:FindDistributor(snapshot) or 'nobody',
                                              #mod:FindRecipients(snapshot))
                            end,
                },
                show = {
                    order = 2,
                    type  = "execute",
                    name  = "Open the reward window",
                    func  = function()
                                mod:CacheGuildInfo()
                                mod:ShowRewardWindow()
                            end,
                    disabled = function()
                                   return not (mod.snapshot or mod.db.global.lastSnapshot)
                               end,
                },
                forget = {
                    order = 3,
                    type  = "execute",
                    name  = "Discard it",
                    func  = function()
                                mod.snapshot = nil
                                mod.db.global.lastSnapshot = nil
                            end,
                    disabled = function()
                                   return not (mod.snapshot or mod.db.global.lastSnapshot)
                               end,
                },
            },
        },
    },
}

-- Called from OnInitialize in bg_core.lua.
function mod:SetupOptions()
    local config = LibStub("AceConfig-3.0")
    local dialog = LibStub("AceConfigDialog-3.0")

    config:RegisterOptionsTable("EPGP Battlegrounds", options)
    dialog:AddToBlizOptions("EPGP Battlegrounds", "EPGP Battlegrounds")
end
