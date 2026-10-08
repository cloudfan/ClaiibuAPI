local addonName, ns = ...

-- Profiles are stored as compact strings. Only the settings that differ
-- from the defaults are written, and keys are sorted, so the same settings
-- always give the same string.
--
--   PSK1:{s4:sizen120;s9:showNamesF}
--
--   s<length>:<text>   string
--   n<number>;         number
--   T / F              true / false
--   { key value ... }  table (string and number keys only)
local SK = ns.SettingsKit
local Serializer = {}
SK.Serializer = Serializer

local PREFIX = "PSK1:"
local MAX_DEPTH = 16

local format, floor, abs = string.format, math.floor, math.abs

local function KeyLess(a, b)
	local ta, tb = type(a), type(b)
	if ta ~= tb then
		return ta == "number"
	end
	return a < b
end

local Encode

local function EncodeNumber(value, out)
	if value ~= value or value == math.huge or value == -math.huge then
		error("cannot store a non-finite number", 0)
	end
	-- %.0f, not %d: %d overflows above 2^31 on clients built with a 32-bit long.
	if value == floor(value) and abs(value) < 2 ^ 53 then
		out[#out + 1] = "n" .. format("%.0f", value) .. ";"
	else
		out[#out + 1] = "n" .. format("%.17g", value) .. ";"
	end
end

function Encode(value, out, depth)
	local kind = type(value)
	if kind == "string" then
		out[#out + 1] = "s" .. #value .. ":" .. value
	elseif kind == "number" then
		EncodeNumber(value, out)
	elseif kind == "boolean" then
		out[#out + 1] = value and "T" or "F"
	elseif kind == "table" then
		if depth >= MAX_DEPTH then
			error("settings are nested too deeply", 0)
		end
		local keys = {}
		for key in pairs(value) do
			local keyKind = type(key)
			if keyKind == "string" or keyKind == "number" then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys, KeyLess)
		out[#out + 1] = "{"
		for i = 1, #keys do
			Encode(keys[i], out, depth + 1)
			Encode(value[keys[i]], out, depth + 1)
		end
		out[#out + 1] = "}"
	else
		error("cannot store a " .. kind, 0)
	end
end

-- Returns the string, or nil and an error message.
function Serializer.Encode(tbl)
	local out = { PREFIX }
	local ok, err = pcall(Encode, tbl, out, 0)
	if not ok then
		return nil, err
	end
	return table.concat(out)
end

local Decode

function Decode(text, pos, depth)
	local tag = text:sub(pos, pos)
	if tag == "s" then
		local colon = text:find(":", pos + 1, true)
		local length = colon and text:sub(pos + 1, colon - 1)
		if not length or not length:match("^%d+$") then
			error("bad string length at " .. pos, 0)
		end
		length = tonumber(length)
		local value = text:sub(colon + 1, colon + length)
		if #value ~= length then
			error("string cut short at " .. pos, 0)
		end
		return value, colon + length + 1
	elseif tag == "n" then
		local semicolon = text:find(";", pos + 1, true)
		local value = semicolon and tonumber(text:sub(pos + 1, semicolon - 1))
		if not value or value ~= value then
			error("bad number at " .. pos, 0)
		end
		return value, semicolon + 1
	elseif tag == "T" then
		return true, pos + 1
	elseif tag == "F" then
		return false, pos + 1
	elseif tag == "{" then
		if depth >= MAX_DEPTH then
			error("nested too deeply", 0)
		end
		local tbl = {}
		pos = pos + 1
		while text:sub(pos, pos) ~= "}" do
			if pos > #text then
				error("table not closed", 0)
			end
			local key, value
			key, pos = Decode(text, pos, depth + 1)
			if type(key) ~= "string" and type(key) ~= "number" then
				error("bad table key at " .. pos, 0)
			end
			value, pos = Decode(text, pos, depth + 1)
			tbl[key] = value
		end
		return tbl, pos + 1
	end
	error("unexpected '" .. tag .. "' at " .. pos, 0)
end

-- Returns the table, or nil and an error message.
function Serializer.Decode(text)
	if type(text) ~= "string" or text:sub(1, #PREFIX) ~= PREFIX then
		return nil, "not a profile string"
	end
	local ok, value, pos = pcall(Decode, text, #PREFIX + 1, 0)
	if not ok then
		return nil, value
	end
	if type(value) ~= "table" then
		return nil, "not a table"
	end
	if pos ~= #text + 1 then
		return nil, "extra text after the profile"
	end
	return value
end

function Serializer.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = Serializer.DeepCopy(inner)
	end
	return copy
end

function Serializer.DeepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in pairs(a) do
		if not Serializer.DeepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- The settings that differ from the defaults, as a profile string.
function Serializer.EncodeSettings(settings, defaults)
	local diff = {}
	for key, default in pairs(defaults) do
		local value = settings[key]
		if value ~= nil and not Serializer.DeepEqual(value, default) then
			diff[key] = value
		end
	end
	return Serializer.Encode(diff)
end

-- A full settings table: the defaults with the profile laid over them. Keys
-- the defaults do not have, and values of the wrong type, are dropped.
function Serializer.DecodeSettings(text, defaults)
	local settings = Serializer.DeepCopy(defaults)
	local stored, err = Serializer.Decode(text)
	if not stored then
		return settings, err
	end
	for key, value in pairs(stored) do
		local default = defaults[key]
		if default ~= nil and type(value) == type(default) then
			settings[key] = value
		end
	end
	return settings
end
