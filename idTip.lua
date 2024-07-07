local hooksecurefunc, select, tonumber, _G = hooksecurefunc, select, tonumber, _G
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture or GetSpellTexture
local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) and C_Item.GetItemIconByID or GetItemIconByID
local GetItemInfo = (C_Item and C_Item.GetItemInfo) and C_Item.GetItemInfo or GetItemInfo
local GetItemGem = (C_Item and C_Item.GetItemGem) and C_Item.GetItemGem or GetItemGem
local GetItemSpell = (C_Item and C_Item.GetItemSpell) and C_Item.GetItemSpell or GetItemSpell
local GetRecipeReagentItemLink = (C_TradeSkillUI and C_TradeSkillUI.GetRecipeReagentItemLink) and C_TradeSkillUI.GetRecipeReagentItemLink or GetTradeSkillReagentItemLink

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
  areapoi = "AreaPoiID",
  vignette = "VignetteID",
  expansion = "ExpansionID",
}

local function contains(table, element)
  for _, value in pairs(table) do
    if value == element then return true end
  end
  return false
end

local function hook(table, fn, cb)
  if table and table[fn] then
    hooksecurefunc(table, fn, cb)
  end
end

local function hookScript(table, fn, cb)
  if table and table:HasScript(fn) then
    table:HookScript(fn, cb)
  end
end

local function getTooltipName(tooltip)
  return tooltip:GetName() or nil
end

local function addLine(tooltip, id, kind)
  if not id or id == "" or not tooltip or not tooltip.GetName then return end
  if type(id) == "table" and #id == 1 then id = id[1] end

  -- Abort when tooltip has no name or when :GetName throws
  local ok, name = pcall(getTooltipName, tooltip)
  if not ok or not name then return end

  -- Check if we already added to this tooltip. Happens on the talent frame
  local frame, text
  for i = 1, 32 do
    frame = _G[name .. "TextLeft" .. i]
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

  local iconId
  if kind == kinds.spell then
    iconId = GetSpellTexture(id)
    if iconId then addLine(tooltip, iconId, kinds.icon) end
  elseif kind == kinds.item then
    iconId = GetItemIconByID(id)
    if iconId then addLine(tooltip, iconId, kinds.icon) end
    local spellId = select(2, GetItemSpell(id))
    if spellId then
      addLine(tooltip, spellId, kinds.spell)
    end
  end

  tooltip:Show()
end

local function addLineByKind(tooltip, id, kind)
  if not kind or not id then return end
  if kind == "spell" or kind == "enchant" or kind == "trade" then
    addLine(tooltip, id, kinds.spell)
  elseif (kinds[kind]) then
    addLine(tooltip, id, kinds[kind])
  end
end

