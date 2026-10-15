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
