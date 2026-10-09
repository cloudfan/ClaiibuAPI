local addonName, ns = ...

-- Settings for any addon that depends on ClaiibuAPI: one entry in
-- Options -> AddOns (the landing page) with a collapsible sublist under it:
-- the addon's own pages, then Profiles.
--
--   local kit = ClaiibuAPI.Settings.New(addonName, { ... })   -- at file scope
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

-- Anchor points, in the order the selector lists them. The keys are the
-- point names SetPoint takes.
SK.ANCHORS = {
	{ key = "TOPLEFT", label = "TOP LEFT" },
	{ key = "TOP", label = "TOP CENTER" },
	{ key = "TOPRIGHT", label = "TOP RIGHT" },
	{ key = "LEFT", label = "LEFT CENTER" },
	{ key = "CENTER", label = "CENTER" },
	{ key = "RIGHT", label = "RIGHT CENTER" },
	{ key = "BOTTOMLEFT", label = "BOTTOM LEFT" },
	{ key = "BOTTOM", label = "BOTTOM CENTER" },
	{ key = "BOTTOMRIGHT", label = "BOTTOM RIGHT" },
}
local anchorKeys = {}
for _, anchor in ipairs(SK.ANCHORS) do
	anchorKeys[anchor.key] = true
end

-- Every kit, by the name of the addon it belongs to.
local kits = {}
SK.kits = kits

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

-- spec: key, label (default "Font Shadow"), tooltip. Values are the keys of
-- Media.SHADOWS; apply them with kit:ApplyFont.
function PageSpec:FontShadow(spec)
	return Add(self, "FontShadow", spec)
end

-- spec: key, label (default "Anchor Point"), tooltip. Values are SetPoint
-- names ("TOPLEFT" ... "BOTTOMRIGHT"); apply them with kit:ApplyAnchor.
function PageSpec:Anchor(spec)
	return Add(self, "Anchor", spec)
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
		error(self.addonName .. ": settings are not loaded yet; use kit:OnReady", 2)
	end
	local default = self.defaults[key]
	if default == nil or type(value) ~= type(default) then
		error(self.addonName .. ": no setting " .. tostring(key) .. " of type " .. type(value), 2)
	end
	self.settings[key] = value
	Changed(self, key, value)
	self:Refresh()
end

-- The media entry a media setting points at (see Media.Get).
function Kit:GetMedia(mediaType, key)
	return Media.Get(mediaType, self.settings[key])
end

-- Sets a FontString from settings: kit:ApplyFont(fs, "font", "fontSize", "fontShadow").
-- size may be a setting key or a number; flags is optional ("OUTLINE").
function Kit:ApplyFont(fontString, fontKey, size, shadowKey, flags)
	if type(size) == "string" then
		size = self.settings[size]
	end
	Media.ApplyFont(fontString, self.settings[fontKey], size,
		shadowKey and self.settings[shadowKey] or "none", flags)
end

-- Places frame by settings: kit:ApplyAnchor(frame, "point", "x", "y").
-- The frame's point and the parent's point are the same, so "TOPLEFT" puts
-- the frame in the parent's top left corner. relativeTo defaults to
-- UIParent; x and y may be setting keys or numbers. Unknown points give
-- CENTER. Check InCombatLockdown() first if the frame is protected.
function Kit:ApplyAnchor(frame, pointKey, x, y, relativeTo)
	local point = self.settings[pointKey]
	if not anchorKeys[point] then
		point = "CENTER"
	end
	if type(x) == "string" then
		x = self.settings[x]
	end
	if type(y) == "string" then
		y = self.settings[y]
	end
	frame:ClearAllPoints()
	frame:SetPoint(point, relativeTo or UIParent, point, x or 0, y or 0)
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
	self.events.Defer("profileRefresh", function()
		self:Refresh()
	end)
end

