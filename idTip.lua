local hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID,
      GetGlyphSocketInfo, tonumber, strfind
    = hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID,
      GetGlyphSocketInfo, tonumber, strfind

local types = {
  spell = "SpellID",
  item = "ItemID",
  unit = "NpcID",
  quest = "QuestID",
  talent = "TalentID",
  achievement = "AchievementID",
  criteria = "CriteriaID",
  ability = "AbilityID",
  currency = "CurrencyID",
  artifactpower = "ArtifactPowerID",
  enchant = "EnchantID",
  bonus = "BonusID",
  gem = "GemID",
  mount = "MountID",
  companion = "CompanionID",
  macro = "MacroID",
  equipmentset = "EquipmentSetID",
}

-- debug dump function
local function dump(...)
  LoadAddOn("Blizzard_DebugTools")
  for key, value in ipairs({...}) do
    DevTools_Dump(value)
  end
end

local function addLine(tooltip, id, type)
  local found = false
  if not id or id == "" then return end

  -- Check if we already added to this tooltip. Happens on the talent frame
  for i = 1,15 do
    local frame = _G[tooltip:GetName() .. "TextLeft" .. i]
    local text
    if frame then text = frame:GetText() end
    if text and text == type then found = true break end
  end

  if not found then
    tooltip:AddLine(NORMAL_FONT_COLOR_CODE .. type .. ": ".. HIGHLIGHT_FONT_COLOR_CODE .. id .. FONT_COLOR_CODE_CLOSE)
    tooltip:Show()
  end
end

local function addLineByType(self, id, type)
  if not type or not id then return end
  if type == "spell" or type == "enchant" or type == "trade" then
    addLine(self, id, types.spell)
  elseif type == "talent" then
    addLine(self, id, types.talent)
  elseif type == "quest" then
    addLine(self, id, types.quest)
  elseif type == "achievement" then
    addLine(self, id, types.achievement)
  elseif type == "item" then
    addLine(self, id, types.item)
  elseif type == "currency" then
    addLine(self, id, types.currency)
  elseif type == "summonmount" then
    addLine(self, id, types.mount)
  elseif type == "companion" then
    addLine(self, id, types.companion)
  elseif type == "macro" then
    addLine(self, id, types.macro)
  elseif type == "equipmentset" then
    addLine(self, id, types.equipmentset)
  end
end

-- All types, primarily for detached tooltips
local function onSetHyperlink(self, link)
  local type, id = string.match(link,"^(%a+):(%d+)")
  addLineByType(self, type, id)
end

hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)

-- Spells
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, ...)
  local id = select(10, UnitBuff(...))
  addLine(self, id, types.spell)
end)

hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, ...)
  local id = select(10, UnitDebuff(...))
  addLine(self, id, types.spell)
end)

hooksecurefunc(GameTooltip, "SetUnitAura", function(self, ...)
  local id = select(10, UnitAura(...))
  addLine(self, id, types.spell)
end)

hooksecurefunc(GameTooltip, "SetAction", function(self, slot)
  local type, id = GetActionInfo(slot)
  addLineByType(self, id, type)
end)

hooksecurefunc(GameTooltip, "SetSpellByID", function(self, id)
  addLineByType(self, id, types.spell)
end)

hooksecurefunc("SetItemRef", function(link, ...)
  local id = tonumber(link:match("spell:(%d+)"))
  addLine(ItemRefTooltip, id, types.spell)
end)

GameTooltip:HookScript("OnTooltipSetSpell", function(self)
  local id = select(3, self:GetSpell())
  addLine(self, id, types.spell)
end)

hooksecurefunc("SpellButton_OnEnter", function(self)
  local slot = SpellBook_GetSpellBookSlot(self)
  local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
  addLine(GameTooltip, spellID, types.spell)
end)

-- Artifact Powers
hooksecurefunc(GameTooltip, "SetArtifactPowerByID", function(self, powerID)
  local powerInfo = C_ArtifactUI.GetPowerInfo(powerID)
  addLine(self, powerID, types.artifactpower)
  addLine(self, powerInfo.spellID, types.spell)
end)

-- Talents
hooksecurefunc(GameTooltip, "SetTalent", function(self, id)
  addLine(self, id, types.talent)
end)
hooksecurefunc(GameTooltip, "SetPvpTalent", function(self, id)
  addLine(self, id, types.talent)
end)

-- NPCs
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
  if C_PetBattles.IsInBattle() then return end
  local unit = select(2, self:GetUnit())
  if unit then
    local guid = UnitGUID(unit) or ""
    local id = tonumber(guid:match("-(%d+)-%x+$"), 10)
    if id and guid:match("%a+") ~= "Player" then addLine(GameTooltip, id, types.unit) end
  end
end)

-- Items
hooksecurefunc(GameTooltip, "SetToyByItemID", function(self, id)
  addLineByType(self, id, "item")
end)

