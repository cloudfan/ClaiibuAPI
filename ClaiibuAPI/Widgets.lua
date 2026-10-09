local addonName, ns = ...

-- Blizzard's settings controls, each with a fallback for a client that lacks
-- the template. Nothing built here is protected.
local SK = ns.SettingsKit
local C = SK.Compat
local W = {}
SK.Widgets = W

-- Layout after Blizzard's settings list: labels on the left, controls from
-- just left of the page's center.
W.LABEL_X = 37
W.CONTROL_X = -40
W.CONTROL_WIDTH = 250
W.ROW_HEIGHT = 32
W.SECTION_GAP = 12
W.MENU_MAX_HEIGHT = 320
W.TOP = -8

local WHITE = "Interface\\Buttons\\WHITE8X8"
local STEPPER_ATLAS = { "Minimal_SliderBar_Button_Left", "Minimal_SliderBar_Button_Right" }

-- Which Blizzard templates this client has, and which ones the widgets
-- ended up using (for the probe). Filled in by W.Detect, once.
local native = {}
W.used = {}

function W.Detect()
	if native.detected then
		return
	end
	native.detected = true
	native.inputScroll = C.HasTemplate("InputScrollFrameTemplate")
	native.dropdown = C.HasTemplate("WowStyle1DropdownTemplate")
	native.dropdownWithButtons = C.HasTemplate("SettingsDropdownWithButtonsTemplate")
	native.slider = C.HasTemplate("MinimalSliderWithSteppersTemplate") and MinimalSliderWithSteppersMixin ~= nil
	native.checkbox = C.HasTemplate("SettingsCheckboxTemplate")
	native.uiCheck = C.HasTemplate("UICheckButtonTemplate")
	native.scroll = C.HasTemplate("ScrollFrameTemplate")
	native.panelScroll = C.HasTemplate("UIPanelScrollFrameTemplate")
end

local function Tooltip()
	return SettingsTooltip or GameTooltip
end

-- Shows label and text over owner, like Blizzard's settings rows.
function W.AttachTooltip(owner, title, text)
	if not text then
		return
	end
	owner:HookScript("OnEnter", function()
		local tip = Tooltip()
		tip:SetOwner(owner, "ANCHOR_RIGHT")
		tip:SetText(title, 1, 1, 1)
		tip:AddLine(text, nil, nil, nil, true)
		tip:Show()
	end)
	owner:HookScript("OnLeave", function()
		Tooltip():Hide()
	end)
end

function W.Divider(parent)
	local divider = parent:CreateTexture(nil, "ARTWORK")
	if C.AtlasExists("Options_HorizontalDivider") then
		divider:SetAtlas("Options_HorizontalDivider", true)
	else
		divider:SetColorTexture(1, 1, 1, 0.15)
		divider:SetHeight(1)
	end
	return divider
end

-- Scroll area --------------------------------------------------------------------

-- Returns the scroll frame and its child. The child is as wide as the frame;
-- set its height after filling it.
function W.ScrollArea(parent)
	local template = (native.scroll and "ScrollFrameTemplate") or (native.panelScroll and "UIPanelScrollFrameTemplate") or nil
	local scroll = CreateFrame("ScrollFrame", nil, parent, template)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	scroll:SetScript("OnSizeChanged", function(_, width)
		child:SetWidth(width)
	end)
	if not template then
		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local range = self:GetVerticalScrollRange()
			local value = math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40))
			self:SetVerticalScroll(value)
		end)
	end
	return scroll, child
end

-- Page -----------------------------------------------------------------------------
-- A page lays controls out top to bottom in a parent frame. Every control
-- has a Refresh that reads its value again.

local Page = {}
Page.__index = Page
W.Page = Page

function W.NewPage(parent)
	return setmetatable({ frame = parent, y = W.TOP, controls = {}, first = true }, Page)
end

function Page:Refresh()
	for i = 1, #self.controls do
		self.controls[i]()
	end
end

function Page:Height()
	return -self.y + 16
end

function Page:Header(text)
	if not self.first then
		self.y = self.y - W.SECTION_GAP
	end
	self.first = false
	local header = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	header:SetPoint("TOPLEFT", 7, self.y)
	header:SetText(text)
	self.y = self.y - 30
end

function Page:Text(text)
	self.first = false
	local note = self.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	note:SetPoint("TOPLEFT", W.LABEL_X, self.y)
	note:SetPoint("RIGHT", self.frame, "RIGHT", -W.LABEL_X, 0)
	note:SetJustifyH("LEFT")
	note:SetSpacing(2)
	note:SetText(text)
	self.y = self.y - note:GetStringHeight() - 10
end

