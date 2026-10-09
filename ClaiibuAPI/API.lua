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
