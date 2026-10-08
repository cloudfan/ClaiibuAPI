local addonName, ns = ...

-- The demo, and the template for a new addon: declare the settings, build
-- the pages, and react to changes. Copy this file and the Kit folder into a
-- new addon and replace what is below.
local SK = ns.SettingsKit
local Events = SK.Events

local Demo = {}
ns.Demo = Demo

local kit = SK.New({
	title = "Pillars Settings Kit",
	description = "A standard settings window for Pillars addons. This demo shows every control the kit offers, "
		.. "and a small preview panel that uses the chosen media.",
	features = {
		"Tabs, sliders, checkboxes and dropdowns from Blizzard's own settings templates",
		"Dropdowns with left and right steppers, listing Blizzard media first, then each LibSharedMedia pack under its own heading",
		"Profiles saved as compact strings, shared across characters",
		"A landing page with the name, version, description and features",
	},
	savedVariable = "PillarsSettingsKitDB",
	charSavedVariable = "PillarsSettingsKitCharDB",
	defaults = {
		showPreview = false,
		width = 220,
		height = 24,
		fontSize = 13,
		font = "default",
		barTexture = "blizzard",
		border = "tooltip",
		borderSize = 12,
		background = "solid",
		alertSound = "readycheck",
		anchor = "center",
	},
	onChange = function()
		Demo.Apply()
	end,
	onProfileChanged = function()
		Demo.Apply()
	end,
	onMediaRegistered = function()
		Demo.Apply()
	end,
})
Demo.kit = kit

-- Pages ----------------------------------------------------------------------------

local general = kit:AddPage("General")
general:Header("Preview")
general:Checkbox({ key = "showPreview", label = "Show Preview Panel", tooltip = "A small panel near the middle of the screen that uses the settings below." })
general:Dropdown({
	key = "anchor",
	label = "Position",
	tooltip = "Where the preview panel sits.",
	options = {
		{ key = "center", label = "Center" },
		{ key = "top", label = "Top" },
		{ key = "bottom", label = "Bottom" },
	},
})
general:Header("Size")
general:Slider({ key = "width", label = "Width", min = 100, max = 400, step = 10 })
general:Slider({ key = "height", label = "Height", min = 12, max = 60, step = 1 })

local style = kit:AddPage("Style")
style:Header("Media")
style:MediaDropdown({ key = "font", mediaType = "font" })
style:Slider({ key = "fontSize", label = "Font Size", min = 8, max = 24, step = 1 })
style:MediaDropdown({ key = "barTexture", mediaType = "statusbar" })
style:MediaDropdown({ key = "border", mediaType = "border" })
style:Slider({ key = "borderSize", label = "Border Size", min = 1, max = 32, step = 1 })
style:MediaDropdown({ key = "background", mediaType = "background" })
style:Header("Sound")
style:MediaDropdown({ key = "alertSound", mediaType = "sound", tooltip = "Plays when you pick it." })
style:Button({
	label = "",
	text = "Play Sound",
	onClick = function(k)
		k:PlaySound("alertSound")
	end,
})
style:Text("Media registered with LibSharedMedia-3.0 appears in these lists under the name of the addon that ships it.")

-- Preview panel ----------------------------------------------------------------------
-- Plain frames, not protected. The bar shows a fixed value, not unit data.

local ANCHORS = {
	center = { "CENTER", 0, 120 },
	top = { "TOP", 0, -160 },
	bottom = { "BOTTOM", 0, 260 },
}

local panel

local function BuildPanel()
	panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	panel:SetFrameStrata("MEDIUM")
	panel.bar = CreateFrame("StatusBar", nil, panel)
	panel.bar:SetMinMaxValues(0, 1)
	panel.bar:SetValue(0.65)
	panel.text = panel.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.text:SetPoint("CENTER")
	panel.text:SetText("Pillars Settings Kit")
end

function Demo.Apply()
	if not kit.ready then
		return
	end
	local s = kit.settings
	if not panel then
		if not s.showPreview then
			return
		end
		BuildPanel()
	end
	panel:SetShown(s.showPreview)
	if not s.showPreview then
		return
	end
	panel:SetSize(s.width, s.height)
	local anchor = ANCHORS[s.anchor] or ANCHORS.center
	panel:ClearAllPoints()
	panel:SetPoint(anchor[1], UIParent, anchor[1], anchor[2], anchor[3])

	local border = kit:GetMedia("border", "border")
	local background = kit:GetMedia("background", "background")
	local edge = border.file and s.borderSize or 0
	local inset = math.floor(edge / 4 + 0.5)
	panel:SetBackdrop({
		bgFile = background.file,
		tile = background.tile,
		tileSize = background.tileSize,
		edgeFile = border.file,
		edgeSize = edge,
		insets = { left = inset, right = inset, top = inset, bottom = inset },
	})
	if background.key == "solid" then
		panel:SetBackdropColor(0, 0, 0, 0.8)
	else
		panel:SetBackdropColor(1, 1, 1, 1)
	end

	panel.bar:ClearAllPoints()
	panel.bar:SetPoint("TOPLEFT", inset, -inset)
	panel.bar:SetPoint("BOTTOMRIGHT", -inset, inset)
	panel.bar:SetStatusBarTexture(kit:GetMedia("statusbar", "barTexture").file)
	panel.bar:SetStatusBarColor(0.1, 0.7, 0.1)

	local font = kit:GetMedia("font", "font")
	panel.text:SetFont(font.file, s.fontSize, "OUTLINE")
end

kit:OnReady(Demo.Apply)

-- Slash commands ----------------------------------------------------------------------

local slash = {}

slash[""] = function()
	kit:Open()
end

slash.probe = function()
	kit:Print("Capability probe:")
	local rows = kit:ProbeRows()
	for i = 1, #rows do
		print("  " .. rows[i])
	end
end

slash.profiles = function()
	kit:Open(#kit.pageSpecs + 2) -- About, the pages, then Profiles
end

slash.help = function()
	kit:Print("/psk - settings, /psk profiles - profiles tab, /psk probe - API check")
end

SLASH_PILLARSSETTINGSKIT1 = "/psk"
SlashCmdList.PILLARSSETTINGSKIT = function(msg)
	local command = strlower(strtrim(msg or ""))
	if not kit.ready then
		kit:Print("Not loaded yet.")
		return
	end
	local handler = slash[command] or slash.help
	handler()
end

-- Keeps the preview in step with media that loads late, e.g. after login.
Events.On("PLAYER_LOGIN", function()
	Demo.Apply()
end)