-- A labelled row. Returns the y of its center line and a frame over the
-- whole row for the tooltip.
function Page:Row(label, tooltip)
	self.first = false
	local center = self.y - W.ROW_HEIGHT / 2
	local hover = CreateFrame("Frame", nil, self.frame)
	hover:SetPoint("TOPLEFT", 0, self.y)
	hover:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
	hover:SetHeight(W.ROW_HEIGHT)
	hover:SetFrameLevel(self.frame:GetFrameLevel()) -- under the row's control
	hover:EnableMouse(tooltip ~= nil)
	W.AttachTooltip(hover, label, tooltip)
	local text = self.frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	text:SetPoint("LEFT", self.frame, "TOPLEFT", W.LABEL_X, center)
	text:SetWidth(220)
	text:SetJustifyH("LEFT")
	text:SetText(label or "")
	self.y = self.y - W.ROW_HEIGHT
	return center, hover
end

function Page:Place(control, center, xOffset)
	control:SetPoint("LEFT", self.frame, "TOP", W.CONTROL_X + (xOffset or 0), center)
end

-- Checkbox -------------------------------------------------------------------------
-- spec: label, tooltip, get(), set(value)

local function CreateCheckbox(parent)
	if native.checkbox then
		local ok, check = pcall(CreateFrame, "CheckButton", nil, parent, "SettingsCheckboxTemplate")
		if ok and check then
			W.used.checkbox = "SettingsCheckboxTemplate"
			return check
		end
	end
	if native.uiCheck then
		W.used.checkbox = "UICheckButtonTemplate"
		local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		check:SetSize(26, 26)
		return check
	end
	W.used.checkbox = "plain"
	local check = CreateFrame("CheckButton", nil, parent)
	check:SetSize(22, 22)
	check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	return check
end

function Page:Checkbox(spec)
	local center, hover = self:Row(spec.label, spec.tooltip)
	local check = CreateCheckbox(self.frame)
	self:Place(check, center, -4)
	W.AttachTooltip(check, spec.label, spec.tooltip)
	-- HookScript keeps the template's own click sound and visuals.
	check:HookScript("OnClick", function(button)
		spec.set(button:GetChecked() and true or false)
	end)
	self.controls[#self.controls + 1] = function()
		check:SetChecked(spec.get() and true or false)
	end
	return check
end

-- Slider ---------------------------------------------------------------------------
-- spec: label, tooltip, min, max, step, format (string or function), get(), set(value)

local function Snap(value, spec)
	value = math.floor((value - spec.min) / spec.step + 0.5) * spec.step + spec.min
	return math.max(spec.min, math.min(spec.max, value))
end

local function FormatValue(spec, value)
	if type(spec.format) == "function" then
		return spec.format(value)
	end
	return format(spec.format or "%d", value)
end

local function NativeSlider(page, spec, center, onChange)
	local slider = CreateFrame("Frame", nil, page.frame, "MinimalSliderWithSteppersTemplate")
	slider:SetWidth(W.CONTROL_WIDTH)
	page:Place(slider, center)
	local steps = math.floor((spec.max - spec.min) / spec.step + 0.5)
	slider:Init(spec.get(), spec.min, spec.max, steps, {
		[MinimalSliderWithSteppersMixin.Label.Right] = function(value)
			return FormatValue(spec, Snap(value, spec))
		end,
	})
	local updating = false
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if not updating then
			onChange(Snap(value, spec))
		end
	end, slider)
	return slider, function(value)
		updating = true
		slider:SetValue(value)
		updating = false
	end
end

