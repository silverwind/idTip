-- Shared between at least two clients, minimal client if/else inside methods

local _, IDTip = ...

-- All kinds
local function onSetHyperlink(self, link)
	local kind, id = string.match(link, "^(%a+):(%d+)")
	IDTip:addLineByKind(self, id, kind)
end

hooksecurefunc(GameTooltip, "SetAction", function(self, slot)
	local kind, id = GetActionInfo(slot)
	IDTip:addLineByKind(self, id, kind)
end)

hooksecurefunc(ItemRefTooltip, "SetHyperlink", onSetHyperlink)
hooksecurefunc(GameTooltip, "SetHyperlink", onSetHyperlink)

-- Spells
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, ...)
	local id = select(10, UnitBuff(...))
	IDTip:addLine(self, id, IDTip.kinds.spell)
end)

hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, ...)
	local id = select(10, UnitDebuff(...))
	IDTip:addLine(self, id, IDTip.kinds.spell)
end)

hooksecurefunc(GameTooltip, "SetUnitAura", function(self, ...)
	local id = select(10, UnitAura(...))
	IDTip:addLine(self, id, IDTip.kinds.spell)
end)

hooksecurefunc(GameTooltip, "SetSpellByID", function(self, id)
	IDTip:addLineByKind(self, id, IDTip.kinds.spell)
end)

hooksecurefunc("SetItemRef", function(link, ...)
	local id = tonumber(link:match("spell:(%d+)"))
	IDTip:addLine(ItemRefTooltip, id, IDTip.kinds.spell)
end)

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
	if not IDTip.Helpers.IsClassic() then
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
		IDTip:addLine(self, id, IDTip.kinds.item)
		if itemSplit[2] ~= 0 then
			enchantid = itemSplit[2]
			IDTip:addLine(self, enchantid, IDTip.kinds.enchant)
		end
		if #bonuses ~= 0 then
			IDTip:addLine(self, bonuses, IDTip.kinds.bonus)
		end
		if #gems ~= 0 then
			IDTip:addLine(self, gems, IDTip.kinds.gem)
		end
	end
end

ItemRefTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip1:HookScript("OnTooltipSetItem", attachItemTooltip)
ShoppingTooltip2:HookScript("OnTooltipSetItem", attachItemTooltip)

IDTip:RegisterAddonLoad("Blizzard_Collections", function()
	PetJournalPetCardPetInfo:HookScript("OnEnter", function(self)
		if PetJournalPetCard.speciesID then
			local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(PetJournalPetCard.speciesID))
			IDTip:addLine(GameTooltip, PetJournalPetCard.speciesID, IDTip.kinds.species)
			IDTip:addLine(GameTooltip, npcId, IDTip.kinds.unit)
		end
	end)
end)

IDTip:RegisterAddonLoad("Blizzard_GarrisonUI", function()
	-- ability id
	hooksecurefunc("AddAutoCombatSpellToTooltip", function(self, info)
		if info and info.autoCombatSpellID then
			IDTip:addLine(self, info.autoCombatSpellID, IDTip.kinds.ability)
		end
	end)

	hooksecurefunc("CovenantMissionInfoTooltip_OnEnter", function(self)
		if self.info then
			IDTip:addLine(GameTooltip, self.info.missionID, IDTip.kinds.mission)
			-- GameTooltip:Show()
		end
	end)
end)