local function attachItemTooltip(tooltip, id)
  local link
  if (tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2) and tooltip.info and tooltip.info.tooltipData and tooltip.info.tooltipData.guid and C_Item and C_Item.GetItemLinkByGUID then
    link = C_Item.GetItemLinkByGUID(tooltip.info.tooltipData.guid)
  elseif tooltip.GetItem then
    link = select(2, tooltip:GetItem())
  else
    addLine(tooltip, id, kinds.item)
    return
  end
  if not link then return end

  local itemString = string.match(link, "item:([%-?%d:]+)")
  if not itemString then return end

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
    for i = 1, 4 do
      local gemLink = select(2, GetItemGem(link, i))
      if gemLink then
        local gemDetail = string.match(gemLink, "item[%-?%d:]+")
        gems[#gems + 1] = string.match(gemDetail, "item:(%d+):")
      elseif flags == 256 then
        gems[#gems + 1] = "0"
      end
    end
  end

  -- TODO: GetMouseFocus is replaced with GetMouseFoci in TWW
  local itemId = string.match(link, "item:(%d*)")
  if (itemId == "" or itemId == "0") and TradeSkillFrame and TradeSkillFrame.RecipeList and TradeSkillFrame:IsVisible() and GetRecipeReagentItemLink and GetMouseFocus and GetMouseFocus().reagentIndex then
    local selectedRecipe = TradeSkillFrame.RecipeList:GetSelectedRecipeID()
    for i = 1, 8 do
      if GetMouseFocus().reagentIndex == i then
        itemId = GetRecipeReagentItemLink(selectedRecipe, i):match("item:(%d*)") or nil
        break
      end
    end
  end

  if itemId then
    addLine(tooltip, itemId, kinds.item)

    if itemSplit[2] ~= 0 then addLine(tooltip, itemSplit[2], kinds.enchant) end
    if #bonuses ~= 0 then addLine(tooltip, bonuses, kinds.bonus) end
    if #gems ~= 0 then addLine(tooltip, gems, kinds.gem) end

    local expansionId = select(15, GetItemInfo(itemId))
    if expansionId then
      addLine(tooltip, expansionId, kinds.expansion)
    end
  end
end

-- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua
if TooltipDataProcessor then
  TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
    if not data or not data.type then return end
    if data.type == Enum.TooltipDataType.Spell then
      addLine(tooltip, data.id, kinds.spell)
    elseif data.type == Enum.TooltipDataType.Item then
      attachItemTooltip(tooltip, data.id)
    elseif data.type == Enum.TooltipDataType.Unit then
      if data.guid then
        local id = tonumber(data.guid:match("-(%d+)-%x+$"), 10)
        if id and data.guid:match("%a+") ~= "Player" then
          addLine(tooltip, id, kinds.unit)
        else
          addLine(tooltip, data.id, kinds.unit)
        end
      end
      addLine(tooltip, data.id, kinds.unit)
    elseif data.type == Enum.TooltipDataType.Currency then
      addLine(tooltip, data.id, kinds.currency)
    elseif data.type == Enum.TooltipDataType.UnitAura then
      addLine(tooltip, data.id, kinds.spell)
    elseif data.type == Enum.TooltipDataType.Mount then
      addLine(tooltip, data.id, kinds.mount)
    elseif data.type == Enum.TooltipDataType.Achievement then
      addLine(tooltip, data.id, kinds.achievement)
    elseif data.type == Enum.TooltipDataType.EquipmentSet then
      addLine(tooltip, data.id, kinds.equipmentset)
    elseif data.type == Enum.TooltipDataType.RecipeRankInfo then
      addLine(tooltip, data.id, kinds.spell)
    elseif data.type == Enum.TooltipDataType.Totem then
      addLine(tooltip, data.id, kinds.spell)
    elseif data.type == Enum.TooltipDataType.Toy then
      addLine(tooltip, data.id, kinds.item)
    elseif data.type == Enum.TooltipDataType.Quest then
      addLine(tooltip, data.id, kinds.quest)
    elseif data.type == Enum.TooltipDataType.Macro then
      addLine(tooltip, data.id, kinds.macro)
    end
  end)
end

if GetActionInfo then
  hook(GameTooltip, "SetAction", function(tooltip, slot)
    local kind, id = GetActionInfo(slot)
    addLineByKind(tooltip, id, kind)
  end)
end

local function onSetHyperlink(tooltip, link)
  local kind, id = string.match(link,"^(%a+):(%d+)")
  addLineByKind(tooltip, id, kind)
end
hook(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
hook(GameTooltip, "SetHyperlink", onSetHyperlink)

if UnitBuff then
  hook(GameTooltip, "SetUnitBuff", function(tooltip, ...)
    local id = select(10, UnitBuff(...))
    addLine(tooltip, id, kinds.spell)
  end)
end

if UnitDebuff then
  hook(GameTooltip, "SetUnitDebuff", function(tooltip, ...)
    local id = select(10, UnitDebuff(...))
    addLine(tooltip, id, kinds.spell)
  end)
end

if UnitAura then
  hook(GameTooltip, "SetUnitAura", function(tooltip, ...)
    local id = select(10, UnitAura(...))
    addLine(tooltip, id, kinds.spell)
  end)
end

hook(GameTooltip, "SetSpellByID", function(tooltip, id)
  addLineByKind(tooltip, id, kinds.spell)
end)

hook(_G, "SetItemRef", function(link)
  local id = tonumber(link:match("spell:(%d+)"))
  addLine(ItemRefTooltip, id, kinds.spell)
end)

hookScript(GameTooltip, "OnTooltipSetSpell", function(tooltip)
  local id = select(2, tooltip:GetSpell())
  addLine(tooltip, id, kinds.spell)
end)

if SpellBook_GetSpellBookSlot then
  hook(_G, "SpellButton_OnEnter", function(btn)
    local slot = SpellBook_GetSpellBookSlot(btn)
    local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
    addLine(GameTooltip, spellID, kinds.spell)
  end)
end

hook(GameTooltip, "SetRecipeResultItem", function(tooltip, id)
  addLine(tooltip, id, kinds.spell)
end)

hook(GameTooltip, "SetRecipeRankInfo", function(tooltip, id)
  addLine(tooltip, id, kinds.spell)
end)

if C_ArtifactUI and C_ArtifactUI.GetPowerInfo then
  hook(GameTooltip, "SetArtifactPowerByID", function(tooltip, powerID)
    local powerInfo = C_ArtifactUI.GetPowerInfo(powerID)
    addLine(tooltip, powerID, kinds.artifactpower)
    addLine(tooltip, powerInfo.spellID, kinds.spell)
  end)
end

if GetTalentInfoByID then
  hook(GameTooltip, "SetTalent", function(tooltip, id)
    local spellID = select(6, GetTalentInfoByID(id))
    addLine(tooltip, id, kinds.talent)
    addLine(tooltip, spellID, kinds.spell)
  end)
end

if GetPvpTalentInfoByID then
  hook(GameTooltip, "SetPvpTalent", function(tooltip, id)
    local spellID = select(6, GetPvpTalentInfoByID(id))
    addLine(tooltip, id, kinds.talent)
    addLine(tooltip, spellID, kinds.spell)
  end)
end

-- Pet Journal team icon
if C_PetJournal and C_PetJournal.GetPetInfoByPetID then
  hook(GameTooltip, "SetCompanionPet", function(_tooltip, petID)
    local speciesID = select(1, C_PetJournal.GetPetInfoByPetID(petID));
    if speciesID then
      local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(speciesID));
      addLine(GameTooltip, speciesID, kinds.species);
      addLine(GameTooltip, npcId, kinds.unit);
    end
  end)
end

hookScript(GameTooltip, "OnTooltipSetUnit", function(tooltip)
  if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then return end
  local unit = select(2, tooltip:GetUnit())
  if unit then
    local guid = UnitGUID(unit) or ""
    local id = tonumber(guid:match("-(%d+)-%x+$"), 10)
    if id and guid:match("%a+") ~= "Player" then addLine(GameTooltip, id, kinds.unit) end
  end
end)

hook(GameTooltip, "SetToyByItemID", function(tooltip, id)
  addLine(tooltip, id, kinds.item)
end)

hook(GameTooltip, "SetRecipeReagentItem", function(tooltip, id)
  addLine(tooltip, id, kinds.item)
end)

local function onSetItem(tooltip)
  attachItemTooltip(tooltip, nil)
end
hookScript(GameTooltip, "OnTooltipSetItem", onSetItem)
hookScript(ItemRefTooltip, "OnTooltipSetItem", onSetItem)
hookScript(ItemRefShoppingTooltip1, "OnTooltipSetItem", onSetItem)
hookScript(ItemRefShoppingTooltip2, "OnTooltipSetItem", onSetItem)
hookScript(ShoppingTooltip1, "OnTooltipSetItem", onSetItem)
hookScript(ShoppingTooltip2, "OnTooltipSetItem", onSetItem)

local function achievementOnEnter(btn)
  GameTooltip:SetOwner(btn, "ANCHOR_NONE")
  GameTooltip:SetPoint("TOPLEFT", btn, "TOPRIGHT", 0, 0)
  addLine(GameTooltip, btn.id, kinds.achievement)
  GameTooltip:Show()
end

local function criteriaOnEnter(index)
  return function(frame)
    local btn = frame:GetParent() and frame:GetParent():GetParent()
    if not btn or not btn.id then return end
    if not GetAchievementCriteriaInfo then return end
    local criteriaId = select(10, GetAchievementCriteriaInfo(btn.id, frame.___index or index))
    if criteriaId then
      if not GameTooltip:IsVisible() then
        GameTooltip:SetOwner(btn:GetParent(), "ANCHOR_NONE")
      end
      GameTooltip:SetPoint("TOPLEFT", btn, "TOPRIGHT", 0, 0)
      addLine(GameTooltip, btn.id, kinds.achievement)
      addLine(GameTooltip, criteriaId, kinds.criteria)
      GameTooltip:Show()
    end
  end
end

-- Achievement Frame Tooltips
local f = CreateFrame("frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addon)
  if addon == "Blizzard_AchievementUI" then
    if AchievementTemplateMixin then
      -- dragonflight
      hook(AchievementTemplateMixin, "OnEnter", achievementOnEnter)
      hook(AchievementTemplateMixin, "OnLeave", GameTooltip_Hide)

      local hooked = {}
      local getter = function(pool)
        return function(self, index)
          if not self or not self[pool] then return end
          local frame = self[pool][index]
          frame.___index = index
          if frame and not hooked[frame] then
            hookScript(frame, "OnEnter", criteriaOnEnter(index))
            hookScript(frame, "OnLeave", GameTooltip_Hide)
            hooked[frame] = true
          end
        end
      end
      hook(AchievementTemplateMixin:GetObjectiveFrame(), "GetCriteria", getter("criterias"))
      hook(AchievementTemplateMixin:GetObjectiveFrame(), "GetMiniAchievement", getter("miniAchivements"))
      hook(AchievementTemplateMixin:GetObjectiveFrame(), "GetMeta", getter("metas"))
      hook(AchievementTemplateMixin:GetObjectiveFrame(), "GetProgressBar", getter("progressBars"))
    elseif AchievementFrameAchievementsContainer then
      -- pre-dragonflight
      for _, button in ipairs(AchievementFrameAchievementsContainer.buttons) do
        hookScript(button, "OnEnter", achievementOnEnter)
        hookScript(button, "OnLeave", GameTooltip_Hide)

        local hooked = {}
        hook(_G, "AchievementButton_GetCriteria", function(index, renderOffScreen)
          local frame = _G["AchievementFrameCriteria" .. (renderOffScreen and "OffScreen" or "") .. index]
          if frame and not hooked[frame] then
            hookScript(frame, "OnEnter", criteriaOnEnter(index))
            hookScript(frame, "OnLeave", GameTooltip_Hide)
            hooked[frame] = true
          end
        end)
      end
    end
  elseif addon == "Blizzard_Collections" then
    hook(_G, "WardrobeCollectionFrame_SetAppearanceTooltip", function(_frame, sources)
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

    -- Pet Journal selected pet info icon
    hookScript(PetJournalPetCardPetInfo, "OnEnter", function()
      if not C_PetJournal or not C_PetBattles.GetPetInfoBySpeciesID then return end
      if PetJournalPetCard.speciesID then
        local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(PetJournalPetCard.speciesID));
        addLine(GameTooltip, PetJournalPetCard.speciesID, kinds.species);
        addLine(GameTooltip, npcId, kinds.unit);
      end
    end);
  elseif addon == "Blizzard_GarrisonUI" then
    -- ability id
    hook(_G, "AddAutoCombatSpellToTooltip", function (tooltip, info)
      if info and info.autoCombatSpellID then
        addLine(tooltip, info.autoCombatSpellID, kinds.ability)
      end
    end)
  end
end)

if C_PetBattles and C_PetBattles.GetActivePet and C_PetBattles.GetAbilityInfo then
  hook(_G, "PetBattleAbilityButton_OnEnter", function(btn)
    local petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
    if btn:GetEffectiveAlpha() > 0 then
      local id = select(1, C_PetBattles.GetAbilityInfo(LE_BATTLE_PET_ALLY, petIndex, btn:GetID()))
      if id then
        local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
        PetBattlePrimaryAbilityTooltip.Description:SetText(oldText .. "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r")
      end
    end
  end)
end

if C_PetBattles and C_PetBattles.GetAuraInfo then
  hook(_G, "PetBattleAura_OnEnter", function(frame)
    local parent = frame:GetParent()
    local id = select(1, C_PetBattles.GetAuraInfo(parent.petOwner, parent.petIndex, frame.auraIndex))
    if id then
      local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
      PetBattlePrimaryAbilityTooltip.Description:SetText(oldText .. "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r")
    end
  end)
end

if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListLink then
  hook(GameTooltip, "SetCurrencyToken", function(tooltip, index)
    local id = tonumber(string.match(C_CurrencyInfo.GetCurrencyListLink(index),"currency:(%d+)"))
    addLine(tooltip, id, kinds.currency)
  end)
end

hook(GameTooltip, "SetCurrencyByID", function(tooltip, id)
  addLine(tooltip, id, kinds.currency)
end)

hook(GameTooltip, "SetCurrencyTokenByID", function(tooltip, id)
  addLine(tooltip, id, kinds.currency)
end)

if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
  hook(_G, "QuestMapLogTitleButton_OnEnter", function(tooltip)
    local id = C_QuestLog.GetQuestIDForLogIndex(tooltip.questLogIndex)
    addLine(GameTooltip, id, kinds.quest)
  end)
end

hook(_G, "TaskPOI_OnEnter", function(tooltip)
  if tooltip and tooltip.questID then addLine(GameTooltip, tooltip.questID, kinds.quest) end
end)

-- AreaPois (on the world map)
hook(AreaPOIPinMixin, "TryShowTooltip", function(tooltip)
  if tooltip and tooltip.areaPoiID then addLine(GameTooltip, tooltip.areaPoiID, kinds.areapoi) end
end)

-- Vignettes (on the world map)
hook(VignettePinMixin, "OnMouseEnter", function(tooltip)
  if tooltip and tooltip.vignetteInfo and tooltip.vignetteInfo.vignetteID then addLine(GameTooltip, tooltip.vignetteInfo.vignetteID, kinds.vignette) end
end)
