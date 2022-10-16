local _, IDTip = ...

local Helpers = {}

function Helpers.GetQuestID()
	if QuestInfoFrame.questLog then
		return C_QuestLog.GetSelectedQuest()
	else
		return GetQuestID()
	end
end

function Helpers.GetGameVersion()
	local _, _, _, version = GetBuildInfo()
	return version
end

function Helpers.IsDragonflight()
	return Helpers.GetGameVersion() > 100000
end

function Helpers.IsPTR()
	return Helpers.GetGameVersion() == 100000
end

function Helpers.IsShadowlands()
	return Helpers.GetGameVersion() > 90000 and Helpers.GetGameVersion() < 100000
end

function Helpers.IsClassic()
	return Helpers.GetGameVersion() < 90000
end

IDTip.Helpers = Helpers
