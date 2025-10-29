local AceGUI = LibStub("AceGUI-3.0")

AnnoyanceSwatterUI = {}
AnnoyanceSwatterUI.offenderLines = {}
AnnoyanceSwatterUI.db = nil -- reference to addon DB

-- Inject DB from core
function AnnoyanceSwatterUI:SetDB(db)
    self.db = db
end

-- Create the main frame
function AnnoyanceSwatterUI:Create()
    if self.frame then return end

    -- Main frame
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("AnnoyanceSwatter")
    frame:SetStatusText("These players used an annoyance.")
    frame:SetLayout("Fill")
    frame:SetWidth(480)
    frame:SetHeight(320)
    frame:Hide() -- hidden until /as show
    frame:EnableResize(true)

    -- Scrollable list for offenders
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    frame:AddChild(scroll)

    self.frame = frame
    self.scroll = scroll
end

-- Add a single offender line
function AnnoyanceSwatterUI:AddOffender(player, spell)
    if not self.frame or not self.scroll then return end

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetWidth(460)
    row:SetHeight(28)

    -- Player name
    local nameLabel = AceGUI:Create("Label")
    nameLabel:SetText(player)
    nameLabel:SetWidth(150)
    row:AddChild(nameLabel)

    -- Spell name
    local spellLabel = AceGUI:Create("Label")
    spellLabel:SetText(spell)
    spellLabel:SetWidth(150)
    row:AddChild(spellLabel)

    -- Raid kick button
    if self.db and self.db.profile.autoRaidKick then
        local raidButton = AceGUI:Create("Button")
        raidButton:SetText("Raid Kick")
        raidButton:SetWidth(80)
        raidButton:SetCallback("OnClick", function()
            if IsRaidLeader() or IsRaidOfficer() then
                KickByName(player)
            end
        end)
        row:AddChild(raidButton)
    end

    -- Guild kick button
    if self.db and self.db.profile.autoGuildKick then
        local guildButton = AceGUI:Create("Button")
        guildButton:SetText("Guild Kick")
        guildButton:SetWidth(80)
        guildButton:SetCallback("OnClick", function()
            if IsGuildLeader() then
                GuildUninvite(player)
            end
        end)
        row:AddChild(guildButton)
    end

    self.scroll:AddChild(row)
    table.insert(self.offenderLines, row)
end

-- Clear the offender list
function AnnoyanceSwatterUI:Clear()
    for _, row in ipairs(self.offenderLines) do
        if self.scroll and self.scroll.RemoveChild then
            self.scroll:RemoveChild(row)
        end
    end
    self.offenderLines = {}
end

function AnnoyanceSwatterUI:Show()
    if self.frame then self.frame:Show() end
end

function AnnoyanceSwatterUI:Hide()
    if self.frame then self.frame:Hide() end
end
