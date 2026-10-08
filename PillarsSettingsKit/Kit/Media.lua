local addonName, ns = ...

-- Media lists for the dropdowns: Blizzard's own art first, then everything
-- registered with LibSharedMedia-3.0, grouped under the addon that ships the
-- file. LibSharedMedia does not record who registered an entry, so the group
-- comes from the file path (Interface\AddOns\<Folder>\...). Entries that
-- point at Blizzard files join the Blizzard group.
--
-- Saved values are keys: a stock key ("friz") or "lsm:<name>".
local SK = ns.SettingsKit
local C = SK.Compat
local Media = {}
SK.Media = Media

local LSM_PREFIX = "lsm:"
local BLIZZARD = "Blizzard"
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Tints for stock borders. Apply them with SetBackdropBorderColor (or
-- SetVertexColor); entries without a color are drawn white.
local BRONZE = { 0.85, 0.6, 0.35, 1 }
local GOLD = { 1, 0.82, 0.25, 1 }
Media.WHITE_COLOR = { 1, 1, 1, 1 }

-- The kinds are LibSharedMedia's media types.
Media.KINDS = { "font", "statusbar", "border", "background", "sound" }
Media.LABELS = {
	font = "Font",
	statusbar = "Bar Texture",
	border = "Border",
	background = "Background",
	sound = "Sound",
}