local function attachItemTooltip(self)
  local link = select(2, self:GetItem())
  if not link then return end

  local itemString = string.match(link, "item:([%-?%d:]+)")
  if not itemString then return end

  local enchantid = ""
  local bonusid = ""
  local gemid = ""
  local bonuses = {}
  local itemSplit = {}

  for v in string.gmatch(itemString, "(%d*:?)") do
    if v == ":" then
      itemSplit[#itemSplit + 1] = 0
    else
      itemSplit[#itemSplit + 1] = string.gsub(v, ":", "")
    end
  end

  for index = 1, tonumber(itemSplit[13]) do
    bonuses[#bonuses + 1] = itemSplit[13 + index]
  end

  local gems = {}
  for i=1, 4 do
    local _,gemLink = GetItemGem(link, i)
    if gemLink then
      local gemDetail = string.match(gemLink, "item[%-?%d:]+")
      gems[#gems + 1] = string.match(gemDetail, "item:(%d+):")
    elseif flags == 256 then
      gems[#gems + 1] = "0"
    end
  end

  local id = string.match(link, "item:(%d*)")
  if (id == "" or id == "0") and TradeSkillFrame ~= nil and TradeSkillFrame:IsVisible() and GetMouseFocus().reagentIndex then
    local selectedRecipe = TradeSkillFrame.RecipeList:GetSelectedRecipeID()
    for i = 1, 8 do
      if GetMouseFocus().reagentIndex == i then
        id = C_TradeSkillUI.GetRecipeReagentItemLink(selectedRecipe, i):match("item:(%d*)") or nil
        break
      end
    end
  end

  if id then
    addLine(self, id, types.item)
    if itemSplit[2] ~= 0 then
      enchantid = itemSplit[2]
      addLine(self, enchantid, types.enchant)
    end
    if #bonuses > 0 then
      bonusid = table.concat(bonuses, "/")
      addLine(self, bonusid, types.bonus)
    end
    if #gems > 0 then
      gemid = table.concat(gems, "/")
      addLine(self, gemid, types.gem)
    end
  end
end

GameTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)

-- Achievement Frame Tooltips
local f = CreateFrame("frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, what)
  if what == "Blizzard_AchievementUI" then
    for i,button in ipairs(AchievementFrameAchievementsContainer.buttons) do
      button:HookScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
        addLine(GameTooltip, button.id, types.achievement)
        GameTooltip:Show()
      end)
      button:HookScript("OnLeave", function()
        GameTooltip:Hide()
      end)

      local hooked = {}
      hooksecurefunc("AchievementButton_GetCriteria", function(index, renderOffScreen)
        local frame = _G["AchievementFrameCriteria" .. (renderOffScreen and "OffScreen" or "") .. index]
        if frame and not hooked[frame] then
          frame:HookScript("OnEnter", function(self)
            local button = self:GetParent() and self:GetParent():GetParent()
            if not button or not button.id then return end
            local criteriaid = select(10, GetAchievementCriteriaInfo(button.id, index))
            if criteriaid then
              GameTooltip:SetOwner(button:GetParent(), "ANCHOR_NONE")
              GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
              addLine(GameTooltip, button.id, types.achievement)
              addLine(GameTooltip, criteriaid, types.criteria)
              GameTooltip:Show()
            end
          end)
          frame:HookScript("OnLeave", function()
            GameTooltip:Hide()
          end)
          hooked[frame] = true
        end
      end)
    end
  end
end)

-- Pet battle buttons
hooksecurefunc("PetBattleAbilityButton_OnEnter", function(self)
  local petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
  if self:GetEffectiveAlpha() > 0 then
    local id = select(1, C_PetBattles.GetAbilityInfo(LE_BATTLE_PET_ALLY, petIndex, self:GetID()))
    if id then
      local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
      PetBattlePrimaryAbilityTooltip.Description:SetText(oldText .. "\r\r" .. types.ability .. "|cffffffff " .. id .. "|r")
    end
  end
end)

-- Pet battle auras
hooksecurefunc("PetBattleAura_OnEnter", function(self)
  local parent = self:GetParent()
  local id = select(1, C_PetBattles.GetAuraInfo(parent.petOwner, parent.petIndex, self.auraIndex))
  if id then
    local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
    PetBattlePrimaryAbilityTooltip.Description:SetText(oldText .. "\r\r" .. types.ability .. "|cffffffff " .. id .. "|r")
  end
end)

-- Currencies
hooksecurefunc(GameTooltip, "SetCurrencyToken", function(self, index)
  local id = tonumber(string.match(GetCurrencyListLink(index),"currency:(%d+)"))
  addLine(self, id, types.currency)
end)

hooksecurefunc(GameTooltip, "SetCurrencyByID", function(self, id)
   addLine(self, id, types.currency)
end)

hooksecurefunc(GameTooltip, "SetCurrencyTokenByID", function(self, id)
   addLine(self, id, types.currency)
end)

-- Quests
hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(self)
  local id = select(8, GetQuestLogTitle(self.questLogIndex))
  addLine(GameTooltip, id, types.quest)
end)

hooksecurefunc("TaskPOI_OnEnter", function(self)
  if self and self.questID then addLine(WorldMapTooltip, self.questID, types.quest) end
end)
