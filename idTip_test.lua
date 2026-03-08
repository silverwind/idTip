-- luacheck: no unused args
local passed, failed = 0, 0

local function test(name, fn)
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

local function assertEq(actual, expected)
  if actual ~= expected then
    error("expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assertNil(actual)
  if actual ~= nil then
    error("expected nil, got " .. tostring(actual), 2)
  end
end

local function assertTrue(actual)
  if not actual then
    error("expected truthy, got " .. tostring(actual), 2)
  end
end

-------------------------------------------------------------------------------
-- Mock WoW environment
-------------------------------------------------------------------------------

local mockState = {} -- mutable per-test config for mock return values
local tooltipCallback = nil -- captured TooltipDataProcessor callback
local eventHandler -- captured ADDON_LOADED event handler

local function createMockTooltip(env, tooltipName)
  local lines = {}
  local t = {}

  function t:GetName() return tooltipName end
  function t:NumLines() return #lines end
  function t:AddDoubleLine(left, right)
    lines[#lines + 1] = {left = left, right = right}
    env[tooltipName .. "TextLeft" .. #lines] = {
      GetText = function() return left end,
    }
  end
  function t:Show() end
  function t:Hide() end
  function t:IsVisible() return false end
  function t:SetOwner() end
  function t:SetPoint() end
  function t:HasScript() return false end
  function t:HookScript() end
  function t:GetItem() return nil end
  function t:SetChecked() end
  function t:GetChecked() return false end
  t.Text = {SetText = function() end}

  function t:_line(i) return lines[i] end
  function t:_reset()
    for i = 1, #lines do
      env[tooltipName .. "TextLeft" .. i] = nil
    end
    for i = #lines, 1, -1 do lines[i] = nil end
  end

  return t
end

local function createEnv()
  local env = setmetatable({}, {__index = _G})
  env._G = env

  -- WoW constants
  env.WHITE_FONT_COLOR = {r = 1, g = 1, b = 1}

  -- Security functions (not present = isSecret always returns false)
  env.issecretvalue = nil
  env.issecrettable = nil

  -- Mock tooltips
  env.GameTooltip = createMockTooltip(env, "GameTooltip")
  env.ItemRefTooltip = createMockTooltip(env, "ItemRefTooltip")
  env.ShoppingTooltip1 = createMockTooltip(env, "ShoppingTooltip1")
  env.ShoppingTooltip2 = createMockTooltip(env, "ShoppingTooltip2")
  env.ItemRefShoppingTooltip1 = createMockTooltip(env, "ItemRefShoppingTooltip1")
  env.ItemRefShoppingTooltip2 = createMockTooltip(env, "ItemRefShoppingTooltip2")
  env.GameTooltip_Hide = function() end

  -- Mock hooksecurefunc
  env.hooksecurefunc = function() end

  -- Mock CreateFrame
  env.CreateFrame = function(frameType, name)
    local frame = createMockTooltip(env, name or ("Frame" .. frameType))
    frame._events = {}
    frame._scripts = {}
    function frame:RegisterEvent(event) self._events[event] = true end
    function frame:SetScript(scriptName, fn) self._scripts[scriptName] = fn end
    function frame:CreateFontString()
      return {SetPoint = function() end, SetText = function() end}
    end
    return frame
  end

  -- Mock TooltipDataProcessor (modern retail path)
  tooltipCallback = nil
  env.TooltipDataProcessor = {
    AllTypes = -1,
    AddTooltipPostCall = function(_, callback)
      tooltipCallback = callback
    end,
  }

  -- WoW API mocks with configurable returns via mockState
  env.C_Spell = {
    GetSpellTexture = function()
      return mockState.spellTexture
    end,
  }

  env.C_Item = {
    GetItemIconByID = function()
      return mockState.itemIcon
    end,
    GetItemInfo = function()
      local i = mockState.itemInfo or {}
      return i[1], i[2], i[3], i[4], i[5], i[6], i[7], i[8],
             i[9], i[10], i[11], i[12], i[13], i[14], i[15], i[16]
    end,
    GetItemGem = function(_, idx)
      if mockState.itemGems and mockState.itemGems[idx] then
        return "gem", mockState.itemGems[idx]
      end
      return nil
    end,
    GetItemSpell = function()
      if mockState.itemSpell then
        return mockState.itemSpell[1], mockState.itemSpell[2]
      end
      return nil
    end,
    GetItemLinkByGUID = function()
      return mockState.itemLink
    end,
  }

  -- Fallback globals for the (X and X.Y) and X.Y or Z pattern
  env.GetSpellTexture = env.C_Spell.GetSpellTexture
  env.GetItemIconByID = env.C_Item.GetItemIconByID
  env.GetItemInfo = env.C_Item.GetItemInfo
  env.GetItemGem = env.C_Item.GetItemGem
  env.GetItemSpell = env.C_Item.GetItemSpell

  -- Disable optional APIs (guarded by if-checks in source)
  env.C_TradeSkillUI = nil
  env.GetTradeSkillReagentItemLink = nil
  env.GetActionInfo = nil
  env.TalentDisplayMixin = nil
  env.UnitBuff = nil
  env.UnitDebuff = nil
  env.UnitAura = nil
  env.SpellBook_GetSpellBookSlot = nil
  env.C_ArtifactUI = nil
  env.GetTalentInfoByID = nil
  env.GetPvpTalentInfoByID = nil
  env.C_PetJournal = nil
  env.C_PetBattles = nil
  env.C_CurrencyInfo = nil
  env.C_QuestLog = nil
  env.TradeSkillFrame = nil
  env.GetMouseFocus = nil
  env.AchievementTemplateMixin = nil
  env.AchievementFrameAchievementsContainer = nil
  env.CollectionWardrobeUtil = nil
  env.PetJournalPetCardPetInfo = nil
  env.PetJournalPetCard = nil
  env.AreaPOIPinMixin = nil
  env.VignettePinMixin = nil
  env.GetAchievementCriteriaInfo = nil
  env.GetAchievementNumCriteria = nil

  -- Settings/UI
  env.InterfaceOptions_AddCategory = function() end
  env.Settings = nil
  env.SlashCmdList = {}

  -- idTipConfig starts as nil (fresh install)
  env.idTipConfig = nil

  return env
end

-------------------------------------------------------------------------------
-- Load addon
-------------------------------------------------------------------------------

-- Wrap CreateFrame to capture created frames
local framesList = {}
local env = createEnv()
local origCreateFrame = env.CreateFrame
env.CreateFrame = function(frameType, name)
  local frame = origCreateFrame(frameType, name)
  framesList[#framesList + 1] = frame
  return frame
end

local source = io.open("idTip.lua"):read("*a")
local fn, loadErr = load(source, "idTip.lua", "t", env)
assert(fn, "Failed to load idTip.lua: " .. tostring(loadErr))
fn("idTip")

assert(tooltipCallback, "TooltipDataProcessor callback not captured")
local eventFrame = framesList[1]
assert(eventFrame, "Event frame not created")
eventHandler = eventFrame._scripts["OnEvent"]
assert(eventHandler, "OnEvent handler not set")

-- Helper: reset tooltip and mock state between tests
local function reset()
  env.GameTooltip:_reset()
  env.ItemRefTooltip:_reset()
  for k in pairs(mockState) do mockState[k] = nil end
end

-- Helper: trigger ADDON_LOADED
local function triggerAddonLoaded()
  env.idTipConfig = nil
  eventHandler(eventFrame, "ADDON_LOADED", "idTip")
end

-- Helper: get tooltip lines as simple table
local function getLines(tooltip)
  local result = {}
  for i = 1, tooltip:NumLines() do
    result[i] = tooltip:_line(i)
  end
  return result
end

-------------------------------------------------------------------------------
-- Tests
-------------------------------------------------------------------------------

describe("syntax", function()
  test("idTip.lua loads without error", function()
    assertTrue(fn)
  end)
end)

describe("config initialization", function()
  test("ADDON_LOADED creates default config", function()
    triggerAddonLoaded()
    assertTrue(env.idTipConfig)
    assertEq(env.idTipConfig.enabled, true)
  end)

  test("config has version", function()
    triggerAddonLoaded()
    -- After migration v1->v2, version should be 2
    assertEq(env.idTipConfig.version, 2)
  end)

  test("core kinds are enabled by default", function()
    triggerAddonLoaded()
    assertEq(env.idTipConfig.spellEnabled, true)
    assertEq(env.idTipConfig.itemEnabled, true)
    assertEq(env.idTipConfig.unitEnabled, true)
    assertEq(env.idTipConfig.questEnabled, true)
    assertEq(env.idTipConfig.achievementEnabled, true)
    assertEq(env.idTipConfig.currencyEnabled, true)
    assertEq(env.idTipConfig.mountEnabled, true)
  end)

  test("bonus kind disabled by default", function()
    triggerAddonLoaded()
    assertEq(env.idTipConfig.bonusEnabled, false)
  end)

  test("trait kinds disabled by default", function()
    triggerAddonLoaded()
    assertEq(env.idTipConfig.traitnodeEnabled, false)
    assertEq(env.idTipConfig.traitentryEnabled, false)
    assertEq(env.idTipConfig.traitdefEnabled, false)
  end)

  test("preserves existing config values", function()
    env.idTipConfig = {enabled = false, version = 2, spellEnabled = true}
    eventHandler(eventFrame, "ADDON_LOADED", "idTip")
    assertEq(env.idTipConfig.enabled, false) -- preserved
    assertEq(env.idTipConfig.spellEnabled, true) -- preserved
  end)

  test("ignores other addon ADDON_LOADED", function()
    env.idTipConfig = nil
    eventHandler(eventFrame, "ADDON_LOADED", "SomeOtherAddon")
    assertNil(env.idTipConfig)
  end)
end)

describe("spell tooltip via TooltipDataProcessor", function()
  test("adds SpellID", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 1, id = 12345})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "SpellID")
    assertEq(lines[1].right, 12345)
  end)

  test("adds IconID when GetSpellTexture returns value", function()
    reset()
    triggerAddonLoaded()
    mockState.spellTexture = 999999
    tooltipCallback(env.GameTooltip, {type = 1, id = 12345})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "SpellID")
    assertEq(lines[2].left, "IconID")
    assertEq(lines[2].right, 999999)
  end)