local function PlainSlider(page, spec, center, onChange)
	local slider = CreateFrame("Slider", nil, page.frame, "BackdropTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(W.CONTROL_WIDTH, 14)
	page:Place(slider, center)
	slider:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	slider:SetBackdropColor(0, 0, 0, 0.6)
	slider:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(1, 0.82, 0, 1)
	thumb:SetSize(8, 18)
	slider:SetThumbTexture(thumb)
	slider:SetMinMaxValues(spec.min, spec.max)
	slider:SetValueStep(spec.step)
	slider:SetObeyStepOnDrag(true)
	local label = slider:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("LEFT", slider, "RIGHT", 8, 0)
	local updating = false
	slider:SetScript("OnValueChanged", function(_, value)
		value = Snap(value, spec)
		label:SetText(FormatValue(spec, value))
		if not updating then
			onChange(value)
		end
	end)
	return slider, function(value)
		updating = true
		slider:SetValue(value)
		label:SetText(FormatValue(spec, value))
		updating = false
	end
end

function Page:Slider(spec)
	local center = self:Row(spec.label, spec.tooltip)
	local build = native.slider and NativeSlider or PlainSlider
	W.used.slider = native.slider and "MinimalSliderWithSteppersTemplate" or "plain"
	local slider, display = build(self, spec, center, spec.set)
	W.AttachTooltip(slider, spec.label, spec.tooltip)
	self.controls[#self.controls + 1] = function()
		display(spec.get())
	end
	return slider
end

-- Dropdown -------------------------------------------------------------------------
-- Blizzard's settings dropdown: a WowStyle1DropdownTemplate menu between a
-- left and a right stepper (SettingsDropdownWithButtonsTemplate). The menu is
-- one scrolling column. Options with a group are listed under a title per
-- group. The steppers walk the same list and stop at its ends, as
-- Blizzard's do.
--
-- spec: label, tooltip, options() -> { { key, label, group } ... }, get(),
-- set(key), canonical(key) (optional: the key shown as selected)

local function CreateDropdownWithButtons(parent)
	if native.dropdownWithButtons then
		local frame = CreateFrame("Frame", nil, parent, "SettingsDropdownWithButtonsTemplate")
		if frame.Dropdown and frame.DecrementButton and frame.IncrementButton then
			frame:SetSize(W.CONTROL_WIDTH, 26)
			W.used.dropdown = "SettingsDropdownWithButtonsTemplate"
			return frame, frame.Dropdown, frame.DecrementButton, frame.IncrementButton
		end
		frame:Hide()
	end
	-- The same layout from parts: Blizzard's dropdown and its stepper arrows.
	W.used.dropdown = "WowStyle1DropdownTemplate"
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(W.CONTROL_WIDTH, 26)
	local steppers = {}
	for i = 1, 2 do
		local button
		if C.AtlasExists(STEPPER_ATLAS[i]) then
			button = CreateFrame("Button", nil, frame)
			button:SetSize(11, 19)
			button:SetNormalAtlas(STEPPER_ATLAS[i])
			button:SetHighlightAtlas(STEPPER_ATLAS[i], "ADD")
		else
			button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
			button:SetSize(22, 22)
			button:SetText(i == 1 and "<" or ">")
		end
		steppers[i] = button
	end
	steppers[1]:SetPoint("LEFT")
	steppers[2]:SetPoint("RIGHT")
	local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
	dropdown:SetPoint("LEFT", steppers[1], "RIGHT", 5, 0)
	dropdown:SetPoint("RIGHT", steppers[2], "LEFT", -5, 0)
	return frame, dropdown, steppers[1], steppers[2]
end

local function Selected(spec)
	local value = spec.get()
	if spec.canonical then
		value = spec.canonical(value)
	end
	return value
end

local function CurrentIndex(spec, options)
	local value = Selected(spec)
	for i, option in ipairs(options) do
		if option.key == value then
			return i
		end
	end
	return 0
end

local function NativeDropdown(page, spec, center)
	local frame, dropdown, decrement, increment = CreateDropdownWithButtons(page.frame)
	page:Place(frame, center)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(spec.defaultText or "")
	end

	local function UpdateSteppers()
		local options = spec.options()
		local index = CurrentIndex(spec, options)
		decrement:SetEnabled(index > 1)
		increment:SetEnabled(index < #options)
	end
	local function IsSelected(key)
		return Selected(spec) == key
	end
	local function Select(key)
		spec.set(key)
		UpdateSteppers()
	end
	local function Step(delta)
		local options = spec.options()
		local index = CurrentIndex(spec, options) + delta
		if index >= 1 and index <= #options then
			Select(options[index].key)
			dropdown:GenerateMenu()
		end
	end

	dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(W.MENU_MAX_HEIGHT)
		local group
		for _, option in ipairs(spec.options()) do
			if option.group and option.group ~= group then
				if group then
					root:CreateDivider()
				end
				group = option.group
				root:CreateTitle(group)
			end
			root:CreateRadio(option.label, IsSelected, Select, option.key)
		end
	end)
	decrement:SetScript("OnClick", function()
		Step(-1)
	end)
	increment:SetScript("OnClick", function()
		Step(1)
	end)
	W.AttachTooltip(dropdown, spec.label, spec.tooltip)
	return frame, function()
		dropdown:GenerateMenu()
		UpdateSteppers()
	end
end

-- Only for a client without Blizzard's dropdown at all: "<  name  >".
local function PlainDropdown(page, spec, center)
	W.used.dropdown = "plain"
	local previous = CreateFrame("Button", nil, page.frame, "UIPanelButtonTemplate")
	previous:SetSize(26, 22)
	page:Place(previous, center)
	previous:SetText("<")
	local nextButton = CreateFrame("Button", nil, page.frame, "UIPanelButtonTemplate")
	nextButton:SetSize(26, 22)
	nextButton:SetPoint("LEFT", previous, "RIGHT", W.CONTROL_WIDTH - 52, 0)
	nextButton:SetText(">")
	local value = page.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	value:SetPoint("LEFT", previous, "RIGHT", 4, 0)
	value:SetPoint("RIGHT", nextButton, "LEFT", -4, 0)

	local function Refresh()
		local options = spec.options()
		local index = CurrentIndex(spec, options)
		local option = options[index]
		value:SetText(option and (option.group and option.group ~= "" and (option.group .. ": ") or "") .. option.label
			or (spec.defaultText or ""))
		previous:SetEnabled(index > 1)
		nextButton:SetEnabled(index < #options)
	end
	local function Step(delta)
		local options = spec.options()
		local index = CurrentIndex(spec, options) + delta
		if index >= 1 and index <= #options then
			spec.set(options[index].key)
			Refresh()
		end
	end
	previous:SetScript("OnClick", function()
		Step(-1)
	end)
	nextButton:SetScript("OnClick", function()
		Step(1)
	end)
	return previous, Refresh
end

function Page:Dropdown(spec)
	local center = self:Row(spec.label, spec.tooltip)
	local build = native.dropdown and NativeDropdown or PlainDropdown
	local frame, refresh = build(self, spec, center)
	self.controls[#self.controls + 1] = refresh
	return frame
end

-- Button ---------------------------------------------------------------------------
-- spec: label (row label, may be empty), text, tooltip, width, onClick()

function Page:Button(spec)
	local center = self:Row(spec.label, spec.tooltip)
	local button = CreateFrame("Button", nil, self.frame, "UIPanelButtonTemplate")
	button:SetSize(spec.width or 200, 24)
	self:Place(button, center)
	button:SetText(spec.text)
	button:SetScript("OnClick", function()
		spec.onClick()
	end)
	W.AttachTooltip(button, spec.text, spec.tooltip)
	if spec.enabled then
		self.controls[#self.controls + 1] = function()
			button:SetEnabled(spec.enabled() and true or false)
		end
	end
	return button
end

-- Text box ---------------------------------------------------------------------------
-- A multi-line box across the page. Blizzard's InputScrollFrameTemplate, or
-- the same thing from parts.
-- spec: height, get() -> text (shown on refresh), tooltip, label

local function NativeTextBox(parent, height)
	local frame = CreateFrame("ScrollFrame", nil, parent, "InputScrollFrameTemplate")
	frame:SetHeight(height)
	local edit = frame.EditBox
	if not edit then
		error("InputScrollFrameTemplate has no EditBox", 0)
	end
	if frame.CharCount then
		frame.CharCount:Hide()
	end
	frame:SetScript("OnSizeChanged", function(_, width)
		edit:SetWidth(width - 18)
	end)
	return frame, edit
end

local function PlainTextBox(parent, height)
	local border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	border:SetHeight(height)
	border:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 } })
	border:SetBackdropColor(0, 0, 0, 0.6)
	border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
	local scroll, child = W.ScrollArea(border)
	scroll:SetPoint("TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", -26, 6)
	local edit = CreateFrame("EditBox", nil, child)
	edit:SetMultiLine(true)
	edit:SetFontObject("ChatFontNormal")
	edit:SetAutoFocus(false)
	edit:SetPoint("TOPLEFT")
	edit:SetPoint("RIGHT", child, "RIGHT")
	edit:SetHeight(height)
	child:SetHeight(height)
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	border:EnableMouse(true)
	border:SetScript("OnMouseDown", function()
		edit:SetFocus()
	end)
	return border, edit
end

function Page:TextBox(spec)
	self.first = false
	local height = spec.height or 90
	local frame, edit
	if native.inputScroll then
		local ok, f, e = pcall(NativeTextBox, self.frame, height)
		if ok then
			frame, edit = f, e
			W.used.textBox = "InputScrollFrameTemplate"
		end
	end
	if not frame then
		frame, edit = PlainTextBox(self.frame, height)
		W.used.textBox = "plain"
	end
	frame:SetPoint("TOPLEFT", W.LABEL_X, self.y - 4)
	frame:SetPoint("RIGHT", self.frame, "RIGHT", -W.LABEL_X, 0)
	edit:SetMaxLetters(0)
	edit:SetAutoFocus(false)
	-- Selecting everything on focus makes Ctrl+C / Ctrl+V a single step.
	edit:HookScript("OnEditFocusGained", function(box)
		box:HighlightText()
	end)
	W.AttachTooltip(edit, spec.label or "", spec.tooltip)
	self.y = self.y - height - 12
	if spec.get then
		self.controls[#self.controls + 1] = function()
			if not edit:HasFocus() then
				edit:SetText(spec.get() or "")
				edit:SetCursorPosition(0)
			end
		end
	end
	return edit
end

-- Page title, as on Blizzard's canvas pages: the name and a divider.
-- Returns the y below the divider.
function W.PageTitle(parent, text)
	local title = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 7, -22)
	title:SetText(text)
	local divider = W.Divider(parent)
	divider:SetPoint("TOPLEFT", 0, -50)
	divider:SetPoint("TOPRIGHT", 0, -50)
	return -56
end
