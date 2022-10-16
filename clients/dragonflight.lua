-- Dragonflight specific changes

local _, IDTip = ...

if IDTip.Helpers.IsDragonflight() or IDTip.Helpers.IsPTR() then
	do
		IDTip:Log("Dragonflight Loaded")

		if not IDTip.Helpers.IsPTR() then -- TODO: Remove this eventually
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(self, a)
				local id = select(2, self:GetSpell())
				IDTip:addLine(self, id, IDTip.kinds.spell)

				local outputItemInfo = C_TradeSkillUI.GetRecipeOutputItemData(id, nil)
				if outputItemInfo then
					IDTip:addGeneric(self, "== Recipe Output ==")
					IDTip:addLine(self, outputItemInfo.itemID, IDTip.kinds.item)
				end
			end)
		end

		hooksecurefunc(NameplateBuffButtonTemplateMixin, "OnEnter", function(self)
			IDTip:addLine(NamePlateTooltip, self.spellID, IDTip.kinds.spell)
			IDTip:addLine(GameTooltip, self.spellID, IDTip.kinds.spell)
		end)

		hooksecurefunc(GameTooltip, "SetUnitBuffByAuraInstanceID", function(self, unit, auraInstanceID)
			local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
			if aura then
				IDTip:addLine(GameTooltip, aura.spellId, IDTip.kinds.spell)
			end
		end)

		hooksecurefunc(GameTooltip, "SetUnitDebuffByAuraInstanceID", function(self, unit, auraInstanceID)
			local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
			if aura then
				IDTip:addLine(GameTooltip, aura.spellId, IDTip.kinds.spell)
			end
		end)

		hooksecurefunc(SpellButtonMixin, "OnEnter", function(self)
			local slot = SpellBook_GetSpellBookSlot(self)
			local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
			IDTip:addLine(GameTooltip, spellID, IDTip.kinds.spell)
		end)

		hooksecurefunc(TalentDisplayMixin, "SetTooltipInternal", function(self)
			if self then
				local spellID = self:GetSpellID()
				if spellID then
					local overrideSpellID = C_SpellBook.GetOverrideSpell(spellID)

					IDTip:addLine(GameTooltip, overrideSpellID, IDTip.kinds.spell)
					if self.GetBaseButton then
						local baseButton = self:GetBaseButton()
						if baseButton then
							IDTip:addLine(GameTooltip, baseButton:GetNodeID(), IDTip.kinds.ctrait)
						end
					end
					if self.GetNodeID then
						IDTip:addLine(GameTooltip, self:GetNodeID(), IDTip.kinds.ctrait)
					end
				end
			end
		end)

		if not IDTip.Helpers.IsPTR() then -- TODO: Remove this eventually
			hooksecurefunc(GameTooltip, "SetRecipeResultItemForOrder", function(self, id)
				IDTip:addLine(self, id, IDTip.kinds.spell)
			end)
		end

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
					IDTip:addLine(GameTooltip, id, IDTip.kinds.unit)
					-- IDTip:addLine(GameTooltip, guid, IDTip.kinds.guid)
				end
			end
		end
		if not IDTip.Helpers.IsPTR() then -- TODO: Remove this eventually
			TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, onTooltipSetUnitFunction)
		end

		IDTip:RegisterAddonLoad("Blizzard_Collections", function()
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

		hooksecurefunc(GameTooltip, "SetCurrencyByID", function(self, id)
			IDTip:addLine(self, id, IDTip.kinds.currency)
		end)
	end
end
