--[[
    EPGP LootMaster - Stand-In plugin, Blizzard interface options panel.
]]--

local mod = EPGPStandIn

local function Get(info)
    return mod.db.global[info[#info]]
end

local function Set(info, value)
    mod.db.global[info[#info]] = value
    mod:Changed()
end

local options = {
    name = "EPGP Stand-In",
    type = "group",
    get  = Get,
    set  = Set,
    args = {
        help = {
            order = 1,
            type  = "description",
            name  = "A stand-in lets a raider use another character's EP/GP for a raid. "..
                    "The master looter window keeps showing the raider as \"Raider (Stand-in)\", "..
                    "but EP, GP and PR are read from - and written to - the stand-in.",
        },

        enabled = {
            order = 10,
            type  = "toggle",
            width = "full",
            name  = "Stand-ins active",
            desc  = "Uncheck to pause every stand-in at once. The list is kept.",
        },

        awards = {
            order = 20,
            type  = "group",
            guiInline = true,
            name  = "Awards",
            args  = {
                redirectEP = {
                    order = 1,
                    type  = "toggle",
                    width = "full",
                    name  = "Award EP to the stand-in",
                    desc  = "EP handed out for a raider is written to his stand-in's officer note. "..
                            "Turn this off if the raider should keep collecting EP on his own character.",
                },
                redirectGP = {
                    order = 2,
                    type  = "toggle",
                    width = "full",
                    name  = "Charge GP to the stand-in",
                    desc  = "GP charged for loot won by a raider is written to his stand-in's officer note. "..
                            "Turn this off if loot should be charged to the character that actually received it.",
                },
            },
        },

        list = {
            order = 30,
            type  = "group",
            guiInline = true,
            name  = "Stand-in list",
            args  = {
                open = {
                    order = 1,
                    type  = "execute",
                    name  = "Open the stand-in window",
                    desc  = "Add, edit, enable and remove stand-ins.",
                    func  = function() mod:ShowWindow() end,
                },
                count = {
                    order = 2,
                    type  = "description",
                    name  = function()
                                local total, active = mod:GetNumEntries(), 0
                                for _, entry in ipairs(mod.db.global.entries) do
                                    if entry.enabled then active = active + 1 end
                                end
                                return format("\n%d stand-in(s) stored, %d active.", total, active)
                            end,
                },
                hint = {
                    order = 3,
                    type  = "description",
                    name  = "\nThe list is stored per account, so it survives logouts and is shared "..
                            "by every character you play.\n\n"..
                            "You can also right click a candidate in the loot window and pick "..
                            "\"Set stand-in...\", or use /standin from the chat frame.",
                },
            },
        },
    },
}

-- Called from OnInitialize in standin_core.lua.
function mod:SetupOptions()
    local config = LibStub("AceConfig-3.0")
    local dialog = LibStub("AceConfigDialog-3.0")

    config:RegisterOptionsTable("EPGP Stand-In", options)
    dialog:AddToBlizOptions("EPGP Stand-In", "EPGP Stand-In")
end