-- Saves under a typed name. text is an imported profile string, or nil for
-- the current settings.
function Kit:RequestSaveAs(typed, text)
	local name = Profiles.CleanName(typed)
	if not name then
		self:Print("A profile needs a name.")
		return
	end
	if self.db.profiles[name] and name ~= Profiles.Active(self) then
		Profiles.PromptOverwrite(self, name, text)
		return
	end
	Profiles.SaveAs(self, name, text)
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
		error(kit.addonName .. ": " .. method .. " \"" .. tostring(spec.label) .. "\" uses key \""
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
		error(kit.addonName .. ": unknown mediaType " .. tostring(kind), 0)
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

function BUILD.FontShadow(kit, page, spec)
	local bound = Bind(kit, spec)
	bound.label = spec.label or "Font Shadow"
	bound.options = function()
		return Media.SHADOWS
	end
	page:Dropdown(bound)
end

function BUILD.Anchor(kit, page, spec)
	local bound = Bind(kit, spec)
	bound.label = spec.label or "Anchor Point"
	bound.options = function()
		return SK.ANCHORS
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
-- The addon's own entry in the AddOns list. Header: name | version. Body:
-- description and features. Footer: the standard credit line.

local function BuildLanding(kit, canvas)
	local config = kit.config
	local title = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 7, -22)
	title:SetText(kit.title)

	local separator = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	separator:SetPoint("LEFT", title, "RIGHT", 10, 0)
	separator:SetTextColor(0.5, 0.5, 0.5)
	separator:SetText("||")

	local version = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	version:SetPoint("LEFT", separator, "RIGHT", 10, 0)
	version:SetText(kit.version and ("Version " .. kit.version) or "")

	local divider = W.Divider(canvas)
	divider:SetPoint("TOPLEFT", 0, -50)
	divider:SetPoint("TOPRIGHT", 0, -50)

	local footerDivider = W.Divider(canvas)
	footerDivider:SetPoint("BOTTOMLEFT", 0, 34)
	footerDivider:SetPoint("BOTTOMRIGHT", 0, 34)

	local footer = canvas:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	footer:SetPoint("BOTTOM", 0, 14)
	footer:SetText(config.footer or SK.FOOTER)

	local scroll, child = W.ScrollArea(canvas)
	scroll:SetPoint("TOPLEFT", 0, -58)
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
	if #kit.pageSpecs > 0 then
		page:Text("The settings are in the sections listed under " .. kit.title .. " on the left.")
	end
	child:SetHeight(page:Height())
	return page
end

-- Profiles page ----------------------------------------------------------------------

local function BuildProfiles(kit, page)
	page:Header("Active Profile")
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

	page:Header("Export and Import")
	page:Text("Export: the code below is the active profile. Click the box, then press Ctrl+C to copy it.\n"
		.. "Import: paste a code into the box with Ctrl+V and click Import. It is saved as a new profile.")
	local box = page:TextBox({
		height = 90,
		get = function()
			return Profiles.Export(kit)
		end,
	})
	page:Button({
		label = "",
		text = "Import",
		tooltip = "Create a new profile from the code in the box.",
		onClick = function()
			Profiles.PromptImport(kit, box:GetText())
		end,
	})
end

-- Window -----------------------------------------------------------------------------
-- The landing page is the addon's entry in Options -> AddOns. Each page and
-- Profiles are subcategories under it, which Blizzard's list shows as a
-- collapsible sublist.

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
	canvas:SetScript("OnShow", function()
		kit:Refresh()
	end)
end

local function NewCanvas(kit, name)
	local canvas = CreateFrame("Frame")
	canvas:Hide()
	canvas.name = name
	AddPanelHooks(kit, canvas)
	return canvas
end

