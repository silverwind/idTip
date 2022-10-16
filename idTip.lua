local hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID, GetGlyphSocketInfo, tonumber, strfind =
	hooksecurefunc, select, UnitBuff, UnitDebuff, UnitAura, UnitGUID, GetGlyphSocketInfo, tonumber, strfind

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
	ctrait = "TraitNodeID",
	cgarrisontalent = "GarrisonTalentID",
	ccovenantsanctumtree = "SanctumTalentTreeID",
	cgarrisontalenttree = "GarrisonTalentTreeID",
	mission = "MissionID",
	guid = "GUID",
}

local isClassicWow = select(4, GetBuildInfo()) < 90000
local isDragonFlight = select(4, GetBuildInfo()) > 100000

local function contains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

local function addGeneric(tooltip, line)
	local frame, text
	for i = 1, 15 do
		frame = _G[tooltip:GetName() .. "TextLeft" .. i]
		if frame then
			text = frame:GetText()
		end
		if text and string.find(text, line) then
			return
		end
	end

	local left = NORMAL_FONT_COLOR_CODE .. line .. FONT_COLOR_CODE_CLOSE

	tooltip:AddLine(left)
end

local function addLine(tooltip, id, kind)
	if not id or id == "" then
		return
	end
	if type(id) == "table" and #id == 1 then
		id = id[1]
	end

	-- Check if we already added to this tooltip. Happens on the talent frame
	local frame, text
	for i = 1, 15 do
		frame = _G[tooltip:GetName() .. "TextLeft" .. i]
		if frame then
			text = frame:GetText()
		end
		if text and string.find(text, kind) then
			return
		end
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
		if iconId then
			addLine(tooltip, iconId, kinds.icon)
		end
	elseif kind == kinds.item then
		if type(id) == "table" then
			local iconIds = {}
			for k, v in pairs(id) do
				iconId = C_Item.GetItemIconByID(v)
				if iconId then
					table.insert(iconIds, iconId)
				end
				addLine(tooltip, iconIds, kinds.icon)

				local spellname, spellId = GetItemSpell(id)
				if spellId then
					addGeneric(tooltip, "=== Item Spell ===")
					addLine(tooltip, spellId, kinds.spell)
				end
			end
		else
			iconId = C_Item.GetItemIconByID(id)
			if iconId then
				addLine(tooltip, iconId, kinds.icon)

				local spellname, spellId = GetItemSpell(id)
				if spellId then
					addGeneric(tooltip, "=== Item Spell ===")
					addLine(tooltip, spellId, kinds.spell)
				end
			end
		end
	end

	tooltip:Show()
end

local function addLineByKind(self, id, kind)
	if not kind or not id then
		return
	end
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

local function _GetQuestID()
	if QuestInfoFrame.questLog then
		return C_QuestLog.GetSelectedQuest()
	else
		return GetQuestID()
	end
end

local questFrameID = CreateFrame("Frame", nil, QuestFrame)
questFrameID:SetWidth(1)
questFrameID:SetHeight(1)
questFrameID:SetAlpha(0.90)
questFrameID:SetPoint("TOPLEFT", 100, isClassicWow and -60 or -45)
questFrameID.text = questFrameID:CreateFontString(nil, "ARTWORK")
questFrameID.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
questFrameID.text:SetPoint("CENTER", 0, 0)
questFrameID:Hide()

local questMapFrameID = CreateFrame("Frame", nil, isClassicWow and QuestLogFrame or QuestMapFrame)
questMapFrameID:SetWidth(1)
questMapFrameID:SetHeight(1)
questMapFrameID:SetAlpha(0.90)
questMapFrameID:SetPoint("TOPLEFT", 390, -55)
questMapFrameID.text = questMapFrameID:CreateFontString(nil, "ARTWORK")
questMapFrameID.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
questMapFrameID.text:SetPoint("CENTER", 0, 0)
questMapFrameID:Hide()

