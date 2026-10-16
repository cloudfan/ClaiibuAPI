local addonName, ns = ...

-- DEPRECATED (1.6.0). On Forever the client refuses aura data to addon code
-- in combat ("Auras cannot be accessed when secret while tainted by
-- <addon>"), and Blizzard's DispelOverlay is a forbidden object, so no
-- addon can track dispellable debuffs in combat. Confirmed in game with
-- 1.5.4 and 1.5.5. The calls below stay so existing addons keep working
-- (out of combat they still read auras; in combat Get returns nil,
-- "blocked"), but new code should not use them. The in-game diagnostics
-- used to find this are in git history (v1.5.5).

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
-- Every mode lets the client choose with an aura filter, so nothing secret
-- has to be read to find a match:
--   "player" (default)  HARMFUL|RAID                     this player can dispel
--   "group"             HARMFUL|RAID_PLAYER_DISPELLABLE  someone in the group can dispel
--   "any"               HARMFUL|DISPELLABLE              dispellable by anyone
-- In "group" and "any", a debuff whose readable type is "" (not dispellable)
-- is skipped, in case a client ignores a filter token it doesn't know.
local SK = ns.SettingsKit
local C = SK.Compat
local Dispel = {}
SK.Dispel = Dispel
Dispel.DEPRECATED = true

local MAX_AURAS = 40
local FILTER = {
	player = "HARMFUL|RAID",
	group = "HARMFUL|RAID_PLAYER_DISPELLABLE",
	any = "HARMFUL|DISPELLABLE",
}

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
		-- A whole aura table could be secret; never test or index it then.
		if C.IsSecret(aura) then
			return true, "(secret aura)"
		end
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
		-- The filter chose dispellable debuffs; a readable "" type means the
		-- client ignored the token, so that debuff is skipped.
		if mode == "player" or not Readable(dispelType) or dispelType ~= "" then
			return Result(unit, name, icon, count, dispelType, duration, expirationTime, spellId, auraInstanceID)
		end
	end
	return nil
end

-- Cache: unit -> mode -> result (false for "none"). Cleared by UNIT_AURA for
-- that unit, and entirely when units may have changed.
local cache = {}

-- The first dispellable debuff on unit, or nil.
-- mode: "player" (default; debuffs this player can dispel), "group"
-- (someone in the group can dispel) or "any" (dispellable by anyone).
-- Returns { name, type, icon, spellId, applications, duration,
-- expirationTime, auraInstanceID, color, secret = { field = true },
-- anySecret }. Fields listed in secret are secret values: show them
-- (SetText, SetTexture) but never compare or print them.
-- Forever refuses aura data to addon code in combat once it is secret
-- ("Auras cannot be accessed when secret while tainted by <addon>"), and
-- that cannot be worked around. After the first refusal, reads stop until
-- combat ends and Get reports "blocked", so an addon can show "unknown"
-- instead of "none".
local blocked = false

local function IsRefusal(message)
	return type(message) == "string" and message:find("cannot be accessed when secret", 1, true) ~= nil
end

function Dispel.IsBlocked()
	return blocked
end

-- Returns info, status. status is "found", "none" or "blocked" (the client
-- refused the read in combat; whether there is a debuff is unknown).
function Dispel.Get(unit, mode)
	if type(unit) ~= "string" then
		return nil, "none"
	end
	if blocked then
		return nil, "blocked"
	end
	if mode ~= "any" and mode ~= "group" then
		mode = "player"
	end
	local byMode = cache[unit]
	if byMode and byMode[mode] ~= nil then
		local cached = byMode[mode]
		return cached or nil, cached and "found" or "none"
	end
	-- Reading auras is not protected, but on Forever a secret value can make
	-- the read fail in combat. That must never become an error in the
	-- calling addon: the failure is kept for /claiibu dispel raw and nil is
	-- returned (not cached, so the next call tries again).
	local ok, result = pcall(Scan, unit, mode)
	if not ok then
		Dispel.lastError = { unit = unit, mode = mode, message = tostring(result) }
		if IsRefusal(result) and InCombatLockdown and InCombatLockdown() then
			blocked = true
			cache = {}
			return nil, "blocked"
		end
		return nil, "none"
	end
	cache[unit] = byMode or {}
	cache[unit][mode] = result or false
	return result, result and "found" or "none"
end

-- The last read that failed, as { unit, mode, message }, or nil.
function Dispel.LastError()
	return Dispel.lastError
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
		local info, status = Dispel.Get(unit)
		if status == "blocked" then
			lines[#lines + 1] = unit .. ": unknown - the client hides auras from addons in combat"
		elseif info then
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

SK.Events.On("PLAYER_REGEN_ENABLED", function()
	if blocked then
		blocked = false
		cache = {}
		-- Auras are readable again; let addons refresh every unit.
		Notify("player")
		for i = 1, 4 do
			Notify("party" .. i)
		end
		Notify("target")
	end
end)
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
	"UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_PET",
	"PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }) do
	SK.Events.On(event, ClearAll)
end