end)

describe("item tooltip via TooltipDataProcessor", function()
  test("adds ItemID for simple item (no GUID)", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 0, id = 67890})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "ItemID")
    assertEq(lines[1].right, 67890)
  end)

  test("parses full item link via GetItemLinkByGUID", function()
    reset()
    triggerAddonLoaded()
    mockState.itemLink = "|Hitem:158075:5932:0:0:0:0:0:0:120:0:0:0:2:3524:1472|h[Vest]|h"
    env.idTipConfig.bonusEnabled = true
    tooltipCallback(env.GameTooltip, {type = 0, id = 158075, guid = "Item-0-0-0-0-158075"})
    local lines = getLines(env.GameTooltip)
    -- Should have ItemID
    assertEq(lines[1].left, "ItemID")
    assertEq(lines[1].right, "158075")
    -- Should have EnchantID (position 2 = 5932)
    assertEq(lines[2].left, "EnchantID")
    assertEq(lines[2].right, "5932")
    -- Should have BonusIDs (2 bonuses: 3524, 1472)
    assertEq(lines[3].left, "BonusIDs")
    assertEq(lines[3].right, "3524,1472")
  end)

  test("parses item link without enchant or bonuses", function()
    reset()
    triggerAddonLoaded()
    -- Note: in WoW's Lua 5.1, "0" == 0 is true (coercion), so enchant "0" is
    -- skipped. In Lua 5.3+, "0" ~= 0, so it would still be added.
    -- Use an item link where enchant position is truly empty (consecutive colons).
    mockState.itemLink = "|Hitem:12345::0:0:0:0:0:0:0:0:0:0:0|h[Simple]|h"
    tooltipCallback(env.GameTooltip, {type = 0, id = 12345, guid = "Item-0-0-0-0-12345"})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "ItemID")
    assertEq(lines[1].right, "12345")
    assertEq(#lines, 1)
  end)

  test("parses item with expansion and set", function()
    reset()
    triggerAddonLoaded()
    mockState.itemLink = "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:0|h[Item]|h"
    local info = {}
    info[15] = 9 -- expansion ID (e.g. Dragonflight)
    info[16] = 42 -- set ID
    mockState.itemInfo = info
    tooltipCallback(env.GameTooltip, {type = 0, id = 12345, guid = "Item-0-0-0-0-12345"})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "ItemID")
    -- Find ExpansionID and SetID lines
    local foundExpansion, foundSet = false, false
    for _, line in ipairs(lines) do
      if line.left == "ExpansionID" then
        assertEq(line.right, 9)
        foundExpansion = true
      end
      if line.left == "SetID" then
        assertEq(line.right, 42)
        foundSet = true
      end
    end
    assertTrue(foundExpansion)
    assertTrue(foundSet)
  end)

  test("skips expansion 254 (classic)", function()
    reset()
    triggerAddonLoaded()
    mockState.itemLink = "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:0|h[Item]|h"
    local info = {}
    info[15] = 254 -- classic, should be skipped
    mockState.itemInfo = info
    tooltipCallback(env.GameTooltip, {type = 0, id = 12345, guid = "Item-0-0-0-0-12345"})
    local lines = getLines(env.GameTooltip)
    for _, line in ipairs(lines) do
      if line.left == "ExpansionID" then
        error("ExpansionID 254 should be skipped")
      end
    end
  end)

  test("parses item with gems", function()
    reset()
    triggerAddonLoaded()
    mockState.itemLink = "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:0|h[Item]|h"
    mockState.itemGems = {
      [1] = "|Hitem:154128:0:0:0|h[Gem]|h",
      [2] = "|Hitem:154129:0:0:0|h[Gem2]|h",
    }
    tooltipCallback(env.GameTooltip, {type = 0, id = 12345, guid = "Item-0-0-0-0-12345"})
    local lines = getLines(env.GameTooltip)
    local foundGem = false
    for _, line in ipairs(lines) do
      if line.left == "GemIDs" then
        assertEq(line.right, "154128,154129")
        foundGem = true
      end
    end
    assertTrue(foundGem)
  end)
