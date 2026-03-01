-- =============================
-- AnnoyanceSwatter Core.lua
-- =============================

local AnnoyanceSwatter = LibStub("AceAddon-3.0"):NewAddon(
    "AnnoyanceSwatter", "AceConsole-3.0", "AceEvent-3.0"
)

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

-- =============================
-- Default Settings
-- =============================
local defaults = {
    profile = {
        trackedSpells = {
            { keyword = "Mohawk", name = "Mohawk Grenade", enabled = true  },
            { keyword = "Mohawked", name = "Mohawk Grenade", enabled = true  },
            { keyword = "Mohawked!", name = "Mohawk Grenade", enabled = true },
            { keyword = "Levitate", name = "Levitate", enabled = true  },
            { keyword = "Wisp", name = "Wisp Costume", enabled = true  },
            { keyword = "Spider", name = "Spider Costume", enabled = true  },
            { keyword = "Ghoul", name = "Ghoul Costume", enabled = true  },
            { keyword = "Jack", name = "Jack-o'-Lanterned!", enabled = true  },
            { keyword = "Leper", name = "Leper Gnome Costume", enabled = true  },
            { keyword = "Skeleton", name = "Skeleton Costume", enabled = true  },
            { keyword = "Pirate", name = "Pirate Costume", enabled = true  },
            { keyword = "Ninja", name = "Ninja Costume", enabled = true  },
            { keyword = "Ghost", name = "Ghost Costume", enabled = true  },
            { keyword = "Bat", name = "Bat Costume", enabled = true  },
            { keyword = "Vampire", name = "Vampire Costume", enabled = true  },
            { keyword = "Nerubian", name = "Nerubian Costume", enabled = true  },
            { keyword = "Slime", name = "Slime Costume", enabled = true  },
            { keyword = "Turkey", name = "Turkey Feathers", enabled = true  },
            { keyword = "Slow Fall", name = "Slow Fall", enabled = true  },
            { keyword = "Moonkin Feather", name = "Moonkin Statue", enabled = true  },
        }
    }
}

-- =============================
-- Initialize
-- =============================
function AnnoyanceSwatter:OnInitialize()
    self.db = AceDB:New("AnnoyanceSwatterDB", defaults, true)
    self.trackedPlayers = {}
    self.recentlyLogged = {} -- throttle table

    self:SetupOptions()

    if AnnoyanceSwatterUI then
        AnnoyanceSwatterUI.db = self.db
        AnnoyanceSwatterUI:Create()
    end

    self:RegisterChatCommand("as", "HandleSlashCommand")
    self:RegisterChatCommand("annoyanceswatter", "HandleSlashCommand")
end

-- =============================
-- Enable Events
-- =============================
function AnnoyanceSwatter:OnEnable()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    --self:RegisterEvent("UNIT_AURA")
    print("|cff00ff00AnnoyanceSwatter enabled.|r Type /as or /annoyanceswatter for options.")
end

-- =============================
-- Slash Commands
-- =============================
function AnnoyanceSwatter:HandleSlashCommand(input)
    input = input and input:trim():lower()
    if input == "config" or input == "" then
        if AceConfigDialog then
            AceConfigDialog:Open("AnnoyanceSwatter")
        else
            print("AnnoyanceSwatter: Settings panel unavailable.")
        end
    elseif input == "show" then
        if AnnoyanceSwatterUI then
            AnnoyanceSwatterUI:Show()
        else
            print("UI not loaded.")
        end
    else
        print("Usage: /as show | /as config")
    end
end

-- =============================
-- Helper: Raid Warning
-- =============================
local function RaidWarn(msg)
    if IsInRaid() then
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            C_ChatInfo.SendChatMessage(msg, "RAID_WARNING")
        else
            C_ChatInfo.SendChatMessage(msg, "RAID")
        end
    elseif IsInGroup() then
        C_ChatInfo.SendChatMessage(msg, "PARTY")
    else
        print(msg)
    end
