local addonName, ns = ...

-- The settings window: one entry in Options -> AddOns with a row of tabs.
-- The first tab is the landing page, then the addon's own pages, then
-- Profiles.
--
--   local kit = ns.SettingsKit.New({ ... })   -- at file scope
--   local page = kit:AddPage("General")
--   page:Checkbox({ key = "locked", label = "Lock Frames" })
--
-- See README.md for every option.
local SK = ns.SettingsKit
local C = SK.Compat
local W = SK.Widgets
local Media = SK.Media
local Profiles = SK.Profiles
local Serializer = SK.Serializer

SK.FOOTER = "Created for use by a lazy sack of shit, Maiibu. (And Friends)"

local Kit = {}
Kit.__index = Kit

-- Page declarations ------------------------------------------------------------------
-- Pages are declared at file scope and built in ADDON_LOADED, once the saved
-- variables exist. Each call records a step.

local PageSpec = {}
PageSpec.__index = PageSpec

local function Add(page, method, spec)
	page.steps[#page.steps + 1] = { method = method, spec = spec }
	return page
end

function PageSpec:Header(text)
	return Add(self, "Header", text)
end

function PageSpec:Text(text)
	return Add(self, "Text", text)
end

-- spec: key, label, tooltip
function PageSpec:Checkbox(spec)
	return Add(self, "Checkbox", spec)
end

-- spec: key, label, tooltip, min, max, step, format
function PageSpec:Slider(spec)
	return Add(self, "Slider", spec)
end

-- spec: key, label, tooltip, options (list or function returning one)
function PageSpec:Dropdown(spec)
	return Add(self, "Dropdown", spec)
end

-- spec: key, label (defaults to the media type's name), tooltip,
-- mediaType ("font", "statusbar", "border", "background" or "sound")
function PageSpec:MediaDropdown(spec)
	return Add(self, "MediaDropdown", spec)
end

-- spec: label, text, tooltip, width, onClick(kit), enabled(kit)
function PageSpec:Button(spec)
	return Add(self, "Button", spec)
end

function Kit:AddPage(name)
	local page = setmetatable({ name = name, steps = {} }, PageSpec)
	self.pageSpecs[#self.pageSpecs + 1] = page
	return page
end

-- Settings ---------------------------------------------------------------------------

function Kit:Print(...)
	print("|cffe0b060" .. self.title .. ":|r", ...)
end

function Kit:Get(key)
	return self.settings[key]
end

local function Changed(kit, key, value)
	Profiles.Flush(kit)
	if kit.config.onChange then
		kit.config.onChange(key, value, kit)
	end
end

-- Sets a setting from code. Keys must exist in the defaults, and the value
-- must have the default's type.
function Kit:Set(key, value)
	if not self.ready then
		error(addonName .. ": settings are not loaded yet; use kit:OnReady", 2)
	end
	local default = self.defaults[key]
	if default == nil or type(value) ~= type(default) then
		error(addonName .. ": no setting " .. tostring(key) .. " of type " .. type(value), 2)
	end
	self.settings[key] = value
	Changed(self, key, value)
	self:Refresh()
end

-- The media entry a media setting points at (see Media.Get).
function Kit:GetMedia(mediaType, key)
	return Media.Get(mediaType, self.settings[key])
end

function Kit:PlaySound(key, channel)
	Media.PlaySound(self.settings[key], channel)
end

function Kit:GetActiveProfile()
	return self.charDB and Profiles.Active(self)
end

function Kit:ProfileChanged()
	if self.config.onProfileChanged then
		self.config.onProfileChanged(self)
	end
	-- After the menu or dialog that asked for it has closed.
	SK.Events.Defer("profileRefresh", function()
		self:Refresh()
	end)
end

function Kit:RequestSaveAs(text)
	local name = Profiles.CleanName(text)
	if not name then
		self:Print("A profile needs a name.")
		return
	end
	if self.db.profiles[name] and name ~= Profiles.Active(self) then
		Profiles.PromptOverwrite(self, name)
		return
	end
	Profiles.SaveAs(self, name)
	self:Print("Saved profile \"" .. name .. "\".")
end

function Kit:ResetProfile()
	Profiles.ResetActive(self)
end

function Kit:Refresh()
	for i = 1, #self.pages do
		self.pages[i]:Refresh()
	end
end

-- Binding a page step to the settings ------------------------------------------------

local function Bind(kit, spec)
	local bound = {}
	for field, value in pairs(spec) do
		bound[field] = value
	end
	local key = spec.key
	bound.get = bound.get or function()
		return kit.settings[key]
	end
	bound.set = bound.set or function(value)
		kit.settings[key] = value
		Changed(kit, key, value)
	end
	return bound
end

local function CheckKey(kit, spec, method)
	if spec.key ~= nil and kit.defaults[spec.key] == nil then
		error(addonName .. ": " .. method .. " \"" .. tostring(spec.label) .. "\" uses key \""
			.. tostring(spec.key) .. "\", which is not in the defaults", 0)
	end
end

local BUILD = {}

function BUILD.Header(kit, page, text)
	page:Header(text)
end

function BUILD.Text(kit, page, text)
	page:Text(text)
end

function BUILD.Checkbox(kit, page, spec)
	page:Checkbox(Bind(kit, spec))
end

function BUILD.Slider(kit, page, spec)
	page:Slider(Bind(kit, spec))
end

function BUILD.Dropdown(kit, page, spec)
	local bound = Bind(kit, spec)
	local options = spec.options
	bound.options = type(options) == "function" and options or function()
		return options
	end
	page:Dropdown(bound)
end

function BUILD.MediaDropdown(kit, page, spec)
	local kind = spec.mediaType
	if not Media.LABELS[kind] then
		error(addonName .. ": unknown mediaType " .. tostring(kind), 0)
	end
	local bound = Bind(kit, spec)
	bound.label = spec.label or Media.LABELS[kind]
	bound.options = function()
		return Media.Options(kind)
	end
	bound.canonical = function(key)
		return Media.Canonical(kind, key)
	end
	if kind == "sound" then
		local set = bound.set
		bound.set = function(key)
			set(key)
			Media.PlaySound(key)
		end
	end
	page:Dropdown(bound)
end

function BUILD.Button(kit, page, spec)
	local bound = {}
	for field, value in pairs(spec) do
		bound[field] = value
	end
	bound.onClick = function()
		spec.onClick(kit)
	end
	if spec.enabled then
		bound.enabled = function()
			return spec.enabled(kit)
		end
	end
	page:Button(bound)
end

-- Landing page -----------------------------------------------------------------------
-- Header: name | version. Body: description and features. Footer: the
-- standard credit line.

local function BuildLanding(kit, parent)
	local config = kit.config
	local title = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 7, -14)
	title:SetText(kit.title)

	local separator = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	separator:SetPoint("LEFT", title, "RIGHT", 10, 0)
	separator:SetTextColor(0.5, 0.5, 0.5)
	separator:SetText("||")

	local version = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	version:SetPoint("LEFT", separator, "RIGHT", 10, 0)
	version:SetText(kit.version and ("Version " .. kit.version) or "")

	local divider = W.Divider(parent)
	divider:SetPoint("TOPLEFT", 0, -44)
	divider:SetPoint("TOPRIGHT", 0, -44)

	local footerDivider = W.Divider(parent)
	footerDivider:SetPoint("BOTTOMLEFT", 0, 34)
	footerDivider:SetPoint("BOTTOMRIGHT", 0, 34)

	local footer = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	footer:SetPoint("BOTTOM", 0, 14)
	footer:SetText(config.footer or SK.FOOTER)

	local scroll, child = W.ScrollArea(parent)
	scroll:SetPoint("TOPLEFT", 0, -52)
	scroll:SetPoint("BOTTOMRIGHT", -24, 40)
	local page = W.NewPage(child)
	if config.description then
		page:Text(config.description)
	end
	if config.features and #config.features > 0 then
		page:Header("Features")
		local lines = {}
		for i, feature in ipairs(config.features) do
			lines[i] = "\226\128\162  " .. feature -- bullet
		end
		page:Text(table.concat(lines, "\n"))
	end
	child:SetHeight(page:Height())
	return page
end

-- Profiles tab -----------------------------------------------------------------------

local function BuildProfiles(kit, page)
	page:Header("Profiles")
	page:Text("A profile holds every setting of this addon. Each character remembers which profile it uses. "
		.. "\"" .. Profiles.DEFAULT .. "\" starts with the default settings. Changes are saved to the active profile as you make them.")
	page:Dropdown({
		label = "Active Profile",
		tooltip = "The profile this character uses.",
		options = function()
			local options = {}
			for _, name in ipairs(Profiles.List(kit)) do
				options[#options + 1] = { key = name, label = name }
			end
			return options
		end,
		get = function()
			return Profiles.Active(kit)
		end,
		set = function(name)
			Profiles.Switch(kit, name)
		end,
	})
	page:Button({
		label = "",
		text = "Save current settings...",
		tooltip = "Create a new profile from the current settings and switch to it.",
		onClick = function()
			Profiles.PromptSave(kit)
		end,
	})
	page:Button({
		label = "",
		text = "Delete current profile...",
		tooltip = "Delete the active profile. If no profile is left, \"" .. Profiles.DEFAULT
			.. "\" is created with the default settings.",
		onClick = function()
			Profiles.PromptDelete(kit)
		end,
	})
end

-- Window -----------------------------------------------------------------------------

local TAB_ROW_HEIGHT = 36

local function BuildCanvas(kit, canvas)
	local names = { kit.config.landingTab or "About" }
	for _, spec in ipairs(kit.pageSpecs) do
		names[#names + 1] = spec.name
	end
	names[#names + 1] = "Profiles"

	local bodies = {}
	local function Select(index)
		for i, body in ipairs(bodies) do
			body:SetShown(i == index)
		end
		kit.selectedTab = index
	end

	local tabs, selectTab = W.Tabs(canvas, names, Select)
	kit.selectTab = selectTab
	tabs:ClearAllPoints()
	tabs:SetPoint("TOPLEFT", canvas, "TOPLEFT", 8, -6)

	local function NewBody()
		local body = CreateFrame("Frame", nil, canvas)
		body:SetPoint("TOPLEFT", 0, -TAB_ROW_HEIGHT - 6)
		body:SetPoint("BOTTOMRIGHT", 0, 0)
		body:Hide()
		bodies[#bodies + 1] = body
		return body
	end

	local tabDivider = W.Divider(canvas)
	tabDivider:SetPoint("TOPLEFT", 0, -TAB_ROW_HEIGHT - 2)
	tabDivider:SetPoint("TOPRIGHT", 0, -TAB_ROW_HEIGHT - 2)

	kit.pages[#kit.pages + 1] = BuildLanding(kit, NewBody())

	local function ScrollingPage(body)
		local scroll, child = W.ScrollArea(body)
		scroll:SetPoint("TOPLEFT", 0, -4)
		scroll:SetPoint("BOTTOMRIGHT", -24, 4)
		return W.NewPage(child), child
	end

	for _, spec in ipairs(kit.pageSpecs) do
		local page, child = ScrollingPage(NewBody())
		for _, step in ipairs(spec.steps) do
			if type(step.spec) == "table" then
				CheckKey(kit, step.spec, step.method)
			end
			BUILD[step.method](kit, page, step.spec)
		end
		child:SetHeight(page:Height())
		kit.pages[#kit.pages + 1] = page
	end

	local profilePage, profileChild = ScrollingPage(NewBody())
	BuildProfiles(kit, profilePage)
	profileChild:SetHeight(profilePage:Height())
	kit.pages[#kit.pages + 1] = profilePage

	canvas:SetScript("OnShow", function()
		kit:Refresh()
	end)
	selectTab(1)
end

-- Hooks the Settings panel calls on a canvas frame. Defaults resets the
-- active profile.
local function AddPanelHooks(kit, canvas)
	canvas.OnRefresh = function()
		kit:Refresh()
	end
	canvas.OnDefault = function()
		kit:ResetProfile()
	end
	canvas.OnCommit = function() end
end

local function RegisterWithSettings(kit, canvas)
	local category = Settings.RegisterCanvasLayoutCategory(canvas, kit.title)
	Settings.RegisterAddOnCategory(category)
	kit.category = category
	kit.widgetsUsed.window = "Settings"
end

-- No Settings API: the same canvas in a window of its own.
local function BuildStandalone(kit, canvas)
	local name = "PSK_" .. addonName .. "_Options"
	local window = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	window:SetSize(720, 600)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", tile = true, tileSize = 32,
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 } })
	window:EnableMouse(true)
	window:SetMovable(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	window:Hide()
	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)
	tinsert(UISpecialFrames, name)
	canvas:SetParent(window)
	canvas:SetPoint("TOPLEFT", 16, -28)
	canvas:SetPoint("BOTTOMRIGHT", -16, 16)
	canvas:Show()
	kit.window = window
	kit.widgetsUsed.window = "standalone"
end

local function Init(kit)
	local config = kit.config
	if type(_G[config.savedVariable]) ~= "table" then
		_G[config.savedVariable] = {}
	end
	if type(_G[config.charSavedVariable]) ~= "table" then
		_G[config.charSavedVariable] = {}
	end
	kit.db = _G[config.savedVariable]
	kit.charDB = _G[config.charSavedVariable]
	Profiles.Load(kit)
	Profiles.Flush(kit)

	W.Detect(kit.widgetsUsed)
	Profiles.InitDialogs(kit)

	local canvas = CreateFrame("Frame")
	canvas:Hide()
	AddPanelHooks(kit, canvas)
	BuildCanvas(kit, canvas)
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		RegisterWithSettings(kit, canvas)
	else
		BuildStandalone(kit, canvas)
	end

	Media.OnRegistered(function()
		kit:Refresh()
		if config.onMediaRegistered then
			config.onMediaRegistered(kit)
		end
	end)

	kit.ready = true
	for i = 1, #kit.readyQueue do
		kit.readyQueue[i](kit)
	end
	kit.readyQueue = {}
end

-- Runs fn(kit) once the settings are loaded (in ADDON_LOADED), or now if
-- they already are.
function Kit:OnReady(fn)
	if self.ready then
		fn(self)
	else
		self.readyQueue[#self.readyQueue + 1] = fn
	end
end

local function OpenNow(kit, tab)
	if kit.window then
		kit.window:Show()
	else
		local id = kit.category.GetID and kit.category:GetID() or kit.category.ID
		Settings.OpenToCategory(id)
	end
	if tab and kit.selectTab then
		kit.selectTab(tab)
	end
end

-- Opens the settings, on the given tab index if any. Waits for the end of
-- combat if needed.
function Kit:Open(tab)
	if not self.ready then
		return
	end
	if InCombatLockdown() then
		self:Print("Settings open when combat ends.")
	end
	SK.Events.AfterCombat("openSettings", function()
		OpenNow(self, tab)
	end)
end

function Kit:ProbeRows()
	return C.ProbeRows(self)
end

-- config:
--   title              shown in Options -> AddOns and on the landing page
--   version            defaults to the .toc's ## Version
--   description        landing page text
--   features           list of strings for the landing page
--   footer             replaces the standard footer (leave unset to keep it)
--   landingTab         name of the first tab (default "About")
--   savedVariable      name of the .toc's ## SavedVariables entry
--   charSavedVariable  name of the .toc's ## SavedVariablesPerCharacter entry
--   defaults           { key = value } (strings, numbers, booleans, tables)
--   onChange(key, value, kit)    after any setting changes
--   onProfileChanged(kit)        after the active profile changes or is reset
--   onMediaRegistered(kit)       after a SharedMedia pack registers media
function SK.New(config)
	if SK.instance then
		error(addonName .. ": ns.SettingsKit.New can be called once per addon", 2)
	end
	assert(type(config) == "table", "SettingsKit.New needs a config table")
	assert(type(config.savedVariable) == "string", "SettingsKit.New needs savedVariable")
	assert(type(config.charSavedVariable) == "string", "SettingsKit.New needs charSavedVariable")
	assert(type(config.defaults) == "table", "SettingsKit.New needs defaults")

	local kit = setmetatable({
		config = config,
		title = config.title or C.AddOnTitle(addonName),
		version = config.version or C.Metadata(addonName, "Version"),
		defaults = Serializer.DeepCopy(config.defaults),
		pageSpecs = {},
		pages = {},
		readyQueue = {},
		widgetsUsed = {},
	}, Kit)
	SK.instance = kit

	SK.Events.Register({
		ADDON_LOADED = function(name)
			if name == addonName and not kit.ready then
				Init(kit)
			end
		end,
		PLAYER_LOGOUT = function()
			if kit.ready then
				Profiles.Flush(kit)
			end
		end,
	})
	return kit
end
