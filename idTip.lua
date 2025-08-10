local addonName = ...

local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) and C_Spell.GetSpellTexture or GetSpellTexture
local GetItemIconByID = (C_Item and C_Item.GetItemIconByID) and C_Item.GetItemIconByID or GetItemIconByID
local GetItemInfo = (C_Item and C_Item.GetItemInfo) and C_Item.GetItemInfo or GetItemInfo
local GetItemGem = (C_Item and C_Item.GetItemGem) and C_Item.GetItemGem or GetItemGem
local GetItemSpell = (C_Item and C_Item.GetItemSpell) and C_Item.GetItemSpell or GetItemSpell
local GetRecipeReagentItemLink = (C_TradeSkillUI and C_TradeSkillUI.GetRecipeReagentItemLink) and C_TradeSkillUI.GetRecipeReagentItemLink or GetTradeSkillReagentItemLink
local GetItemLinkByGUID = (C_Item and C_Item.GetItemLinkByGUID) and C_Item.GetItemLinkByGUID

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
  set = "SetID",
  visual = "VisualID",
  source = "SourceID",
  species = "SpeciesID",
  icon = "IconID",
  areapoi = "AreaPoiID",
  vignette = "VignetteID",
  expansion = "ExpansionID",
  object = "ObjectID",
  traitnode = "TraitNodeID",
  traitentry = "TraitEntryID",
  traitdef = "TraitDefinitionID",
}

local defaultDisabledKinds = {
  "bonus", "traitnode", "traitentry", "traitdef",
}

-- https://warcraft.wiki.gg/wiki/Struct_TooltipData
-- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua
local kindsByID = {
  [0]  = "item", -- Item
  [1]  = "spell", -- Spell
  [2]  = "unit", -- Unit
  [3]  = "unit", -- Corpse
  [4]  = "object", -- Object
  [5]  = "currency", -- Currency
  [6]  = "unit", -- BattlePet
  [7]  = "spell", -- UnitAura
  [8]  = "spell", -- AzeriteEssence
  [9]  = "unit", -- CompanionPet
  [10] = "mount", -- Mount
  [11] = "spell", -- PetAction
  [12] = "achievement", -- Achievement
  [13] = "spell", -- EnhancedConduit
  [14] = "set", -- EquipmentSet
  [15] = "", -- InstanceLock
  [16] = "", -- PvPBrawl
  [17] = "spell", -- RecipeRankInfo
  [18] = "spell", -- Totem
  [19] = "item", -- Toy
  [20] = "", -- CorruptionCleanser
  [21] = "", -- MinimapMouseover
  [22] = "", -- Flyout
  [23] = "quest", -- Quest
  [24] = "quest", -- QuestPartyProgress
  [25] = "macro", -- Macro
  [26] = "", -- Debug
}

local function contains(table, element)
  for _, value in pairs(table) do
    if value == element then return true end
  end
  return false
end

local function configKey(key)
  return key .. "Enabled"
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
  if idTipConfig and (not idTipConfig.enabled or not idTipConfig[configKey(kind)]) then return end

  -- Abort when tooltip has no name or when :GetName throws
  local ok, name = pcall(getTooltipName, tooltip)
  if not ok or not name then return end

  -- Check if we already added to this tooltip
  local frame, text
  for i = tooltip:NumLines(), 1, -1 do
    frame = _G[name .. "TextLeft" .. i]
    if frame then text = frame:GetText() end
    if text and string.find(text, kinds[kind]) then return end
  end

  local multiple = type(id) == "table"
  if multiple and #id == 1 then
    id = id[1]
    multiple = false
  end

  local left = kinds[kind] .. (multiple and "s" or "")
  local right = multiple and table.concat(id, ",") or id
  tooltip:AddDoubleLine(left, right, nil, nil, nil, WHITE_FONT_COLOR.r, WHITE_FONT_COLOR.g, WHITE_FONT_COLOR.b)
  tooltip:Show()
end

local function isStringOrNumber(val)
  local t = type(val)
  return (t == "string") or (t == "number")
end

-- id here can also be a table of multiple ids like for visuals
-- TODO: refactor to single id and dynamically extend ids in existing tooltip
local function add(tooltip, id, kind)
  addLine(tooltip, id, kind)

  -- spell texture
  if kind == "spell" and GetSpellTexture and isStringOrNumber(id) then
    local iconId = GetSpellTexture(id)
    if iconId then add(tooltip, iconId, "icon") end
  end

  -- item icon
  if kind == "item" and GetItemIconByID and isStringOrNumber(id) then
    local iconId = GetItemIconByID(id)
    if iconId then add(tooltip, iconId, "icon") end
  end

  -- item spell
  if kind == "item" and GetItemSpell and isStringOrNumber(id) then
    local spellId = select(2, GetItemSpell(id))
    if spellId then add(tooltip, spellId, "spell") end
  end

  -- macro spell
  if kind == "macro" and tooltip.GetPrimaryTooltipData then
    data = tooltip:GetPrimaryTooltipData();
    if data and data.lines and data.lines[1] and data.lines[1].tooltipID then
      add(tooltip, data.lines[1].tooltipID, "spell")
    end
  end
