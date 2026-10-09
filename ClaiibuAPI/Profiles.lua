local addonName, ns = ...

-- Profiles. Each profile is one compact string (Serializer.lua) in the
-- account-wide saved variable. Each character remembers which profile it
-- uses in its per-character saved variable.
--
--   <savedVariable> = {
--       profiles = { ["Default-Global"] = "PSK1:{}", ["Maiibu-Area 52"] = "PSK1:{...}" },
--       corrupt = { [name] = "<string that would not decode>" },
--   }
--   <charSavedVariable> = { profile = "Maiibu-Area 52" }
local SK = ns.SettingsKit
local Serializer = SK.Serializer
local C = SK.Compat
local Profiles = {}
SK.Profiles = Profiles

Profiles.DEFAULT = "Default-Global"
Profiles.MAX_NAME = 48

function Profiles.CleanName(name)
	if type(name) ~= "string" then
		return nil
	end
	name = name:gsub("|", ""):gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		return nil
	end
	return name:sub(1, Profiles.MAX_NAME)
end

-- Default-Global first, then the rest alphabetically.
function Profiles.List(kit)
	local names = {}
	for name in pairs(kit.db.profiles) do
		if name ~= Profiles.DEFAULT then
			names[#names + 1] = name
		end
	end
	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)
	if kit.db.profiles[Profiles.DEFAULT] then
		table.insert(names, 1, Profiles.DEFAULT)
	end
	return names
end

local function DefaultsString(kit)
	return Serializer.EncodeSettings(kit.defaults, kit.defaults)
end

-- The profile to use when the remembered one is gone. Creates Default-Global
-- with the default settings if no profile is left.
local function Fallback(kit)
	if kit.db.profiles[Profiles.DEFAULT] then
		return Profiles.DEFAULT
	end
	local names = Profiles.List(kit)
	if names[1] then
		return names[1]
	end
	kit.db.profiles[Profiles.DEFAULT] = DefaultsString(kit)
	return Profiles.DEFAULT
end

local function Activate(kit, name)
	kit.charDB.profile = name
	local settings, err = Serializer.DecodeSettings(kit.db.profiles[name], kit.defaults)
	if err then
		-- Keep the unreadable string so it can be recovered by hand, and carry
		-- on with the defaults.
		kit.db.corrupt = kit.db.corrupt or {}
		kit.db.corrupt[name] = kit.db.profiles[name]
		kit.db.profiles[name] = DefaultsString(kit)
		kit:Print("Profile \"" .. name .. "\" could not be read (" .. tostring(err) .. "). It was reset to the defaults; the old text is kept in the saved variables under corrupt.")
	end
	kit.settings = settings
end

-- Called once, in ADDON_LOADED, after the saved variables exist.
function Profiles.Load(kit)
	local db = kit.db
	if type(db.profiles) ~= "table" then
		db.profiles = {}
	end
	for name, text in pairs(db.profiles) do
		if type(name) ~= "string" or type(text) ~= "string" then
			db.profiles[name] = nil
		end
	end
	local active = kit.charDB.profile
	if type(active) ~= "string" or not db.profiles[active] then
		active = Fallback(kit)
	end
	Activate(kit, active)
end

function Profiles.Active(kit)
	return kit.charDB.profile
end

-- Writes the live settings into the active profile's string.
function Profiles.Flush(kit)
	local text, err = Serializer.EncodeSettings(kit.settings, kit.defaults)
	if not text then
		kit:Print("Could not save the settings: " .. tostring(err))
		return false
	end
	kit.db.profiles[Profiles.Active(kit)] = text
	return true
end

function Profiles.Switch(kit, name)
	if not kit.db.profiles[name] or name == Profiles.Active(kit) then
		return
	end
	Profiles.Flush(kit)
	Activate(kit, name)
	kit:ProfileChanged()
end

-- Saves a profile string (the live settings when text is nil) under name,
-- replacing any profile of that name, and makes it active.
function Profiles.SaveAs(kit, name, text)
	name = Profiles.CleanName(name)
	if not name then
		return false
	end
	Profiles.Flush(kit)
	text = text or Serializer.EncodeSettings(kit.settings, kit.defaults)
	if not text then
		return false
	end
	kit.db.profiles[name] = text
	Activate(kit, name)
	kit:ProfileChanged()
	return true
