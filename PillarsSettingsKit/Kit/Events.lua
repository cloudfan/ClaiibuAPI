local addonName, ns = ...

-- Pillars Settings Kit. Copy the Kit folder into an addon, list its files in
-- the addon's .toc (this file first), and reach it through ns.SettingsKit.
-- Nothing here creates a global apart from the StaticPopup entries, whose
-- names carry the addon's name.
local SK = ns.SettingsKit or {}
ns.SettingsKit = SK

-- One frame and one handler table for the whole addon. The kit and the host
-- addon both register here, so a handler table entry holds a list.
local Events = {}
SK.Events = Events

local handlers = {}
local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		list[i](...)
	end
end)

local function EventIsValid(event)
	if C_EventUtils and C_EventUtils.IsEventValid then
		return C_EventUtils.IsEventValid(event)
	end
	return true
end

-- Returns false when this client does not know the event.
function Events.On(event, fn)
	if not EventIsValid(event) then
		return false
	end
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		frame:RegisterEvent(event)
	end
	list[#list + 1] = fn
	return true
end

-- map is { EVENT_NAME = function(...) }.
function Events.Register(map)
	for event, fn in pairs(map) do
		Events.On(event, fn)
	end
end

-- Runs fn now, or once combat ends. A later call with the same key replaces
-- the queued closure, so repeated requests collapse into one.
local queue, queueOrder = {}, {}

function Events.AfterCombat(key, fn)
	if not InCombatLockdown() then
		fn()
		return
	end
	if not queue[key] then
		queueOrder[#queueOrder + 1] = key
	end
	queue[key] = fn
end

Events.On("PLAYER_REGEN_ENABLED", function()
	local order, pending = queueOrder, queue
	queue, queueOrder = {}, {}
	for i = 1, #order do
		pending[order[i]]()
	end
end)

-- Runs fn on the next frame, once, however often it is asked for.
local deferred = {}

function Events.Defer(key, fn, delay)
	if deferred[key] then
		return
	end
	if not (C_Timer and C_Timer.After) then
		fn()
		return
	end
	deferred[key] = true
	C_Timer.After(delay or 0, function()
		deferred[key] = nil
		fn()
	end)
end
