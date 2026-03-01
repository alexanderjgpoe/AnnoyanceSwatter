local AceGUI = LibStub("AceGUI-3.0")

AnnoyanceSwatterUI = {}
AnnoyanceSwatterUI.offenderLines = {}
AnnoyanceSwatterUI.db = nil -- Set by Core

-- =====================================
-- DB Injection
-- =====================================
function AnnoyanceSwatterUI:SetDB(db)
    self.db = db
end

-- =====================================
-- Create Main UI Frame
-- =====================================
function AnnoyanceSwatterUI:Create()
    if self.frame then return end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("AnnoyanceSwatter")
    frame:SetStatusText("These players used an annoyance.")
    frame:SetLayout("Flow")
    frame:SetWidth(580)
    frame:SetHeight(360)
    frame:Hide()
    frame:EnableResize(true)

    -- Scroll container
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    frame:AddChild(scroll)

    self.frame = frame
    self.scroll = scroll
end

-- =====================================
-- Add a row to the offender list
-- =====================================
function AnnoyanceSwatterUI:AddOffender(player, spell)
    if not self.frame or not self.scroll then return end

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(32)

    --------------------------------------------------------
    -- Player name label
    --------------------------------------------------------
    local nameLabel = AceGUI:Create("Label")
    nameLabel:SetText(player)
    nameLabel:SetWidth(150)
    row:AddChild(nameLabel)

    --------------------------------------------------------
    -- Spell name label
    --------------------------------------------------------
    local spellLabel = AceGUI:Create("Label")
    spellLabel:SetText(spell)
    spellLabel:SetWidth(160)
    row:AddChild(spellLabel)

    --------------------------------------------------------
    -- Add to UI
    --------------------------------------------------------
    self.scroll:AddChild(row)
    table.insert(self.offenderLines, row)
end


-- =====================================
-- Clear entire offender list
-- =====================================
function AnnoyanceSwatterUI:Clear()
    if not self.scroll then return end

    for _, row in ipairs(self.offenderLines) do
        self.scroll:RemoveChild(row)
    end

    self.offenderLines = {}
end


-- =====================================
-- Show / Hide UI
-- =====================================
function AnnoyanceSwatterUI:Show()
    if self.frame then
        self.frame:Show()
    end
end

function AnnoyanceSwatterUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
