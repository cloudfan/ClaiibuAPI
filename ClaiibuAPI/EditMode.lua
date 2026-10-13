local addonName, ns = ...

-- Edit Mode movers in Blizzard's style. While Blizzard's Edit Mode is open,
-- each registered frame gets a blue highlight; clicking it turns it yellow
-- with the addon's name, and dragging moves the frame and saves its
-- position. Settings can be given temporary values that last only while
-- Edit Mode is open (for example "show when solo" so there is something to
-- move).
--
-- Blizzard's Edit Mode is only listened to, never called: EditModeManagerFrame
-- methods are post-hooked, never invoked; nothing inherits Edit Mode
-- templates or registers as an Edit Mode system. Calling into it taints it.
--
-- The highlight is drawn from color textures, in colors measured from the
-- Forever client (build 70338): Blizzard's Edit Mode atlases have no usable
-- corners there, Texture:GetAtlas() returns nil, and BackdropTemplate's
-- border keys clash with NineSliceUtil's.
local SK = ns.SettingsKit
local EM = {}
SK.EditMode = EM

local PADDING = 6
local RADIUS = 7
local RINGS = 3
local SAMPLES = 4

local LOOKS = {
	highlight = {
		outer = { 0x41 / 255, 0xB2 / 255, 0xE2 / 255, 0.95 },
		inner = { 0xA4 / 255, 0xE4 / 255, 0xFF / 255, 1 },
		glow = 0.4,
		fill = { 121 / 255, 169 / 255, 189 / 255, 0.71 },
	},
	-- Estimated, not measured: replace with samples of Blizzard's own
	-- selected highlight when one is available.
	selected = {
		outer = { 0xE8 / 255, 0xB0 / 255, 0x20 / 255, 0.95 },
		inner = { 0xFF / 255, 0xE6 / 255, 0x8A / 255, 1 },
		glow = 0.4,
		fill = { 190 / 255, 165 / 255, 95 / 255, 0.6 },
	},
}

-- Every mover of every addon. Shared on purpose: selecting one deselects
-- the others, and Blizzard's Edit Mode opens and closes for all of them.
local movers = {}
local active = false

local function SafeCall(fn, ...)
	if not fn then
		return
	end
	local args, count = { ... }, select("#", ...)
	local ok, err = pcall(function()
		return fn(unpack(args, 1, count))
	end)
	if not ok then
		-- Reported like any other Lua error; one addon's error never stops
		-- another addon's mover.
		local handler = geterrorhandler and geterrorhandler()
		if handler then
			handler(err)
		end
	end
end

-- Drawing ----------------------------------------------------------------------

local function GlowColor(style)
	local f, g = style.fill, style.glow
	local a = 1 - (1 - g) * (1 - f[4])
	local function Channel(c)
		return (g + (1 - g) * f[4] * c) / a
	end
	return { Channel(f[1]), Channel(f[2]), Channel(f[3]), a }
end

-- Share of corner pixel (i, j) in each band: outside, outer, inner, glow, fill.
local function CornerCoverage(i, j)
	local cover = { 0, 0, 0, 0, 0 }
	local step = 1 / SAMPLES
	for sx = 1, SAMPLES do
		for sy = 1, SAMPLES do
			local x, y = i + (sx - 0.5) * step, j + (sy - 0.5) * step
			local d = math.sqrt((RADIUS - x) ^ 2 + (RADIUS - y) ^ 2)
			local band = 5
			if d > RADIUS then
				band = 1
			elseif d > RADIUS - 1 then
				band = 2
			elseif d > RADIUS - 2 then
				band = 3
			elseif d > RADIUS - RINGS then
				band = 4
			end
			cover[band] = cover[band] + step * step
		end
	end
	return cover
end

local coverage = {}
for n = 1, RADIUS * RADIUS do
	coverage[n] = CornerCoverage((n - 1) % RADIUS, math.floor((n - 1) / RADIUS))
end

local function MixColor(cover, colors)
	local r, g, b, a = 0, 0, 0, 0
	for band = 2, 5 do
		local c, share = colors[band], cover[band]
		if share > 0 then
			r, g, b = r + share * c[4] * c[1], g + share * c[4] * c[2], b + share * c[4] * c[3]
			a = a + share * c[4]
		end
	end
	if a <= 0 then
		return 0, 0, 0, 0
	end
	return r / a, g / a, b / a, a
end

