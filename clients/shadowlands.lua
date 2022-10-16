local _, IDTip = ...

if IDTip.Helpers.IsShadowlands() then
	do
    IDTip:Log("Shadowlands Loaded")

		GameTooltip:HookScript("OnTooltipSetSpell", function(self)
			local id = select(2, self:GetSpell())
			IDTip:addLine(self, id, IDTip.kinds.spell)
		end)

		hooksecurefunc("SpellButton_OnEnter", function(self)
			local slot = SpellBook_GetSpellBookSlot(self)
			local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
			IDTip:addLine(GameTooltip, spellID, IDTip.kinds.spell)
		end)

		hooksecurefunc(GameTooltip, "SetRecipeRankInfo", function(self, id)
			IDTip:addLine(self, id, IDTip.kinds.spell)
		end)
	end
end
