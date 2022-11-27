local hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID,
      GetGlyphSocketInfo, tonumber, strfind, _G
    = hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID,
      GetGlyphSocketInfo, tonumber, strfind, _G

local kinds = {
  spell = "SpellID",
  item = "ItemID",
  unit = "NPC ID",
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
  visual = "VisualID",
  source = "SourceID",
  species = "SpeciesID",
  icon = "IconID",
}

local function contains(table, element)
  for _, value in pairs(table) do
    if value == element then return true end
  end
  return false
end

local function addLine(tooltip, id, kind)
  if not id or id == "" then return end
  if type(id) == "table" and #id == 1 then id = id[1] end

  -- Check if we already added to this tooltip. Happens on the talent frame
  local frame, text
  for i = 1,15 do
    frame = _G[tooltip:GetName() .. "TextLeft" .. i]
    if frame then text = frame:GetText() end
    if text and string.find(text, kind) then return end
  end

  local left, right
  if type(id) == "table" then
    left = NORMAL_FONT_COLOR_CODE .. kind .. "s" .. FONT_COLOR_CODE_CLOSE
    right = HIGHLIGHT_FONT_COLOR_CODE .. table.concat(id, ", ") .. FONT_COLOR_CODE_CLOSE
  else
    left = NORMAL_FONT_COLOR_CODE .. kind .. FONT_COLOR_CODE_CLOSE
    right = HIGHLIGHT_FONT_COLOR_CODE .. id .. FONT_COLOR_CODE_CLOSE
  end

  tooltip:AddDoubleLine(left, right)

  if kind == kinds.spell then
    iconId = select(3, GetSpellInfo(id))
    if iconId then addLine(tooltip, iconId, kinds.icon) end
  elseif kind == kinds.item then
    iconId = C_Item.GetItemIconByID(id)
    if iconId then addLine(tooltip, iconId, kinds.icon) end
  end

  tooltip:Show()
end

local function addLineByKind(self, id, kind)
  if not kind or not id then return end
  if kind == "spell" or kind == "enchant" or kind == "trade" then
    addLine(self, id, kinds.spell)
  elseif kind == "talent" then
    addLine(self, id, kinds.talent)
  elseif kind == "quest" then
    addLine(self, id, kinds.quest)
  elseif kind == "achievement" then
    addLine(self, id, kinds.achievement)
  elseif kind == "item" then
    addLine(self, id, kinds.item)
  elseif kind == "currency" then
    addLine(self, id, kinds.currency)
  elseif kind == "summonmount" then
    addLine(self, id, kinds.mount)
  elseif kind == "companion" then
    addLine(self, id, kinds.companion)
  elseif kind == "macro" then
    addLine(self, id, kinds.macro)
  elseif kind == "equipmentset" then
    addLine(self, id, kinds.equipmentset)
  elseif kind == "visual" then
    addLine(self, id, kinds.visual)
  end
end

local function onSetHyperlink(self, link)
  local kind, id = string.match(link,"^(%a+):(%d+)")
  addLineByKind(self, id, kind)
end

if GameTooltip.SetAction then
  hooksecurefunc(GameTooltip, "SetAction", function(self, slot)
    local kind, id = GetActionInfo(slot)
    addLineByKind(self, id, kind)
  end)
end

if ItemRefTooltip.SetHyperlink then
  hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
end

if GameTooltip.SetHyperlink then
  hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)
end

if GameTooltip.SetUnitBuff then
  hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, ...)
    local id = select(10, UnitBuff(...))
    addLine(self, id, kinds.spell)
  end)
end

if GameTooltip.SetUnitDebuff then
  hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, ...)
    local id = select(10, UnitDebuff(...))
    addLine(self, id, kinds.spell)
  end)
end

if GameTooltip.SetUnitAura then
  hooksecurefunc(GameTooltip, "SetUnitAura", function(self, ...)
    local id = select(10, UnitAura(...))
    addLine(self, id, kinds.spell)
  end)
end

if GameTooltip.SetSpellByID then
  hooksecurefunc(GameTooltip, "SetSpellByID", function(self, id)
    addLineByKind(self, id, kinds.spell)
  end)
end

if SetItemRef then
  hooksecurefunc("SetItemRef", function(link, ...)
    local id = tonumber(link:match("spell:(%d+)"))
    addLine(ItemRefTooltip, id, kinds.spell)
  end)
end

if GameTooltip:HasScript("OnTooltipSetSpell") then
  GameTooltip:HookScript("OnTooltipSetSpell", function(self)
    local id = select(2, self:GetSpell())
    addLine(self, id, kinds.spell)
  end)
end

if SpellButton_OnEnter then
  hooksecurefunc("SpellButton_OnEnter", function(self)
    local slot = SpellBook_GetSpellBookSlot(self)
    local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
    addLine(GameTooltip, spellID, kinds.spell)
  end)