local CORNERS = {
	{ "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 },
	{ "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 },
}

-- Builds the textures of one highlight on look (a plain frame, never
-- BackdropTemplate).
local function CreatePieces(look)
	local pieces = { corners = {}, bands = {}, fills = {} }
	local function NewTexture(sublevel)
		return look:CreateTexture(nil, "BORDER", nil, sublevel or 0)
	end
	for k, corner in ipairs(CORNERS) do
		local point, dx, dy = corner[1], corner[2], corner[3]
		pieces.corners[k] = {}
		for n = 1, RADIUS * RADIUS do
			local i, j = (n - 1) % RADIUS, math.floor((n - 1) / RADIUS)
			local t = NewTexture()
			t:SetSize(1, 1)
			t:SetPoint(point, look, point, dx * i, dy * j)
			pieces.corners[k][n] = t
		end
	end
	for ring = 1, RINGS do
		local o = ring - 1
		local top, bottom, left, right = NewTexture(), NewTexture(), NewTexture(), NewTexture()
		top:SetHeight(1)
		top:SetPoint("TOPLEFT", look, "TOPLEFT", RADIUS, -o)
		top:SetPoint("TOPRIGHT", look, "TOPRIGHT", -RADIUS, -o)
		bottom:SetHeight(1)
		bottom:SetPoint("BOTTOMLEFT", look, "BOTTOMLEFT", RADIUS, o)
		bottom:SetPoint("BOTTOMRIGHT", look, "BOTTOMRIGHT", -RADIUS, o)
		left:SetWidth(1)
		left:SetPoint("TOPLEFT", look, "TOPLEFT", o, -RADIUS)
		left:SetPoint("BOTTOMLEFT", look, "BOTTOMLEFT", o, RADIUS)
		right:SetWidth(1)
		right:SetPoint("TOPRIGHT", look, "TOPRIGHT", -o, -RADIUS)
		right:SetPoint("BOTTOMRIGHT", look, "BOTTOMRIGHT", -o, RADIUS)
		pieces.bands[ring] = { top, bottom, left, right }
	end
	local middle = NewTexture(-1)
	middle:SetPoint("TOPLEFT", look, "TOPLEFT", RADIUS, -RINGS)
	middle:SetPoint("BOTTOMRIGHT", look, "BOTTOMRIGHT", -RADIUS, RINGS)
	local left = NewTexture(-1)
	left:SetPoint("TOPLEFT", look, "TOPLEFT", RINGS, -RADIUS)
	left:SetPoint("BOTTOMRIGHT", look, "BOTTOMLEFT", RADIUS, RADIUS)
	local right = NewTexture(-1)
	right:SetPoint("TOPRIGHT", look, "TOPRIGHT", -RINGS, -RADIUS)
	right:SetPoint("BOTTOMLEFT", look, "BOTTOMRIGHT", -RADIUS, RADIUS)
	pieces.fills = { middle, left, right }
	return pieces
end

local function ApplyLook(pieces, selected)
	local style = LOOKS[selected and "selected" or "highlight"]
	local colors = { nil, style.outer, style.inner, GlowColor(style), style.fill }
	for ring = 1, RINGS do
		local c = colors[ring + 1]
		for _, line in ipairs(pieces.bands[ring]) do
			line:SetColorTexture(c[1], c[2], c[3], c[4])
		end
	end
	for _, fill in ipairs(pieces.fills) do
		fill:SetColorTexture(style.fill[1], style.fill[2], style.fill[3], style.fill[4])
	end
	for n = 1, RADIUS * RADIUS do
		local r, g, b, a = MixColor(coverage[n], colors)
		for k = 1, #CORNERS do
			pieces.corners[k][n]:SetColorTexture(r, g, b, a)
		end
	end
end

-- Geometry ---------------------------------------------------------------------

local function Scale(region)
	return region:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- Grows bounds (in UIParent units) by a shown region.
local function Extend(bounds, region)
	if not (region and region.IsShown and region:IsShown()) then
		return
	end
	local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
	if not (l and r and t and b) then
		return
	end
	local s = Scale(region)
	l, r, t, b = l * s, r * s, t * s, b * s
	bounds.left = math.min(bounds.left or l, l)
	bounds.right = math.max(bounds.right or r, r)
	bounds.top = math.max(bounds.top or t, t)
	bounds.bottom = math.min(bounds.bottom or b, b)
end

local function PointX(frame, point)
	if point:find("LEFT") then
		return frame:GetLeft()
	elseif point:find("RIGHT") then
		return frame:GetRight()
	end
	return (frame:GetLeft() + frame:GetRight()) / 2
end

local function PointY(frame, point)
	if point:find("TOP") then
		return frame:GetTop()
	elseif point:find("BOTTOM") then
		return frame:GetBottom()
	end
	return (frame:GetTop() + frame:GetBottom()) / 2
end

-- Mover ------------------------------------------------------------------------

local Mover = {}
Mover.__index = Mover

function Mover:Root()
	local frame = self.spec.frame
	if type(frame) == "function" then
		frame = frame()
	end
	return frame
end

function Mover:Regions()
	if self.spec.regions then
		return self.spec.regions() or {}
	end
	return { self:Root() }
end

function Mover:GetPosition()
	if self.spec.getPosition then
		return self.spec.getPosition()
	end
	local kit, keys = self.kit, self.keys
	return kit:GetSaved(keys.point), kit:GetSaved(keys.x), kit:GetSaved(keys.y)
end

function Mover:SetSelected(selected)
	self.selected = selected and true or false
	if self.frame then
		ApplyLook(self.pieces, self.selected)
		self.frame.Label:SetShown(self.selected)
	end
end

-- Places the root by its saved point; outside combat only.
function Mover:Reanchor()
	if self.spec.reanchor == false then
		return
	end
	local root = self:Root()
	local point, x, y = self:GetPosition()
	if not (root and point) then
		return
	end
	SK.Events.AfterCombat(self, function()
		root:ClearAllPoints()
		root:SetPoint(point, UIParent, point, x or 0, y or 0)
	end)
end

-- Keeps the saved anchor point; stores the offsets where the frame was dropped.
function Mover:SavePosition()
	local root = self:Root()
	local point = self:GetPosition() or "CENTER"
	if not (root and root:GetLeft() and UIParent:GetLeft()) then
		return
	end
	local rs, us = root:GetEffectiveScale(), UIParent:GetEffectiveScale()
	-- Offsets in the root's own units, as SetPoint uses them.
	local x = (PointX(root, point) * rs - PointX(UIParent, point) * us) / rs
	local y = (PointY(root, point) * rs - PointY(UIParent, point) * us) / rs
	x, y = math.floor(x + 0.5), math.floor(y + 0.5)
	if self.spec.savePosition then
		self.spec.savePosition(point, x, y)
	else
		self.kit:Set(self.keys.x, x)
		self.kit:Set(self.keys.y, y)
	end
	self:Reanchor()
end

function Mover:StopDrag()
	if self.dragging then
		self.dragging = false
		local root = self:Root()
		if root then
			root:StopMovingOrSizing()
		end
		self:SavePosition()
	end
end

function Mover:Resize()
	if not (self.active and self.frame) then
		return
	end
	local root = self:Root()
	if not root then
		return
	end
	local bounds = {}
	for _, region in ipairs(self:Regions()) do
		Extend(bounds, region)
	end
	local rootLeft, rootTop = root:GetLeft(), root:GetTop()
	local frame = self.frame
	frame:ClearAllPoints()
	if bounds.left and rootLeft and rootTop then
		local s = Scale(root)
		frame:SetPoint("TOPLEFT", root, "TOPLEFT",
			(bounds.left - rootLeft * s - PADDING) / s, (bounds.top - rootTop * s + PADDING) / s)
		frame:SetSize(bounds.right - bounds.left + 2 * PADDING, bounds.top - bounds.bottom + 2 * PADDING)
	else
		-- Nothing measurable is shown: cover the root itself.
		frame:SetPoint("TOPLEFT", root, "TOPLEFT", -PADDING, PADDING)
		frame:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", PADDING, -PADDING)
	end
end

-- Call after any layout change; resizes one frame later.
function Mover:UpdateBounds()
	if not self.active then
		return
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			self:Resize()
		end)
	else
		self:Resize()
	end
end

local function DeselectAll(except)
	for _, mover in ipairs(movers) do
		if mover ~= except and mover.selected then
			mover:SetSelected(false)
		end
	end
end

function Mover:Build()
	local root = self:Root()
	if self.frame or not root then
		return self.frame ~= nil
	end
	root:SetMovable(true)
	root:SetClampedToScreen(true)
	if root.SetDontSavePosition then
		root:SetDontSavePosition(true)
	end

	-- Parented to UIParent so it shows even while the root is hidden.
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:Hide()
	self.frame = frame

	local look = CreateFrame("Frame", nil, frame)
	look:SetAllPoints()
	self.pieces = CreatePieces(look)

	local label = frame:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(GameFontHighlightLarge or GameFontHighlight)
	label:SetPoint("CENTER")
	label:SetText(self.label)
	frame.Label = label
	self:SetSelected(false)

	frame:SetScript("OnMouseDown", function()
		DeselectAll(self)
		self:SetSelected(true)
	end)
	frame:SetScript("OnDragStart", function()
		DeselectAll(self)
		self:SetSelected(true)
		if not InCombatLockdown() then
			self.dragging = true
			self:Root():StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function()
		self:StopDrag()
	end)
	return true
end

function Mover:Enter()
	if self.active or InCombatLockdown() then
		return
	end
	if self.kit and self.spec.temporary then
		self.kit:SetTemporary(self.spec.temporary)
	end
	SafeCall(self.spec.onEnter, self.handle)
	if not self:Build() then
		return
	end
	self.active = true
	self:SetSelected(false)
	self.frame:Show()
	self:Resize()
	self:UpdateBounds()
end

function Mover:Exit()
	if self.active then
		self:StopDrag()
		self.active = false
		self:SetSelected(false)
		self.frame:Hide()
	end
	if self.kit and self.spec.temporary then
		local keys = {}
		for key in pairs(self.spec.temporary) do
			keys[#keys + 1] = key
		end
		self.kit:ClearTemporary(keys)
	end
	SafeCall(self.spec.onExit, self.handle)
end

-- Blizzard's Edit Mode --------------------------------------------------------------

local hooked = false

-- Deselect when Blizzard selects one of its own frames or clears the
-- selection. Post-hooks only: the manager is never called.
local function HookBlizzardSelection()
	local manager = EditModeManagerFrame
	if hooked or not (manager and hooksecurefunc) then
		return
	end
	hooked = true
	for _, method in ipairs({ "SelectSystem", "ClearSelectedSystem" }) do
		if type(manager[method]) == "function" then
			hooksecurefunc(manager, method, function()
				DeselectAll(nil)
			end)
		end
	end
end

local function OnEnter()
	active = true
	HookBlizzardSelection()
	for _, mover in ipairs(movers) do
		SafeCall(mover.Enter, mover)
	end
end

local function OnExit()
	active = false
	for _, mover in ipairs(movers) do
		SafeCall(mover.Exit, mover)
	end
end

if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("EditMode.Enter", OnEnter, EM)
	EventRegistry:RegisterCallback("EditMode.Exit", OnExit, EM)
	EM.listening = true
end

-- PLAYER_REGEN_DISABLED fires just before lockdown: the last moment a drag
-- can be ended and saved.
SK.Events.On("PLAYER_REGEN_DISABLED", function()
	for _, mover in ipairs(movers) do
		if mover.dragging then
			SafeCall(mover.StopDrag, mover)
		end
	end
end)

function EM.IsActive()
	return active
end

-- Public handle ----------------------------------------------------------------------

local Handle = {}
Handle.__index = Handle

function Handle:UpdateBounds()
	self.mover:UpdateBounds()
end

function Handle:IsActive()
	return self.mover.active
end

function Handle:IsSelected()
	return self.mover.selected
end

function Handle:Deselect()
	self.mover:SetSelected(false)
end

-- Places the frame at its saved position (outside combat, else after it).
function Handle:ApplyPosition()
	self.mover:Reanchor()
end

-- spec:
--   frame          the frame to move (or a function returning it); plain, not secure
--   label          name on the selected highlight (default: the addon's title)
--   pointKey, xKey, yKey   kit setting keys (default "point", "x", "y")
--   getPosition()  -> point, x, y      instead of kit keys
--   savePosition(point, x, y)          instead of kit keys
--   regions()      -> list of regions the highlight surrounds (default { frame })
--   temporary      { key = value } kit settings that hold these values only
--                  while Edit Mode is open (kit only)
--   onEnter(handle), onExit(handle)    show or hide previews and the like
--   reanchor       false to skip re-placing the frame after a drag
function EM.New(owner, spec, kit)
	assert(type(spec) == "table" and spec.frame, owner .. ": Edit Mode needs spec.frame")
	local mover = setmetatable({ owner = owner, spec = spec, kit = kit, active = false, selected = false }, Mover)
	if not (spec.getPosition and spec.savePosition) then
		if not kit then
			error(owner .. ": Edit Mode without a settings kit needs getPosition and savePosition", 2)
		end
		mover.keys = { point = spec.pointKey or "point", x = spec.xKey or "x", y = spec.yKey or "y" }
		for _, key in pairs(mover.keys) do
			if kit.defaults[key] == nil then
				error(owner .. ": Edit Mode position key \"" .. key .. "\" is not in the defaults", 2)
			end
		end
	end
	if spec.temporary and not kit then
		error(owner .. ": Edit Mode temporary values need a settings kit; use onEnter/onExit", 2)
	end
	mover.label = spec.label or (kit and kit.title) or (SK.Compat.AddOnTitle(owner))
	mover.handle = setmetatable({ mover = mover }, Handle)
	movers[#movers + 1] = mover
	-- Edit Mode may already be open (an addon loaded on demand).
	if active then
		SafeCall(mover.Enter, mover)
	end
	return mover.handle
end