end

local function addByKind(tooltip, id, kind)
  if not kind or not id then return end
  if kind == "spell" or kind == "enchant" or kind == "trade" then
    add(tooltip, id, "spell")
  elseif (kinds[kind]) then
    add(tooltip, id, kind)
  end
end

local function addItemInfo(tooltip, link)
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
    add(tooltip, itemId, "item")

    if itemSplit[2] ~= 0 then add(tooltip, itemSplit[2], "enchant") end
    if #bonuses ~= 0 then add(tooltip, bonuses, "bonus") end
    if #gems ~= 0 then add(tooltip, gems, "gem") end

    local expansionId = select(15, GetItemInfo(itemId))
    if expansionId and expansionId ~= 254 then -- always 254 on classic, therefor uninteresting
      add(tooltip, expansionId, "expansion")
    end

    local setId = select(16, GetItemInfo(itemId))
    if setId then
      add(tooltip, setId, "set")
    end
  end
end

local function attachItemTooltip(tooltip, id)
  if (tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2) and tooltip.info and tooltip.info.tooltipData and tooltip.info.tooltipData.guid and GetItemLinkByGUID then
    local link = GetItemLinkByGUID(tooltip.info.tooltipData.guid)
    if link then
      addItemInfo(tooltip, link)
    else
      add(tooltip, id, "item")
    end
  elseif tooltip.GetItem then
    local link = select(2, tooltip:GetItem())
    if link then
      addItemInfo(tooltip, link)
    else
      add(tooltip, id, "item")
    end
  else
    add(tooltip, id, "item")
  end
end

if TooltipDataProcessor then
  TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
    if not data or not data.type then return end
    local kind = kindsByID[tonumber(data.type)]

    -- unit special handling
    if kind == "unit" and data and data.guid then
      local unitId = tonumber(data.guid:match("-(%d+)-%x+$"), 10)
      if unitId and data.guid:match("%a+") ~= "Player" then
        add(tooltip, unitId, "unit")
      else
        add(tooltip, data.id, "unit")
      end
    elseif kind == "item" and data and data.guid and GetItemLinkByGUID then
      local link = GetItemLinkByGUID(data.guid)
      if link then
        addItemInfo(tooltip, link)
      else
        add(tooltip, data.id, kind)
      end
    elseif kind then
      add(tooltip, data.id, kind)
    end
  end)
end

if GetActionInfo then
  hook(GameTooltip, "SetAction", function(tooltip, slot)
    local kind, id = GetActionInfo(slot)
    addByKind(tooltip, id, kind)
  end)
end

if TalentDisplayMixin then
  hook(TalentDisplayMixin, "SetTooltipInternal", function(btn)
    if not btn then return end
    add(GameTooltip, btn.entryID, "traitentry")
    add(GameTooltip, btn.definitionID, "traitdef")
    if btn.GetNodeInfo then
      add(GameTooltip, btn:GetNodeInfo().ID, "traitnode")
    end
  end)
end

local function onSetHyperlink(tooltip, link)
  local kind, id = string.match(link,"^(%a+):(%d+)")
  addByKind(tooltip, id, kind)