IDTip:RegisterAddonLoad("Blizzard_CovenantSanctum", function()
	hooksecurefunc(CovenantSanctumUpgradeTalentMixin, "RefreshTooltip", function(self)
		IDTip:addLine(GameTooltip, self.talentID, IDTip.kinds.cgarrisontalent)
		IDTip:addLine(GameTooltip, C_CovenantSanctumUI.GetCurrentTalentTreeID(), IDTip.kinds.ccovenantsanctumtree)
	end)

	hooksecurefunc(CovenantSanctumFrame.UpgradesTab.TravelUpgrade, "RefreshTooltip", function(self)
		IDTip:addLine(GameTooltip, self.treeID, IDTip.kinds.cgarrisontalenttree)
	end)

	hooksecurefunc(CovenantSanctumFrame.UpgradesTab.DiversionUpgrade, "RefreshTooltip", function(self)
		IDTip:addLine(GameTooltip, self.treeID, IDTip.kinds.cgarrisontalenttree)
	end)

	hooksecurefunc(CovenantSanctumFrame.UpgradesTab.AdventureUpgrade, "RefreshTooltip", function(self)
		IDTip:addLine(GameTooltip, self.treeID, IDTip.kinds.cgarrisontalenttree)
	end)

	hooksecurefunc(CovenantSanctumFrame.UpgradesTab.UniqueUpgrade, "RefreshTooltip", function(self)
		IDTip:addLine(GameTooltip, self.treeID, IDTip.kinds.cgarrisontalenttree)
	end)
end)

if not IDTip.Helpers.IsClassic() then
	if not IDTip.Helpers.IsPTR() then -- TODO: Remove this eventually
		hooksecurefunc(GameTooltip, "SetRecipeResultItem", function(self, id)
			IDTip:addLine(self, id, IDTip.kinds.spell)
		end)
	end

	hooksecurefunc(GameTooltip, "SetRecipeRankInfo", function(self, id)
		IDTip:addLine(self, id, IDTip.kinds.spell)
	end)

	-- Artifact Powers
	hooksecurefunc(GameTooltip, "SetArtifactPowerByID", function(self, powerID)
		local powerInfo = C_ArtifactUI.GetPowerInfo(powerID)
		IDTip:addLine(self, powerID, IDTip.kinds.artifactpower)
		IDTip:addLine(self, powerInfo.spellID, IDTip.kinds.spell)
	end)

	-- Talents
	hooksecurefunc(GameTooltip, "SetTalent", function(self, id)
		local spellID = select(6, GetTalentInfoByID(id))
		IDTip:addLine(self, id, IDTip.kinds.talent)
		IDTip:addLine(self, spellID, IDTip.kinds.spell)
	end)
	hooksecurefunc(GameTooltip, "SetPvpTalent", function(self, id)
		local spellID = select(6, GetPvpTalentInfoByID(id))
		IDTip:addLine(self, id, IDTip.kinds.talent)
		IDTip:addLine(self, spellID, IDTip.kinds.spell)
	end)

	-- Pet Journal team icon
	hooksecurefunc(GameTooltip, "SetCompanionPet", function(self, petID)
		local speciesID = select(1, C_PetJournal.GetPetInfoByPetID(petID))
		if speciesID then
			local npcId = select(4, C_PetJournal.GetPetInfoBySpeciesID(speciesID))
			IDTip:addLine(GameTooltip, speciesID, IDTip.kinds.species)
			IDTip:addLine(GameTooltip, npcId, IDTip.kinds.unit)
		end
	end)

	hooksecurefunc(GameTooltip, "SetToyByItemID", function(self, id)
		IDTip:addLine(self, id, IDTip.kinds.item)
	end)

	hooksecurefunc(GameTooltip, "SetRecipeReagentItem", function(self, id)
		IDTip:addLine(self, id, IDTip.kinds.item)
	end)

	-- Pet battle buttons
	hooksecurefunc("PetBattleAbilityButton_OnEnter", function(self)
		local petIndex = C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
		if self:GetEffectiveAlpha() > 0 then
			local id = select(1, C_PetBattles.GetAbilityInfo(LE_BATTLE_PET_ALLY, petIndex, self:GetID()))
			if id then
				local oldText = PetBattlePrimaryAbilityTooltip.Description:GetText(id)
				PetBattlePrimaryAbilityTooltip.Description:SetText(
					oldText .. "\r\r" .. IDTip.kinds.ability .. "|cffffffff " .. id .. "|r"
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
				oldText .. "\r\r" .. IDTip.kinds.ability .. "|cffffffff " .. id .. "|r"
			)
		end
	end)

	-- Currencies
	hooksecurefunc(GameTooltip, "SetCurrencyToken", function(self, index)
		local id = tonumber(string.match(C_CurrencyInfo.GetCurrencyListLink(index), "currency:(%d+)"))
		IDTip:addLine(self, id, IDTip.kinds.currency)
	end)

	hooksecurefunc(GameTooltip, "SetCurrencyByID", function(self, id)
		IDTip:addLine(self, id, IDTip.kinds.currency)
	end)

	-- Quests
	hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(self)
		local id = C_QuestLog.GetQuestIDForLogIndex(self.questLogIndex)
		IDTip:addLine(GameTooltip, id, IDTip.kinds.quest)
	end)

	hooksecurefunc("TaskPOI_OnEnter", function(self)
		if self and self.questID then
			IDTip:addLine(GameTooltip, self.questID, IDTip.kinds.quest)
		end
	end)

	-- AreaPois (on the world map)
	hooksecurefunc(AreaPOIPinMixin, "TryShowTooltip", function(self)
		if self and self.areaPoiID then
			IDTip:addLine(GameTooltip, self.areaPoiID, IDTip.kinds.areapoi)
		end
	end)

	-- Vignettes (on the world map)
	hooksecurefunc(VignettePinMixin, "OnMouseEnter", function(self)
		if self and self.vignetteInfo and self.vignetteInfo.vignetteID then
			IDTip:addLine(GameTooltip, self.vignetteInfo.vignetteID, IDTip.kinds.vignette)
		end
	end)

	local questFrameID = CreateFrame("Frame", nil, QuestFrame)
	questFrameID:SetWidth(1)
	questFrameID:SetHeight(1)
	questFrameID:SetAlpha(0.90)
	questFrameID:SetPoint("TOPLEFT", 100, -45)
	questFrameID.text = questFrameID:CreateFontString(nil, "ARTWORK")
	questFrameID.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
	questFrameID.text:SetPoint("CENTER", 0, 0)
	questFrameID:Hide()

	local questMapFrameID = CreateFrame("Frame", nil, QuestMapFrame)
	questMapFrameID:SetWidth(1)
	questMapFrameID:SetHeight(1)
	questMapFrameID:SetAlpha(0.90)
	questMapFrameID:SetPoint("TOPLEFT", 150, -22)
	questMapFrameID.text = questMapFrameID:CreateFontString(nil, "ARTWORK")
	questMapFrameID.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
	questMapFrameID.text:SetPoint("CENTER", 0, 0)
	questMapFrameID:Hide()

	hooksecurefunc("QuestMapFrame_ShowQuestDetails", function()
		questMapFrameID.text:SetText("QuestID: " .. IDTip.Helpers.GetQuestID())
		questMapFrameID:Show()
	end)

	QuestFrame:HookScript("OnShow", function()
		questFrameID.text:SetText("QuestID: " .. IDTip.Helpers.GetQuestID())
		questFrameID:Show()
	end)
