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
  local rows = {}
  local t = {_rows = rows, _scripts = {}, _hooks = {}}

  function t:GetName() return tooltipName end
  function t:NumLines() return #rows end
  function t:AddDoubleLine(left, right)
    local index = #rows + 1
    rows[index] = {left = left, right = right}
    for side, key in pairs({Left = "left", Right = "right"}) do
      env[tooltipName .. "Text" .. side .. index] = {
        GetText = function() return tostring(rows[index][key]) end,
        SetText = function(_, text) rows[index][key] = text end,
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
  function t:ProcessInfo() end
  function t:GetParent() return self._parent end
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

  function t:_reset()
    self._shown, self._owner = nil, nil
    for i = #rows, 1, -1 do
      env[tooltipName .. "TextLeft" .. i] = nil
      env[tooltipName .. "TextRight" .. i] = nil
      rows[i] = nil
    end
  end

  return t
end

local function repr(value)
  return type(value) == "string" and string.format("%q", value) or tostring(value)
end

local function lines(tooltip)
  local out = {}
  for i, row in ipairs(tooltip._rows) do out[i] = row.left .. "=" .. repr(row.right) end
  return table.concat(out, " ")
end

assert(_VERSION == "Lua 5.1", "run under luajit, WoW's dialect, not " .. _VERSION)

local source = io.open("idTip.lua"):read("*a")

local function loadAddon(env, name)
  env.eventFrame._scripts.OnEvent(env.eventFrame, "ADDON_LOADED", name)
end

local function loadInto(reduce)
  local env = setmetatable({}, {__index = _G})
  env._G = env
  env.hooks, env.hookCounts, env.settings, env.headers = {}, {}, {}, {}

  env.WHITE_FONT_COLOR = {r = 1, g = 1, b = 1}
  env.GameTooltip = createMockTooltip(env, "GameTooltip")

  env.hooksecurefunc = function(_, name, cb)
    env.hooks[name] = cb
    env.hookCounts[name] = (env.hookCounts[name] or 0) + 1
  end

  env.CreateFrame = function(frameType, name)
    local frame = createMockTooltip(env, name or ("Frame" .. frameType))
    function frame:RegisterEvent() env.eventFrame = self end
    return frame
  end

  env.TooltipDataProcessor = {
    AllTypes = -1,
    AddTooltipPostCall = function(_, callback) env.tooltipCallback = callback end,
  }

  env.C_Spell = {GetSpellTexture = function() return mockState.spellTexture end}

  env.C_Item = {
    GetItemIconByID = function() end,
    GetItemLinkByGUID = function() return mockState.guidLink or mockState.itemLink end,
    GetItemInfo = function()
      mockState.itemInfoCalls = (mockState.itemInfoCalls or 0) + 1
      return unpack(mockState.itemInfo or {}, 1, 16)
    end,
    GetItemGem = function(_, index)
      local link = (mockState.itemGems or {})[index]
      return link and "gem", link
    end,
    GetItemSpell = function() return unpack(mockState.itemSpell or {}, 1, 2) end,
  }

  env.Settings = {
    RegisterVerticalLayoutCategory = function(name)
      return {ID = name}, {AddInitializer = function(_, header) env.headers[#env.headers + 1] = header end}
    end,
    RegisterAddOnSetting = function(_, _variable, key, table_, valueType, label, default)
      local setting = {key = key, table = table_, valueType = valueType, label = label, default = default}
      env.settings[#env.settings + 1] = setting
      return setting
    end,
    CreateCheckbox = function(_, setting) setting.checkbox = true end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
  }
  env.CreateSettingsListSectionHeaderInitializer = function(name) return name end

  for _, name in ipairs({"PetBattleAbilityButton_OnEnter", "PetBattleAura_OnEnter", "AchievementButton_GetCriteria"}) do
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

  env.Enum = {BattlePetOwner = {Ally = 1}}
  env.PetBattlePrimaryAbilityTooltip = {
    Description = {
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

  local function getAura() return mockState.aura end
  env.C_UnitAuras = {GetAuraDataByIndex = getAura, GetBuffDataByIndex = getAura, GetDebuffDataByIndex = getAura,
    GetAuraDataByAuraInstanceID = getAura}

  env.TalentDisplayMixin = {SetTooltipInternal = function() end}
  env.AreaPOIPinMixin = {TryShowTooltip = function() end}
  env.VignettePinMixin = {OnMouseEnter = function() end}
  env.WorldMapTooltip = createMockTooltip(env, "WorldMapTooltip")

  env.EVALUATION_TREE_FLAG_PROGRESS_BAR = 0x1
  env.bit = {band = function(value, mask) return value % (mask * 2) >= mask and mask or 0 end}

  env.AchievementFrameAchievementsContainer = {buttons = {}}
  for i = 1, 5 do
    env.AchievementFrameAchievementsContainer.buttons[i] = createMockTooltip(env, "AchButton" .. i)
  end
  env.SlashCmdList = {}

  if reduce then reduce(env) end
  assert(load(source, "@idTip.lua", "t", env))("idTip")
  loadAddon(env, "idTip")
  return env
end

local env = loadInto()
local tooltipCallback = assert(env.tooltipCallback, "TooltipDataProcessor callback not captured")
local hooks = env.hooks

local plainLink = "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:0|h[Item]|h"
local vestLink = "|Hitem:158075:5932:0:0:0:0:0:0:120:0:0:0:2:3524:1472|h[Vest]|h"

local function setup()
  env.GameTooltip:_reset()
  env.WorldMapTooltip:_reset()
  mockState, env.hookCounts, env.settings, env.headers = {}, {}, {}, {}
  env.idTipConfig, env.AchievementTemplateMixin = nil, nil
  env.PetBattlePrimaryAbilityTooltip.Description._text = "base"
  loadAddon(env, "idTip")
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

local function show(data)
  if type(data) == "string" then
    mockState.itemLink = data
    local id = tonumber(data:match("item:(%d+)"))
    data = {type = 0, id = id, guid = "Item-0-0-0-0-" .. id}
  end
  tooltipCallback(env.GameTooltip, data)
end

local function cases(list, observe)
  for _, case in ipairs(list) do
    test(case[1], function()
      for key, value in pairs(case.state or {}) do mockState[key] = value end
      for key, value in pairs(case.config or {}) do env.idTipConfig[key] = value end
      if type(case[2]) == "function" then case[2]() else show(case[2]) end
      assertEq((observe or lines)(env.GameTooltip), case[3])
      if type(case[2]) == "string" then assertEq(mockState.itemInfoCalls, 1) end
    end)
  end
end

describe("config initialization", function()
  test("ADDON_LOADED creates an enabled version 2 config, core kinds on, bonus and trait kinds off", function()
    for key, value in pairs({enabled = true, version = 2, spellEnabled = true, itemEnabled = true, unitEnabled = true,
      questEnabled = true, achievementEnabled = true, currencyEnabled = true, mountEnabled = true,
      bonusEnabled = false, traitnodeEnabled = false, traitentryEnabled = false, traitdefEnabled = false}) do
      assertEq(key .. "=" .. repr(env.idTipConfig[key]), key .. "=" .. repr(value))
    end
  end)

  test("preserves existing config values", function()
    env.idTipConfig = {enabled = false, version = 2, spellEnabled = true}
    loadAddon(env, "idTip")
    assertEq(env.idTipConfig.enabled, false)
    assertEq(env.idTipConfig.spellEnabled, true)
  end)

  test("ignores other addon ADDON_LOADED", function()
    env.idTipConfig = nil
    loadAddon(env, "SomeOtherAddon")
    assertEq(env.idTipConfig, nil)
  end)
end)

describe("items", function()
  cases({
    {"adds ItemID for simple item (no GUID)", {type = 0, id = 67890}, "ItemID=67890"},
    {"parses full item link via GetItemLinkByGUID", vestLink, 'ItemID="158075" EnchantID="5932" BonusIDs="3524,1472"',
      config = {bonusEnabled = true}},
    {"a negative suffix id does not shift the link fields", {type = 0, id = 158075},
      'ItemID="158075" EnchantID="5932" BonusIDs="3524,1472"', config = {bonusEnabled = true},
      state = {itemLink = "|Hitem:158075:5932:0:0:0:0:-25:0:120:0:0:0:2:3524:1472|h[Vest]|h"}},
    {"a link claiming more bonus ids than it carries is bounded", {type = 0, id = 12345},
      'ItemID="12345" BonusID="100"', config = {bonusEnabled = true},
      state = {itemLink = "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:99999999999:100|h[Evil]|h"}},
    {"the GUID link wins over the hyperlink",
      {type = 0, id = 158075, guid = "Item-0-0-0-0-158075", hyperlink = plainLink},
      'ItemID="158075" EnchantID="5932"', state = {guidLink = vestLink}},
    {"falls back to the link from GetItem when there is no GUID", {type = 0, id = 158075},
      'ItemID="158075" EnchantID="5932"', state = {itemLink = vestLink}},
    {"parses item link without enchant or bonuses", "|Hitem:12345::0:0:0:0:0:0:0:0:0:0:0|h[Simple]|h",
      'ItemID="12345"'},
    {"parses expansion and set, querying GetItemInfo once per item, not once per field", plainLink,
      'ItemID="12345" ExpansionID=9 SetID=42', state = {itemInfo = {[15] = 9, [16] = 42}}},
    {"skips expansion 254 (classic)", plainLink, 'ItemID="12345"', state = {itemInfo = {[15] = 254}}},
    {"parses item with gems", plainLink, 'ItemID="12345" GemIDs="154128,154129"',
      state = {itemGems = {"|Hitem:154128:0:0:0|h[Gem]|h", "|Hitem:154129:0:0:0|h[Gem2]|h"}}},
    {"a single bonus uses the singular label", "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:1:9999|h[Item]|h",
      'ItemID="12345" BonusID="9999"', config = {bonusEnabled = true}},
    {"multiple bonuses use the plural label", "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:3:100:200:300|h[Item]|h",
      'ItemID="12345" BonusIDs="100,200,300"', config = {bonusEnabled = true}},
    {"a short item link does not error", "|Hitem:6948|h[Hearthstone]|h", 'ItemID="6948"'},
    {"the recipe spell joins the crafted item's use effect", function()
      show(plainLink)
      hooks.SetRecipeResultItem(env.GameTooltip, 222)
    end, 'ItemID="12345" SpellIDs="111,222"', state = {itemSpell = {"Use", 111}}},
  })
end)

describe("tooltip data", function()
  local spell, quest = {type = 1, id = 12345}, {type = 23, id = 100}
  cases({
    {"adds SpellID and the derived IconID", spell, "SpellID=12345 IconID=999999", state = {spellTexture = 999999}},
    {"type 23 adds QuestID", {type = 23, id = 55001}, "QuestID=55001"},
    {"type 5 adds CurrencyID", {type = 5, id = 1234}, "CurrencyID=1234"},
    {"type 10 adds MountID", {type = 10, id = 777}, "MountID=777"},
    {"type 12 adds AchievementID", {type = 12, id = 9999}, "AchievementID=9999"},
    {"type 4 adds ObjectID", {type = 4, id = 300}, "ObjectID=300"},
    {"a macro adds only MacroID", {type = 25, id = 7}, "MacroID=7"},
    {"resolves NpcID from a creature guid", {type = 2, id = 0, guid = "Creature-0-1234-0-5678-69-0000123ABC"},
      "NpcID=69"},
    {"resolves NpcID from a vehicle guid", {type = 2, id = 0, guid = "Vehicle-0-1234-0-5678-12345-0000ABCDEF"},
      "NpcID=12345"},
    {"resolves NpcID from a player guid, falling back to data.id", {type = 2, id = 0, guid = "Player-1234-0000ABCD"},
      "NpcID=0"},
    {"a non-creature guid falls back to the tooltip's own id", {type = 2, id = 42, guid = "BattlePet-0-0000047DAB65"},
      "NpcID=42"},
    {"adds nothing for a type carrying no id", {type = 15, id = 100}, ""},
    {"adds nothing for nil data", nil, ""},
    {"adds nothing for data without a type", {id = 123}, ""},
    {"adds nothing for a nil id", {type = 1, id = nil}, ""},
    {"adds nothing for an empty string id", {type = 1, id = ""}, ""},
    {"adds nothing for a boolean id", {type = 1, id = true}, ""},
    {"adds nothing for a secret id", spell, "", state = {secretValue = 12345}},
    {"the master toggle suppresses everything", spell, "", config = {enabled = false}},
    {"a disabled kind is suppressed while others still work", function()
      show(spell)
      show({type = 23, id = 55001})
    end, "QuestID=55001", config = {spellEnabled = false}},
    {"does not add the same kind twice", function()
      show(quest)
      show(quest)
    end, "QuestID=100"},
    {"a secret line is left alone rather than read", function()
      show(quest)
      mockState.secretValue = "QuestID"
      show(quest)
    end, "QuestID=100 QuestID=100"},
    {"another addon's longer label is not mistaken for ours", function()
      env.GameTooltip:AddDoubleLine("SpellID: 999", "")
      show(spell)
    end, 'SpellID: 999="" SpellID=12345'},
  })
end)

describe("ids tooltip data does not carry", function()
  local pet = {petSpeciesId = 42, petNpcId = 777}
  local function setCompanionPet() hooks.SetCompanionPet(nil, "petguid") end
  cases({
    {"SetTalent adds TalentID", function() hooks.SetTalent(env.GameTooltip, 55) end, "TalentID=55"},
    {"SetPvpTalent adds TalentID", function() hooks.SetPvpTalent(env.GameTooltip, 66) end, "TalentID=66"},
    {"an artifact power adds its id", function() hooks.SetArtifactPowerByID(env.GameTooltip, 1739) end,
      "ArtifactPowerID=1739"},
    {"SetTooltipInternal adds trait ids", function() hooks.SetTooltipInternal({entryID = 11, definitionID = 22}) end,
      "TraitEntryID=11 TraitDefinitionID=22", config = {traitentryEnabled = true, traitdefEnabled = true}},
    {"SetCompanionPet adds species and NPC id", setCompanionPet, "SpeciesID=42 NpcID=777", state = pet},
    {"a companion pet's species and creature ids land on their own lines", function()
      show({type = 9, id = 42})
      setCompanionPet()
    end, "SpeciesID=42 NpcID=888", state = {petSpeciesId = 42, petNpcId = 888}},
    {"an id already shown is not repeated", function()
      show({type = 2, id = 777, guid = "Creature-0-1-0-1-777-0"})
      setCompanionPet()
    end, "NpcID=777 SpeciesID=42", state = pet},
    {"the wardrobe appearance tooltip dedups ids and unwraps single-element lists", function()
      hooks.SetAppearanceTooltip(nil, {sources = {
        {visualID = 1, sourceID = 7, itemID = 9},
        {visualID = 1, sourceID = 8, itemID = 9},
      }})
    end, 'VisualID=1 SourceIDs="7,8" ItemID=9'},
  })
end)

describe("pet battles", function()
  local description = env.PetBattlePrimaryAbilityTooltip.Description
  local function hoverAbility()
    hooks.PetBattleAbilityButton_OnEnter({GetEffectiveAlpha = function() return 1 end, GetID = function() return 1 end})
  end
  cases({
    {"ability button appends the id to the description font string", hoverAbility,
      "base\r\rAbilityID|cffffffff 555|r", state = {petAbilityId = 555}},
    {"an empty description does not error", function()
      description._text = nil
      hoverAbility()
    end, "\r\rAbilityID|cffffffff 111|r", state = {petAbilityId = 111}},
    {"aura frame appends the id to the description font string", function()
      hooks.PetBattleAura_OnEnter({GetParent = function() return {} end})
    end, "base\r\rAbilityID|cffffffff 666|r", state = {petAuraId = 666}},
    {"the pet battle writer honours the master toggle", hoverAbility, "base", state = {petAbilityId = 555},
      config = {enabled = false}},
  }, function() return description._text end)

  cases({
    {"unit ids are suppressed during a pet battle, with or without a guid", function()
      show({type = 2, id = 0, guid = "Creature-0-1234-0-5678-4242-0000123ABC"})
      show({type = 2, id = 4242})
    end, "", state = {inPetBattle = true}},
  })
end)

describe("regressions", function()
  test("a criterion after a progress bar resolves its own index on row or name hover, with mouse motion on", function()
    local flags, criteriaIds = {env.EVALUATION_TREE_FLAG_PROGRESS_BAR, 0, 0}, {111, 222, 333}
    env.GetAchievementNumCriteria = function() return 3 end
    env.GetAchievementCriteriaInfo = function(_, index)
      return "text", 0, false, 0, 0, nil, flags[index], nil, "", criteriaIds[index]
    end

    local button = env.CreateFrame("Button", "AchButton")
    button.id = 5150
    local objectives = env.CreateFrame("Frame", "Objectives")
    objectives._parent, objectives.GetCriteria = button, function() end
    local row = env.CreateFrame("Frame", "Criteria1")
    row._parent, row.Name = objectives, env.CreateFrame("FontString", "Criteria1Name")
    row.Name._parent = row
    objectives.criterias = {row}

    env.AchievementTemplateMixin = {GetObjectiveFrame = function() return objectives end}
    loadAddon(env, "Blizzard_AchievementUI")
    hooks.GetCriteria(objectives, 1)

    row.Name:_fire("OnEnter")
    assertEq(lines(env.GameTooltip), "AchievementID=5150 CriteriaID=222")

    env.GameTooltip:_reset()
    row:_fire("OnEnter")
    assertEq(lines(env.GameTooltip), "AchievementID=5150 CriteriaID=222")

    assertEq(row._motion, true)
  end)

  test("a disabled addon does not steal the achievement tooltip", function()
    loadAddon(env, "Blizzard_AchievementUI")
    env.idTipConfig.enabled = false
    env.AchievementFrameAchievementsContainer.buttons[1]:_fire("OnEnter")
    assertEq(env.GameTooltip:IsShown(), false)
  end)

  test("a map pin writes only to the tooltip it owns", function()
    local poi, vignette = {poiInfo = {areaPoiID = 7788}}, {vignetteInfo = {vignetteID = 4242}}

    hooks.TryShowTooltip(poi)
    hooks.OnMouseEnter(vignette)
    assertEq(lines(env.GameTooltip), "")
    assertEq(lines(env.WorldMapTooltip), "")

    env.GameTooltip:SetOwner(poi)
    env.GameTooltip:Show()
    hooks.TryShowTooltip(poi)
    env.WorldMapTooltip:SetOwner(vignette)
    env.WorldMapTooltip:Show()
    hooks.OnMouseEnter(vignette)
    assertEq(lines(env.GameTooltip), "AreaPoiID=7788")
    assertEq(lines(env.WorldMapTooltip), "VignetteID=4242")
  end)

  test("the global criteria hook is registered once, not once per button", function()
    loadAddon(env, "Blizzard_AchievementUI")
    assertEq(#env.AchievementFrameAchievementsContainer.buttons, 5)
    assertEq(env.hookCounts.AchievementButton_GetCriteria, 1)
  end)
end)

describe("options", function()
  test("every kind is registered once, as a checkbox bound to its config key, under four section headers", function()
    local byKey, kinds = {}, 0
    for _, setting in ipairs(env.settings) do
      assertEq(byKey[setting.key], nil)
      assertTrue(setting.checkbox)
      assertEq(setting.valueType, "boolean")
      assertEq(setting.table, env.idTipConfig)
      assertTrue(#setting.label > 0)
      byKey[setting.key] = setting
    end

    assertEq(byKey.enabled.default, true)
    for key, value in pairs(env.idTipConfig) do
      if key ~= "enabled" and string.match(key, "Enabled$") then
        kinds = kinds + 1
        assertEq(assert(byKey[key], "no setting for " .. key).default, value)
      end
    end
    assertTrue(kinds > 20)
    assertEq(#env.settings, kinds + 1)
    assertEq(table.concat(env.headers, ","), "Items,Spells,World,Collections")
  end)

  test("the slash command opens the category", function()
    assertTrue(env.SlashCmdList.IDTIP)
  end)
end)

describe("client profiles", function()
  test("loads with any single Blizzard namespace missing, keeping the slash command unless it is Settings", function()
    for _, global in ipairs({"C_Spell", "C_Item", "C_PetBattles", "C_PetJournal", "C_CurrencyInfo", "C_QuestLog",
      "Settings", "WHITE_FONT_COLOR", "GameTooltip", "ItemRefTooltip", "TalentDisplayMixin", "AreaPOIPinMixin",
      "VignettePinMixin", "GetActionInfo", "TooltipDataProcessor", "CollectionWardrobeUtil", "Enum"}) do
      local ok, profile = pcall(loadInto, function(profileEnv) profileEnv[global] = false end)
      if not ok then error("a missing " .. global .. " breaks load: " .. tostring(profile), 2) end
      assert(global == "Settings" or profile.SlashCmdList.IDTIP, "a missing " .. global .. " drops the slash command")
    end
  end)

  test("lines still render when WHITE_FONT_COLOR is gone", function()
    local profile = loadInto(function(profileEnv) profileEnv.WHITE_FONT_COLOR = false end)
    profile.tooltipCallback(profile.GameTooltip, {type = 0, id = 12345})
    assertEq(lines(profile.GameTooltip), "ItemID=12345")
  end)

  test("retail does not register the classic script hooks", function()
    assertEq(next(env.GameTooltip._hooks), nil)
  end)

  test("classic still shows ids when the post call never fires", function()
    local profile = loadInto(function(profileEnv)
      profileEnv.C_Item.GetItemLinkByGUID = nil
      profileEnv.TooltipDataProcessor.AddTooltipPostCall = function() end
      profileEnv.GameTooltip.ProcessInfo = nil
    end)
    local tooltip = profile.GameTooltip
    mockState.itemLink = plainLink
    tooltip:_fire("OnTooltipSetItem")
    assertEq(lines(tooltip), 'ItemID="12345"')
    mockState.spellId = 555
    tooltip:_fire("OnTooltipSetSpell")
    assertEq(lines(tooltip), 'ItemID="12345" SpellID=555')

    mockState.aura = {spellId = 777}
    for _, method in ipairs({"SetUnitAura", "SetUnitBuff", "SetUnitDebuff", "SetUnitAuraByAuraInstanceID",
      "SetUnitBuffByAuraInstanceID", "SetUnitDebuffByAuraInstanceID"}) do
      tooltip:_reset()
      profile.hooks[method](tooltip, "player", 1)
      assertEq(lines(tooltip), "SpellID=777")
    end

    tooltip:_reset()
    profile.hooks.SetCurrencyByID(tooltip, 3008)
    assertEq(lines(tooltip), "CurrencyID=3008")
  end)

  test("a removed member function costs its id, not the rest", function()
    local profile = loadInto(function(profileEnv)
      profileEnv.C_PetJournal.GetPetInfoBySpeciesID = nil
      profileEnv.C_PetBattles.GetAbilityInfo = nil
      profileEnv.Settings.OpenToCategory = nil
    end)

    mockState.petSpeciesId = 42
    profile.hooks.SetCompanionPet(nil, "petguid")
    assertEq(lines(profile.GameTooltip), "SpeciesID=42")

    assertEq(profile.hooks.PetBattleAbilityButton_OnEnter, nil)
    assertEq(profile.SlashCmdList.IDTIP, nil)
  end)

  test("classic item tooltips work without GetItemLinkByGUID", function()
    local profile = loadInto(function(profileEnv) profileEnv.C_Item.GetItemLinkByGUID = nil end)
    mockState.itemLink = plainLink
    profile.tooltipCallback(profile.GameTooltip, {type = 0, id = 12345, guid = "Item-0-0-0-0-12345"})
    assertEq(lines(profile.GameTooltip), 'ItemID="12345"')
  end)
end)

describe("harness isolation", function()
  test("a profile load does not rebind the retail env's hooks", function()
    env.idTipConfig.talentEnabled = false
    hooks.SetTalent(env.GameTooltip, 55)
    assertEq(lines(env.GameTooltip), "")

    env.idTipConfig.talentEnabled = true
    hooks.SetTalent(env.GameTooltip, 55)
    assertEq(lines(env.GameTooltip), "TalentID=55")
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