if not isClassicWow then
	hooksecurefunc("QuestMapFrame_ShowQuestDetails", function()
		questMapFrameID.text:SetText("QuestID: " .. _GetQuestID())
		questMapFrameID:Show()
	end)
else
	hooksecurefunc("QuestLog_SetSelection", function(selection)
		local questID = select(8, GetQuestLogTitle(selection))
		print("Selection", questID)
		questMapFrameID.text:SetText("QuestID: " .. questID)
		questMapFrameID:Show()
	end)
end

QuestFrame:HookScript("OnShow", function()
	questFrameID.text:SetText("QuestID: " .. _GetQuestID())
	questFrameID:Show()
	print("Show 2")
end)

-- All kinds
local function onSetHyperlink(self, link)
	local kind, id = string.match(link, "^(%a+):(%d+)")
	addLineByKind(self, id, kind)
end

hooksecurefunc(GameTooltip, "SetAction", function(self, slot)
	local kind, id = GetActionInfo(slot)
	addLineByKind(self, id, kind)
end)

hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)

-- Spells
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, ...)
	local id = select(10, UnitBuff(...))
	addLine(self, id, kinds.spell)
end)

hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, ...)
	local id = select(10, UnitDebuff(...))
	addLine(self, id, kinds.spell)
end)

hooksecurefunc(GameTooltip, "SetUnitAura", function(self, ...)
	local id = select(10, UnitAura(...))
	addLine(self, id, kinds.spell)
end)

hooksecurefunc(GameTooltip, "SetSpellByID", function(self, id)
	addLineByKind(self, id, kinds.spell)
end)

hooksecurefunc("SetItemRef", function(link, ...)
	local id = tonumber(link:match("spell:(%d+)"))
	addLine(ItemRefTooltip, id, kinds.spell)
end)

if isDragonFlight then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(self, a)
		local id = select(2, self:GetSpell())
		addLine(self, id, kinds.spell)

		local outputItemInfo = C_TradeSkillUI.GetRecipeOutputItemData(id, nil)
		if outputItemInfo then
			addGeneric(self, "== Recipe Output ==")
			addLine(self, outputItemInfo.itemID, kinds.item)
		end
	end)
else
	GameTooltip:HookScript("OnTooltipSetSpell", function(self)
		local id = select(2, self:GetSpell())
		addLine(self, id, kinds.spell)
	end)
end

if isDragonFlight then
	hooksecurefunc(NameplateBuffButtonTemplateMixin, "OnEnter", function(self)
		addLine(NamePlateTooltip, self.spellID, kinds.spell)
		addLine(GameTooltip, self.spellID, kinds.spell)
	end)

	hooksecurefunc(GameTooltip, "SetUnitBuffByAuraInstanceID", function(self, unit, auraInstanceID)
		local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
		if aura then
			addLine(GameTooltip, aura.spellId, kinds.spell)
		end
	end)

	hooksecurefunc(GameTooltip, "SetUnitDebuffByAuraInstanceID", function(self, unit, auraInstanceID)
		local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
		if aura then
			addLine(GameTooltip, aura.spellId, kinds.spell)
		end
	end)

	hooksecurefunc(SpellButtonMixin, "OnEnter", function(self)
		local slot = SpellBook_GetSpellBookSlot(self)
		local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
		addLine(GameTooltip, spellID, kinds.spell)
	end)

	hooksecurefunc(TalentDisplayMixin, "SetTooltipInternal", function(self)
		if self then
			local spellID = self:GetSpellID()
			if spellID then
				local overrideSpellID = C_SpellBook.GetOverrideSpell(spellID)

				addLine(GameTooltip, overrideSpellID, kinds.spell)
				if self.GetBaseButton then
					local baseButton = self:GetBaseButton()
					if baseButton then
						addLine(GameTooltip, baseButton:GetNodeID(), kinds.ctrait)
					end
				end
				if self.GetNodeID then
					addLine(GameTooltip, self:GetNodeID(), kinds.ctrait)
				end
			end
		end
	end)
