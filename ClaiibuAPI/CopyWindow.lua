local addonName, ns = ...

-- A window that shows text ready to copy: diagnostics, probe output, error
-- reports. The text is selected when the window opens, so Ctrl+C copies it
-- at once. Edits are undone, so the text stays as it was shown. One window
-- is shared by every addon; each call replaces its title and text.
local SK = ns.SettingsKit
local C = SK.Compat
local W = SK.Widgets
local Copy = {}
SK.CopyWindow = Copy

local window

local function StripCodes(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("||", "|"))
end

-- Lines of any kind become one string, one line each.
local function ToText(content)
	if type(content) ~= "table" then
		return tostring(content)
	end
	local lines = {}
	for i = 1, #content do
		lines[i] = tostring(content[i])
	end
	return table.concat(lines, "\n")
end
Copy.ToText = ToText

local function Build()
	local frame
	if C.HasTemplate("BasicFrameTemplateWithInset") then
		frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
	else
		frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", tile = true, tileSize = 32,
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 } })
	end
	if not frame.CloseButton then
		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -2, -2)
	end
	frame:SetSize(560, 420)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", 0, -5)

	frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.hint:SetPoint("TOPLEFT", 16, -32)
	frame.hint:SetText("Press Ctrl+C to copy. Esc closes this window.")

	local box, edit = W.CreateTextBox(frame, 300)
	box:SetPoint("TOPLEFT", 14, -50)
	box:SetPoint("BOTTOMRIGHT", -14, 44)
	frame.edit = edit

	-- Read-only: typing puts the shown text back. HookScript keeps the
	-- template's own scroll handling.
	edit:HookScript("OnTextChanged", function(self, userInput)
		if userInput and frame.text then
			self:SetText(frame.text)
			self:HighlightText()
		end
	end)
	edit:HookScript("OnEscapePressed", function()
		frame:Hide()
	end)

	local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	selectAll:SetSize(120, 22)
	selectAll:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 14)
	selectAll:SetText("Select All")
	selectAll:SetScript("OnClick", function()
		edit:SetFocus()
		edit:HighlightText()
	end)

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(120, 22)
	close:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 14)
	close:SetText(CLOSE or "Close")
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame:SetScript("OnHide", function()
		edit:ClearFocus()
	end)
	return frame
end

-- Shows content (a string, or a list of lines) under title. Color and
-- texture codes are removed unless keepCodes is true.
function Copy.Show(title, content, keepCodes)
	window = window or Build()
	local text = ToText(content)
	if not keepCodes then
		text = StripCodes(text)
	end
	window.text = text
	window.title:SetText(title or "")
	window.edit:SetText(text)
	window.edit:SetCursorPosition(0)
	window:Show()
	window:Raise()
	window.edit:SetFocus()
	window.edit:HighlightText()
	return window
end

function Copy.Hide()
	if window then
		window:Hide()
	end
end