end

if not IDTip.Helpers.IsDragonflight() then
	GameTooltip:HookScript("OnTooltipSetUnit", function(self)
		if not IDTip.Helpers.IsClassic() and C_PetBattles.IsInBattle() then
			return
		end
		local unit = select(2, self:GetUnit())
		if unit then
			local guid = UnitGUID(unit) or ""
			local id = tonumber(guid:match("-(%d+)-%x+$"), 10)
			if id and guid:match("%a+") ~= "Player" then
				IDTip:addLine(GameTooltip, id, IDTip.kinds.unit)
			end
		end
	end)

	GameTooltip:HookScript("OnTooltipSetItem", attachItemTooltip)

	IDTip:RegisterAddonLoad("Blizzard_Collections", function()
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
				IDTip:addLine(GameTooltip, visualIDs, IDTip.kinds.visual)
			end
			if #sourceIDs ~= 0 then
				IDTip:addLine(GameTooltip, sourceIDs, IDTip.kinds.source)
			end
			if #itemIDs ~= 0 then
				IDTip:addLine(GameTooltip, itemIDs, IDTip.kinds.item)
			end
		end)
	end)

	hooksecurefunc(GameTooltip, "SetCurrencyTokenByID", function(self, id)
		IDTip:addLine(self, id, IDTip.kinds.currency)
	end)
end

if IDTip.Helpers.IsDragonflight() then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, attachItemTooltip)
end
