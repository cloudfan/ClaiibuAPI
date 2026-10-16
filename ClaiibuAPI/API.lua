local addonName, ns = ...

-- The public face of ClaiibuAPI. Addons that list ClaiibuAPI under
-- ## Dependencies use this global; nothing else in the API is global apart
-- from each addon's StaticPopup entries.
--
-- API_LEVEL goes up by one whenever something here changes in a way that
-- could break an addon written for the previous level. Additions do not
-- raise it.
local SK = ns.SettingsKit
local C = SK.Compat
local Media = SK.Media
local Serializer = SK.Serializer

local API = {
	VERSION = C.Metadata(addonName, "Version") or "unknown",
	API_LEVEL = 1,
}

-- Settings windows, profiles and the landing page.
API.Settings = {
	New = SK.New,                -- New(addonName, config) -> kit
	ANCHORS = SK.ANCHORS,        -- { { key = "TOPLEFT", label = "TOP LEFT" }, ... }
	FOOTER = SK.FOOTER,
}

-- The kit an addon created, or nil.
function API.GetSettings(owner)
	return SK.kits[owner]
end

-- Blizzard and LibSharedMedia media.
API.Media = {
	KINDS = Media.KINDS,         -- "font", "statusbar", "border", "background", "sound"
	LABELS = Media.LABELS,
	DEFAULT = Media.DEFAULT,
	SHADOWS = Media.SHADOWS,
	Get = Media.Get,             -- Get(kind, key) -> { key, label, file, color, tile, tileSize, soundKit }
	Options = Media.Options,     -- Options(kind) -> { { key, label, group } ... }
	PlaySound = Media.PlaySound, -- PlaySound(key, channel)
	ApplyFont = Media.ApplyFont, -- ApplyFont(fontString, fontKey, size, shadowKey, flags)
	LSM = Media.LSM,
}

-- Compact strings for tables of strings, numbers and booleans.
API.Serializer = {
	Encode = Serializer.Encode,  -- Encode(table) -> string or nil, err
	Decode = Serializer.Decode,  -- Decode(string) -> table or nil, err
	DeepCopy = Serializer.DeepCopy,
	DeepEqual = Serializer.DeepEqual,
}

-- Capability checks for Forever.
API.Compat = {
	IsSecret = C.IsSecret,
	TemplateExists = C.TemplateExists,
	AtlasExists = C.AtlasExists,
	AddOnTitle = C.AddOnTitle,
	CharacterProfileName = C.CharacterProfileName,
	ProbeRows = C.ProbeRows,     -- ProbeRows(kit) -> list of strings
}

-- A shared window that shows text ready to copy (Ctrl+C), for diagnostics.
-- ShowCopyText(title, content, keepCodes): content is a string or a list of
-- lines; color codes are removed unless keepCodes is true.
API.ShowCopyText = SK.CopyWindow.Show
API.HideCopyText = SK.CopyWindow.Hide

-- Edit Mode movers without a settings kit (kits use kit:AddEditMode).
-- New(addonName, spec) needs spec.getPosition and spec.savePosition.
API.EditMode = {
	New = function(owner, spec)
		return SK.EditMode.New(owner, spec)
	end,
	IsActive = SK.EditMode.IsActive, -- true while Blizzard's Edit Mode is open
}

-- Dispellable debuffs, safe in combat (reads auras only; secret fields are
-- passed through and flagged, never compared).
--   Get(unit, mode)  -> info or nil, status ("found", "none" or "blocked"); mode "player" (default), "group" or "any"
--   Has(unit, mode)  -> boolean
--   ColorFor(type)   -> { r, g, b, a } or nil
--   OnChange(fn)     -> fn(unit) after a unit's auras change
API.Dispel = {
	Get = SK.Dispel.Get,
	Has = SK.Dispel.Has,
	ColorFor = SK.Dispel.ColorFor,
	OnChange = SK.Dispel.OnChange,
	IsBlocked = SK.Dispel.IsBlocked, -- true while the client refuses aura data (in combat on Forever)
	LastError = SK.Dispel.LastError, -- LastError() -> { unit, mode, message } of the last failed read, or nil
	IsSupported = SK.Dispel.IsSupported,
	Report = SK.Dispel.Report,       -- Report(units) -> lines of plain text, secret fields as "(secret)"
	TYPES = SK.Dispel.TYPES,
	COLORS = SK.Dispel.COLORS,
}

-- An event frame with a handler table, AfterCombat and Defer, for an addon
-- that wants one without a settings window. kit.events is one of these.
API.NewEvents = SK.NewEvents

-- Returns the API if it is at least the given level; otherwise prints why
-- and returns nil. Use: local API = ClaiibuAPI and ClaiibuAPI.Require(1, addonName)
function API.Require(level, owner)
	if API.API_LEVEL >= level then
		return API
	end
	print("|cffff4040" .. tostring(owner) .. " needs ClaiibuAPI API level " .. level .. " or newer (installed: "
		.. API.API_LEVEL .. ", version " .. API.VERSION .. "). Update ClaiibuAPI.|r")
	return nil
end

ClaiibuAPI = API

-- /claiibu: diagnostics that work without the demo addon.
local commands = {}

local function Show(value)
	if value == nil then
		return "nil"
	end
	if C.IsSecret(value) then
		return "(secret)"
	end
	return tostring(value)
end

commands.dispel = function(unit)
	if unit == "watch" or unit == "watch raw" then
		local raw = unit == "watch raw"
		if SK.Dispel.ToggleWatch(raw) then
			print("|cffe0b060ClaiibuAPI|r Dispel recorder on" .. (raw and " (raw)" or "")
				.. ": start a fight; the results open when combat ends.")
		else
			print("|cffe0b060ClaiibuAPI|r Dispel recorder off.")
		end
		return
	end
	if unit == "raw" or unit:find("^raw ") then
		local target = strtrim(unit:sub(4))
		local units = target ~= "" and { target } or { "player", "target", "party1", "party2", "party3", "party4" }
		local _, class = UnitClass("player")
		local lines = { "Your class: " .. Show(class) .. ". In combat: " .. ((InCombatLockdown and InCombatLockdown()) and "yes" or "no"),
			"Counts per filter, then up to 3 debuffs: name [type, spell].", "" }
		for _, line in ipairs(SK.Dispel.Raw(units)) do
			lines[#lines + 1] = line
		end
		SK.CopyWindow.Show("ClaiibuAPI: Raw Aura Data", lines)
		return
	end
	local units = unit ~= "" and { unit } or { "player", "target", "party1", "party2", "party3", "party4" }
	SK.CopyWindow.Show("ClaiibuAPI: Dispellable Debuffs", SK.Dispel.Report(units))
end

commands.probe = function()
	SK.CopyWindow.Show("ClaiibuAPI: Diagnostics", C.ProbeRows(nil))
end

commands.version = function()
	print("|cffe0b060ClaiibuAPI|r version " .. API.VERSION .. ", API level " .. API.API_LEVEL)
end

commands.help = function()
	print("|cffe0b060ClaiibuAPI|r /claiibu dispel [unit] - dispellable debuffs, /claiibu dispel watch [raw] - record them in your next fights, /claiibu dispel raw [unit] - raw aura data, /claiibu probe - API check, /claiibu version")
end

SLASH_CLAIIBUAPI1 = "/claiibu"
SLASH_CLAIIBUAPI2 = "/claiibuapi"
SlashCmdList.CLAIIBUAPI = function(msg)
	local command, rest = strlower(strtrim(msg or "")):match("^(%S*)%s*(.-)$")
	local handler = commands[command] or commands.help
	handler(rest)
end