end

if GameTooltip.SetRecipeResultItem then
  hooksecurefunc(GameTooltip, "SetRecipeResultItem", function(self, id)
    addLine(self, id, kinds.spell)
  end)
end


if GameTooltip.SetRecipeRankInfo then
  hooksecurefunc(GameTooltip, "SetRecipeRankInfo", function(self, id)
    addLine(self, id, kinds.spell)
  end)
end

if GameTooltip.SetArtifactPowerByID then
  hooksecurefunc(GameTooltip, "SetArtifactPowerByID", function(self, powerID)
    local powerInfo = C_ArtifactUI.GetPowerInfo(powerID)
    addLine(self, powerID, kinds.artifactpower)
    addLine(self, powerInfo.spellID, kinds.spell)
  end)
end

if GameTooltip.SetTalent then
  hooksecurefunc(GameTooltip, "SetTalent", function(self, id)
    local spellID = select(6, GetTalentInfoByID(id))
    addLine(self, id, kinds.talent)
    addLine(self, spellID, kinds.spell)
  end)
end

if GameTooltip.SetPvpTalent then
  hooksecurefunc(GameTooltip, "SetPvpTalent", function(self, id)
    local spellID = select(6, GetPvpTalentInfoByID(id))
    addLine(self, id, kinds.talent)
    addLine(self, spellID, kinds.spell)
  end)
end

  -- Pet Journal team icon
if GameTooltip.SetCompanionPet then
  hooksecurefunc(GameTooltip, "SetCompanionPet", function(self, petID)
    local speciesID = select(1, C_PetJournal.GetPetInfoByPetID(petID));
    if speciesID then
      local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(speciesID));
      addLine(GameTooltip, speciesID, kinds.species);
      addLine(GameTooltip, npcId, kinds.unit);
    end
  end)
end

if GameTooltip:HasScript("OnTooltipSetUnit") then
  GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    if C_PetBattles and C_PetBattles.IsInBattle then
      if C_PetBattles.IsInBattle() then return end
    end
    local unit = select(2, self:GetUnit())
    if unit then
      local guid = UnitGUID(unit) or ""
      local id = tonumber(guid:match("-(%d+)-%x+$"), 10)
      if id and guid:match("%a+") ~= "Player" then addLine(GameTooltip, id, kinds.unit) end
    end
  end)
end

if GameTooltip.SetToyByItemID then
  hooksecurefunc(GameTooltip, "SetToyByItemID", function(self, id)
    addLine(self, id, kinds.item)
  end)
end

if GameTooltip.SetRecipeReagentItem then
  hooksecurefunc(GameTooltip, "SetRecipeReagentItem", function(self, id)
    addLine(self, id, kinds.item)
  end)