else
	hooksecurefunc("SpellButton_OnEnter", function(self)
		local slot = SpellBook_GetSpellBookSlot(self)
		local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
		addLine(GameTooltip, spellID, kinds.spell)
	end)
end

if not isClassicWow then
	if isDragonFlight then
		hooksecurefunc(GameTooltip, "SetRecipeResultItem", function(self, id)
			addLine(self, id, kinds.spell)
		end)

		hooksecurefunc(GameTooltip, "SetRecipeResultItemForOrder", function(self, id)
			addLine(self, id, kinds.spell)
		end)
	else
		hooksecurefunc(GameTooltip, "SetRecipeResultItem", function(self, id)
			addLine(self, id, kinds.spell)
		end)
	end

	hooksecurefunc(GameTooltip, "SetRecipeRankInfo", function(self, id)
		addLine(self, id, kinds.spell)
	end)

	-- Artifact Powers
	hooksecurefunc(GameTooltip, "SetArtifactPowerByID", function(self, powerID)
		local powerInfo = C_ArtifactUI.GetPowerInfo(powerID)
		addLine(self, powerID, kinds.artifactpower)
		addLine(self, powerInfo.spellID, kinds.spell)
	end)

	-- Talents
	hooksecurefunc(GameTooltip, "SetTalent", function(self, id)
		local spellID = select(6, GetTalentInfoByID(id))
		addLine(self, id, kinds.talent)
		addLine(self, spellID, kinds.spell)
	end)
	hooksecurefunc(GameTooltip, "SetPvpTalent", function(self, id)
		local spellID = select(6, GetPvpTalentInfoByID(id))
		addLine(self, id, kinds.talent)
		addLine(self, spellID, kinds.spell)
	end)

	-- Pet Journal team icon
	hooksecurefunc(GameTooltip, "SetCompanionPet", function(self, petID)
		local speciesID = select(1, C_PetJournal.GetPetInfoByPetID(petID))
		if speciesID then
			local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(speciesID))
			addLine(GameTooltip, speciesID, kinds.species)
			addLine(GameTooltip, npcId, kinds.unit)
		end
	end)
end

if isDragonFlight then
	local function onTooltipSetUnitFunction(tooltip, tooltipData)
		if not isClassicWow then
			if C_PetBattles.IsInBattle() then
				return
			end
		end
		local unit = select(2, tooltip:GetUnit())
		if unit then
			local guid = UnitGUID(unit) or ""
			local id = tonumber(guid:match("-(%d+)-%x+$"), 10)
			if id and guid:match("%a+") ~= "Player" then
				addLine(GameTooltip, id, kinds.unit)
				-- addLine(GameTooltip, guid, kinds.guid)
			end
		end
	end
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onTooltipSetUnitFunction)
else
	-- NPCs
	GameTooltip:HookScript("OnTooltipSetUnit", function(self)
		if not isClassicWow then
			if C_PetBattles.IsInBattle() then
				return
			end
		end
		local unit = select(2, self:GetUnit())
		if unit then
			local guid = UnitGUID(unit) or ""
			local id = tonumber(guid:match("-(%d+)-%x+$"), 10)
			if id and guid:match("%a+") ~= "Player" then
				addLine(GameTooltip, id, kinds.unit)
			end
		end
	end)
end

-- Items

if not isClassicWow then
	hooksecurefunc(GameTooltip, "SetToyByItemID", function(self, id)
		addLine(self, id, kinds.item)
	end)

	hooksecurefunc(GameTooltip, "SetRecipeReagentItem", function(self, id)
		addLine(self, id, kinds.item)
	end)
end