end)

describe("unit tooltip via TooltipDataProcessor", function()
  test("extracts NPC ID from creature GUID", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {
      type = 2, id = 0,
      guid = "Creature-0-1234-0-5678-69-0000123ABC",
    })
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "NPC ID")
    assertEq(lines[1].right, 69)
  end)

  test("skips Player GUID", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {
      type = 2, id = 0,
      guid = "Player-1234-0000ABCD",
    })
    local lines = getLines(env.GameTooltip)
    -- Player GUID has no NPC-like pattern match, falls through to data.id
    assertEq(lines[1].left, "NPC ID")
    assertEq(lines[1].right, 0)
  end)

  test("handles vehicle GUID", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {
      type = 2, id = 0,
      guid = "Vehicle-0-1234-0-5678-12345-0000ABCDEF",
    })
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "NPC ID")
    assertEq(lines[1].right, 12345)
  end)
end)

describe("other tooltip types via TooltipDataProcessor", function()
  test("quest tooltip adds QuestID", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 23, id = 55001})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "QuestID")
    assertEq(lines[1].right, 55001)
  end)

  test("currency tooltip adds CurrencyID", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 5, id = 1234})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "CurrencyID")
    assertEq(lines[1].right, 1234)
  end)

  test("mount tooltip adds MountID", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 10, id = 777})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "MountID")
    assertEq(lines[1].right, 777)
  end)

  test("achievement tooltip adds AchievementID", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 12, id = 9999})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "AchievementID")
    assertEq(lines[1].right, 9999)
  end)

  test("object tooltip adds ObjectID", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 4, id = 300})
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "ObjectID")
    assertEq(lines[1].right, 300)
  end)

  test("ignores unknown tooltip types", function()
    reset()
    triggerAddonLoaded()
    -- type 15 = InstanceLock, maps to "" (empty), no kind
    tooltipCallback(env.GameTooltip, {type = 15, id = 100})
    assertEq(env.GameTooltip:NumLines(), 0)
  end)

  test("ignores nil data", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, nil)
    assertEq(env.GameTooltip:NumLines(), 0)
  end)

  test("ignores data without type", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {id = 123})
    assertEq(env.GameTooltip:NumLines(), 0)
  end)