end
hook(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
hook(GameTooltip, "SetHyperlink", onSetHyperlink)

if UnitBuff then
  hook(GameTooltip, "SetUnitBuff", function(tooltip, ...)
    local id = select(10, UnitBuff(...))
    add(tooltip, id, "spell")
  end)
end

if UnitDebuff then
  hook(GameTooltip, "SetUnitDebuff", function(tooltip, ...)
    local id = select(10, UnitDebuff(...))
    add(tooltip, id, "spell")
  end)
end

if UnitAura then
  hook(GameTooltip, "SetUnitAura", function(tooltip, ...)
    local id = select(10, UnitAura(...))
    add(tooltip, id, "spell")
  end)
end

hook(GameTooltip, "SetSpellByID", function(tooltip, id)
  addByKind(tooltip, id, "spell")
end)

hook(_G, "SetItemRef", function(link)
  local id = tonumber(link:match("spell:(%d+)"))
  add(ItemRefTooltip, id, "spell")
end)

hookScript(GameTooltip, "OnTooltipSetSpell", function(tooltip)
  local id = select(2, tooltip:GetSpell())
  add(tooltip, id, "spell")
end)

if SpellBook_GetSpellBookSlot then
  hook(_G, "SpellButton_OnEnter", function(btn)
    local slot = SpellBook_GetSpellBookSlot(btn)
    local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
    add(GameTooltip, spellID, "spell")
  end)
end

hook(GameTooltip, "SetRecipeResultItem", function(tooltip, id)
  add(tooltip, id, "spell")
end)

hook(GameTooltip, "SetRecipeRankInfo", function(tooltip, id)
  add(tooltip, id, "spell")
end)

if C_ArtifactUI and C_ArtifactUI.GetPowerInfo then
  hook(GameTooltip, "SetArtifactPowerByID", function(tooltip, powerID)
    local powerInfo = C_ArtifactUI.GetPowerInfo(powerID)
    add(tooltip, powerID, "artifactpower")
    add(tooltip, powerInfo.spellID, "spell")
  end)
end

if GetTalentInfoByID then
  hook(GameTooltip, "SetTalent", function(tooltip, id)
    local spellID = select(6, GetTalentInfoByID(id))
    add(tooltip, id, "talent")
    add(tooltip, spellID, "spell")
  end)
end

if GetPvpTalentInfoByID then
  hook(GameTooltip, "SetPvpTalent", function(tooltip, id)
    local spellID = select(6, GetPvpTalentInfoByID(id))
    add(tooltip, id, "talent")
    add(tooltip, spellID, "spell")
  end)
end

-- Pet Journal team icon
if C_PetJournal and C_PetJournal.GetPetInfoByPetID then
  hook(GameTooltip, "SetCompanionPet", function(_tooltip, petId)
    local speciesId = select(1, C_PetJournal.GetPetInfoByPetID(petId));
    if speciesId then
      local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(speciesId));
      add(GameTooltip, speciesId, "species");
      add(GameTooltip, npcId, "unit");
    end
  end)
end

hookScript(GameTooltip, "OnTooltipSetUnit", function(tooltip)
  if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then return end
  local unit = select(2, tooltip:GetUnit())
  if unit and UnitGUID then
    local guid = UnitGUID(unit) or ""
    local id = tonumber(guid:match("-(%d+)-%x+$"), 10)
    if id and guid:match("%a+") ~= "Player" then add(GameTooltip, id, "unit") end
  end
end)

hook(GameTooltip, "SetToyByItemID", function(tooltip, id)
  add(tooltip, id, "item")
end)

hook(GameTooltip, "SetRecipeReagentItem", function(tooltip, id)
  add(tooltip, id, "item")
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
  add(GameTooltip, btn.id, "achievement")
  GameTooltip:Show()
end

local function criteriaOnEnter(enterIndex)
  return function(frame)
    if not GetAchievementCriteriaInfo then return end
    local btn = frame:GetParent() and frame:GetParent():GetParent()
    if not btn or not btn.id then return end
    local achievementId = btn.id
    local index = frame.___index or enterIndex
    if index > GetAchievementNumCriteria(achievementId) then return end -- avoid error on some of the buttons like on "Level 70" achievement
    local criteriaId = select(10, GetAchievementCriteriaInfo(achievementId, index))
    if criteriaId then
      if not GameTooltip:IsVisible() then
        GameTooltip:SetOwner(btn:GetParent(), "ANCHOR_NONE")
      end
      GameTooltip:SetPoint("TOPLEFT", btn, "TOPRIGHT", 0, 0)
      add(GameTooltip, achievementId, "achievement")
      add(GameTooltip, criteriaId, "criteria")
      GameTooltip:Show()
    end
  end
end

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
    add(tooltip, id, "currency")
  end)
end

hook(GameTooltip, "SetCurrencyByID", function(tooltip, id)
  add(tooltip, id, "currency")
end)

hook(GameTooltip, "SetCurrencyTokenByID", function(tooltip, id)
  add(tooltip, id, "currency")
end)

if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
  hook(_G, "QuestMapLogTitleButton_OnEnter", function(tooltip)
    local id = C_QuestLog.GetQuestIDForLogIndex(tooltip.questLogIndex)
    add(GameTooltip, id, "quest")
  end)
end

hook(_G, "TaskPOI_OnEnter", function(tooltip)
  if tooltip and tooltip.questID then add(GameTooltip, tooltip.questID, "quest") end
end)

-- AreaPois (on the world map)
hook(AreaPOIPinMixin, "TryShowTooltip", function(tooltip)
  if tooltip and tooltip.areaPoiID then add(GameTooltip, tooltip.areaPoiID, "areapoi") end
end)

