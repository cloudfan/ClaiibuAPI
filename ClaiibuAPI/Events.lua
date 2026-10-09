local addonName, ns = ...

-- ClaiibuAPI: shared code for Forever addons. Other addons list it under
-- ## Dependencies and reach it through the ClaiibuAPI global (API.lua).
-- Inside this addon, the modules live on ns.SettingsKit.
local SK = {}
ns.SettingsKit = SK

-- An event frame with a handler table keyed by event name. Each addon that
-- uses the API gets its own (kit.events), so one addon's error never stops
-- another's handlers. A handler table entry holds a list, so the kit and its
-- addon can both listen to the same event.
function SK.NewEvents()
	local Events = {}
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

	-- Returns false when this client does not know the event.
	function Events.On(event, fn)
		if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
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

	-- Runs fn now, or once combat ends. A later call with the same key
	-- replaces the queued closure, so repeated requests collapse into one.
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

	-- Runs fn on the next frame (or after delay seconds), once, however
	-- often it is asked for.
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

	return Events
end

-- The API's own events (LibSharedMedia registration).
SK.Events = SK.NewEvents()