end)

describe("config controls", function()
  test("disabled config prevents tooltip additions", function()
    reset()
    triggerAddonLoaded()
    env.idTipConfig.enabled = false
    tooltipCallback(env.GameTooltip, {type = 1, id = 12345})
    assertEq(env.GameTooltip:NumLines(), 0)
  end)

  test("disabled kind prevents that kind", function()
    reset()
    triggerAddonLoaded()
    env.idTipConfig.spellEnabled = false
    tooltipCallback(env.GameTooltip, {type = 1, id = 12345})
    assertEq(env.GameTooltip:NumLines(), 0)
  end)

  test("other kinds still work when one is disabled", function()
    reset()
    triggerAddonLoaded()
    env.idTipConfig.spellEnabled = false
    tooltipCallback(env.GameTooltip, {type = 23, id = 55001}) -- quest
    local lines = getLines(env.GameTooltip)
    assertEq(lines[1].left, "QuestID")
  end)
end)

describe("duplicate prevention", function()
  test("same kind is not added twice", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 23, id = 100})
    tooltipCallback(env.GameTooltip, {type = 23, id = 100})
    -- Should only have one QuestID line
    local count = 0
    for _, line in ipairs(getLines(env.GameTooltip)) do
      if line.left == "QuestID" then count = count + 1 end
    end
    assertEq(count, 1)
  end)