end

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
  if GetItemGem then
      for i=1, 4 do
      local _,gemLink = GetItemGem(link, i)
      if gemLink then
        local gemDetail = string.match(gemLink, "item[%-?%d:]+")
        gems[#gems + 1] = string.match(gemDetail, "item:(%d+):")
      elseif flags == 256 then
        gems[#gems + 1] = "0"
      end
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
    addLine(self, id, kinds.item)
    if itemSplit[2] ~= 0 then
      enchantid = itemSplit[2]
      addLine(self, enchantid, kinds.enchant)
    end
    if #bonuses ~= 0 then addLine(self, bonuses, kinds.bonus) end
    if #gems ~= 0 then addLine(self, gems, kinds.gem) end
  end
end

if GameTooltip:HasScript("OnTooltipSetSpell") then
  GameTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
end
if ItemRefTooltip:HasScript("OnTooltipSetItem") then
  ItemRefTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
end
if ItemRefShoppingTooltip1:HasScript("OnTooltipSetItem") then
  ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
end
if ItemRefShoppingTooltip2:HasScript("OnTooltipSetItem") then
  ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
end
if ShoppingTooltip1:HasScript("OnTooltipSetItem") then
  ShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
end
if ShoppingTooltip2:HasScript("OnTooltipSetItem") then
  ShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
end

-- Achievement Frame Tooltips
local f = CreateFrame("frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, what)
  if what == "Blizzard_AchievementUI" then
    for i,button in ipairs(AchievementFrameAchievementsContainer.buttons) do
      if button:HasScript("onEnter") then
        button:HookScript("OnEnter", function()
          GameTooltip:SetOwner(button, "ANCHOR_NONE")
          GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
          addLine(GameTooltip, button.id, kinds.achievement)
          GameTooltip:Show()
        end)
      end
      if button:HasScript("OnLeave") then
        button:HookScript("OnLeave", function()
          GameTooltip:Hide()
        end)
      end

      local hooked = {}
      if AchievementButton_GetCriteria then
        hooksecurefunc("AchievementButton_GetCriteria", function(index, renderOffScreen)
          local frame = _G["AchievementFrameCriteria" .. (renderOffScreen and "OffScreen" or "") .. index]
          if frame and not hooked[frame] then
            if frame:HasScript("OnEnter") then
              frame:HookScript("OnEnter", function(self)
                local button = self:GetParent() and self:GetParent():GetParent()
                if not button or not button.id then return end
                local criteriaid = select(10, GetAchievementCriteriaInfo(button.id, index))
                if criteriaid then
                  GameTooltip:SetOwner(button:GetParent(), "ANCHOR_NONE")
                  GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
                  addLine(GameTooltip, button.id, kinds.achievement)
                  addLine(GameTooltip, criteriaid, kinds.criteria)
                  GameTooltip:Show()
                end
              end)
            end
            if frame:HasScript("OnLeave") then
              frame:HookScript("OnLeave", function()
                GameTooltip:Hide()
              end)
            end
            hooked[frame] = true
          end
        end)
      end
    end
  elseif what == "Blizzard_Collections" then
    if WardrobeCollectionFrame_SetAppearanceTooltip then
      hooksecurefunc("WardrobeCollectionFrame_SetAppearanceTooltip", function(self, sources)
        local visualIDs = {}
        local sourceIDs = {}
        local itemIDs = {}

        for i = 1, #sources do
          if sources[i].visualID and not contains(visualIDs, sources[i].visualID) then table.insert(visualIDs, sources[i].visualID) end
          if sources[i].sourceID and not contains(visualIDs, sources[i].sourceID) then table.insert(sourceIDs, sources[i].sourceID) end
          if sources[i].itemID and not contains(visualIDs, sources[i].itemID) then table.insert(itemIDs, sources[i].itemID) end
        end

        if #visualIDs ~= 0 then addLine(GameTooltip, visualIDs, kinds.visual) end
        if #sourceIDs ~= 0 then addLine(GameTooltip, sourceIDs, kinds.source) end
        if #itemIDs ~= 0 then addLine(GameTooltip, itemIDs, kinds.item) end
      end)
    end

    -- Pet Journal selected pet info icon
    if PetJournalPetCardPetInfo:HasScript("OnEnter") then
      PetJournalPetCardPetInfo:HookScript("OnEnter", function(self)
        if PetJournalPetCard.speciesID then
          local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(PetJournalPetCard.speciesID));
          addLine(GameTooltip, PetJournalPetCard.speciesID, kinds.species);
          addLine(GameTooltip, npcId, kinds.unit);
        end
      end);
    end
  elseif what == "Blizzard_GarrisonUI" then
    -- ability id
    if AddAutoCombatSpellToTooltip then
      hooksecurefunc("AddAutoCombatSpellToTooltip", function (self, info)
        if info and info.autoCombatSpellID then
          addLine(self, info.autoCombatSpellID, kinds.ability)
        end
      end)
    end
  end
end)

if PetBattleAbilityButton_OnEnter then
  hooksecurefunc("PetBattleAbilityButton_OnEnter", function(self)
    local petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
    if self:GetEffectiveAlpha() > 0 then
      local id = select(1, C_PetBattles.GetAbilityInfo(LE_BATTLE_PET_ALLY, petIndex, self:GetID()))
      if id then
        local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
        PetBattlePrimaryAbilityTooltip.Description:SetText(oldText .. "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r")
      end
    end
  end)
end

if PetBattleAura_OnEnter then
  hooksecurefunc("PetBattleAura_OnEnter", function(self)
    local parent = self:GetParent()
    local id = select(1, C_PetBattles.GetAuraInfo(parent.petOwner, parent.petIndex, self.auraIndex))
    if id then
      local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
      PetBattlePrimaryAbilityTooltip.Description:SetText(oldText .. "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r")
    end
  end)
end

if GameTooltip.SetCurrencyToken then
  hooksecurefunc(GameTooltip, "SetCurrencyToken", function(self, index)
    local id = tonumber(string.match(C_CurrencyInfo.GetCurrencyListLink(index),"currency:(%d+)"))
    addLine(self, id, kinds.currency)
  end)
end

if GameTooltip.SetCurrencyByID then
  hooksecurefunc(GameTooltip, "SetCurrencyByID", function(self, id)
     addLine(self, id, kinds.currency)
  end)
end

if GameTooltip.SetCurrencyTokenByID then
  hooksecurefunc(GameTooltip, "SetCurrencyTokenByID", function(self, id)
     addLine(self, id, kinds.currency)
  end)
end

if QuestMapLogTitleButton_OnEnter then
  hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(self)
    local id = C_QuestLog.GetQuestIDForLogIndex(self.questLogIndex)
    addLine(GameTooltip, id, kinds.quest)
  end)
end

if TaskPOI_OnEnter then
  hooksecurefunc("TaskPOI_OnEnter", function(self)
    if self and self.questID then addLine(GameTooltip, self.questID, kinds.quest) end
  end)
end
