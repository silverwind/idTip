-- Shared between classic (TBC/Wrath (Official Blizzard recreation clients)) and classic_era (Official recreation vanilla client)

local _, IDTip = ...

if IDTip.Helpers.IsClassic() then
	do
		IDTip:Log("Classic Loaded")

		local questFrameID = CreateFrame("Frame", nil, QuestFrame)
		questFrameID:SetWidth(1)
		questFrameID:SetHeight(1)
		questFrameID:SetAlpha(0.90)
		questFrameID:SetPoint("TOPLEFT", 100, -60)
		questFrameID.text = questFrameID:CreateFontString(nil, "ARTWORK")
		questFrameID.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
		questFrameID.text:SetPoint("CENTER", 0, 0)
		questFrameID:Hide()

		local questLogFrameID = CreateFrame("Frame", nil, QuestLogFrame)
		questLogFrameID:SetWidth(1)
		questLogFrameID:SetHeight(1)
		questLogFrameID:SetAlpha(0.90)
		questLogFrameID:SetPoint("TOPLEFT", 390, -55)
		questLogFrameID.text = questLogFrameID:CreateFontString(nil, "ARTWORK")
		questLogFrameID.text:SetFont("Fonts\\ARIALN.ttf", 13, "OUTLINE")
		questLogFrameID.text:SetPoint("CENTER", 0, 0)
		questLogFrameID:Hide()

		hooksecurefunc("QuestLog_SetSelection", function(selection)
			local questID = select(8, GetQuestLogTitle(selection))
			questLogFrameID.text:SetText("QuestID: " .. questID)
			questLogFrameID:Show()
		end)

		QuestFrame:HookScript("OnShow", function()
			questFrameID.text:SetText("QuestID: " .. IDTip.Helpers.GetQuestID())
			questFrameID:Show()
		end)

		IDTip:RegisterAddonLoad("Blizzard_AchievementUI", function()
			for i, button in ipairs(AchievementFrameAchievementsContainer.buttons) do
				button:HookScript("OnEnter", function()
					GameTooltip:SetOwner(button, "ANCHOR_NONE")
					GameTooltip:SetPoint("TOPLEFT", button, "TOPRIGHT", 0, 0)
					IDTip:addLine(GameTooltip, button.id, IDTip.kinds.achievement)
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
								IDTip:addLine(GameTooltip, button.id, IDTip.kinds.achievement)
								IDTip:addLine(GameTooltip, criteriaid, IDTip.kinds.criteria)
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
		end)

		GameTooltip:HookScript("OnTooltipSetSpell", function(self)
			local id = select(2, self:GetSpell())
			IDTip:addLine(self, id, IDTip.kinds.spell)
		end)

		hooksecurefunc("SpellButton_OnEnter", function(self)
			local slot = SpellBook_GetSpellBookSlot(self)
			local spellID = select(2, GetSpellBookItemInfo(slot, SpellBookFrame.bookType))
			IDTip:addLine(GameTooltip, spellID, IDTip.kinds.spell)
		end)
	end
end
