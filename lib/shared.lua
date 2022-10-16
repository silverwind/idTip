local IDTipLib = LibStub:NewLibrary("idTip", 1)

local _, IDTip = ...

IDTip.kinds = {
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

local function table_invert(t)
	local s = {}
	for k, v in pairs(t) do
		s[v] = k
	end
	return s
end

IDTip.kinds_inverse = table_invert(IDTip.kinds)

local ALL_IDS = {}

local function contains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

function IDTipLib:addGenericLine(tooltip, line)
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

function IDTipLib:addLine(tooltip, id, kind)
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

	table.insert(ALL_IDS, { kind = IDTip.kinds_inverse[kind], id = id })

	local left, right
	if type(id) == "table" then
		left = NORMAL_FONT_COLOR_CODE .. kind .. "s" .. FONT_COLOR_CODE_CLOSE
		right = HIGHLIGHT_FONT_COLOR_CODE .. table.concat(id, ", ") .. FONT_COLOR_CODE_CLOSE
	else
		left = NORMAL_FONT_COLOR_CODE .. kind .. FONT_COLOR_CODE_CLOSE
		right = HIGHLIGHT_FONT_COLOR_CODE .. id .. FONT_COLOR_CODE_CLOSE
	end

	tooltip:AddDoubleLine(left, right)

	if kind == IDTip.kinds.spell then
		iconId = select(3, GetSpellInfo(id))
		if iconId then
			self:addLine(tooltip, iconId, IDTip.kinds.icon)
		end
	elseif kind == IDTip.kinds.item then
		if type(id) == "table" then
			local iconIds = {}
			for k, v in pairs(id) do
				iconId = C_Item.GetItemIconByID(v)
				if iconId then
					table.insert(iconIds, iconId)
				end
				self:addLine(tooltip, iconIds, IDTip.kinds.icon)

				local spellname, spellId = GetItemSpell(id)
				if spellId then
					self:addGenericLine(tooltip, "=== Item Spell ===")
					self:addLine(tooltip, spellId, IDTip.kinds.spell)
				end
			end
		else
			iconId = C_Item.GetItemIconByID(id)
			if iconId then
				self:addLine(tooltip, iconId, IDTip.kinds.icon)

				local spellname, spellId = GetItemSpell(id)
				if spellId then
					self:addGenericLine(tooltip, "=== Item Spell ===")
					self:addLine(tooltip, spellId, IDTip.kinds.spell)
				end
			end
		end
	end

	tooltip:HookScript("OnHide", function()
		ALL_IDS = {}
	end)

	tooltip:Show()
end

function IDTipLib:GetAllIds()
	return ALL_IDS
end

function IDTipLib:addLineByKind(frame, id, kind)
	if not kind or not id then
		return
	end
	if kind == "spell" or kind == "enchant" or kind == "trade" then
		self:addLine(frame, id, IDTip.kinds.spell)
	elseif kind == "talent" then
		self:addLine(frame, id, IDTip.kinds.talent)
	elseif kind == "quest" then
		self:addLine(frame, id, IDTip.kinds.quest)
	elseif kind == "achievement" then
		self:addLine(frame, id, IDTip.kinds.achievement)
	elseif kind == "item" then
		self:addLine(frame, id, IDTip.kinds.item)
	elseif kind == "currency" then
		self:addLine(frame, id, IDTip.kinds.currency)
	elseif kind == "summonmount" then
		self:addLine(frame, id, IDTip.kinds.mount)
	elseif kind == "companion" then
		self:addLine(frame, id, IDTip.kinds.companion)
	elseif kind == "macro" then
		self:addLine(frame, id, IDTip.kinds.macro)
	elseif kind == "equipmentset" then
		self:addLine(frame, id, IDTip.kinds.equipmentset)
	elseif kind == "visual" then
		self:addLine(frame, id, IDTip.kinds.visual)
	end
end

local addon_watchers = {}

function IDTipLib:RegisterAddonLoad(addon, cb)
	table.insert(addon_watchers, { addon = addon, cb = cb })
end

-- Achievement Frame Tooltips
local f = CreateFrame("frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addon)
	for _, watcher in pairs(addon_watchers) do
		if watcher.addon == addon then
			watcher.cb()
		end
	end
end)

function IDTipLib:Log(...)
	print("|cffFF8000[IDTip]|r ", ...)
end

IDTipLib:Log("Library Loaded")

setmetatable(IDTip, { __index = setmetatable(IDTipLib, getmetatable(IDTip)) })
