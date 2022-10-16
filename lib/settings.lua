local _, IDTip = ...

IDTip:RegisterAddonLoad("idTip", function()
	local DEFAULTS = {}
	for k, v in pairs(IDTip.kinds) do
		DEFAULTS[k] = true
	end

	IDTIP_CONFIG = IDTIP_CONFIG ~= nil and IDTIP_CONFIG or DEFAULTS

	local idTipFrame = CreateFrame("Frame", nil, nil, "BackdropTemplate")
	idTipFrame:ClearAllPoints()

	local Backdrop = {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		tileSize = 32,
		edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border",
		tile = 1,
		edgeSize = 7,
		insets = {
			top = 2,
			right = 2,
			left = 3,
			bottom = 3,
		},
	}

	idTipFrame:SetScale(0.8)
	idTipFrame:SetBackdrop(Backdrop)
	idTipFrame:SetHeight(500)
	idTipFrame:SetWidth(210)
	idTipFrame:SetFrameStrata("HIGH")
	idTipFrame:SetMovable(true)
	idTipFrame:SetPoint("CENTER")

	local scrollFrame = CreateFrame("ScrollFrame", nil, idTipFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 0, -20)
	scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

	local scrollChild = CreateFrame("Frame")
	scrollFrame:SetScrollChild(scrollChild)
	scrollChild:SetWidth(idTipFrame:GetWidth() - 18)
	scrollChild:SetHeight(1)

	local TitleBar = CreateFrame("Frame", nil, idTipFrame, "BackdropTemplate")
	TitleBar:SetPoint("TOPLEFT", 1, -1)
	TitleBar:SetPoint("TOPRIGHT", -2, -1)
	TitleBar:SetHeight(16)

	Backdrop.edgeSize = 2
	Backdrop.insets.bottom = 1
	local backdropInfo = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileEdge = true,
		tileSize = 8,
		edgeSize = 8,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	}

	TitleBar:SetBackdrop(backdropInfo)

	TitleBar:SetScript("OnMouseUp", function()
		idTipFrame:StopMovingOrSizing()

		local Point, RelativeTo, RelativePoint, X, Y = idTipFrame:GetPoint()
	end)
	TitleBar:SetScript("OnMouseDown", function()
		idTipFrame:StartMoving()
	end)

	local TitleBarText = TitleBar:CreateFontString()
	TitleBarText:SetAllPoints(TitleBar)
	TitleBarText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	TitleBarText:SetText("idTip")
	TitleBarText:SetJustifyH("CENTER")

	local CloseButton = CreateFrame("Button", nil, TitleBar, "UIPanelCloseButton")
	CloseButton:SetPoint("TOPRIGHT", 1, 1)
	CloseButton:SetHeight(18)
	CloseButton:SetWidth(18)
	CloseButton:SetScript("OnClick", function()
		idTipFrame:Hide()
	end)

	local checks = 0

	local function Checkbox(option)
		local myCheckButton = CreateFrame("CheckButton", nil, scrollChild, "ChatConfigCheckButtonTemplate")
		myCheckButton:SetPoint("TOPLEFT", 10, checks * -20)
		myCheckButton.Text:SetText(IDTip.kinds[option])
		myCheckButton.tooltip = "Enable showing " .. IDTip.kinds[option]
		myCheckButton:SetChecked(IDTIP_CONFIG[option])
		myCheckButton:SetScript("OnClick", function(self)
			IDTIP_CONFIG[option] = self:GetChecked()
		end)
		checks = checks + 1
		return myCheckButton
	end

	local Config = {}

	for k, v in pairs(IDTip.kinds) do
		Checkbox(k)
	end

	idTipFrame:Hide()

	SLASH_IDTIP1 = "/idtip"
	SlashCmdList["IDTIP"] = function(msg)
		idTipFrame:Show()
	end
end)
