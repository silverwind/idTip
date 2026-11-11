local addonName = ...

-- gated, so a namespace Blizzard drops costs one kind, not the addon. Callers check.
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local GetItemIconByID = C_Item and C_Item.GetItemIconByID
local GetItemInfo = C_Item and C_Item.GetItemInfo
local GetItemGem = C_Item and C_Item.GetItemGem
local GetItemSpell = C_Item and C_Item.GetItemSpell
local GetItemLinkByGUID = C_Item and C_Item.GetItemLinkByGUID -- retail only
local GetMountInfoByID = C_MountJournal and C_MountJournal.GetMountInfoByID
local GetMountFromItem = C_MountJournal and C_MountJournal.GetMountFromItem
local GetMountFromSpell = C_MountJournal and C_MountJournal.GetMountFromSpell
local GetTransmogItemInfo = C_TransmogCollection and C_TransmogCollection.GetItemInfo -- retail only
local GetPetInfoByItemID = C_PetJournal and C_PetJournal.GetPetInfoByItemID

local white = WHITE_FONT_COLOR or {r = 1, g = 1, b = 1}

local kinds = {
  spell = "SpellID",
  item = "ItemID",
  unit = "NpcID",
  quest = "QuestID",
  talent = "TalentID",
  achievement = "AchievementID",
  criteria = "CriteriaID",
  ability = "AbilityID",
  artifactpower = "ArtifactPowerID",
  currency = "CurrencyID",
  enchant = "EnchantID",
  bonus = "BonusID",
  gem = "GemID",
  mount = "MountID",
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

local defaultDisabledKinds = {bonus = true, traitnode = true, traitentry = true, traitdef = true}

-- options order, every kind in exactly one section, pinned by a test
local kindSections = {
  {name = "Items", "item", "currency", "enchant", "gem", "bonus", "set", "expansion"},
  {name = "Spells", "spell", "ability", "macro", "talent", "artifactpower",
    "traitnode", "traitentry", "traitdef"},
  {name = "World", "unit", "object", "quest", "achievement", "criteria", "areapoi", "vignette"},
  {name = "Collections", "mount", "species", "visual", "source", "icon"},
}

-- Enum.TooltipDataType, identical on every client. Types with no useful id are absent.
-- https://warcraft.wiki.gg/wiki/Struct_TooltipData
local kindsByID = {
  [0]  = "item", -- Item
  [1]  = "spell", -- Spell
  [2]  = "unit", -- Unit
  [3]  = "unit", -- Corpse
  [4]  = "object", -- Object
  [5]  = "currency", -- Currency
  [7]  = "spell", -- UnitAura
  [8]  = "spell", -- AzeriteEssence
  [9]  = "species", -- CompanionPet, whose id is a species id
  [10] = "mount", -- Mount
  [11] = "spell", -- PetAction
  [12] = "achievement", -- Achievement
  [13] = "spell", -- EnhancedConduit
  [14] = "set", -- EquipmentSet
  [17] = "spell", -- RecipeRankInfo
  [18] = "spell", -- Totem
  [19] = "item", -- Toy
  [23] = "quest", -- Quest
  [24] = "quest", -- QuestPartyProgress
  [25] = "macro", -- Macro
}

local function addUnique(list, value)
  if not value then return end
  for _, existing in ipairs(list) do
    if existing == value then return end
  end
  list[#list + 1] = value
end

local function configKey(key)
  return key .. "Enabled"
end

local function hook(target, method, callback)
  if callback and target and target[method] then
    hooksecurefunc(target, method, callback)
  end
end

local function hookScript(target, script, callback)
  if callback and target and target.HasScript and target:HasScript(script) then
    target:HookScript(script, callback)
  end
end

local function inPetBattle() return C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() end

local function getTooltipName(tooltip)
  return tooltip:GetName()
end

-- absent before the secret-value API existed, bound once rather than per call.
-- Only a table can be a secret table, and this runs once per line scanned.
local isSecret = issecretvalue and issecrettable and function(value)
  return issecretvalue(value) or (type(value) == "table" and issecrettable(value))
end or function() return false end

-- positional API returns vary by version, so drop non-ids here, not at each site
local function isStringOrNumber(value)
  return type(value) == "string" or type(value) == "number"
end

local function isValidId(id)
  if type(id) == "table" then return #id > 0 end
  return isStringOrNumber(id) and id ~= ""
end

local function cellText(name, side, index)
  local frame = _G[name .. "Text" .. side .. index]
  local text = frame and frame:GetText()
  -- a secret cell is unreadable rather than fatal
  if isSecret(text) then return nil end
  return text, frame
end

-- Joins later ids onto the line this kind already has. The left cell must match
-- exactly, so no foreign label counts as ours. Returns whether one existed and changed.
local function extendLine(tooltip, name, label, id)
  for index = tooltip:NumLines(), 1, -1 do
    if cellText(name, "Left", index) == label then
      local joined, right = cellText(name, "Right", index)
      if not right then return true, false end

      local values = {} -- a foreign left-only line leaves its right cell unwritten
      for value in string.gmatch(joined or "", "[^,]+") do values[#values + 1] = value end

      local count = #values
      if type(id) == "table" then
        for _, value in ipairs(id) do addUnique(values, tostring(value)) end
      else
        addUnique(values, tostring(id)) -- wrapping a scalar would allocate per merge
      end
      if #values == count then return true, false end
      right:SetText(table.concat(values, ","))
      return true, true
    end
  end
  return false, false
end

local compactLabels = {}
for _, label in pairs(kinds) do compactLabels[label] = true end

local function parseCompact(text)
  if not text then return end
  local entries, position = {}, 1
  while position <= #text do
    local _, finish, label, joined = string.find(text, "^%s*(%a+) |cffffffff([^|]+)|r", position)
    if not compactLabels[label] then return end
    local values = {}
    for value in string.gmatch(joined, "[^,]+") do values[#values + 1] = value end
    entries[#entries + 1] = {label = label, values = values}
    position = finish + 1
  end
  return entries[1] and entries
end

local function findCompact(tooltip, name)
  for index = tooltip:NumLines(), 1, -1 do
    local text, line = cellText(name, "Left", index)
    local entries = parseCompact(text)
    if entries then return entries, line, index end
  end
end

local function compactToken(entry)
  return entry.label .. " |cffffffff" .. table.concat(entry.values, ",") .. "|r"
end

-- laid out extents, so column gaps, indents and wrapped cells count as drawn, right cells sitting flush
local sides = {"Left", "Right"}
local function contentWidth(tooltip, name, line, skip)
  local left = line:GetLeft()
  if not left or isSecret(left) then return 0 end -- an unplaced tooltip, like a scanning one
  local right = left
  for index = 1, tooltip:NumLines() do
    for _, side in ipairs(sides) do
      local cell = index ~= skip and _G[name .. "Text" .. side .. index]
      local edge = cell and cell:IsShown() and cell:GetRight()
      if edge and not isSecret(edge) then right = math.max(right, edge) end
    end
  end
  return right - left
end

local function fits(line, text, limit)
  line:SetText(text)
  return line:GetStringWidth() <= limit
end

-- runs after every Show, so later lines widen the rows too, and breaks only between ids
local packing
local function packCompact(tooltip)
  if packing then return end
  local ok, name = pcall(getTooltipName, tooltip)
  if not ok or not name then return end
  local entries, line, lineIndex = findCompact(tooltip, name)
  if not entries then return end

  local current = line:GetText()
  local limit = contentWidth(tooltip, name, line, lineIndex)
  local rows, row = {}, nil
  for _, entry in ipairs(entries) do
    local token = compactToken(entry)
    local joined = row and row .. " " .. token
    if joined and fits(line, joined, limit) then
      row = joined
    else
      rows[#rows + 1] = row
      row = token
    end
  end
  rows[#rows + 1] = row
  local packed = table.concat(rows, "\n")
  line:SetText(packed)
  if packed == current then return end -- the usual case once later lines stop widening it
  packing = true
  tooltip:Show()
  packing = false
end

local showHooked = setmetatable({}, {__mode = "k"})
local function addCompact(tooltip, name, label, id)
  local entries, line = findCompact(tooltip, name)
  entries = entries or {}

  local entry
  for _, existing in ipairs(entries) do
    if existing.label == label then entry = existing end
  end
  if not entry then
    entry = {label = label, values = {}}
    entries[#entries + 1] = entry
  end

  local count = #entry.values
  for _, value in ipairs(type(id) == "table" and id or {id}) do addUnique(entry.values, tostring(value)) end
  if #entry.values == count then return false end

  if not showHooked[tooltip] then
    showHooked[tooltip] = true
    hooksecurefunc(tooltip, "Show", packCompact)
  end
  local tokens = {}
  for index, existing in ipairs(entries) do tokens[index] = compactToken(existing) end
  local narrowest = table.concat(tokens, "\n") -- so only other lines size the layout packCompact measures
  if line then
    line:SetText(narrowest)
  else
    tooltip:AddLine(narrowest) -- unwrapped, so the client never splits an id
  end
  return true
end

local function isEnabled(kind)
  return not idTipConfig or (idTipConfig.enabled and idTipConfig[configKey(kind)])
end

-- one policy for every writer, so the pet battle one cannot drift from this
local function shouldAdd(id, kind)
  return not isSecret(id) and isValidId(id) and isEnabled(kind)
end

-- returns whether the tooltip changed, leaving the Show, a full relayout, to the caller
local function addLine(tooltip, id, kind)
  if not shouldAdd(id, kind) then return false end

  -- abort when the tooltip has no name, or when :GetName throws
  local ok, name = pcall(getTooltipName, tooltip)
  if not ok or not name then return false end

  local label = kinds[kind]

  -- the rendered lines are the only per-tooltip state that cannot go stale
  if idTipConfig and idTipConfig.compact then return addCompact(tooltip, name, label, id) end
  local found, changed = extendLine(tooltip, name, label, id)
  if found then return changed end
  local right = type(id) == "table" and table.concat(id, ",") or id
  tooltip:AddDoubleLine(label, right, nil, nil, nil, white.r, white.g, white.b)
  return true
end

-- returns whether the tooltip changed. id may be a list, source is the kind it derives from, ending mount and spell cycles.
local function collect(tooltip, id, kind, source)
  if type(id) == "table" and #id == 1 then id = id[1] end
  local changed = addLine(tooltip, id, kind)
  if not isStringOrNumber(id) then return changed end

  if kind == "spell" then
    local iconId = GetSpellTexture and GetSpellTexture(id)
    if iconId then changed = collect(tooltip, iconId, "icon") or changed end

    local mountId = source ~= "mount" and GetMountFromSpell and GetMountFromSpell(id)
    if mountId then changed = collect(tooltip, mountId, "mount", kind) or changed end
  elseif kind == "item" then
    local iconId = GetItemIconByID and GetItemIconByID(id)
    if iconId then changed = collect(tooltip, iconId, "icon") or changed end

    local spellId = GetItemSpell and select(2, GetItemSpell(id))
    if spellId then changed = collect(tooltip, spellId, "spell") or changed end

    local speciesId = GetPetInfoByItemID and select(13, GetPetInfoByItemID(id))
    if speciesId then changed = collect(tooltip, speciesId, "species") or changed end

    local mountId = GetMountFromItem and tonumber(id) and GetMountFromItem(tonumber(id))
    if mountId then changed = collect(tooltip, mountId, "mount", kind) or changed end
  elseif kind == "mount" then
    local spellId = source ~= "spell" and GetMountInfoByID and select(2, GetMountInfoByID(id))
    if spellId then changed = collect(tooltip, spellId, "spell", kind) or changed end
  end
  return changed
end

-- for hooks that run after Blizzard's own Show
local function add(tooltip, id, kind)
  if collect(tooltip, id, kind) then tooltip:Show() end
end

-- only the creature form carries an npc id, a Player or BattlePet guid holds something else
local function npcIdFromGUID(guid)
  return tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$"))
end

local function wildPetSpecies(guid)
  local unit = guid and UnitTokenFromGUID and UnitBattlePetSpeciesID and UnitTokenFromGUID(guid)
  local speciesId = unit and UnitBattlePetSpeciesID(unit)
  if speciesId and not isSecret(speciesId) and speciesId > 0 then return speciesId end
end

-- during a battle the unit is the pet, whose npc id belongs on no tooltip
local function addNpc(tooltip, guid, fallbackId)
  return not inPetBattle() and collect(tooltip, npcIdFromGUID(guid or "") or fallbackId, "unit")
end

-- nil without an item link, else whether the tooltip changed
local function addItemInfo(tooltip, link)
  local itemString = link and string.match(link, "item:([%-?%d:]+)")
  if not itemString then return end

  local itemSplit = {}
  -- never matches empty, so negative and blank fields keep position on Lua 5.1
  for value in string.gmatch(itemString .. ":", "([^:]*):") do
    itemSplit[#itemSplit + 1] = value
  end

  local itemId = string.match(link, "item:(%d*)")
  if not itemId or itemId == "" or itemId == "0" then return end
  local changed = collect(tooltip, itemId, "item")

  if GetTransmogItemInfo then
    local appearanceId, sourceId = GetTransmogItemInfo(link)
    changed = collect(tooltip, appearanceId, "visual") or changed
    changed = collect(tooltip, sourceId, "source") or changed
  end

  local enchantId = tonumber(itemSplit[2])
  if enchantId and enchantId ~= 0 then changed = collect(tooltip, itemSplit[2], "enchant") or changed end

  -- both kinds are checked here as well as in addLine, so a disabled one costs
  -- neither a table per tooltip nor four gem queries
  if isEnabled("bonus") then
    local bonuses = {}
    -- a crafted link can claim more bonus ids than it carries, and the count is the bound
    for index = 1, math.min(tonumber(itemSplit[13]) or 0, #itemSplit - 13) do
      bonuses[#bonuses + 1] = itemSplit[13 + index]
    end
    changed = collect(tooltip, bonuses, "bonus") or changed
  end

  if GetItemGem and isEnabled("gem") then
    local gems = {}
    for socket = 1, 4 do
      local gemLink = select(2, GetItemGem(link, socket))
      addUnique(gems, gemLink and string.match(gemLink, "item:(%d+):"))
    end
    changed = collect(tooltip, gems, "gem") or changed
  end

  if GetItemInfo then
    local expansionId, setId = select(15, GetItemInfo(itemId))
    if expansionId and expansionId ~= 254 then -- always 254 on classic, therefor uninteresting
      changed = collect(tooltip, expansionId, "expansion") or changed
    end
    if setId then changed = collect(tooltip, setId, "set") or changed end
  end

  return changed
end

-- Tooltip data
--
-- On retail every GameTooltip:SetX is generated by TooltipDataHandlerMixin and routes
-- through ProcessInfo, which fires this post call, so one hook covers every kind.
-- Only retail mixes that in, see the classic section below.

-- absent on classic era, where TooltipDataHandler.lua is ExcludeLoadGameType vanilla
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
  TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
    if not data or not data.type then return end
    if isSecret(data.type) or isSecret(data.guid) then return end -- indexing with a secret errors
    local kind = kindsByID[tonumber(data.type)]
    if not kind then return end

    -- collect, not add, since InternalProcessInfo shows the tooltip right after its post calls
    if kind == "unit" then
      addNpc(tooltip, data.guid, data.id)
      collect(tooltip, wildPetSpecies(data.guid), "species")
    elseif kind == "item" then
      -- the link carries ids data.id lacks, and the guid resolves the actual
      -- item instance, so it wins, as in TooltipUtil.GetDisplayedItem
      local link = (data.guid and GetItemLinkByGUID and GetItemLinkByGUID(data.guid)) or data.hyperlink
      if not link and tooltip.GetItem then link = select(2, tooltip:GetItem()) end
      if addItemInfo(tooltip, link) == nil then collect(tooltip, data.id, kind) end
    else
      collect(tooltip, data.id, kind)
    end
  end)
end

-- Classic and anniversary
--
-- Both ship TooltipDataHandler.lua but mix TooltipDataHandlerMixin into no tooltip,
-- so the post call above never fires here. Only that mixin defines ProcessInfo, so
-- its absence is the test. Registering these on retail too would parse every link twice.

if GameTooltip and not GameTooltip.ProcessInfo then

hookScript(GameTooltip, "OnTooltipSetItem", function(tooltip)
  if addItemInfo(tooltip, select(2, tooltip:GetItem())) then tooltip:Show() end
end)

hookScript(GameTooltip, "OnTooltipSetSpell", function(tooltip)
  add(tooltip, select(2, tooltip:GetSpell()), "spell")
end)

hookScript(GameTooltip, "OnTooltipSetUnit", function(tooltip)
  local unit = select(2, tooltip:GetUnit())
  if unit and UnitGUID and addNpc(tooltip, UnitGUID(unit)) then tooltip:Show() end
end)

-- an aura is its own tooltip type, so no OnTooltipSet script covers it, and the
-- player buff bar uses the instance-ID setters
if C_UnitAuras then
  local byInstance = C_UnitAuras.GetAuraDataByAuraInstanceID
  for method, getAura in pairs({SetUnitAura = C_UnitAuras.GetAuraDataByIndex,
    SetUnitBuff = C_UnitAuras.GetBuffDataByIndex, SetUnitDebuff = C_UnitAuras.GetDebuffDataByIndex,
    SetUnitAuraByAuraInstanceID = byInstance, SetUnitBuffByAuraInstanceID = byInstance,
    SetUnitDebuffByAuraInstanceID = byInstance}) do
    hook(GameTooltip, method, function(tooltip, unit, key, filter)
      local aura = getAura(unit, key, filter)
      add(tooltip, aura and aura.spellId, "spell")
    end)
  end
end

local function onSetHyperlink(tooltip, link)
  local kind, id = string.match(link, "^(%a+):(%d+)")
  if kind == "enchant" or kind == "trade" then kind = "spell" end
  if kind and kinds[kind] then add(tooltip, id, kind) end
end
hook(GameTooltip, "SetHyperlink", onSetHyperlink)
hook(ItemRefTooltip, "SetHyperlink", onSetHyperlink)

if GetActionInfo then
  hook(GameTooltip, "SetAction", function(tooltip, slot)
    local kind, id = GetActionInfo(slot)
    if kinds[kind] then add(tooltip, id, kind) end -- the other action types carry no id we label
  end)
end

if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListLink then
  hook(GameTooltip, "SetCurrencyToken", function(tooltip, index)
    local link = C_CurrencyInfo.GetCurrencyListLink(index)
    add(tooltip, link and tonumber(link:match("currency:(%d+)")), "currency")
  end)
end

-- SetCurrencyToken only covers the token frame, and no script fires for a currency
hook(GameTooltip, "SetCurrencyByID", function(tooltip, id)
  add(tooltip, id, "currency")
end)

end

-- the recipe tooltip carries Item data, so the spell is only available here
hook(GameTooltip, "SetRecipeResultItem", function(tooltip, id)
  add(tooltip, id, "spell")
end)

-- no TooltipDataType covers artifact power, so the setter is the only source
hook(GameTooltip, "SetArtifactPowerByID", function(tooltip, id)
  add(tooltip, id, "artifactpower")
end)

-- Ids that tooltip data does not carry

-- SetTalent is the classic path. Retail only reaches SetPvpTalent, its class
-- talents being traits, covered by the TalentDisplayMixin hook below.
local function onSetTalent(tooltip, id)
  add(tooltip, id, "talent")
end
hook(GameTooltip, "SetTalent", onSetTalent)
hook(GameTooltip, "SetPvpTalent", onSetTalent)

if C_PetJournal and C_PetJournal.GetPetInfoByPetID then
  local function addPetInfo(speciesId)
    if not speciesId then return end
    add(GameTooltip, speciesId, "species")
    if C_PetJournal.GetPetInfoBySpeciesID then
      add(GameTooltip, select(4, C_PetJournal.GetPetInfoBySpeciesID(speciesId)), "unit")
    end
  end

  hook(GameTooltip, "SetCompanionPet", function(_tooltip, petId)
    addPetInfo(C_PetJournal.GetPetInfoByPetID(petId))
  end)
end

if TalentDisplayMixin then
  hook(TalentDisplayMixin, "SetTooltipInternal", function(button)
    if not button then return end
    add(GameTooltip, button.entryID, "traitentry")
    add(GameTooltip, button.definitionID, "traitdef")
    local nodeInfo = button.GetNodeInfo and button:GetNodeInfo()
    add(GameTooltip, nodeInfo and nodeInfo.ID, "traitnode")
  end)
end

hook(_G, "TaskPOI_OnEnter", function(button)
  if button and button.questID then add(GameTooltip, button.questID, "quest") end
end)

if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then -- retail only
  hook(_G, "QuestMapLogTitleButton_OnEnter", function(button)
    add(GameTooltip, C_QuestLog.GetQuestIDForLogIndex(button.questLogIndex), "quest")
  end)
end

-- A pin with nothing to show gets no tooltip, and hooksecurefunc cannot see that
-- early return, so ownership is the only signal. It also picks the frame, since
-- classic vignettes fill WorldMapTooltip.
local function pinTooltip(pin)
  if not pin then return end
  for _, tooltip in ipairs({GameTooltip, WorldMapTooltip}) do -- ipairs stops at the nil
    if tooltip:IsShown() and tooltip:IsOwned(pin) then return tooltip end
  end
end

hook(AreaPOIPinMixin, "TryShowTooltip", function(pin)
  local tooltip = pinTooltip(pin)
  if tooltip then
    add(tooltip, pin.areaPoiID or pin.poiInfo and pin.poiInfo.areaPoiID, "areapoi") -- retail nests it, classic puts it on the pin
  end
end)

hook(VignettePinMixin, "OnMouseEnter", function(pin)
  local tooltip = pinTooltip(pin)
  if tooltip and pin.vignetteInfo then add(tooltip, pin.vignetteInfo.vignetteID, "vignette") end
end)

-- in Blizzard_FrameXMLUtil, which always loads, and the dressing room and transmog
-- NPC reach it without Blizzard_Collections
hook(CollectionWardrobeUtil, "SetAppearanceTooltip", function(_tooltip, appearanceData)
  local sources = appearanceData and appearanceData.sources
  if not sources then return end

  local visualIDs, sourceIDs, itemIDs = {}, {}, {}
  for _, source in ipairs(sources) do
    addUnique(visualIDs, source.visualID)
    addUnique(sourceIDs, source.sourceID)
    addUnique(itemIDs, source.itemID)
  end

  add(GameTooltip, visualIDs, "visual")
  add(GameTooltip, sourceIDs, "source")
  add(GameTooltip, itemIDs, "item")
end)

-- these two own the tooltip rather than appending, so with nothing to add they
-- must not touch it, or they leave an empty box
local function achievementOnEnter(button)
  if not isEnabled("achievement") then return end
  GameTooltip:SetOwner(button, "ANCHOR_NONE")
  GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
  collect(GameTooltip, button.id, "achievement")
  GameTooltip:Show()
end

-- Blizzard pools frames per criteria kind, so a pool index equals the criteria
-- index only while an achievement mixes no kinds
local function criteriaIndex(achievementId, kind, poolIndex)
  if not GetAchievementNumCriteria or not GetAchievementCriteriaInfo then return end
  for index = 1, GetAchievementNumCriteria(achievementId) do
    local _, criteriaType, _, _, _, _, flags, assetId = GetAchievementCriteriaInfo(achievementId, index)
    local frameKind = criteriaType == CRITERIA_TYPE_ACHIEVEMENT and assetId and "metas"
      or bit.band(flags or 0, EVALUATION_TREE_FLAG_PROGRESS_BAR or 0) ~= 0 and "progressBars"
      or "criterias"
    if frameKind == kind then
      poolIndex = poolIndex - 1
      if poolIndex == 0 then return index end
    end
  end
end

local function criteriaOnEnter(frame)
  if not isEnabled("achievement") and not isEnabled("criteria") then return end
  local button = frame:GetParent()
  while button and not button.id do button = button:GetParent() end
  if not button then return end
  local index = criteriaIndex(button.id, frame.idTipKind, frame.idTipIndex)
  if not index then return end -- released pool frames keep an index the achievement no longer has
  local criteriaId = select(10, GetAchievementCriteriaInfo(button.id, index))
  if not criteriaId then return end
  if not GameTooltip:IsVisible() then GameTooltip:SetOwner(button:GetParent(), "ANCHOR_NONE") end
  GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
  collect(GameTooltip, button.id, "achievement")
  collect(GameTooltip, criteriaId, "criteria")
  GameTooltip:Show()
end

local function hookCriteria(frame, kind, index)
  if not frame then return end
  -- retail 11.2.0 moved the tooltip to the criterion's Name font string, which
  -- takes the mouse from the row. Classic has no such key.
  for _, target in ipairs({frame, frame.Name}) do
    -- stamped with the addon prefix, since these are Blizzard's frames
    target.idTipIndex = index -- pooled frames get reused with a different index
    target.idTipKind = kind
    if not target.idTipHooked then
      -- classic criteria rows ship mouse-disabled, so OnEnter could never fire.
      -- Motion only, leaving clicks to fall through to the achievement button.
      if target.SetMouseMotionEnabled then target:SetMouseMotionEnabled(true) end
      hookScript(target, "OnEnter", criteriaOnEnter)
      hookScript(target, "OnLeave", GameTooltip_Hide)
      target.idTipHooked = true
    end
  end
end

if C_PetBattles then
  -- PetBattlePrimaryAbilityTooltip is a bare Frame with no lines or cells, so
  -- addLine cannot reach it and this appends to a font string instead
  local function addPetBattleAbility(id)
    if not shouldAdd(id, "ability") then return end
    local description = PetBattlePrimaryAbilityTooltip and PetBattlePrimaryAbilityTooltip.Description
    if not description then return end
    description:SetText((description:GetText() or "") .. "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r")
  end

  -- retail dropped the LE_ constant in favour of the enum
  local ally = Enum and Enum.BattlePetOwner and Enum.BattlePetOwner.Ally or LE_BATTLE_PET_ALLY

  if C_PetBattles.GetAbilityInfo and C_PetBattles.GetActivePet then
    hook(_G, "PetBattleAbilityButton_OnEnter", function(button)
      if button:GetEffectiveAlpha() > 0 then
        addPetBattleAbility(C_PetBattles.GetAbilityInfo(ally, C_PetBattles.GetActivePet(ally), button:GetID()))
      end
    end)
  end

  if C_PetBattles.GetAuraInfo then
    hook(_G, "PetBattleAura_OnEnter", function(frame)
      local parent = frame:GetParent()
      addPetBattleAbility(C_PetBattles.GetAuraInfo(parent.petOwner, parent.petIndex, frame.auraIndex))
    end)
  end
end

-- native settings list, so Blizzard owns layout, hit areas and search, and each
-- setting writes straight into idTipConfig
local function registerOptions()
  local category, layout = Settings.RegisterVerticalLayoutCategory(addonName)

  local function addCheckbox(key, label, default, tooltip)
    local setting = Settings.RegisterAddOnSetting(category, addonName .. "_" .. key, key, idTipConfig,
      "boolean", label, default)
    Settings.CreateCheckbox(category, setting, tooltip)
  end

  local function addHeader(name)
    if layout and CreateSettingsListSectionHeaderInitializer then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name))
    end
  end

  addCheckbox("enabled", "Enabled", true)
  addCheckbox("compact", "Single Line", false, "Show all IDs on one line, wrapped to the tooltip's width")

  for _, section in ipairs(kindSections) do
    addHeader(section.name)
    for _, kind in ipairs(section) do
      addCheckbox(configKey(kind), kinds[kind], not defaultDisabledKinds[kind])
    end
  end

  Settings.RegisterAddOnCategory(category)
  return category
end

-- Events

local eventFrame = CreateFrame("frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, addon)
  if addon == addonName then
    if not idTipConfig then idTipConfig = {} end

    if type(idTipConfig.enabled) ~= "boolean" then idTipConfig.enabled = true end
    if type(idTipConfig.compact) ~= "boolean" then idTipConfig.compact = false end
    -- 1, not 2, so a config written before the field existed still migrates
    if type(idTipConfig.version) ~= "number" then idTipConfig.version = 1 end

    for key in pairs(kinds) do
      if type(idTipConfig[configKey(key)]) ~= "boolean" then
        idTipConfig[configKey(key)] = not defaultDisabledKinds[key]
      end
    end

    -- config migrations
    if idTipConfig.version == 1 then -- v1 to v2 - disable bonus kind
      idTipConfig[configKey("bonus")] = false
      idTipConfig.version = 2
    end

    -- after the defaults, since each setting binds a key that must already exist
    if Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting
      and Settings.CreateCheckbox and Settings.RegisterAddOnCategory then
      local category = registerOptions()
      if Settings.OpenToCategory then
        SLASH_IDTIP1 = "/idtip"
        function SlashCmdList.IDTIP() Settings.OpenToCategory(category.ID) end
      end
    end
  elseif addon == "Blizzard_AchievementUI" then
    if AchievementTemplateMixin then
      -- retail
      hook(AchievementTemplateMixin, "OnEnter", achievementOnEnter)
      hook(AchievementTemplateMixin, "OnLeave", GameTooltip_Hide)

      -- miniAchievements are earlier links in a chain, not criteria, and carry no id
      local objectives = AchievementTemplateMixin.GetObjectiveFrame and AchievementTemplateMixin:GetObjectiveFrame()
      for method, kind in pairs({GetCriteria = "criterias", GetMeta = "metas", GetProgressBar = "progressBars"}) do
        hook(objectives, method, function(self, index)
          if self and self[kind] then hookCriteria(self[kind][index], kind, index) end
        end)
      end
    elseif AchievementFrameAchievementsContainer and AchievementFrameAchievementsContainer.buttons then
      -- classic and anniversary
      for _, button in ipairs(AchievementFrameAchievementsContainer.buttons) do
        hookScript(button, "OnEnter", achievementOnEnter)
        hookScript(button, "OnLeave", GameTooltip_Hide)
      end

      hook(_G, "AchievementButton_GetCriteria", function(index)
        hookCriteria(_G["AchievementFrameCriteria" .. index], "criterias", index)
      end)
    end
  elseif addon == "Blizzard_LegacySystem" then
    -- Forever's achievement cards, unless they copied AchievementTemplateMixin after its hook
    local legacyMixin = LegacyChallengeTemplateMixin
    if legacyMixin and AchievementTemplateMixin and legacyMixin.OnEnter ~= AchievementTemplateMixin.OnEnter then
      hook(legacyMixin, "OnEnter", achievementOnEnter)
      hook(legacyMixin, "OnLeave", GameTooltip_Hide)
    end
  elseif addon == "Blizzard_GarrisonUI" then
    -- ability id
    hook(_G, "AddAutoCombatSpellToTooltip", function (tooltip, info)
      if info and info.autoCombatSpellID then
        add(tooltip, info.autoCombatSpellID, "ability")
      end
    end)
  end
end)
