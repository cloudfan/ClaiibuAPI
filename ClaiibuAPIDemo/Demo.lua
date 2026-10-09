local addonName, ns = ...

-- The demo, and the template for a new addon that depends on ClaiibuAPI:
-- declare the settings, build the pages, and react to changes. Copy this
-- addon, rename it, and replace what is below. The .toc needs
-- "## Dependencies: ClaiibuAPI" and its own two saved variables.
local API = ClaiibuAPI and ClaiibuAPI.Require(1, addonName)
if not API then
	return
end

local Demo = {}
ns.Demo = Demo

local kit = API.Settings.New(addonName, {
	title = "ClaiibuAPI Demo",
	description = "Every control ClaiibuAPI offers, and a small preview panel that uses the chosen settings. "
		.. "Copy this addon to start a new one.",
	features = {
		"Pages listed under the addon in Options -> AddOns, as a collapsible sublist",
		"Sliders, checkboxes and dropdowns from Blizzard's own settings templates",
		"Dropdowns with left and right steppers, listing Blizzard media first, then each LibSharedMedia pack under its own heading",
		"Anchor point and font shadow selectors",
		"Profiles saved as compact strings, shared across characters, with export and import",
	},
	savedVariable = "ClaiibuAPIDemoDB",
	charSavedVariable = "ClaiibuAPIDemoCharDB",
	defaults = {
		showPreview = false,
		point = "CENTER",
		x = 0,
		y = 120,
		width = 220,
		height = 24,
		font = "default",
		fontSize = 13,
		fontShadow = "soft",
		barTexture = "blizzard",
		border = "tooltip",
		borderSize = 12,
		background = "solid",
		alertSound = "readycheck",
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
general:Checkbox({ key = "showPreview", label = "Show Preview Panel", tooltip = "A small panel that uses the settings below." })
general:Header("Position")
general:Anchor({ key = "point", tooltip = "The corner or edge of the screen the panel is attached to." })
general:Slider({ key = "x", label = "X Offset", min = -800, max = 800, step = 5 })
general:Slider({ key = "y", label = "Y Offset", min = -500, max = 500, step = 5 })
general:Header("Size")
general:Slider({ key = "width", label = "Width", min = 100, max = 400, step = 10 })
general:Slider({ key = "height", label = "Height", min = 12, max = 60, step = 1 })

local style = kit:AddPage("Style")
style:Header("Text")
style:MediaDropdown({ key = "font", mediaType = "font" })
style:Slider({ key = "fontSize", label = "Font Size", min = 8, max = 24, step = 1 })
style:FontShadow({ key = "fontShadow" })
style:Header("Frame")
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

local panel

local function BuildPanel()
	panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	panel:SetFrameStrata("MEDIUM")
	panel.bar = CreateFrame("StatusBar", nil, panel)
	panel.bar:SetMinMaxValues(0, 1)
	panel.bar:SetValue(0.65)
	panel.text = panel.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	panel.text:SetPoint("CENTER")
	panel.text:SetText("ClaiibuAPI Demo")
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
	kit:ApplyAnchor(panel, "point", "x", "y")

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
	local tint = border.color
	panel:SetBackdropBorderColor(tint[1], tint[2], tint[3], tint[4])
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

	kit:ApplyFont(panel.text, "font", "fontSize", "fontShadow")
end

kit:OnReady(Demo.Apply)

-- Keeps the preview in step with media that loads late.
kit.events.On("PLAYER_LOGIN", Demo.Apply)

-- Slash commands ----------------------------------------------------------------------

local slash = {}

slash[""] = function()
	kit:Open()
end

slash.profiles = function()
	kit:Open(kit:ProfilesIndex())
end

slash.probe = function()
	kit:Print("Capability probe:")
	for _, row in ipairs(kit:ProbeRows()) do
		print("  " .. row)
	end
end

slash.help = function()
	kit:Print("/capi - settings, /capi profiles - profiles, /capi probe - API check")
end

SLASH_CLAIIBUAPIDEMO1 = "/capi"
SlashCmdList.CLAIIBUAPIDEMO = function(msg)
	local command = strlower(strtrim(msg or ""))
	if not kit.ready then
		kit:Print("Not loaded yet.")
		return
	end
	local handler = slash[command] or slash.help
	handler()
end
