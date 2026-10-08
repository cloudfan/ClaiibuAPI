local addonName, ns = ...

-- Every API the kit could not confirm on Forever is reached through here.
local SK = ns.SettingsKit
local C = {}
SK.Compat = C

function C.IsSecret(value)
	if issecretvalue then
		return issecretvalue(value)
	end
	return false
end

-- true, false, or nil when the client cannot tell.
function C.TemplateExists(name)
	if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
		return C_XMLUtil.GetTemplateInfo(name) ~= nil
	end
	return nil
end

function C.HasTemplate(name)
	return C.TemplateExists(name) == true
end

function C.AtlasExists(name)
	return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(name) ~= nil
end

local function Metadata(addon, field)
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if not get then
		return nil
	end
	-- Not a protected call: an unknown addon name raises a plain Lua error.
	local ok, value = pcall(get, addon, field)
	if ok and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end
C.Metadata = Metadata

local function StripCodes(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
	return strtrim and strtrim(text) or text
end

local titles = {}

-- The display name of an installed addon folder, without color codes.
function C.AddOnTitle(folder)
	local title = titles[folder]
	if title == nil then
		local raw = Metadata(folder, "Title")
		title = raw and StripCodes(raw) or folder
		if title == "" then
			title = folder
		end
		titles[folder] = title
	end
	return title
end

-- "Name-Realm" for the profile name prompt. Unit names can be secret on
-- Forever, so a secret name falls back to a plain word.
function C.CharacterProfileName()
	local name = UnitName and UnitName("player")
	if name == nil or C.IsSecret(name) then
		name = "Character"
	end
	local realm = GetRealmName and GetRealmName()
	if realm == nil or C.IsSecret(realm) or realm == "" then
		return name
	end
	return name .. "-" .. realm
end

local function Has(value)
	return value ~= nil and "yes" or "|cffff4040MISSING|r"
end

local function Known(value)
	if value == nil then
		return "unknown"
	end
	return value and "yes" or "|cffff4040MISSING|r"
end

-- Lines for a host addon's probe command.
function C.ProbeRows(kit)
	local _, build, _, interface = GetBuildInfo()
	local rows = {
		"Build " .. tostring(build) .. ", interface " .. tostring(interface)
			.. ", WOW_PROJECT_ID " .. tostring(WOW_PROJECT_ID)
			.. ", LE_EXPANSION_LEVEL_CURRENT " .. tostring(LE_EXPANSION_LEVEL_CURRENT),
		"issecretvalue: " .. Has(issecretvalue),
		"Settings.RegisterCanvasLayoutCategory: " .. Has(Settings and Settings.RegisterCanvasLayoutCategory),
		"Settings.RegisterAddOnCategory: " .. Has(Settings and Settings.RegisterAddOnCategory),
		"Settings.OpenToCategory: " .. Has(Settings and Settings.OpenToCategory),
		"C_XMLUtil.GetTemplateInfo: " .. Has(C_XMLUtil and C_XMLUtil.GetTemplateInfo),
		"TabSystemTemplate: " .. Known(C.TemplateExists("TabSystemTemplate")),
		"PanelTopTabButtonTemplate: " .. Known(C.TemplateExists("PanelTopTabButtonTemplate")),
		"SettingsDropdownWithButtonsTemplate: " .. Known(C.TemplateExists("SettingsDropdownWithButtonsTemplate")),
		"WowStyle1DropdownTemplate: " .. Known(C.TemplateExists("WowStyle1DropdownTemplate")),
		"MinimalSliderWithSteppersTemplate: " .. Known(C.TemplateExists("MinimalSliderWithSteppersTemplate")),
		"SettingsCheckboxTemplate: " .. Known(C.TemplateExists("SettingsCheckboxTemplate")),
		"UICheckButtonTemplate: " .. Known(C.TemplateExists("UICheckButtonTemplate")),
		"ScrollFrameTemplate: " .. Known(C.TemplateExists("ScrollFrameTemplate")),
		"StaticPopup_Show: " .. Has(StaticPopup_Show),
		"SOUNDKIT: " .. Has(SOUNDKIT),
		"C_AddOns.GetAddOnMetadata: " .. Has(C_AddOns and C_AddOns.GetAddOnMetadata),
		"LibSharedMedia-3.0: " .. (SK.Media.LSM() and "loaded" or "not loaded (optional)"),
	}
	if kit then
		local used = kit.widgetsUsed or {}
		rows[#rows + 1] = "Kit is using: tabs=" .. tostring(used.tabs) .. ", dropdown=" .. tostring(used.dropdown)
			.. ", slider=" .. tostring(used.slider) .. ", checkbox=" .. tostring(used.checkbox)
			.. ", dialogs=" .. tostring(used.dialogs) .. ", window=" .. tostring(used.window)
		rows[#rows + 1] = "Active profile: " .. tostring(kit:GetActiveProfile())
	end
	rows[#rows + 1] = "Player name is secret: " .. (C.IsSecret(UnitName("player")) and "yes" or "no")
	return rows
end