local function attachItemTooltip(self)
	if
		self ~= GameTooltip
		and self ~= ItemRefTooltip
		and self ~= ItemRefShoppingTooltip1
		and self ~= ItemRefShoppingTooltip2
		and self ~= ShoppingTooltip1
		and self ~= ShoppingTooltip2
	then
		return
	end

	local link
	if self == ShoppingTooltip1 or self == ShoppingTooltip2 then
		if self.info and self.info.tooltipData and self.info.tooltipData.guid then
			local guid = self.info.tooltipData.guid
			link = C_Item.GetItemLinkByGUID(guid)
		end
	else
		link = select(2, self:GetItem())
	end

	if not link then
		return
	end

	local itemString = string.match(link, "item:([%-?%d:]+)")
	if not itemString then
		return
	end

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
	if not isClassicWow then
		for i = 1, 4 do
			local _, gemLink = GetItemGem(link, i)
			if gemLink then
				local gemDetail = string.match(gemLink, "item[%-?%d:]+")
				gems[#gems + 1] = string.match(gemDetail, "item:(%d+):")
			elseif flags == 256 then
				gems[#gems + 1] = "0"
			end
		end
	end
	local id = string.match(link, "item:(%d*)")
	if
		(id == "" or id == "0")
		and TradeSkillFrame ~= nil
		and TradeSkillFrame:IsVisible()
		and GetMouseFocus().reagentIndex
	then
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
		if #bonuses ~= 0 then
			addLine(self, bonuses, kinds.bonus)
		end
		if #gems ~= 0 then
			addLine(self, gems, kinds.gem)
		end
	end
end

if isDragonFlight then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, attachItemTooltip)
else
	GameTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
end
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
		if isDragonFlight then
			hooksecurefunc(AchievementTemplateMixin, "OnEnter", function(achievement)
				GameTooltip:SetOwner(achievement, "ANCHOR_NONE")
				GameTooltip:SetPoint("TOPLEFT", achievement, "TOPRIGHT", 0, 0)
				addLine(GameTooltip, achievement.id, kinds.achievement)
				GameTooltip:Show()
			end)

			hooksecurefunc(AchievementTemplateMixin, "OnLeave", function()
				GameTooltip:Hide()
			end)

			local hooked = {}
			local function HookCriteria(criteria)
				if not hooked[criteria] then
					criteria:HookScript("OnEnter", function(self)
						local button = self:GetParent() and self:GetParent():GetParent()
						if not button then
							return
						end
						GameTooltip:SetOwner(button:GetParent(), "ANCHOR_NONE")
						GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
						addLine(GameTooltip, self._aid, kinds.achievement)
						addLine(GameTooltip, self._cid, kinds.criteria)
						GameTooltip:Show()
					end)
					criteria:HookScript("OnLeave", function()
						GameTooltip:Hide()
					end)
				end
				hooked[criteria] = true
			end

			hooksecurefunc("AchievementObjectives_DisplayCriteria", function(objectivesFrame, achievementId)
				local textStrings = 0
				local progressBars = 0
				local metas = 0
				local criteria = 0
				for criteriaIndex = 1, GetAchievementNumCriteria(achievementId) do
					local _, criteriaType, _, _, _, _, flags, assetID, _, criteriaID =
						GetAchievementCriteriaInfo(achievementId, criteriaIndex)

					if criteriaType == CRITERIA_TYPE_ACHIEVEMENT and assetID then
						metas = metas + 1
						criteria = objectivesFrame:GetMeta(metas)
					elseif bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR then
						progressBars = progressBars + 1
						criteria = objectivesFrame:GetProgressBar(progressBars)
					else
						textStrings = textStrings + 1
						criteria = objectivesFrame:GetCriteria(textStrings)
					end

					criteria._aid = achievementId
					criteria._cid = criteriaID
					HookCriteria(criteria)
				end
			end)
		else
			for i, button in ipairs(AchievementFrameAchievementsContainer.buttons) do
				button:HookScript("OnEnter", function()
					GameTooltip:SetOwner(button, "ANCHOR_NONE")
					GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
					addLine(GameTooltip, button.id, kinds.achievement)
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
							if not button or not button.id then
								return
							end
							local criteriaid = select(10, GetAchievementCriteriaInfo(button.id, index))
							if criteriaid then
								GameTooltip:SetOwner(button:GetParent(), "ANCHOR_NONE")
								GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
								addLine(GameTooltip, button.id, kinds.achievement)
								addLine(GameTooltip, criteriaid, kinds.criteria)
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
	elseif what == "Blizzard_Collections" then
		if isDragonFlight then
			hooksecurefunc(CollectionWardrobeUtil, "SetAppearanceTooltip", function(self, sources)
				local visualIDs = {}
				local sourceIDs = {}
				local itemIDs = {}

				for i = 1, #sources do
					if sources[i].visualID and not contains(visualIDs, sources[i].visualID) then
						table.insert(visualIDs, sources[i].visualID)
					end
					if sources[i].sourceID and not contains(visualIDs, sources[i].sourceID) then
						table.insert(sourceIDs, sources[i].sourceID)
					end
					if sources[i].itemID and not contains(visualIDs, sources[i].itemID) then
						table.insert(itemIDs, sources[i].itemID)
					end
				end

				if #visualIDs ~= 0 then
					addLine(GameTooltip, visualIDs, kinds.visual)
				end
				if #sourceIDs ~= 0 then
					addLine(GameTooltip, sourceIDs, kinds.source)
				end
				if #itemIDs ~= 0 then
					addLine(GameTooltip, itemIDs, kinds.item)
				end
			end)
		else
			hooksecurefunc("WardrobeCollectionFrame_SetAppearanceTooltip", function(self, sources)
				local visualIDs = {}
				local sourceIDs = {}
				local itemIDs = {}

				for i = 1, #sources do
					if sources[i].visualID and not contains(visualIDs, sources[i].visualID) then
						table.insert(visualIDs, sources[i].visualID)
					end
					if sources[i].sourceID and not contains(visualIDs, sources[i].sourceID) then
						table.insert(sourceIDs, sources[i].sourceID)
					end
					if sources[i].itemID and not contains(visualIDs, sources[i].itemID) then
						table.insert(itemIDs, sources[i].itemID)
					end
				end

				if #visualIDs ~= 0 then
					addLine(GameTooltip, visualIDs, kinds.visual)
				end
				if #sourceIDs ~= 0 then
					addLine(GameTooltip, sourceIDs, kinds.source)
				end
				if #itemIDs ~= 0 then
					addLine(GameTooltip, itemIDs, kinds.item)
				end
			end)
		end

		-- Pet Journal selected pet info icon
		PetJournalPetCardPetInfo:HookScript("OnEnter", function(self)
			if PetJournalPetCard.speciesID then
				local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(PetJournalPetCard.speciesID))
				addLine(GameTooltip, PetJournalPetCard.speciesID, kinds.species)
				addLine(GameTooltip, npcId, kinds.unit)
			end
		end)
	elseif what == "Blizzard_GarrisonUI" then
		-- ability id
		hooksecurefunc("AddAutoCombatSpellToTooltip", function(self, info)
			if info and info.autoCombatSpellID then
				addLine(self, info.autoCombatSpellID, kinds.ability)
			end
		end)

		hooksecurefunc("CovenantMissionInfoTooltip_OnEnter", function(self)
			if self.info then
				addLine(GameTooltip, self.info.missionID, kinds.mission)
				-- GameTooltip:Show()
			end
		end)
	elseif what == "Blizzard_CovenantSanctum" then
		hooksecurefunc(CovenantSanctumUpgradeTalentMixin, "RefreshTooltip", function(self)
			addLine(GameTooltip, self.talentID, kinds.cgarrisontalent)
			addLine(GameTooltip, C_CovenantSanctumUI.GetCurrentTalentTreeID(), kinds.ccovenantsanctumtree)
		end)

		hooksecurefunc(CovenantSanctumFrame.UpgradesTab.TravelUpgrade, "RefreshTooltip", function(self)
			addLine(GameTooltip, self.treeID, kinds.cgarrisontalenttree)
		end)

		hooksecurefunc(CovenantSanctumFrame.UpgradesTab.DiversionUpgrade, "RefreshTooltip", function(self)
			addLine(GameTooltip, self.treeID, kinds.cgarrisontalenttree)
		end)

		hooksecurefunc(CovenantSanctumFrame.UpgradesTab.AdventureUpgrade, "RefreshTooltip", function(self)
			addLine(GameTooltip, self.treeID, kinds.cgarrisontalenttree)
		end)

		hooksecurefunc(CovenantSanctumFrame.UpgradesTab.UniqueUpgrade, "RefreshTooltip", function(self)
			addLine(GameTooltip, self.treeID, kinds.cgarrisontalenttree)
		end)
	elseif what == "Blizzard_TrainerUI" then
		hooksecurefunc(GameTooltip, "SetTrainerService", function(self, a)
			local serviceName, serviceType, texture, reqLevel = GetTrainerServiceInfo(a)
			local b = C_TooltipInfo.GetTrainerService(a)
			TooltipUtil.SurfaceArgs(b)
		end)
	end
end)