-- A page with a title, a divider, and a scrolling body.
local function BuildSettingsPage(kit, name, fill)
	local canvas = NewCanvas(kit, name)
	local top = W.PageTitle(canvas, name)
	local scroll, child = W.ScrollArea(canvas)
	scroll:SetPoint("TOPLEFT", 0, top - 4)
	scroll:SetPoint("BOTTOMRIGHT", -24, 4)
	local page = W.NewPage(child)
	fill(page)
	child:SetHeight(page:Height())
	kit.pages[#kit.pages + 1] = page
	return canvas
end

-- Returns the canvases: landing page first, then the pages, then Profiles.
local function BuildCanvases(kit)
	local canvases = {}
	local landing = NewCanvas(kit, kit.title)
	kit.pages[#kit.pages + 1] = BuildLanding(kit, landing)
	canvases[1] = landing
	for _, spec in ipairs(kit.pageSpecs) do
		canvases[#canvases + 1] = BuildSettingsPage(kit, spec.name, function(page)
			for _, step in ipairs(spec.steps) do
				if type(step.spec) == "table" then
					CheckKey(kit, step.spec, step.method)
				end
				BUILD[step.method](kit, page, step.spec)
			end
		end)
	end
	canvases[#canvases + 1] = BuildSettingsPage(kit, "Profiles", function(page)
		BuildProfiles(kit, page)
	end)
	return canvases
end

local function RegisterWithSettings(kit, canvases)
	local category = Settings.RegisterCanvasLayoutCategory(canvases[1], kit.title)
	kit.categories = { category }
	for i = 2, #canvases do
		kit.categories[i] = Settings.RegisterCanvasLayoutSubcategory(category, canvases[i], canvases[i].name)
	end
	Settings.RegisterAddOnCategory(category)
	kit.category = category
	W.used.window = "Settings (subcategories)"
end

-- No Settings API: one window with the same list down the left.
local function BuildStandalone(kit, canvases)
	local name = "ClaiibuAPI_" .. kit.addonName .. "_Options"
	local window = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	window:SetSize(860, 620)
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

	local function Select(index)
		for i, canvas in ipairs(canvases) do
			canvas:SetShown(i == index)
		end
	end
	for i, canvas in ipairs(canvases) do
		canvas:SetParent(window)
		canvas:SetPoint("TOPLEFT", 200, -16)
		canvas:SetPoint("BOTTOMRIGHT", -16, 16)
		local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
		button:SetSize(170, 24)
		button:SetPoint("TOPLEFT", 20, -20 - (i - 1) * 28)
		button:SetText((i == 1 and "" or "   ") .. canvas.name)
		button:SetScript("OnClick", function()
			Select(i)
		end)
	end
	Select(1)
	kit.selectPage = Select
	kit.window = window
	W.used.window = "standalone"
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

	W.Detect()
	Profiles.InitDialogs(kit)

	local canvases = BuildCanvases(kit)
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterCanvasLayoutSubcategory
		and Settings.RegisterAddOnCategory then
		RegisterWithSettings(kit, canvases)
	else
		BuildStandalone(kit, canvases)
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

local function OpenNow(kit, index)
	index = index or 1
	if kit.window then
		kit.selectPage(index)
		kit.window:Show()
		return
	end
	local category = kit.categories[index] or kit.category
	local id = category.GetID and category:GetID() or category.ID
	Settings.OpenToCategory(id)
end

-- Opens the settings: 1 (or nil) is the landing page, then the pages in the
-- order they were added, then Profiles (see Kit:ProfilesIndex). Waits for the
-- end of combat if needed.
function Kit:Open(index)
	if not self.ready then
		return
	end
	if InCombatLockdown() then
		self:Print("Settings open when combat ends.")
	end
	self.events.AfterCombat("openSettings", function()
		OpenNow(self, index)
	end)
end

function Kit:ProfilesIndex()
	return #self.pageSpecs + 2
end

function Kit:ProbeRows()
	return C.ProbeRows(self)
end

-- ClaiibuAPI.Settings.New(addonName, config). config:
--   title              shown in Options -> AddOns and on the landing page
--   version            defaults to the .toc's ## Version
--   description        landing page text
--   features           list of strings for the landing page
--   footer             replaces the standard footer (leave unset to keep it)
--   savedVariable      name of the .toc's ## SavedVariables entry
--   charSavedVariable  name of the .toc's ## SavedVariablesPerCharacter entry
--   defaults           { key = value } (strings, numbers, booleans, tables)
--   onChange(key, value, kit)    after any setting changes
--   onProfileChanged(kit)        after the active profile changes or is reset
--   onMediaRegistered(kit)       after a SharedMedia pack registers media
function SK.New(owner, config)
	assert(type(owner) == "string", "ClaiibuAPI.Settings.New(addonName, config): pass your addon's name first (local addonName = ...)")
	if kits[owner] then
		error(owner .. ": ClaiibuAPI.Settings.New can be called once per addon", 2)
	end
	assert(type(config) == "table", owner .. ": Settings.New needs a config table")
	assert(type(config.savedVariable) == "string", owner .. ": Settings.New needs savedVariable")
	assert(type(config.charSavedVariable) == "string", owner .. ": Settings.New needs charSavedVariable")
	assert(type(config.defaults) == "table", owner .. ": Settings.New needs defaults")

	local kit = setmetatable({
		addonName = owner,
		config = config,
		title = config.title or C.AddOnTitle(owner),
		version = config.version or C.Metadata(owner, "Version"),
		defaults = Serializer.DeepCopy(config.defaults),
		pageSpecs = {},
		pages = {},
		readyQueue = {},
		-- The owning addon's own event frame. The addon may use it too.
		events = SK.NewEvents(),
	}, Kit)
	kits[owner] = kit

	kit.events.Register({
		ADDON_LOADED = function(name)
			if name == owner and not kit.ready then
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
