local addonName, ns = ...

-- Dispellable debuffs. ClaiibuAPI.Dispel.Get(unit) returns the first
-- dispellable debuff on a unit, or nil.
--
-- Safe in combat: it only reads aura data (C_UnitAuras, or the older
-- UnitDebuff), never calls a protected function, hooks Blizzard frames or
-- touches secure attributes, so it cannot taint anything. On Forever some
-- aura fields can be secret values in combat. Those are never compared or
-- branched on: they are passed through as they are (FontString:SetText and
-- Texture:SetTexture accept them) and the result says which ones are secret.
--
-- "player" mode (the default) asks the client for the debuffs this player
-- can dispel (the HARMFUL|RAID filter), so the client decides and nothing
-- secret has to be read to find them. "any" mode returns the first debuff
-- with any dispel type; it has to read the type, so it skips debuffs whose
-- type is secret.
local SK = ns.SettingsKit
local C = SK.Compat
local Dispel = {}
SK.Dispel = Dispel

local MAX_AURAS = 40
local FILTER = { player = "HARMFUL|RAID", any = "HARMFUL" }

-- Dispel types as the client names them. Hexes and similar effects are not
-- a type of their own: each reports the type of its spell (Hex is a Curse).
Dispel.TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }

-- ClaiibuAPI's dispel colors, the same in every addon. { r, g, b, a } plus
-- named fields. Types without an entry (Bleed, Enrage) have no color.
Dispel.COLORS = {
	Magic = { 0.2, 0.5, 1, 0.85 },     -- #3380FF
	Curse = { 0.65, 0.2, 0.95, 0.85 }, -- #A633F2
	Poison = { 0.2, 0.9, 0.2, 0.85 },  -- #33E633
	Disease = { 0.6, 0.4, 0.0, 0.85 }, -- #966400
}
for _, color in pairs(Dispel.COLORS) do
	color.r, color.g, color.b, color.a = color[1], color[2], color[3], color[4]
end

local function Readable(value)
	return value ~= nil and not C.IsSecret(value)
end

-- The color of a dispel type ({ r, g, b, a }, also [1] to [4]), or nil for
-- an unknown or secret type.
function Dispel.ColorFor(dispelType)
	if not Readable(dispelType) then
		return nil
	end
	return Dispel.COLORS[dispelType]
end

local function HasType(dispelType)
	return Readable(dispelType) and dispelType ~= ""
end

local function Result(unit, name, icon, count, dispelType, duration, expirationTime, spellId, auraInstanceID)
	local secret = {}
	for field, value in pairs({ name = name, type = dispelType, icon = icon, spellId = spellId,
		applications = count, duration = duration, expirationTime = expirationTime }) do
		if C.IsSecret(value) then
			secret[field] = true
		end
	end
	return {
		unit = unit,
		name = name,
		type = dispelType,
		icon = icon,
		spellId = spellId,
		applications = count,
		duration = duration,
		expirationTime = expirationTime,
		auraInstanceID = auraInstanceID,
		color = (not secret.type) and Dispel.ColorFor(dispelType) or nil,
		secret = secret,
		anySecret = next(secret) ~= nil,
	}
end

-- Reads aura index i with the given filter. Returns nil when there is none.
local function ReadAura(unit, i, filter)
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
		if not aura then
			return nil
		end
		return true, aura.name, aura.icon, aura.applications, aura.dispelName, aura.duration,
			aura.expirationTime, aura.spellId, aura.auraInstanceID
	end
	if UnitDebuff then
		local name, icon, count, dispelType, duration, expirationTime, _, _, _, spellId = UnitDebuff(unit, i, filter)
		if name == nil then
			return nil
		end
		return true, name, icon, count, dispelType, duration, expirationTime, spellId, nil
	end
	return nil
end

local function Scan(unit, mode)
	local filter = FILTER[mode] or FILTER.player
	for i = 1, MAX_AURAS do
		local found, name, icon, count, dispelType, duration, expirationTime, spellId, auraInstanceID =
			ReadAura(unit, i, filter)
		if not found then
			return nil
		end
		-- In "player" mode the filter already chose dispellable debuffs.
		if mode ~= "any" or HasType(dispelType) then
			return Result(unit, name, icon, count, dispelType, duration, expirationTime, spellId, auraInstanceID)
		end
	end
	return nil
end

-- Cache: unit -> mode -> result (false for "none"). Cleared by UNIT_AURA for
-- that unit, and entirely when units may have changed.
local cache = {}

-- The first dispellable debuff on unit, or nil.
-- mode: "player" (default; debuffs this player can dispel) or "any".
-- Returns { name, type, icon, spellId, applications, duration,
-- expirationTime, auraInstanceID, color, secret = { field = true },
-- anySecret }. Fields listed in secret are secret values: show them
-- (SetText, SetTexture) but never compare or print them.
function Dispel.Get(unit, mode)
	if type(unit) ~= "string" then
		return nil
	end
	mode = mode == "any" and "any" or "player"
	local byMode = cache[unit]
	if byMode and byMode[mode] ~= nil then
		return byMode[mode] or nil
	end
	local result = Scan(unit, mode)
	cache[unit] = byMode or {}
	cache[unit][mode] = result or false
	return result