if not isClassicWow then
	-- Pet battle buttons
	hooksecurefunc("PetBattleAbilityButton_OnEnter", function(self)
		local petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
		if self:GetEffectiveAlpha() > 0 then
			local id = select(1, C_PetBattles.GetAbilityInfo(LE_BATTLE_PET_ALLY, petIndex, self:GetID()))
			if id then
				local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
				PetBattlePrimaryAbilityTooltip.Description:SetText(
					oldText .. "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r"
				)
			end
		end
	end)

	-- Pet battle auras
	hooksecurefunc("PetBattleAura_OnEnter", function(self)
		local parent = self:GetParent()
		local id = select(1, C_PetBattles.GetAuraInfo(parent.petOwner, parent.petIndex, self.auraIndex))
		if id then
			local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
			PetBattlePrimaryAbilityTooltip.Description:SetText(
				oldText .. "\r\r" .. kinds.ability .. "|cffffffff " .. id .. "|r"
			)
		end
	end)

	-- Currencies
	hooksecurefunc(GameTooltip, "SetCurrencyToken", function(self, index)
		local id = tonumber(string.match(C_CurrencyInfo.GetCurrencyListLink(index), "currency:(%d+)"))
		addLine(self, id, kinds.currency)
	end)

	hooksecurefunc(GameTooltip, "SetCurrencyByID", function(self, id)
		addLine(self, id, kinds.currency)
	end)

	if isDragonFlight then
		hooksecurefunc(GameTooltip, "SetCurrencyByID", function(self, id)
			addLine(self, id, kinds.currency)
		end)
	else
		hooksecurefunc(GameTooltip, "SetCurrencyTokenByID", function(self, id)
			addLine(self, id, kinds.currency)
		end)
	end

	-- Quests
	hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(self)
		local id = C_QuestLog.GetQuestIDForLogIndex(self.questLogIndex)
		addLine(GameTooltip, id, kinds.quest)
	end)

	hooksecurefunc("TaskPOI_OnEnter", function(self)
		if self and self.questID then
			addLine(GameTooltip, self.questID, kinds.quest)
		end
	end)

	-- AreaPois (on the world map)
	hooksecurefunc(AreaPOIPinMixin, "TryShowTooltip", function(self)
		if self and self.areaPoiID then
			addLine(GameTooltip, self.areaPoiID, kinds.areapoi)
		end
	end)

	-- Vignettes (on the world map)
	hooksecurefunc(VignettePinMixin, "OnMouseEnter", function(self)
		if self and self.vignetteInfo and self.vignetteInfo.vignetteID then
			addLine(GameTooltip, self.vignetteInfo.vignetteID, kinds.vignette)
		end
	end)
end