end
-- =============================
-- Cooldown Helper (0.5 sec throttle)
-- =============================
local function CanLog(self, player)
    local now = GetTime()
    if not self.recentlyLogged[player] or (now - self.recentlyLogged[player]) > 0.5 then
        self.recentlyLogged[player] = now
        return true
    end
    return false
end

-- =============================
-- Combat Log Detection
-- =============================
-- Table to store recent offenders and their timestamps
local recentLogs = {}

function AnnoyanceSwatter:COMBAT_LOG_EVENT_UNFILTERED()
    local _, eventType, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName =
        CombatLogGetCurrentEventInfo()

    if not sourceName or not spellName then return end

    -- Only care about successful casts or aura applications
    if eventType ~= "SPELL_CAST_SUCCESS" and eventType ~= "SPELL_AURA_APPLIED" then
        return
    end

    for _, entry in ipairs(self.db.profile.trackedSpells) do
        if entry.enabled and spellName:lower():find(entry.keyword:lower()) then

            -- Only care about group members
            if not (UnitInParty(sourceName) or UnitInRaid(sourceName)) then
                return
            end

            local key = sourceName .. ":" .. entry.name
            local now = GetTime()

            if not self.recentlyLogged[key] or (now - self.recentlyLogged[key]) > 0.5 then
                self.recentlyLogged[key] = now

                self:AddOffender(sourceName, entry.name)
                RaidWarn(sourceName .. " used " .. entry.name)
            end

            break -- stop checking after match
        end
    end
end

-- =============================
-- Aura Tracking
-- =============================
--[[
function AnnoyanceSwatter:UNIT_AURA(event, unit)
    if not UnitBuff then return end
    for i = 1, 40 do
        local name, _, _, _, _, _, source, _, _, spellID = UnitBuff(unit, i)
        if not name then break end
        local lowerName = name:lower()
        for _, entry in ipairs(self.db.profile.trackedSpells) do
            if lowerName:find(entry.keyword:lower()) then
                local caster = source or "unknown"
                if (UnitInParty(caster) or UnitInRaid(caster)) and CanLog(self, caster) then
                    self:AddOffender(caster, entry.name)
                    RaidWarn(caster .. " used " .. entry.name)
                end
                if entry.autoRemove and unit == "player" then
                    C_Timer.After(0.5, function()
                        self:CancelBuffByID("player", spellID)
                    end)
                end
            end
        end
    end
end
]]

-- =============================
-- Add Offender
-- =============================
function AnnoyanceSwatter:AddOffender(player, spell)
    if not self.trackedPlayers[player] then
        self.trackedPlayers[player] = {}
    end
    table.insert(self.trackedPlayers[player], spell)

    if AnnoyanceSwatterUI then
        AnnoyanceSwatterUI:AddOffender(player, spell)
    end

    print(string.format("|cffff0000Annoyance detected:|r %s used %s", player, spell))
end

-- =============================
-- Options Panel
-- =============================
function AnnoyanceSwatter:SetupOptions()
    local spellArgs = {}
    local order = 10
    for idx, spellData in ipairs(self.db.profile.trackedSpells) do
        spellArgs["spell"..idx] = {
            type = "toggle",
            name = spellData.name,
            order = order,
            get = function()
                return self.db.profile.trackedSpells[idx].enabled
            end,
            set = function(_, val)
                self.db.profile.trackedSpells[idx].enabled = val
            end,
        }
        order = order + 1
    end

    local options = {
        name = "AnnoyanceSwatter",
        type = "group",
        args = {
            desc = {
                type = "description",
                name = "AnnoyanceSwatter: Detect and punish annoying spell users.",
                order = 1,
            },
            trackedSpells = {
                type = "group",
                name = "Tracked Spells / Buffs",
                inline = true,
                order = 2,
                args = spellArgs,
            },
        },
    }

    AceConfig:RegisterOptionsTable("AnnoyanceSwatter", options)
end

