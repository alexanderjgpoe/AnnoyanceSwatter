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
            { keyword = "Mohawk", name = "Mohawk Grenade", autoRemove = true },
            { keyword = "Levitate", name = "Levitate", autoRemove = true },
            { keyword = "Wisp", name = "Wisp Costume", autoRemove = false },
            { keyword = "Spider", name = "Spider Costume", autoRemove = false },
            { keyword = "Ghoul", name = "Ghoul Costume", autoRemove = false },
            { keyword = "Jack", name = "Jack-o'-Lanterned!", autoRemove = false },
            { keyword = "Leper", name = "Leper Gnome Costume", autoRemove = false },
            { keyword = "Skeleton", name = "Skeleton Costume", autoRemove = false },
            { keyword = "Pirate", name = "Pirate Costume", autoRemove = false },
            { keyword = "Ninja", name = "Ninja Costume", autoRemove = false },
            { keyword = "Ghost", name = "Ghost Costume", autoRemove = false },
            { keyword = "Bat", name = "Bat Costume", autoRemove = false },
            { keyword = "Vampire", name = "Vampire Costume", autoRemove = false },
            { keyword = "Nerubian", name = "Nerubian Costume", autoRemove = false },
            { keyword = "Slime", name = "Slime Costume", autoRemove = false },
        },
        autoRaidKick = false,
        autoGuildKick = false,
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
    self:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
    --self:RegisterEvent("UNIT_AURA")
    print("|cff00ff00AnnoyanceSwatter enabled.|r Type /as or /annoyanceswatter for options.")
end

-- =============================
-- Slash Commands
-- =============================
function AnnoyanceSwatter:HandleSlashCommand(input)
    input = input and input:trim():lower()
    if input == "config" or input == "" then
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("AnnoyanceSwatter")
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
    if IsInRaid() and SendChatMessage then
        SendChatMessage(msg, "RAID_WARNING")
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

    -- Track both SPELL_CAST_SUCCESS and SPELL_AURA_APPLIED (since some only appear as auras)
    if eventType ~= "SPELL_CAST_SUCCESS" and eventType ~= "SPELL_AURA_APPLIED" then
        return
    end

    for _, entry in ipairs(self.db.profile.trackedSpells) do
        if spellName:lower():find(entry.keyword:lower()) then
            -- Only care about players in your group/raid
            if not (UnitInParty(sourceName) or UnitInRaid(sourceName)) then
                return
            end

            local key = sourceName .. ":" .. entry.name
            local now = GetTime()

            -- If this player/spell combo was seen recently, ignore
            if recentLogs[key] and (now - recentLogs[key]) < 0.5 then
                return
            end
            recentLogs[key] = now

            -- Log offender
            self:AddOffender(sourceName, entry.name)
            RaidWarn(sourceName .. " used " .. entry.name)

            -- Remove the buff from the player if needed
            if entry.autoRemove and destName == UnitName("player") then
                C_Timer.After(0.5, function()
                    self:CancelBuffByID("player", spellID)
                end)
            end
        end
    end
end


-- =============================
-- Emote Tracking
-- =============================
function AnnoyanceSwatter:CHAT_MSG_TEXT_EMOTE(event, msg, playerName)
    if not playerName then return end
    local lowerMsg = msg:lower()
    if lowerMsg:find("mohawk") or lowerMsg:find("grenade") then
        if (UnitInRaid(playerName) or UnitInParty(playerName)) and CanLog(self, playerName) then
            self:AddOffender(playerName, "Mohawk Grenade")
            RaidWarn(playerName .. " used Mohawk Grenade")
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
-- Cancel Buff by Spell ID
-- =============================
function AnnoyanceSwatter:CancelBuffByID(unit, spellID)
    if not UnitBuff then return end
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, id = UnitBuff(unit, i)
        if id == spellID then
            CancelUnitBuff(unit, i)
            print("|cff00ffffAnnoyanceSwatter:|r Removed " .. name)
            break
        end
    end
end

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
            desc = "Automatically remove " .. spellData.name .. " when applied to you.",
            order = order,
            get = function() return self.db.profile.trackedSpells[idx].autoRemove end,
            set = function(_, val) self.db.profile.trackedSpells[idx].autoRemove = val end,
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
            autoRaidKick = {
                type = "toggle",
                name = "Enable Auto Raid Kick Button",
                desc = "Show a button to automatically raid kick offenders.",
                order = 3,
                get = function() return self.db.profile.autoRaidKick end,
                set = function(_, val) self.db.profile.autoRaidKick = val end,
            },
            autoGuildKick = {
                type = "toggle",
                name = "Enable Auto Guild Kick Button",
                desc = "Show a button to automatically guild kick offenders.",
                order = 4,
                get = function() return self.db.profile.autoGuildKick end,
                set = function(_, val) self.db.profile.autoGuildKick = val end,
            },
        },
    }

    AceConfig:RegisterOptionsTable("AnnoyanceSwatter", options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("AnnoyanceSwatter", "AnnoyanceSwatter")
end
