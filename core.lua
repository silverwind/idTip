local hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID, GetGlyphSocketInfo, tonumber, strfind, strsub, strmatch =
      hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID, GetGlyphSocketInfo, tonumber, strfind, strsub, strmatch

local wod = select(4, GetBuildInfo()) >= 60000

local types = {
    spell       = "SpellID",
    item        = "ItemID",
    glyph       = "GlyphID",
    unit        = "NPC ID",
    quest       = "QuestID",
    talent      = "TalentID",
    achievement = "AchievementID"
}

local function addLine(tooltip, id, type, noEmptyLine)
    local found = false

    -- Check if we already added to this tooltip. Happens on the talent frame
    for i = 1,15 do
        local frame = _G[tooltip:GetName() .. "TextLeft" .. i]
        local text
        if frame then text = frame:GetText() end
        if text and text == type then found = true break end
    end

    if not found then
        if not noEmptyLine then tooltip:AddLine(" ") end
        tooltip:AddDoubleLine(type .. ":", "|cffffffff" .. id)
        tooltip:Show()
    end
end

-- All types, primarily for linked tooltips
local function onSetHyperlink(self, link)
    local type, id = string.match(link,"^(%a+):(%d+)")
    if not type or not id then return end
    if type == "spell" or type == "enchant" or type == "trade" then
        addLine(self, id, types.spell)
    elseif type == "glyph" then
        addLine(self, id, types.glyph)
    elseif type == "talent" then
        addLine(self, id, types.talent)
    elseif type == "quest" then
        addLine(self, id, types.quest)
    elseif type == "achievement" then
        addLine(self, id, types.achievement)
    elseif type == "item" then
        addLine(self, id, types.item)
    end
end

hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)

-- Spells
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, ...)
    local id = select(11, UnitBuff(...))
    if id then addLine(self, id, types.spell) end
end)

hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self,...)
    local id = select(11, UnitDebuff(...))
    if id then addLine(self, id, types.spell) end
end)

hooksecurefunc(GameTooltip, "SetUnitAura", function(self,...)
    local id = select(11, UnitAura(...))
    if id then addLine(self, id, types.spell) end
end)

hooksecurefunc("SetItemRef", function(link, ...)
    local id = tonumber(link:match("spell:(%d+)"))
    if id then addLine(ItemRefTooltip, id, types.spell) end
end)

GameTooltip:HookScript("OnTooltipSetSpell", function(self)
    local id = select(3, self:GetSpell())
    if id then addLine(self, id, types.spell) end
end)

-- NPCs
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    if C_PetBattles.IsInBattle() then return end
    local unit = select(2, self:GetUnit())
    if unit then
        local id = wod and tonumber(strmatch(UnitGUID(unit) or "", "-(%d+)-%x+$"), 10) or tonumber(strsub(UnitGUID(unit) or "", 6, 10), 16)
        -- ID 970 seems to be used for players
        if id and id ~= 0 and id ~= 970 then addLine(GameTooltip, id, types.unit) end
    end
end)

-- Items
local function attachItemTooltip(self)
    local link = select(2, self:GetItem())
    if link then
        local id = select(3, strfind(link, "^|%x+|Hitem:(%-?%d+):(%d+):(%d+).*"))
        if id then addLine(self, id, types.item) end
    end
end

GameTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)

-- Glyphs
hooksecurefunc(GameTooltip, "SetGlyph", function(self, ...)
    local id = select(4, GetGlyphSocketInfo(...))
    if id then addLine(self, id, types.glyph) end
end)

hooksecurefunc(GameTooltip, "SetGlyphByID", function(self, id)
    if id then addLine(self, id, types.glyph) end
end)

-- Achievement Frame Tooltips
local f = CreateFrame("frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, what)
    if what == "Blizzard_AchievementUI" then
        for i,button in ipairs(AchievementFrameAchievementsContainer.buttons) do
            button:HookScript("OnEnter", function()
                GameTooltip:SetOwner(button, "ANCHOR_NONE")
                GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
                addLine(GameTooltip, button.id, types.achievement, true)
                GameTooltip:Show()
            end)
            button:HookScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end
end)