-- Vignettes (on the world map)
hook(VignettePinMixin, "OnMouseEnter", function(tooltip)
  if tooltip and tooltip.vignetteInfo and tooltip.vignetteInfo.vignetteID then add(GameTooltip, tooltip.vignetteInfo.vignetteID, "vignette") end
end)

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local f = CreateFrame("frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addon)
  if addon == addonName then
    local defaults = {
      enabled = true,
      version = 1,
    }

    if not idTipConfig then idTipConfig = {} end

    for key, _ in pairs(defaults) do
      if type(idTipConfig[key]) ~= type(defaults[key]) then idTipConfig[key] = defaults[key] end
    end

    for key, _ in pairs(kinds) do
      if type(idTipConfig[configKey(key)]) ~= "boolean" then
        idTipConfig[configKey(key)] = not contains(defaultDisabledKinds, key)
      end
    end

    -- config migrations
    if idTipConfig.version == 1 then -- v1 to v2 - disable bonus kind
      idTipConfig[configKey("bonus")] = false
      idTipConfig.version = 2
    end
  elseif addon == "Blizzard_AchievementUI" then
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
    hook(CollectionWardrobeUtil, "SetAppearanceTooltip", function(_frame, sources)
      local visualIDs = {}
      local sourceIDs = {}
      local itemIDs = {}

      for i = 1, #sources do
        if sources[i].visualID and not contains(visualIDs, sources[i].visualID) then table.insert(visualIDs, sources[i].visualID) end
        if sources[i].sourceID and not contains(visualIDs, sources[i].sourceID) then table.insert(sourceIDs, sources[i].sourceID) end
        if sources[i].itemID and not contains(visualIDs, sources[i].itemID) then table.insert(itemIDs, sources[i].itemID) end
      end

      if #visualIDs == 1 then add(GameTooltip, visualIDs[1], "visual") end
      if #sourceIDs == 1 then add(GameTooltip, sourceIDs[1], "source") end
      if #itemIDs == 1 then add(GameTooltip, itemIDs[1], "item") end

      if #visualIDs > 1 then add(GameTooltip, visualIDs, "visual") end
      if #sourceIDs > 1 then add(GameTooltip, sourceIDs, "source") end
      if #itemIDs > 1 then add(GameTooltip, itemIDs, "item") end
    end)

    -- Pet Journal selected pet info icon
    hookScript(PetJournalPetCardPetInfo, "OnEnter", function()
      if not C_PetJournal or not C_PetBattles.GetPetInfoBySpeciesID then return end
      if PetJournalPetCard.speciesID then
        local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(PetJournalPetCard.speciesID));
        add(GameTooltip, PetJournalPetCard.speciesID, "species");
        add(GameTooltip, npcId, "unit");
      end
    end);
  elseif addon == "Blizzard_GarrisonUI" then
    -- ability id
    hook(_G, "AddAutoCombatSpellToTooltip", function (tooltip, info)
      if info and info.autoCombatSpellID then
        add(tooltip, info.autoCombatSpellID, "ability")
      end
    end)
  end
end)

-------------------------------------------------------------------------------
-- Options panel
-------------------------------------------------------------------------------

local panel = CreateFrame("Frame")
panel.name = addonName
panel:Hide()

panel:SetScript("OnShow", function()
  local function createCheckbox(label, key)
    local checkBox = CreateFrame("CheckButton", addonName .. "Check" .. label, panel, "ChatConfigCheckButtonTemplate")
    checkBox:SetChecked(idTipConfig[key])
    checkBox:HookScript("OnClick", function(self)
      local checked = self:GetChecked()
      idTipConfig[key] = checked
    end)
    checkBox.Text:SetText(label)
    return checkBox
  end

  local title = panel:CreateFontString("ARTWORK", nil, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(addonName)

  local enabledCheckBox = createCheckbox("Enabled", "enabled")
  enabledCheckBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)

  local kindsTitle = panel:CreateFontString("ARTWORK", nil, "GameFontNormal")
  kindsTitle:SetPoint("TOPLEFT", enabledCheckBox, "BOTTOMLEFT", 0, -16)
  kindsTitle:SetText("Types")

  local index = 0
  local rowHeight = 24
  local columnWidth = 150
  local rowNum = 10

  local keys = {}
  for key in pairs(kinds) do table.insert(keys, key) end
  table.sort(keys)

  for _, key in pairs(keys) do
    local checkBox = createCheckbox(kinds[key], configKey(key))
    local columnIndex = math.floor(index / rowNum)
    local offsetRight = columnIndex * columnWidth
    local offsetUp = -(index * rowHeight) + (rowHeight * rowNum  * columnIndex) - 16
    checkBox:SetPoint("TOPLEFT", kindsTitle, "BOTTOMLEFT", offsetRight, offsetUp)
    index = index + 1
  end

  panel:SetScript("OnShow", nil)
end)

local categoryId = nil
if InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(panel)
elseif Settings and Settings.RegisterAddOnCategory and Settings.RegisterCanvasLayoutCategory then
  local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
  categoryId = category.ID
  Settings.RegisterAddOnCategory(category);
end

SLASH_IDTIP1 = "/idtip"
function SlashCmdList.IDTIP()
  if InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  elseif categoryId then
    Settings.OpenToCategory(categoryId)
  end
end