end

-- True when the unit has a dispellable debuff (same modes as Get).
function Dispel.Has(unit, mode)
	return Dispel.Get(unit, mode) ~= nil
end

-- Plain-text lines describing units' dispellable debuffs, for a copy
-- window or chat. Secret fields are written as "(secret)": they are never
-- concatenated, compared or printed.
local function Field(info, field)
	if info.secret[field] then
		return "(secret)"
	end
	return tostring(info[field])
end

function Dispel.Report(units)
	local lines = {}
	if not Dispel.IsSupported() then
		lines[1] = "This client has no aura API the dispel tracker can read."
		return lines
	end
	local combat = InCombatLockdown and InCombatLockdown()
	lines[1] = "In combat: " .. (combat and "yes" or "no")
	for _, unit in ipairs(units) do
		local info = Dispel.Get(unit)
		if info then
			lines[#lines + 1] = unit .. ": " .. Field(info, "name") .. " (" .. Field(info, "type") .. "), spell "
				.. Field(info, "spellId") .. ", stacks " .. Field(info, "applications")
		else
			lines[#lines + 1] = unit .. ": none you can dispel"
		end
		local any = Dispel.Get(unit, "any")
		if any and not info then
			lines[#lines + 1] = "  (someone else could dispel: " .. Field(any, "name") .. ", " .. Field(any, "type") .. ")"
		end
	end
	return lines
end

function Dispel.IsSupported()
	return (C_UnitAuras ~= nil and C_UnitAuras.GetAuraDataByIndex ~= nil) or UnitDebuff ~= nil
end

-- Change notifications: fn(unit) after a unit's auras change (UNIT_AURA),
-- so an addon can call Get again. Errors in one listener don't stop others.
local listeners = {}

function Dispel.OnChange(fn)
	listeners[#listeners + 1] = fn
end

local function Notify(unit)
	for i = 1, #listeners do
		local ok, err = pcall(listeners[i], unit)
		if not ok and geterrorhandler then
			geterrorhandler()(err)
		end
	end
end

SK.Events.On("UNIT_AURA", function(unit)
	if type(unit) == "string" then
		cache[unit] = nil
		Notify(unit)
	end
end)

-- Unit tokens can point at someone else after these.
local function ClearAll()
	cache = {}
end
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
	"UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_PET",
	"PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }) do
	SK.Events.On(event, ClearAll)
end

-- Combat recorder ----------------------------------------------------------------
-- Commands can't be typed in combat, so /claiibu dispel watch arms a
-- recorder: in combat it notes what Report sees for the watched units
-- whenever their auras change, and shows it all in the copy window when
-- combat ends. Each different line is kept once, up to MAX_RECORDED.

local WATCH_UNITS = { "player", "target", "party1", "party2", "party3", "party4" }
local MAX_RECORDED = 60
local recorder = { on = false }

local function Now()
	return GetTime and GetTime() or 0
end

local function Record(unit)
	if not (recorder.on and recorder.inCombat) then
		return
	end
	local lines = Dispel.Report({ unit })
	-- lines[1] is the "In combat" line; the rest describe the unit.
	for i = 2, #lines do
		local line = lines[i]
		if not recorder.seen[line] and #recorder.lines < MAX_RECORDED then
			recorder.seen[line] = true
			recorder.lines[#recorder.lines + 1] = format("[+%.1fs] %s", Now() - recorder.started, line)
		end
	end
end

local function WatchedUnit(unit)
	for _, watched in ipairs(WATCH_UNITS) do
		if unit == watched then
			return true
		end
	end
	return false
end

Dispel.OnChange(function(unit)
	if WatchedUnit(unit) then
		Record(unit)
	end
end)

SK.Events.On("PLAYER_REGEN_DISABLED", function()
	if not recorder.on then
		return
	end
	recorder.inCombat, recorder.started = true, Now()
	recorder.lines, recorder.seen = {}, {}
	for _, unit in ipairs(WATCH_UNITS) do
		Record(unit)
	end
end)

SK.Events.On("PLAYER_REGEN_ENABLED", function()
	if not (recorder.on and recorder.inCombat) then
		return
	end
	recorder.inCombat = false
	local lines = { format("Recorded in combat (%.0f seconds). Units: %s", Now() - recorder.started,
		table.concat(WATCH_UNITS, ", ")) }
	if #recorder.lines == 0 then
		lines[2] = "No unit had a debuff the tracker could see."
	else
		for i = 1, #recorder.lines do
			lines[#lines + 1] = recorder.lines[i]
		end
		if #recorder.lines >= MAX_RECORDED then
			lines[#lines + 1] = "(stopped after " .. MAX_RECORDED .. " lines)"
		end
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Still recording the next combat. /claiibu dispel watch turns it off."
	SK.CopyWindow.Show("ClaiibuAPI: Dispellable Debuffs in Combat", lines)
end)

-- Turns the recorder on or off; returns the new state.
function Dispel.ToggleWatch()
	recorder.on = not recorder.on
	recorder.inCombat = false
	return recorder.on
end