end

-- The active profile as a string to copy.
function Profiles.Export(kit)
	Profiles.Flush(kit)
	return kit.db.profiles[Profiles.Active(kit)]
end

-- Checks a pasted string. Returns it rewritten in standard form (unknown
-- keys and wrong types dropped), or nil and the reason.
function Profiles.ParseImport(kit, text)
	if type(text) ~= "string" then
		return nil, "nothing to import"
	end
	text = text:gsub("%s", "")
	if text == "" then
		return nil, "the box is empty"
	end
	local stored, err = Serializer.Decode(text)
	if not stored then
		return nil, "that is not a settings string (" .. tostring(err) .. ")"
	end
	local any, known = false, false
	for key in pairs(stored) do
		any = true
		if kit.defaults[key] ~= nil then
			known = true
		end
	end
	if any and not known then
		return nil, "that string is for a different addon"
	end
	local settings = Serializer.DecodeSettings(text, kit.defaults)
	return Serializer.EncodeSettings(settings, kit.defaults)
end

function Profiles.Delete(kit, name)
	if not kit.db.profiles[name] then
		return
	end
	kit.db.profiles[name] = nil
	if Profiles.Active(kit) == name then
		Activate(kit, Fallback(kit))
	end
	kit:ProfileChanged()
end

-- Puts every setting of the active profile back to its default.
function Profiles.ResetActive(kit)
	kit.settings = Serializer.DeepCopy(kit.defaults)
	Profiles.Flush(kit)
	kit:ProfileChanged()
end

-- Dialogs ----------------------------------------------------------------------------
-- StaticPopup, as Blizzard's own confirmations use. A client without it gets
-- a small dialog built from Blizzard templates.

-- StaticPopup names carry the owning addon's name, so every addon that uses
-- the API has its own three dialogs.
local function PopupNames(kit)
	local prefix = "CLAIIBUAPI_" .. kit.addonName:upper()
	return { save = prefix .. "_SAVE_PROFILE", overwrite = prefix .. "_OVERWRITE_PROFILE",
		delete = prefix .. "_DELETE_PROFILE" }
end

local function EditBoxOf(dialog)
	if not dialog then
		return nil
	end
	if dialog.GetEditBox then
		return dialog:GetEditBox()
	end
	return dialog.editBox or dialog.EditBox
end

local fallbackDialog

-- spec: text, button1, button2, editText (nil = no edit box), onAccept(text)
local function ShowFallback(spec)
	local dialog = fallbackDialog
	if not dialog then
		dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		dialog:SetSize(360, 130)
		dialog:SetPoint("TOP", 0, -140)
		dialog:SetFrameStrata("FULLSCREEN_DIALOG")
		dialog:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", tile = true, tileSize = 32,
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 } })
		dialog:EnableMouse(true)
		dialog.text = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		dialog.text:SetPoint("TOP", 0, -20)
		dialog.text:SetWidth(320)
		dialog.edit = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
		dialog.edit:SetSize(240, 20)
		dialog.edit:SetPoint("TOP", dialog.text, "BOTTOM", 0, -10)
		dialog.edit:SetAutoFocus(false)
		dialog.accept = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
		dialog.accept:SetSize(110, 22)
		dialog.accept:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 16)
		dialog.cancel = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
		dialog.cancel:SetSize(110, 22)
		dialog.cancel:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 16)
		dialog.cancel:SetScript("OnClick", function()
			dialog:Hide()
		end)
		dialog.edit:SetScript("OnEscapePressed", function()
			dialog:Hide()
		end)
		fallbackDialog = dialog
	end
	dialog.text:SetText(spec.text)
	dialog.accept:SetText(spec.button1)
	dialog.cancel:SetText(spec.button2)
	local function Accept()
		local text = spec.editText and dialog.edit:GetText()
		dialog:Hide()
		spec.onAccept(text)
	end
	dialog.accept:SetScript("OnClick", Accept)
	dialog.edit:SetScript("OnEnterPressed", Accept)
	dialog.edit:SetShown(spec.editText ~= nil)
	dialog:Show()
	if spec.editText then
		dialog.edit:SetText(spec.editText)
		dialog.edit:SetFocus()
		dialog.edit:HighlightText()
	end