-- Stock Blizzard art. Mainline paths: retest on the current Forever build.
-- A missing file draws nothing. file = nil on a font means the client's
-- GameFontNormal font. Sounds name a SOUNDKIT entry; entries this client
-- does not have are left out.
Media.STOCK = {
	font = {
		{ key = "default", label = "Game Default" },
		{ key = "friz", label = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
		{ key = "arialn", label = "Arial Narrow", file = "Fonts\\ARIALN.TTF" },
		{ key = "morpheus", label = "Morpheus", file = "Fonts\\MORPHEUS.TTF" },
		{ key = "skurri", label = "Skurri", file = "Fonts\\SKURRI.TTF" },
	},
	statusbar = {
		{ key = "flat", label = "Flat", file = WHITE },
		{ key = "blizzard", label = "Blizzard", file = "Interface\\TargetingFrame\\UI-StatusBar" },
		{ key = "raid", label = "Raid", file = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
		{ key = "skills", label = "Skills", file = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
	},
	border = {
		{ key = "tooltip", label = "Tooltip", file = "Interface\\Tooltips\\UI-Tooltip-Border" },
		{ key = "dialog", label = "Dialog", file = "Interface\\DialogFrame\\UI-DialogBox-Border" },
		{ key = "dialoggold", label = "Dialog Gold", file = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border" },
		{ key = "wood", label = "Achievement Wood", file = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder" },
		{ key = "party", label = "Party", file = "Interface\\CharacterFrame\\UI-Party-Border" },
		{ key = "bubble", label = "Chat Bubble", file = "Interface\\Tooltips\\ChatBubble-Backdrop" },
		{ key = "dialogbronze", label = "Dialog Bronze", file = "Interface\\DialogFrame\\UI-DialogBox-Border", color = BRONZE },
		{ key = "toast", label = "Toast", file = "Interface\\FriendsFrame\\UI-Toast-Border" },
		{ key = "toastbronze", label = "Toast Bronze", file = "Interface\\FriendsFrame\\UI-Toast-Border", color = BRONZE },
		{ key = "toastgold", label = "Toast Gold", file = "Interface\\FriendsFrame\\UI-Toast-Border", color = GOLD },
		{ key = "solid", label = "Solid", file = WHITE },
		{ key = "none", label = "None" },
	},
	background = {
		{ key = "solid", label = "Solid", file = WHITE },
		{ key = "tooltip", label = "Tooltip", file = "Interface\\Tooltips\\UI-Tooltip-Background" },
		{ key = "dialog", label = "Dialog", file = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 32 },
		{ key = "dialogdark", label = "Dialog Dark", file = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", tile = true, tileSize = 32 },
		{ key = "dialoggold", label = "Dialog Gold", file = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background", tile = true, tileSize = 32 },
		{ key = "marble", label = "Marble", file = "Interface\\FrameGeneral\\UI-Background-Marble", tile = true, tileSize = 128 },
		{ key = "rock", label = "Rock", file = "Interface\\FrameGeneral\\UI-Background-Rock", tile = true, tileSize = 128 },
		{ key = "parchment", label = "Parchment", file = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal" },
		{ key = "none", label = "None" },
	},
	sound = {
		{ key = "none", label = "None" },
		{ key = "raidwarning", label = "Raid Warning", soundKit = "RAID_WARNING" },
		{ key = "readycheck", label = "Ready Check", soundKit = "READY_CHECK" },
		{ key = "alarm", label = "Alarm Clock", soundKit = "ALARM_CLOCK_WARNING_3" },
		{ key = "whisper", label = "Whisper", soundKit = "TELL_MESSAGE" },
		{ key = "invite", label = "Party Invite", soundKit = "IG_PLAYER_INVITE" },
		{ key = "mapping", label = "Map Ping", soundKit = "MAP_PING" },
	},
}

-- The default key of each kind, for unknown or removed media.
Media.DEFAULT = {
	font = "default",
	statusbar = "blizzard",
	border = "tooltip",
	background = "solid",
	sound = "none",
}

function Media.LSM()
	if LibStub then
		return LibStub("LibSharedMedia-3.0", true)
	end
end

local function NormalizePath(data)
	if type(data) == "number" then
		return tostring(data)
	end
	if type(data) ~= "string" then
		return nil
	end
	return (data:gsub("/", "\\"):lower())
end

-- The addon folder a file lives in, or nil for a Blizzard file.
local ADDONS_PREFIX = "interface\\addons\\"
local function AddOnFolder(data)
	if type(data) ~= "string" then
		return nil
	end
	local path = data:gsub("/", "\\")
	if path:sub(1, #ADDONS_PREFIX):lower() ~= ADDONS_PREFIX then
		return nil
	end
	return path:sub(#ADDONS_PREFIX + 1):match("^([^\\]+)")
end

local function StockEntries(kind)
	local list = {}
	for _, entry in ipairs(Media.STOCK[kind]) do
		if not entry.soundKit or (SOUNDKIT and SOUNDKIT[entry.soundKit]) then
			list[#list + 1] = entry
		end
	end
	return list
end

local stockByKey = {}
for _, kind in ipairs(Media.KINDS) do
	stockByKey[kind] = {}
	for _, entry in ipairs(Media.STOCK[kind]) do
		entry.color = entry.color or Media.WHITE_COLOR
		stockByKey[kind][entry.key] = entry
	end
end

-- "lsm:<name>" keys that point at a stock file, mapped to the stock key.
local aliases = {}
for _, kind in ipairs(Media.KINDS) do
	aliases[kind] = {}
end

-- { { key, label, group } ... } in menu order: the Blizzard group, then one
-- group per addon in alphabetical order.
function Media.Options(kind)
	local options = {}
	local seenPath, seenLabel = {}, {}
	for _, entry in ipairs(StockEntries(kind)) do
		options[#options + 1] = { key = entry.key, label = entry.label, group = BLIZZARD }
		if entry.file then
			seenPath[NormalizePath(entry.file)] = entry.key
		end
		seenLabel[entry.label:lower()] = entry.key
	end

	local lsm = Media.LSM()
	if not lsm then
		return options
	end
	local groups, groupNames = {}, {}
	local names = lsm:List(kind) or {}
	for i = 1, #names do
		local name = names[i]
		local data = lsm:Fetch(kind, name, true)
		local key = LSM_PREFIX .. name
		local folder = AddOnFolder(data)
		if folder then
			local group = C.AddOnTitle(folder)
			if not groups[group] then
				groups[group] = {}
				groupNames[#groupNames + 1] = group
			end
			local list = groups[group]
			list[#list + 1] = { key = key, label = name, group = group }
		else
			local path = NormalizePath(data)
			local same = (path and seenPath[path]) or seenLabel[name:lower()]
			if same then
				aliases[kind][key] = same
			else
				options[#options + 1] = { key = key, label = name, group = BLIZZARD }
				if path then
					seenPath[path] = key
				end
				seenLabel[name:lower()] = key
			end
		end
	end
	table.sort(groupNames, function(a, b)
		return a:lower() < b:lower()
	end)
	for _, group in ipairs(groupNames) do
		for _, option in ipairs(groups[group]) do
			options[#options + 1] = option
		end
	end
	return options
end

-- The key a dropdown shows as selected (a SharedMedia copy of a stock file
-- selects the stock entry).
function Media.Canonical(kind, key)
	return aliases[kind][key] or key
end

local lsmCache = {}
for _, kind in ipairs(Media.KINDS) do
	lsmCache[kind] = {}
end

local function DefaultFontFile()
	if GameFontNormal and GameFontNormal.GetFont then
		return (GameFontNormal:GetFont())
	end
	return "Fonts\\FRIZQT__.TTF"
end

-- Returns { key, label, file, color, tile, tileSize, soundKit }. color is
-- { r, g, b, a } (white unless the entry is tinted). Fonts always have
-- a file. A border, background or sound may have none ("None"). Unknown keys
-- and SharedMedia entries whose pack is gone give the kind's default.
function Media.Get(kind, key)
	local entry = stockByKey[kind][key]
	if not entry and type(key) == "string" and key:sub(1, #LSM_PREFIX) == LSM_PREFIX then
		local lsm = Media.LSM()
		local name = key:sub(#LSM_PREFIX + 1)
		local data = lsm and lsm:Fetch(kind, name, true)
		if data then
			entry = lsmCache[kind][key]
			if not entry or entry.file ~= data then
				entry = { key = key, label = name, file = data, color = Media.WHITE_COLOR }
				lsmCache[kind][key] = entry
			end
		end
	end
	entry = entry or stockByKey[kind][Media.DEFAULT[kind]]
	if kind == "font" and not entry.file then
		return { key = entry.key, label = entry.label, file = DefaultFontFile(), color = entry.color }
	end
	return entry
end

-- Font shadows. Saved values are these keys.
Media.SHADOWS = {
	{ key = "none", label = "None" },
	{ key = "soft", label = "Soft", x = 1, y = -1, alpha = 0.6 },
	{ key = "hard", label = "Hard", x = 1, y = -1, alpha = 1 },
	{ key = "heavy", label = "Heavy", x = 2, y = -2, alpha = 1 },
}
local shadowByKey = {}
for _, shadow in ipairs(Media.SHADOWS) do
	shadowByKey[shadow.key] = shadow
end

-- Sets a FontString's font, size, flags and shadow from setting keys.
function Media.ApplyFont(fontString, fontKey, size, shadowKey, flags)
	fontString:SetFont(Media.Get("font", fontKey).file, size, flags or "")
	local shadow = shadowByKey[shadowKey] or shadowByKey.none
	if shadow.x then
		fontString:SetShadowOffset(shadow.x, shadow.y)
		fontString:SetShadowColor(0, 0, 0, shadow.alpha)
	else
		fontString:SetShadowOffset(0, 0)
		fontString:SetShadowColor(0, 0, 0, 0)
	end
end

-- Plays a sound key on the given channel ("Master" by default).
function Media.PlaySound(key, channel)
	local entry = Media.Get("sound", key)
	channel = channel or "Master"
	if entry.soundKit and SOUNDKIT and SOUNDKIT[entry.soundKit] then
		PlaySound(SOUNDKIT[entry.soundKit], channel)
	elseif entry.file then
		PlaySoundFile(entry.file, channel)
	end
end

-- Tells listeners when a SharedMedia pack registers media after load (for
-- example a saved choice whose pack loads after this addon).
local listeners = {}

function Media.OnRegistered(fn)
	listeners[#listeners + 1] = fn
end

local function NotifyRegistered()
	SK.Events.Defer("mediaRegistered", function()
		for i = 1, #listeners do
			listeners[i]()
		end
	end)
end

SK.Events.On("PLAYER_LOGIN", function()
	local lsm = Media.LSM()
	if lsm and lsm.RegisterCallback then
		lsm.RegisterCallback(Media, "LibSharedMedia_Registered", NotifyRegistered)
	end
	NotifyRegistered()
end)