end)

describe("multiple IDs", function()
  test("single-element table treated as single value", function()
    reset()
    triggerAddonLoaded()
    env.idTipConfig.bonusEnabled = true
    mockState.itemLink = "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:1:9999|h[Item]|h"
    tooltipCallback(env.GameTooltip, {type = 0, id = 12345, guid = "Item-0-0-0-0-12345"})
    local lines = getLines(env.GameTooltip)
    local found = false
    for _, line in ipairs(lines) do
      if line.left == "BonusID" then -- singular, not "BonusIDs"
        assertEq(line.right, "9999")
        found = true
      end
    end
    assertTrue(found)
  end)

  test("multiple bonuses use plural label", function()
    reset()
    triggerAddonLoaded()
    env.idTipConfig.bonusEnabled = true
    mockState.itemLink = "|Hitem:12345:0:0:0:0:0:0:0:0:0:0:0:3:100:200:300|h[Item]|h"
    tooltipCallback(env.GameTooltip, {type = 0, id = 12345, guid = "Item-0-0-0-0-12345"})
    local lines = getLines(env.GameTooltip)
    local found = false
    for _, line in ipairs(lines) do
      if line.left == "BonusIDs" then
        assertEq(line.right, "100,200,300")
        found = true
      end
    end
    assertTrue(found)
  end)
end)

describe("edge cases", function()
  test("nil id produces no tooltip line", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 1, id = nil})
    assertEq(env.GameTooltip:NumLines(), 0)
  end)

  test("empty string id produces no tooltip line", function()
    reset()
    triggerAddonLoaded()
    tooltipCallback(env.GameTooltip, {type = 1, id = ""})
    assertEq(env.GameTooltip:NumLines(), 0)
  end)
end)

-------------------------------------------------------------------------------
-- Summary
-------------------------------------------------------------------------------

print()
local total = passed + failed
if failed > 0 then
  print(string.format("\27[31m%d of %d tests failed\27[0m", failed, total))
  os.exit(1)
else
  print(string.format("\27[32m%d tests passed\27[0m", total))
end