end

local function UsePopups()
	return StaticPopup_Show ~= nil and StaticPopupDialogs ~= nil
end

local function RegisterPopups(kit)
	local POPUP_SAVE, POPUP_OVERWRITE, POPUP_DELETE = kit.popups.save, kit.popups.overwrite, kit.popups.delete
	StaticPopupDialogs[POPUP_SAVE] = {
		text = "Save %s as a new profile named:",
		button1 = SAVE or "Save",
		button2 = CANCEL or "Cancel",
		hasEditBox = true,
		maxLetters = Profiles.MAX_NAME,
		OnShow = function(dialog, data)
			local edit = EditBoxOf(dialog)
			if edit then
				edit:SetText(data and data.default or "")
				edit:SetFocus()
				edit:HighlightText()
			end
		end,
		OnAccept = function(dialog, data)
			local edit = EditBoxOf(dialog)
			kit:RequestSaveAs(edit and edit:GetText(), data and data.text)
		end,
		EditBoxOnEnterPressed = function(edit, data)
			local name = edit:GetText()
			StaticPopup_Hide(POPUP_SAVE)
			kit:RequestSaveAs(name, data and data.text)
		end,
		EditBoxOnEscapePressed = function()
			StaticPopup_Hide(POPUP_SAVE)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs[POPUP_OVERWRITE] = {
		text = "A profile named \"%s\" already exists. Replace it?",
		button1 = YES or "Yes",
		button2 = NO or "No",
		OnAccept = function(_, data)
			Profiles.SaveAs(kit, data.name, data.text)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		showAlert = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs[POPUP_DELETE] = {
		text = "Delete the profile \"%s\"?\n\nAre you sure?",
		button1 = YES or "Yes",
		button2 = NO or "No",
		OnAccept = function(_, data)
			Profiles.Delete(kit, data.name)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		showAlert = true,
		preferredIndex = 3,
	}
end

function Profiles.InitDialogs(kit)
	kit.popups = PopupNames(kit)
	if UsePopups() then
		RegisterPopups(kit)
		SK.Widgets.used.dialogs = "StaticPopup"
	else
		SK.Widgets.used.dialogs = "fallback"
	end
end

-- "Save current settings..." (text nil), or naming an imported string.
function Profiles.PromptSave(kit, text, default)
	default = default or C.CharacterProfileName()
	local what = text and "the imported settings" or "the current settings"
	if UsePopups() then
		StaticPopup_Show(kit.popups.save, what, nil, { default = default, text = text })
		return
	end
	ShowFallback({
		text = format("Save %s as a new profile named:", what),
		button1 = SAVE or "Save",
		button2 = CANCEL or "Cancel",
		editText = default,
		onAccept = function(name)
			kit:RequestSaveAs(name, text)
		end,
	})
end

function Profiles.PromptOverwrite(kit, name, text)
	if UsePopups() then
		StaticPopup_Show(kit.popups.overwrite, name, nil, { name = name, text = text })
		return
	end
	ShowFallback({
		text = format("A profile named \"%s\" already exists. Replace it?", name),
		button1 = YES or "Yes",
		button2 = NO or "No",
		onAccept = function()
			Profiles.SaveAs(kit, name, text)
		end,
	})
end

-- "Import": checks the pasted string, then asks for the new profile's name.
function Profiles.PromptImport(kit, pasted)
	local text, err = Profiles.ParseImport(kit, pasted)
	if not text then
		kit:Print("Could not import: " .. err .. ".")
		return false
	end
	Profiles.PromptSave(kit, text, "Imported")
	return true
end

-- "Delete current profile..."
function Profiles.PromptDelete(kit)
	local name = Profiles.Active(kit)
	if UsePopups() then
		StaticPopup_Show(kit.popups.delete, name, nil, { name = name })
		return
	end
	ShowFallback({
		text = format("Delete the profile \"%s\"?\n\nAre you sure?", name),
		button1 = YES or "Yes",
		button2 = NO or "No",
		onAccept = function()
			Profiles.Delete(kit, name)
		end,
	})
end
