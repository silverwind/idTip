-- luacheck: no unused args
local function assertEq(actual, expected)
  if actual ~= expected then
    error("expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assertTrue(actual)
  if not actual then
    error("expected truthy, got " .. tostring(actual), 2)
  end
end

local mockState = {}

local function createMockTooltip(env, tooltipName)
  local lines = {}
  local t = {}

  function t:GetName() return tooltipName end
  function t:NumLines() return #lines end
  function t:AddDoubleLine(left, right)
    local index = #lines + 1
    lines[index] = {left = left, right = right}
    for side, key in pairs({Left = "left", Right = "right"}) do
      env[tooltipName .. "Text" .. side .. index] = {
        GetText = function() return tostring(lines[index][key]) end,
        SetText = function(_, text) lines[index][key] = text end,
      }
    end
  end
  function t:Show() self._shown = true end
  function t:IsVisible() return false end
  function t:IsShown() return self._shown == true end
  function t:SetOwner(owner) self._owner = owner end
  function t:IsOwned(frame) return self._owner == frame end
  function t:SetPoint() end
  function t:SetMouseMotionEnabled(enabled) self._motion = enabled end
  function t:GetItem() return nil, mockState.itemLink end
  function t:GetSpell() return nil, mockState.spellId end
  function t:GetUnit() return nil, mockState.unit end
  function t:ProcessInfo() end
  function t:GetParent() return self._parent end

  t._scripts = {}
  t._hooks = {}
  function t:HasScript() return true end
  function t:SetScript(name, fn) self._scripts[name] = fn end
  function t:HookScript(name, fn)
    self._hooks[name] = self._hooks[name] or {}
    table.insert(self._hooks[name], fn)
  end
  function t:_fire(name, ...)
    for _, fn in ipairs(self._hooks[name] or {}) do fn(self, ...) end
  end

  for _, method in ipairs({"SetTalent", "SetPvpTalent", "SetCompanionPet", "SetRecipeResultItem", "SetCurrencyByID",
    "SetArtifactPowerByID", "SetUnitAura", "SetUnitBuff", "SetUnitDebuff", "SetUnitAuraByAuraInstanceID", "SetUnitBuffByAuraInstanceID",
    "SetUnitDebuffByAuraInstanceID"}) do
    t[method] = function() end
  end

  function t:_line(i) return lines[i] end
  function t:_reset()
    self._shown, self._owner = nil, nil
    for i = #lines, 1, -1 do
      env[tooltipName .. "TextLeft" .. i] = nil
      env[tooltipName .. "TextRight" .. i] = nil
      lines[i] = nil
    end
  end

  return t
end

assert(_VERSION == "Lua 5.1", "run under luajit, WoW's dialect, not " .. _VERSION)

local function createEnv()
  local env = setmetatable({}, {__index = _G})
  env._G = env

  env.hooks = {}
  env.hookCounts = {}
  env.settings = {}
  env.headers = {}

  env.WHITE_FONT_COLOR = {r = 1, g = 1, b = 1}
  env.GameTooltip = createMockTooltip(env, "GameTooltip")

  env.hooksecurefunc = function(_, name, cb)
    env.hooks[name] = cb
    env.hookCounts[name] = (env.hookCounts[name] or 0) + 1
  end

  env.CreateFrame = function(frameType, name)
    local frame = createMockTooltip(env, name or ("Frame" .. frameType))
    frame._events = {}
    function frame:RegisterEvent(event) self._events[event] = true end
    return frame
  end

  env.TooltipDataProcessor = {
    AllTypes = -1,
    AddTooltipPostCall = function(_, callback) env.tooltipCallback = callback end,
  }

  env.C_Spell = {GetSpellTexture = function() return mockState.spellTexture, mockState.spellTexture end}

  env.C_Item = {
    GetItemIconByID = function() return mockState.itemIcon end,
    GetItemLinkByGUID = function() return mockState.guidLink or mockState.itemLink end,
    GetItemInfo = function()
      mockState.itemInfoCalls = (mockState.itemInfoCalls or 0) + 1
      return unpack(mockState.itemInfo or {}, 1, 16)
    end,
    GetItemGem = function(_, index)
      local link = (mockState.itemGems or {})[index]
      return link and "gem", link
    end,
    GetItemSpell = function()
      local spell = mockState.itemSpell or {}
      return spell[1], spell[2]
    end,
  }

  env.Settings = {
    RegisterVerticalLayoutCategory = function(name)
      return {ID = name}, {AddInitializer = function(_, header) env.headers[#env.headers + 1] = header end}
    end,
    RegisterAddOnSetting = function(_, variable, key, table_, valueType, label, default)
      local setting = {variable = variable, key = key, table = table_, valueType = valueType,
        label = label, default = default}
      env.settings[#env.settings + 1] = setting
      return setting
    end,
    CreateCheckbox = function(_, setting) setting.checkbox = true end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
  }
  env.CreateSettingsListSectionHeaderInitializer = function(name) return {header = name} end

  for _, name in ipairs({"GameTooltip_Hide", "TaskPOI_OnEnter", "QuestMapLogTitleButton_OnEnter",
    "AddAutoCombatSpellToTooltip", "PetBattleAbilityButton_OnEnter",
    "PetBattleAura_OnEnter", "AchievementButton_GetCriteria"}) do
    env[name] = function() end
  end

  env.issecretvalue = function(value)
    return mockState.secretValue ~= nil and value == mockState.secretValue
  end
  env.issecrettable = function() return false end

  env.CollectionWardrobeUtil = {SetAppearanceTooltip = function() end}
  env.C_PetJournal = {
    GetPetInfoByPetID = function() return mockState.petSpeciesId end,
    GetPetInfoBySpeciesID = function() return nil, nil, nil, mockState.petNpcId end,
  }

  env.UnitGUID = function() return mockState.unitGuid end

  env.Enum = {BattlePetOwner = {Ally = 1}}
  env.PetBattlePrimaryAbilityTooltip = {
    Description = {
      _text = "base",
      GetText = function(self) return self._text end,
      SetText = function(self, value) self._text = value end,
    },
  }
  env.C_PetBattles = {
    IsInBattle = function() return mockState.inPetBattle == true end,
    GetActivePet = function() return 1 end,
    GetAbilityInfo = function() return mockState.petAbilityId end,
    GetAuraInfo = function() return mockState.petAuraId end,
  }

  env.C_UnitAuras = {
    GetAuraDataByIndex = function() return mockState.aura end,
    GetBuffDataByIndex = function() return mockState.aura end,
    GetDebuffDataByIndex = function() return mockState.aura end,
    GetAuraDataByAuraInstanceID = function() return mockState.aura end,
  }

  env.TalentDisplayMixin = {SetTooltipInternal = function() end}
  env.AreaPOIPinMixin = {TryShowTooltip = function() end}
  env.VignettePinMixin = {OnMouseEnter = function() end}
  env.WorldMapTooltip = createMockTooltip(env, "WorldMapTooltip")

  env.CRITERIA_TYPE_ACHIEVEMENT = 8
  env.EVALUATION_TREE_FLAG_PROGRESS_BAR = 0x1
  env.bit = {band = function(value, mask) return value % (mask * 2) >= mask and mask or 0 end}

  env.AchievementFrameAchievementsContainer = {buttons = {}}
  for i = 1, 5 do
    local button = createMockTooltip(env, "AchButton" .. i)
    button.id = 5150
    env.AchievementFrameAchievementsContainer.buttons[i] = button
  end
  env.SlashCmdList = {}

  return env
end

local source = io.open("idTip.lua"):read("*a")

local function loadInto(reduce)
  local newEnv = createEnv()
  local frames = {}
  local createFrame = newEnv.CreateFrame
  newEnv.CreateFrame = function(...)
    local frame = createFrame(...)
    frames[#frames + 1] = frame
    return frame
  end
  if reduce then reduce(newEnv) end
  assert(load(source, "@idTip.lua", "t", newEnv))("idTip")
  return newEnv, frames
end

local env, framesList = loadInto()
local tooltipCallback = assert(env.tooltipCallback, "TooltipDataProcessor callback not captured")
local hooks, hookCounts, settings, headers = env.hooks, env.hookCounts, env.settings, env.headers
local eventFrame = framesList[1]
assert(eventFrame, "Event frame not created")
local eventHandler = eventFrame._scripts["OnEvent"]
assert(eventHandler, "OnEvent handler not set")

local function findLine(tooltip, label)
  for i = 1, tooltip:NumLines() do
    local line = tooltip:_line(i)
    if line.left == label then return line end
  end
end

local plainLink = "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:0|h[Item]|h"
local vestLink = "|Hitem:158075:5932:0:0:0:0:0:0:120:0:0:0:2:3524:1472|h[Vest]|h"
local abilityButton = {GetEffectiveAlpha = function() return 1 end, GetID = function() return 1 end}

local function loadAddon(name)
  eventHandler(eventFrame, "ADDON_LOADED", name)
end

local function setup()
  env.GameTooltip:_reset()
  env.WorldMapTooltip:_reset()
  for k in pairs(mockState) do mockState[k] = nil end
  for k in pairs(hookCounts) do hookCounts[k] = nil end
  for i = #settings, 1, -1 do settings[i] = nil end
  for i = #headers, 1, -1 do headers[i] = nil end
  env.idTipConfig = nil
  env.AchievementTemplateMixin = nil
  env.PetBattlePrimaryAbilityTooltip.Description._text = "base"
  loadAddon("idTip")
end

local passed, failed = 0, 0

local function test(name, fn)
  setup()
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("  \27[32m✓\27[0m " .. name)
  else
    failed = failed + 1
    print("  \27[31m✗\27[0m " .. name)
    print("    " .. tostring(err))
  end
end

local function describe(name, fn)
  print("\27[1m" .. name .. "\27[0m")
  fn()
end

local function showItem(link, id)
  id = id or 12345
  mockState.itemLink = link
  tooltipCallback(env.GameTooltip, {type = 0, id = id, guid = "Item-0-0-0-0-" .. id})
end

describe("config initialization", function()
  test("ADDON_LOADED creates default config", function()
    assertTrue(env.idTipConfig)
    assertEq(env.idTipConfig.enabled, true)
  end)

  test("config is migrated to version 2", function()
    assertEq(env.idTipConfig.version, 2)
  end)

  test("core kinds are enabled by default", function()
    assertEq(env.idTipConfig.spellEnabled, true)
    assertEq(env.idTipConfig.itemEnabled, true)
    assertEq(env.idTipConfig.unitEnabled, true)
    assertEq(env.idTipConfig.questEnabled, true)
    assertEq(env.idTipConfig.achievementEnabled, true)
    assertEq(env.idTipConfig.currencyEnabled, true)
    assertEq(env.idTipConfig.mountEnabled, true)
  end)

  test("bonus and trait kinds are disabled by default", function()
    assertEq(env.idTipConfig.bonusEnabled, false)
    assertEq(env.idTipConfig.traitnodeEnabled, false)
    assertEq(env.idTipConfig.traitentryEnabled, false)
    assertEq(env.idTipConfig.traitdefEnabled, false)
  end)

  test("preserves existing config values", function()
    env.idTipConfig = {enabled = false, version = 2, spellEnabled = true}
    loadAddon("idTip")
    assertEq(env.idTipConfig.enabled, false)
    assertEq(env.idTipConfig.spellEnabled, true)
  end)

  test("ignores other addon ADDON_LOADED", function()
    env.idTipConfig = nil
    loadAddon("SomeOtherAddon")
    assertEq(env.idTipConfig, nil)
  end)
end)

describe("item tooltip via TooltipDataProcessor", function()
  test("adds ItemID for simple item (no GUID)", function()
    tooltipCallback(env.GameTooltip, {type = 0, id = 67890})
    assertEq(findLine(env.GameTooltip, "ItemID").right, 67890)
  end)

  test("parses full item link via GetItemLinkByGUID", function()
    env.idTipConfig.bonusEnabled = true
    showItem(vestLink, 158075)
    assertEq(findLine(env.GameTooltip, "ItemID").right, "158075")
    assertEq(findLine(env.GameTooltip, "EnchantID").right, "5932")
    assertEq(findLine(env.GameTooltip, "BonusIDs").right, "3524,1472")
  end)

  test("a negative suffix id does not shift the link fields", function()
    mockState.itemLink = "|Hitem:158075:5932:0:0:0:0:-25:0:120:0:0:0:2:3524:1472|h[Vest]|h"
    env.idTipConfig.bonusEnabled = true
    tooltipCallback(env.GameTooltip, {type = 0, id = 158075})
    assertEq(findLine(env.GameTooltip, "BonusIDs").right, "3524,1472")
  end)

  test("a link claiming more bonus ids than it carries is bounded", function()
    mockState.itemLink = "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:99999999999:100|h[Evil]|h"
    env.idTipConfig.bonusEnabled = true
    tooltipCallback(env.GameTooltip, {type = 0, id = 12345})
    assertEq(findLine(env.GameTooltip, "BonusID").right, "100")
  end)

  test("the GUID link wins over the hyperlink", function()
    mockState.guidLink = vestLink
    tooltipCallback(env.GameTooltip, {type = 0, id = 158075, guid = "Item-0-0-0-0-158075", hyperlink = plainLink})
    assertEq(findLine(env.GameTooltip, "ItemID").right, "158075")
    assertEq(findLine(env.GameTooltip, "EnchantID").right, "5932")
  end)

  test("falls back to the link from GetItem when there is no GUID", function()
    mockState.itemLink = vestLink
    tooltipCallback(env.GameTooltip, {type = 0, id = 158075})
    assertEq(findLine(env.GameTooltip, "ItemID").right, "158075")
    assertEq(findLine(env.GameTooltip, "EnchantID").right, "5932")
  end)

  test("parses item link without enchant or bonuses", function()
    showItem("|Hitem:12345::0:0:0:0:0:0:0:0:0:0:0|h[Simple]|h")
    assertEq(findLine(env.GameTooltip, "ItemID").right, "12345")
    assertEq(env.GameTooltip:NumLines(), 1)
  end)

  test("parses item with expansion and set", function()
    mockState.itemInfo = {[15] = 9, [16] = 42}
    showItem(plainLink)
    assertEq(findLine(env.GameTooltip, "ExpansionID").right, 9)
    assertEq(findLine(env.GameTooltip, "SetID").right, 42)
  end)

  test("skips expansion 254 (classic)", function()
    mockState.itemInfo = {[15] = 254}
    showItem(plainLink)
    assertEq(findLine(env.GameTooltip, "ExpansionID"), nil)
  end)

  test("parses item with gems", function()
    mockState.itemGems = {
      [1] = "|Hitem:154128:0:0:0|h[Gem]|h",
      [2] = "|Hitem:154129:0:0:0|h[Gem2]|h",
    }
    showItem(plainLink)
    assertEq(findLine(env.GameTooltip, "GemIDs").right, "154128,154129")
  end)
end)

describe("tooltip data", function()
  test("adds SpellID and the derived IconID", function()
    mockState.spellTexture = 999999
    tooltipCallback(env.GameTooltip, {type = 1, id = 12345})
    assertEq(findLine(env.GameTooltip, "SpellID").right, 12345)
    assertEq(findLine(env.GameTooltip, "IconID").right, 999999)
  end)

  for _, case in ipairs({
    {type = 23, id = 55001, label = "QuestID"},
    {type = 5,  id = 1234,  label = "CurrencyID"},
    {type = 10, id = 777,   label = "MountID"},
    {type = 12, id = 9999,  label = "AchievementID"},
    {type = 4,  id = 300,   label = "ObjectID"},
  }) do
    test("type " .. case.type .. " adds " .. case.label, function()
      tooltipCallback(env.GameTooltip, {type = case.type, id = case.id})
      assertEq(findLine(env.GameTooltip, case.label).right, case.id)
    end)
  end

  for _, case in ipairs({
    {name = "a creature guid", guid = "Creature-0-1234-0-5678-69-0000123ABC", npcId = 69},
    {name = "a vehicle guid", guid = "Vehicle-0-1234-0-5678-12345-0000ABCDEF", npcId = 12345},
    {name = "a player guid, falling back to data.id", guid = "Player-1234-0000ABCD", npcId = 0},
  }) do
    test("resolves NpcID from " .. case.name, function()
      tooltipCallback(env.GameTooltip, {type = 2, id = 0, guid = case.guid})
      assertEq(findLine(env.GameTooltip, "NpcID").right, case.npcId)
    end)
  end

  for _, case in ipairs({
    {name = "a type carrying no id", data = {type = 15, id = 100}},
    {name = "nil data", data = nil},
    {name = "data without a type", data = {id = 123}},
    {name = "a nil id", data = {type = 1, id = nil}},
    {name = "an empty string id", data = {type = 1, id = ""}},
    {name = "a boolean id", data = {type = 1, id = true}},
    {name = "a secret id", data = {type = 1, id = 12345}, secretValue = 12345},
  }) do
    test("adds nothing for " .. case.name, function()
      mockState.secretValue = case.secretValue
      tooltipCallback(env.GameTooltip, case.data)
      assertEq(env.GameTooltip:NumLines(), 0)
    end)
  end

  test("a secret line is left alone rather than read", function()
    tooltipCallback(env.GameTooltip, {type = 23, id = 100})
    mockState.secretValue = "QuestID"
    tooltipCallback(env.GameTooltip, {type = 23, id = 100})
    assertEq(env.GameTooltip:NumLines(), 2)
  end)

  test("does not add the same kind twice", function()
    tooltipCallback(env.GameTooltip, {type = 23, id = 100})
    tooltipCallback(env.GameTooltip, {type = 23, id = 100})
    assertEq(env.GameTooltip:NumLines(), 1)
  end)
end)

describe("a second source for a kind already on the tooltip", function()
  test("the recipe spell joins the crafted item's use effect", function()
    mockState.itemSpell = {"Use", 111}
    showItem(plainLink)
    hooks.SetRecipeResultItem(env.GameTooltip, 222)
    assertEq(findLine(env.GameTooltip, "SpellIDs").right, "111,222")
    assertEq(findLine(env.GameTooltip, "SpellID"), nil)
  end)

  test("a companion pet's species and creature ids land on their own lines", function()
    mockState.petSpeciesId, mockState.petNpcId = 42, 888
    tooltipCallback(env.GameTooltip, {type = 9, id = 42})
    hooks.SetCompanionPet(nil, "petguid")
    assertEq(findLine(env.GameTooltip, "SpeciesID").right, 42)
    assertEq(findLine(env.GameTooltip, "NpcID").right, 888)
  end)

  test("an id already shown is not repeated", function()
    mockState.petSpeciesId, mockState.petNpcId = 42, 777
    tooltipCallback(env.GameTooltip, {type = 2, id = 777, guid = "Creature-0-1-0-1-777-0"})
    hooks.SetCompanionPet(nil, "petguid")
    assertEq(findLine(env.GameTooltip, "NpcID").right, 777)
    assertEq(env.GameTooltip:NumLines(), 2)
  end)

  test("another addon's longer label is not mistaken for ours", function()
    env.GameTooltip:AddDoubleLine("SpellID: 999", "")
    tooltipCallback(env.GameTooltip, {type = 1, id = 12345})
    assertEq(findLine(env.GameTooltip, "SpellID").right, 12345)
  end)
end)

describe("config controls", function()
  test("the master toggle suppresses everything", function()
    env.idTipConfig.enabled = false
    tooltipCallback(env.GameTooltip, {type = 1, id = 12345})
    assertEq(env.GameTooltip:NumLines(), 0)
  end)

  test("a disabled kind is suppressed while others still work", function()
    env.idTipConfig.spellEnabled = false
    tooltipCallback(env.GameTooltip, {type = 1, id = 12345})
    assertEq(env.GameTooltip:NumLines(), 0)
    tooltipCallback(env.GameTooltip, {type = 23, id = 55001})
    assertEq(findLine(env.GameTooltip, "QuestID").right, 55001)
  end)
end)

describe("multiple ids", function()
  test("a single bonus uses the singular label", function()
    env.idTipConfig.bonusEnabled = true
    showItem("|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:1:9999|h[Item]|h")
    assertEq(findLine(env.GameTooltip, "BonusID").right, "9999")
  end)

  test("multiple bonuses use the plural label", function()
    env.idTipConfig.bonusEnabled = true
    showItem("|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:3:100:200:300|h[Item]|h")
    assertEq(findLine(env.GameTooltip, "BonusIDs").right, "100,200,300")
  end)
end)

describe("ids tooltip data does not carry", function()
  test("SetTalent adds TalentID", function()
    hooks.SetTalent(env.GameTooltip, 55)
    assertEq(findLine(env.GameTooltip, "TalentID").right, 55)
  end)

  test("SetPvpTalent adds TalentID", function()
    hooks.SetPvpTalent(env.GameTooltip, 66)
    assertEq(findLine(env.GameTooltip, "TalentID").right, 66)
  end)

  test("SetCompanionPet adds species and NPC id", function()
    mockState.petSpeciesId, mockState.petNpcId = 42, 777
    hooks.SetCompanionPet(nil, "petguid")
    assertEq(findLine(env.GameTooltip, "SpeciesID").right, 42)
    assertEq(findLine(env.GameTooltip, "NpcID").right, 777)
  end)

  test("SetTooltipInternal adds trait ids", function()
    env.idTipConfig.traitentryEnabled = true
    env.idTipConfig.traitdefEnabled = true
    hooks.SetTooltipInternal({entryID = 11, definitionID = 22})
    assertEq(findLine(env.GameTooltip, "TraitEntryID").right, 11)
    assertEq(findLine(env.GameTooltip, "TraitDefinitionID").right, 22)
  end)
end)

describe("macro tooltips", function()
  test("a macro adds only MacroID", function()
    tooltipCallback(env.GameTooltip, {type = 25, id = 7})
    assertEq(findLine(env.GameTooltip, "MacroID").right, 7)
    assertEq(findLine(env.GameTooltip, "SpellID"), nil)
  end)
end)

describe("wardrobe appearance tooltip", function()
  test("dedups ids and unwraps single-element lists", function()
    hooks.SetAppearanceTooltip(nil, {sources = {
      {visualID = 1, sourceID = 7, itemID = 9},
      {visualID = 1, sourceID = 8, itemID = 9},
    }})
    assertEq(findLine(env.GameTooltip, "VisualID").right, 1)
    assertEq(findLine(env.GameTooltip, "SourceIDs").right, "7,8")
    assertEq(findLine(env.GameTooltip, "ItemID").right, 9)
  end)
end)

describe("pet battles", function()
  test("ability button appends the id to the description font string", function()
    mockState.petAbilityId = 555
    hooks.PetBattleAbilityButton_OnEnter(abilityButton)
    assertEq(env.PetBattlePrimaryAbilityTooltip.Description._text, "base\r\rAbilityID|cffffffff 555|r")
  end)

  test("an empty description does not error", function()
    env.PetBattlePrimaryAbilityTooltip.Description._text = nil
    mockState.petAbilityId = 111
    hooks.PetBattleAbilityButton_OnEnter(abilityButton)
    assertEq(env.PetBattlePrimaryAbilityTooltip.Description._text, "\r\rAbilityID|cffffffff 111|r")
  end)

  test("aura frame appends the id to the description font string", function()
    mockState.petAuraId = 666
    hooks.PetBattleAura_OnEnter({GetParent = function() return {} end})
    assertEq(env.PetBattlePrimaryAbilityTooltip.Description._text, "base\r\rAbilityID|cffffffff 666|r")
  end)

  test("unit ids are suppressed during a pet battle, with or without a guid", function()
    mockState.inPetBattle = true
    tooltipCallback(env.GameTooltip, {type = 2, id = 0, guid = "Creature-0-1234-0-5678-4242-0000123ABC"})
    tooltipCallback(env.GameTooltip, {type = 2, id = 4242})
    assertEq(env.GameTooltip:NumLines(), 0)
  end)
end)

describe("regressions", function()
  test("the pet battle writer honours the master toggle", function()
    env.idTipConfig.enabled = false
    mockState.petAbilityId = 555
    hooks.PetBattleAbilityButton_OnEnter(abilityButton)
    assertEq(env.PetBattlePrimaryAbilityTooltip.Description._text, "base")
  end)

  test("an artifact power adds its id", function()
    hooks.SetArtifactPowerByID(env.GameTooltip, 1739)
    assertEq(findLine(env.GameTooltip, "ArtifactPowerID").right, 1739)
  end)

  test("a criterion after a progress bar resolves its own index on row or name hover, with mouse motion on", function()
    local flags = {env.EVALUATION_TREE_FLAG_PROGRESS_BAR, 0, 0}
    local criteriaIds = {111, 222, 333}
    env.GetAchievementNumCriteria = function() return 3 end
    env.GetAchievementCriteriaInfo = function(_, index)
      return "text", 0, false, 0, 0, nil, flags[index], nil, "", criteriaIds[index]
    end

    local button = env.CreateFrame("Button", "AchButton")
    button.id = 5150
    local objectives = env.CreateFrame("Frame", "Objectives")
    objectives._parent = button
    objectives.GetCriteria = function() end
    local row = env.CreateFrame("Frame", "Criteria1")
    row._parent = objectives
    row.Name = env.CreateFrame("FontString", "Criteria1Name")
    row.Name._parent = row
    objectives.criterias = {row}

    env.AchievementTemplateMixin = {
      OnEnter = function() end,
      OnLeave = function() end,
      GetObjectiveFrame = function() return objectives end,
    }
    loadAddon("Blizzard_AchievementUI")
    hooks.GetCriteria(objectives, 1)

    row.Name:_fire("OnEnter")
    assertEq(findLine(env.GameTooltip, "AchievementID").right, 5150)
    assertEq(findLine(env.GameTooltip, "CriteriaID").right, 222)

    env.GameTooltip:_reset()
    row:_fire("OnEnter")
    assertEq(findLine(env.GameTooltip, "CriteriaID").right, 222)

    assertEq(row._motion, true)
  end)

  test("a non-creature guid falls back to the tooltip's own id", function()
    tooltipCallback(env.GameTooltip, {type = 2, id = 42, guid = "BattlePet-0-0000047DAB65"})
    assertEq(findLine(env.GameTooltip, "NpcID").right, 42)
  end)

  test("a disabled addon does not steal the achievement tooltip", function()
    loadAddon("Blizzard_AchievementUI")
    env.idTipConfig.enabled = false
    env.AchievementFrameAchievementsContainer.buttons[1]:_fire("OnEnter")
    assertEq(env.GameTooltip:IsShown(), false)
  end)

  test("a map pin writes only to the tooltip it owns", function()
    local poi, vignette = {poiInfo = {areaPoiID = 7788}}, {vignetteInfo = {vignetteID = 4242}}

    hooks.TryShowTooltip(poi)
    hooks.OnMouseEnter(vignette)
    assertEq(env.GameTooltip:NumLines(), 0)
    assertEq(env.WorldMapTooltip:NumLines(), 0)

    env.GameTooltip:SetOwner(poi)
    env.GameTooltip:Show()
    hooks.TryShowTooltip(poi)
    assertEq(findLine(env.GameTooltip, "AreaPoiID").right, 7788)

    env.WorldMapTooltip:SetOwner(vignette)
    env.WorldMapTooltip:Show()
    hooks.OnMouseEnter(vignette)
    assertEq(findLine(env.WorldMapTooltip, "VignetteID").right, 4242)
    assertEq(env.GameTooltip:NumLines(), 1)
  end)

  test("a short item link does not error", function()
    showItem("|Hitem:6948|h[Hearthstone]|h", 6948)
    assertEq(findLine(env.GameTooltip, "ItemID").right, "6948")
  end)

  test("GetItemInfo is queried once per item, not once per field", function()
    mockState.itemInfo = {[15] = 9, [16] = 42}
    showItem(plainLink)
    assertEq(mockState.itemInfoCalls, 1)
  end)

  test("the global criteria hook is registered once, not once per button", function()
    loadAddon("Blizzard_AchievementUI")
    assertEq(#env.AchievementFrameAchievementsContainer.buttons, 5)
    assertEq(hookCounts.AchievementButton_GetCriteria, 1)
  end)
end)

describe("options", function()
  test("every kind is registered as a checkbox bound to its config key", function()
    local byKey = {}
    for _, setting in ipairs(settings) do
      assertTrue(setting.checkbox)
      assertEq(setting.valueType, "boolean")
      assertEq(setting.table, env.idTipConfig)
      assertTrue(#setting.label > 0)
      byKey[setting.key] = setting
    end

    assertEq(byKey.enabled.default, true)
    local kinds = 0
    for key, value in pairs(env.idTipConfig) do
      if key ~= "enabled" and string.match(key, "Enabled$") then
        kinds = kinds + 1
        assertEq(assert(byKey[key], "no setting for " .. key).default, value)
      end
    end
    assertTrue(kinds > 20)
  end)

  test("the list is split into sections covering every kind exactly once", function()
    local expected = {"Items", "Spells", "World", "Collections"}
    assertEq(#headers, #expected)
    for index, name in ipairs(expected) do assertEq(headers[index].header, name) end

    local kinds, seen = 0, {}
    for key in pairs(env.idTipConfig) do
      if key ~= "enabled" and string.match(key, "Enabled$") then kinds = kinds + 1 end
    end
    for _, setting in ipairs(settings) do
      assertEq(seen[setting.key], nil)
      seen[setting.key] = true
    end
    assertEq(#settings, kinds + 1)
  end)

  test("the slash command opens the category", function()
    assertTrue(env.SlashCmdList.IDTIP)
  end)
end)

describe("client profiles", function()
  local function loadProfile(reduce)
    local profile, profileFrames = loadInto(reduce)

    for _, frame in ipairs(profileFrames) do
      local onEvent = frame._scripts["OnEvent"]
      if onEvent then onEvent(frame, "ADDON_LOADED", "idTip") end
    end
    return profile, profile.tooltipCallback
  end

  test("classic era loads without TooltipDataProcessor", function()
    local profile = loadProfile(function(profileEnv) profileEnv.TooltipDataProcessor = nil end)
    assertTrue(profile.SlashCmdList.IDTIP)
  end)

  test("loads with any single Blizzard namespace missing", function()
    for _, global in ipairs({"C_Spell", "C_Item", "C_PetBattles", "C_PetJournal", "C_CurrencyInfo", "C_QuestLog",
      "Settings", "WHITE_FONT_COLOR", "GameTooltip", "ItemRefTooltip", "TalentDisplayMixin", "AreaPOIPinMixin",
      "VignettePinMixin", "GetActionInfo", "TooltipDataProcessor", "CollectionWardrobeUtil", "Enum"}) do
      local ok, err = pcall(loadProfile, function(profileEnv) profileEnv[global] = false end)
      if not ok then error("a missing " .. global .. " breaks load: " .. tostring(err), 2) end
    end
  end)

  test("lines still render when WHITE_FONT_COLOR is gone", function()
    local profile, callback = loadProfile(function(profileEnv) profileEnv.WHITE_FONT_COLOR = false end)
    callback(profile.GameTooltip, {type = 0, id = 12345})
    assertEq(findLine(profile.GameTooltip, "ItemID").right, 12345)
  end)

  test("retail does not register the classic script hooks", function()
    assertEq(env.GameTooltip._hooks["OnTooltipSetItem"], nil)
    assertEq(env.GameTooltip._hooks["OnTooltipSetSpell"], nil)
  end)

  test("classic still shows ids when the post call never fires", function()
    local profile = loadProfile(function(profileEnv)
      profileEnv.C_Item.GetItemLinkByGUID = nil
      profileEnv.TooltipDataProcessor.AddTooltipPostCall = function() end
      profileEnv.GameTooltip.ProcessInfo = nil
    end)
    mockState.itemLink = plainLink
    profile.GameTooltip:_fire("OnTooltipSetItem")
    assertEq(findLine(profile.GameTooltip, "ItemID").right, "12345")
    mockState.spellId = 555
    profile.GameTooltip:_fire("OnTooltipSetSpell")
    assertEq(findLine(profile.GameTooltip, "SpellID").right, 555)

    mockState.aura = {spellId = 777}
    for _, method in ipairs({"SetUnitAura", "SetUnitBuff", "SetUnitDebuff", "SetUnitAuraByAuraInstanceID",
      "SetUnitBuffByAuraInstanceID", "SetUnitDebuffByAuraInstanceID"}) do
      profile.GameTooltip:_reset()
      profile.hooks[method](profile.GameTooltip, "player", 1)
      assertEq(findLine(profile.GameTooltip, "SpellID").right, 777)
    end

    profile.GameTooltip:_reset()
    profile.hooks.SetCurrencyByID(profile.GameTooltip, 3008)
    assertEq(findLine(profile.GameTooltip, "CurrencyID").right, 3008)
  end)

  test("a removed member function costs its id, not the rest", function()
    local profile = loadProfile(function(profileEnv)
      profileEnv.C_PetJournal.GetPetInfoBySpeciesID = nil
      profileEnv.C_PetBattles.GetAbilityInfo = nil
      profileEnv.Settings.OpenToCategory = nil
    end)

    mockState.petSpeciesId = 42
    profile.hooks.SetCompanionPet(nil, "petguid")
    assertEq(findLine(profile.GameTooltip, "SpeciesID").right, 42)
    assertEq(findLine(profile.GameTooltip, "NpcID"), nil)

    assertEq(profile.hooks.PetBattleAbilityButton_OnEnter, nil)
    assertEq(profile.SlashCmdList.IDTIP, nil)
  end)

  test("classic item tooltips work without GetItemLinkByGUID", function()
    local profile, callback = loadProfile(function(profileEnv) profileEnv.C_Item.GetItemLinkByGUID = nil end)
    mockState.itemLink = plainLink
    callback(profile.GameTooltip, {type = 0, id = 12345, guid = "Item-0-0-0-0-12345"})
    assertEq(findLine(profile.GameTooltip, "ItemID").right, "12345")
  end)
end)

describe("harness isolation", function()
  test("a profile load does not rebind the retail env's hooks", function()
    env.idTipConfig.talentEnabled = false
    hooks.SetTalent(env.GameTooltip, 55)
    assertEq(env.GameTooltip:NumLines(), 0)

    env.idTipConfig.talentEnabled = true
    hooks.SetTalent(env.GameTooltip, 55)
    assertEq(findLine(env.GameTooltip, "TalentID").right, 55)
  end)
end)

print()
local total = passed + failed
if failed > 0 then
  print(string.format("\27[31m%d of %d tests failed\27[0m", failed, total))
  os.exit(1)
else
  print(string.format("\27[32m%d tests passed\27[0m", total))
end
