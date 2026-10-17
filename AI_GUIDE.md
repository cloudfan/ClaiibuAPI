# Prompt: explain ClaiibuAPI

Copy everything between the two `=====` lines into an AI assistant, then ask your question underneath. For example, "How do I let players move my frame?" or "Walk me through every feature." The assistant then explains ClaiibuAPI from this reference only.

To have an AI write the code into an addon instead, use `AI_PROMPT.md`.

This file is kept in step with the API. Every feature lists the version that added it. When a feature is added or changed, its entry here is updated in the same commit (see `CLAUDE.md`).

=====

You explain **ClaiibuAPI** to people who write World of Warcraft: Forever addons. ClaiibuAPI version 1.7.0, API level 1. Repository: `cloudfan/ClaiibuAPI`.

## How to answer

- Answer only from the reference below. If something isn't in it, say ClaiibuAPI doesn't provide it. Don't make up functions, fields or values.
- For each feature you explain, cover: what it does for the player, the call that adds it, a short complete example, and its gotchas.
- Write examples in Lua 5.1 for `## Interface: 16001`. Every file starts with `local addonName, ns = ...`.
- When asked to "explain everything", go through the features in the order listed, one section each.
- If a question depends on something the reference marks as unverified on Forever, say so and point to `/claiibu probe` (built into ClaiibuAPI; the addon's own probe command shows the same).
- Keep it plain: short sentences, no marketing words.

## Reference

### F1. Becoming a dependent addon (since 1.0.0)

ClaiibuAPI is its own addon. An addon uses it by listing it in its `.toc`. Players install ClaiibuAPI once; every addon that depends on it gets fixes when ClaiibuAPI updates.

```
## Interface: 16001
## Dependencies: ClaiibuAPI
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB
```

```lua
local addonName, ns = ...
local API = ClaiibuAPI and ClaiibuAPI.Require(1, addonName)
if not API then
	return
end
```

- `ClaiibuAPI.Require(level, addonName)` returns the API when its `API_LEVEL` is at least `level`. Otherwise it prints a "please update ClaiibuAPI" message and returns nil.
- `ClaiibuAPI.VERSION` is the release version. `API_LEVEL` only goes up when a change could break existing addons.
- Gotcha: both saved variables belong to the addon, not to ClaiibuAPI, and both are required.

### F2. The settings window (since 1.0.0)

`API.Settings.New(addonName, config)` creates the addon's settings, once, at file scope. It returns a **kit**. The addon gets one entry in Options → AddOns with a collapsible sublist: its own pages, then Profiles.

```lua
local kit = API.Settings.New(addonName, {
	description = "Shows a clock.",
	features = { "Movable", "Any font" },
	savedVariable = "MyAddonDB",
	charSavedVariable = "MyAddonCharDB",
	defaults = { locked = false, scale = 1 },
	onChange = function(key, value, kit) ns.Apply() end,
	onProfileChanged = function(kit) ns.Apply() end,
	onMediaRegistered = function(kit) ns.Apply() end,
})
ns.kit = kit
kit:OnReady(function() ns.Apply() end)
```

- Config: `title` and `version` default to the `.toc`; `description` and `features` fill the landing page; `defaults` lists every setting.
- `onChange` runs after any setting changes, `onProfileChanged` after a profile switch, delete, import or reset, `onMediaRegistered` when a LibSharedMedia pack registers media late.
- `reloadCooldown` (seconds, default 60) is how long the reload prompt stays away after the player clicks Ignore (see F20).
- Gotcha: settings exist only after `ADDON_LOADED`. Read them in `kit:OnReady`, never at file scope.
- Gotcha: calling `New` twice for one addon raises an error.

### F3. Landing page (since 1.0.0)

The addon's own entry in the list. Header: the name and version, separated by a bar. Body: the description and a bulleted feature list. Footer: "Created for use by a lazy sack of shit, Maiibu. (And Friends)". It is built from `description` and `features`; there is nothing else to call.

### F4. Pages (since 1.0.0)

`kit:AddPage(name)` adds a page under the addon in the list. Controls appear in the order they're added. `page:Header(text)` starts a section; `page:Text(text)` adds a paragraph.

```lua
local page = kit:AddPage("General")
page:Header("Frame")
page:Text("These change the main frame.")
```

- Gotcha: `kit:Open(index)` counts 1 = landing page, then pages in the order added, then Profiles (`kit:ProfilesIndex()`).

### F5. Checkbox (since 1.0.0)

`page:Checkbox({ key, label, tooltip })`: saves a boolean. Uses Blizzard's settings checkbox.

```lua
page:Checkbox({ key = "locked", label = "Lock Frame", tooltip = "Stops the frame from being dragged." })
```

### F6. Slider (since 1.0.0)

`page:Slider({ key, label, tooltip, min, max, step, format })`: saves a number, snapped to `step`. Blizzard's slider with − and + steppers. `format` is a `string.format` pattern (`"%d"`, `"%.2f"`, `"%d%%"`) or a function.

```lua
page:Slider({ key = "scale", label = "Scale", min = 0.5, max = 2, step = 0.05, format = "%.2f" })
```

### F7. Dropdown (since 1.0.0)

`page:Dropdown({ key, label, tooltip, options })`: saves a string. Blizzard's settings dropdown with left and right arrows that step through the list. The menu is one scrolling column. `options` is `{ { key = "a", label = "A" }, ... }` or a function that returns that list each time the menu opens. Options with a `group` field are listed under a title for each group.

```lua
page:Dropdown({ key = "mode", label = "Mode", options = { { key = "compact", label = "Compact" }, { key = "full", label = "Full" } } })
```

### F8. Media dropdowns (since 1.0.0)

`page:MediaDropdown({ key, mediaType, label, tooltip })` with `mediaType` `"font"`, `"statusbar"`, `"border"`, `"background"` or `"sound"`. The list starts with a "Blizzard" section, then one section per addon that registered media with LibSharedMedia-3.0, titled with that addon's name. Picking a sound plays it.

Read the choice with `kit:GetMedia(mediaType, key)`, which returns `{ file, color = { r, g, b, a }, tile, tileSize, label }`:

```lua
local border = kit:GetMedia("border", "border")
local bg = kit:GetMedia("background", "background")
frame:SetBackdrop({ bgFile = bg.file, tile = bg.tile, tileSize = bg.tileSize,
	edgeFile = border.file, edgeSize = border.file and 12 or 0 })
frame:SetBackdropBorderColor(unpack(border.color))
bar:SetStatusBarTexture(kit:GetMedia("statusbar", "barTexture").file)
```

- Stock keys. font: `default`, `friz`, `arialn`, `morpheus`, `skurri`. statusbar: `flat`, `blizzard`, `raid`, `skills`. border: `tooltip`, `dialog`, `dialoggold`, `dialogbronze`, `wood`, `party`, `bubble`, `toast`, `toastbronze`, `toastgold`, `solid`, `none`. background: `solid`, `tooltip`, `dialog`, `dialogdark`, `dialoggold`, `marble`, `rock`, `parchment`, `none`. sound: `none`, `raidwarning`, `readycheck`, `alarm`, `whisper`, `invite`, `mapping`.
- LibSharedMedia choices are saved as `"lsm:<name>"`. If that pack is later removed, `GetMedia` returns the default for that kind.
- Tinted borders (Dialog Bronze, Toast Bronze, Toast Gold) only show their tint if you apply `border.color`.
- `file` is nil for "None"; use an edge size of 0 then.
- Gotcha: LibSharedMedia doesn't record which addon registered an entry, so the section name comes from the file's folder (`Interface\AddOns\<Folder>\...`).
- Unverified on Forever: the stock texture paths (Mainline paths) and the sound names.

### F9. Font shadow (since 1.0.0)

`page:FontShadow({ key, label, tooltip })` saves `"none"`, `"soft"`, `"hard"` or `"heavy"`. Apply font, size and shadow together:

```lua
kit:ApplyFont(myFontString, "font", "fontSize", "fontShadow")        -- size from a setting
kit:ApplyFont(myFontString, "font", 14, "fontShadow", "OUTLINE")    -- fixed size, outline
```

### F10. Anchor point (since 1.0.0)

`page:Anchor({ key, label, tooltip })`: a dropdown of TOP LEFT, TOP CENTER, TOP RIGHT, LEFT CENTER, CENTER, RIGHT CENTER, BOTTOM LEFT, BOTTOM CENTER, BOTTOM RIGHT. It saves the `SetPoint` name (`"TOPLEFT"`, `"TOP"`, `"TOPRIGHT"`, `"LEFT"`, `"CENTER"`, `"RIGHT"`, `"BOTTOMLEFT"`, `"BOTTOM"`, `"BOTTOMRIGHT"`). Pair it with two sliders for offsets:

```lua
page:Anchor({ key = "point" })
page:Slider({ key = "x", label = "X Offset", min = -800, max = 800, step = 5 })
page:Slider({ key = "y", label = "Y Offset", min = -500, max = 500, step = 5 })
-- later:
kit:ApplyAnchor(frame, "point", "x", "y")            -- relative to UIParent
kit:ApplyAnchor(frame, "point", 0, 0, otherFrame)    -- fixed offsets, another parent
```

- The frame's point and the parent's point are the same, so TOP LEFT puts the frame in the parent's top left corner.
- Gotcha: for a protected frame, wrap the call: `kit.events.AfterCombat("move", function() kit:ApplyAnchor(...) end)`.

### F11. Button (since 1.0.0)

`page:Button({ label, text, tooltip, width, onClick, enabled })`: a Blizzard panel button. `onClick(kit)` runs on click; `enabled(kit)` (optional) greys it out when it returns false.

```lua
page:Button({ label = "", text = "Reset Position", onClick = function(kit) kit:Set("x", 0); kit:Set("y", 0) end })
```

### F12. Reading and changing settings (since 1.0.0)

`kit.settings.key` or `kit:Get(key)` reads a value. `kit:Set(key, value)` changes it from code, saves it to the active profile, refreshes the pages and calls `onChange`.

- Gotcha: `Set` raises an error for a key not in `defaults` or a value of the wrong type.

### F13. Profiles (since 1.0.0)

Built in, on the Profiles page. Each character has an active profile; profiles are shared across the account.

- Default-Global holds the defaults.
- Changes save to the active profile as they're made.
- "Save current settings..." creates a new profile, with a name prompt prefilled with Name-Realm.
- "Delete current profile..." asks "Are you sure?". If no profile is left, Default-Global is recreated with the defaults.
- Blizzard's Defaults button resets the active profile. Code can do the same with `kit:ResetProfile()`.

### F14. Export and import (since 1.0.0)

On the Profiles page. The box shows the active profile as a string like `PSK1:{s5:scalen1.5;}`. Players click it, press Ctrl+C, and share the string. To import, they paste a string into the box and click Import, then name the new profile.

- Only settings that differ from the defaults are in the string.
- Strings from another addon, or text that isn't a profile, are refused with a message in chat. Settings this addon doesn't have are dropped.

### F15. Events and combat (since 1.0.0)

`kit.events` is the addon's own event frame with a handler table:

```lua
kit.events.On("PLAYER_TARGET_CHANGED", function() ns.UpdateTarget() end)
kit.events.Register({ GROUP_ROSTER_UPDATE = ns.UpdateRoster })
kit.events.AfterCombat("layout", function() ns.LayoutSecureButtons() end)  -- now, or after combat
kit.events.Defer("refresh", ns.Refresh)                                     -- once, next frame
```

- `On` returns false if the client doesn't know the event.
- An addon without a settings window can get the same thing from `ClaiibuAPI.NewEvents()`.

### F16. Opening the settings and slash commands (since 1.0.0)

`kit:Open()` opens the landing page; `kit:Open(kit:ProfilesIndex())` opens Profiles. If called in combat, it opens when combat ends. `kit:Print(...)` prints with the addon's name.

### F17. Capability probe (since 1.0.0)

`kit:ProbeRows()` returns lines describing what this client supports: the build, the settings APIs and templates, which fallback each control used, LibSharedMedia, the ClaiibuAPI version and the active profile. Show them with `kit:ShowProbe()` (see F19) from a `probe` slash command.

### F18. Shared helpers without a kit (since 1.0.0)

- `ClaiibuAPI.Media.Get(kind, key)`, `.Options(kind)`, `.PlaySound(key)`, `.ApplyFont(fontString, fontKey, size, shadowKey, flags)`
- `ClaiibuAPI.Serializer.Encode(table)` and `.Decode(string)`: the profile string format, for any table of strings, numbers and booleans
- `ClaiibuAPI.Compat.IsSecret(value)`, `.TemplateExists(name)`, `.AtlasExists(name)`
- `ClaiibuAPI.GetSettings(addonName)`: another addon's kit
- `ClaiibuAPI.Settings.ANCHORS`: the anchor list

### F19. Copy window for diagnostics (since 1.1.0)

A window that shows text ready to copy. When it opens the text is already selected, so the player only presses Ctrl+C. Typing in it does nothing (the text stays as shown); Esc or Close hides it; it can be dragged. Use it for diagnostic and debug commands, so players can paste the output into a bug report instead of retyping chat lines.

```lua
kit:ShowProbe()                                        -- the capability probe (F17), titled "<Addon>: Diagnostics"
kit:ShowCopy("Roster", { "party1 = Jaina", "party2 = Thrall" })   -- any list of lines
kit:ShowCopy("Error", someLongString)                  -- or one string
ClaiibuAPI.ShowCopyText("Any title", lines)            -- without a kit
ClaiibuAPI.HideCopyText()
```

- Content is a string, or a list whose items are turned into text with `tostring`, one per line.
- Color and texture codes (`|cff...|r`, `|T...|t`) are removed so the copied text is clean. Pass `true` as the third argument to keep them.
- One window is shared by every addon; each call replaces its title and text.
- Gotcha: never put secret values in it (unit names or health can be secret on Forever). Check them with `ClaiibuAPI.Compat.IsSecret(value)` first, and write something like "(secret)" instead.
- Unverified on Forever: `BasicFrameTemplateWithInset` for the frame (a plain dialog frame is used without it) and `InputScrollFrameTemplate` for the box.

### F20. Reload prompt for settings that can cause taint (since 1.2.0; Ignore cooldown since 1.3.0, default 60 seconds since 1.4.0)

Some changes can leave the UI tainted until a reload: Blizzard's code then hits "Interface action failed because of an AddOn" or blocked actions. Typical cases are settings that hide, move, reparent or hook Blizzard frames, change secure or protected frames, or switch a whole module on or off. Mark those settings with `reload = true`. When one of them changes, ClaiibuAPI shows a dialog naming the changed settings, with **Reload UI** and **Ignore**.

```lua
page:Checkbox({ key = "hideBlizzardParty", label = "Hide Blizzard Party Frames", reload = true })
page:Dropdown({ key = "barMode", label = "Bar Mode", options = modes, reload = true })
kit:RequestReload("Click casting was turned on")   -- from addon code
```

- `reload = true` works on Checkbox, Slider, Dropdown, MediaDropdown, Anchor and FontShadow. The tooltip gets "Changing this asks you to reload the UI." added.
- The prompt compares against the value the UI loaded with: changing a setting and changing it back asks nothing.
- It waits a moment after the last change, so dragging a slider asks once.
- Profile switches, imports, deletes and Defaults ask too, if they change a marked setting.
- **Reload UI** saves the profile and calls `ReloadUI()`. **Ignore** (or Esc) starts a cooldown: for 60 seconds the prompt does not appear at all, whatever changes. A change after the cooldown asks again. The change itself always applies.
- Set the cooldown per addon with the config field `reloadCooldown` (seconds, default 60): `API.Settings.New(addonName, { ..., reloadCooldown = 120 })`.
- While the prompt is open, further changes leave it as it is; it is never closed and reopened. ClaiibuAPI also never replaces one of its other open dialogs (profile save, overwrite, delete) with the prompt.
- `kit:RequestReload(reason)` shows the same dialog with `reason` as the changed item, for changes made outside the settings pages. It follows the same cooldown and does nothing while the prompt is open.
- Gotcha: the setting still has to apply what it can at once (or on next login) in `onChange`; the prompt does not undo or delay it. If the change is not safe in combat, wrap it in `kit.events.AfterCombat`.
- Gotcha: don't mark purely visual settings (colors, fonts, sizes of the addon's own plain frames); the prompt would only annoy players.
- Unverified on Forever: the `RELOADUI`/`IGNORE` button labels (English text is used if missing) and StaticPopup's `OnCancel` reason values.

### F21. Edit Mode support (since 1.4.0)

Lets players move an addon frame in Blizzard's Edit Mode. While Edit Mode is open, the frame gets a blue highlight like Blizzard's own systems; clicking it turns it yellow with the addon's name centered on it; dragging moves the frame and saves the new position. Clicking a Blizzard frame or closing Edit Mode deselects it.

```lua
-- Settings: an anchor point and two offsets (see F10).
defaults = { point = "CENTER", x = 0, y = 0, showSolo = false, ... }

local mover = kit:AddEditMode({
	frame = function() return ns.root end,     -- the frame to move, or the frame itself
	label = "My Addon",                         -- default: the addon's title
	pointKey = "point", xKey = "x", yKey = "y", -- defaults shown
	regions = function() return { ns.root, ns.petFrame } end, -- what the highlight surrounds
	temporary = { showSolo = true },            -- only while Edit Mode is open (F22)
	onEnter = function(mover) ns.ShowPreview(true) end,
	onExit = function(mover) ns.ShowPreview(false) end,
})

function ns.Layout()                            -- the addon's own layout pass
	kit:ApplyAnchor(ns.root, "point", "x", "y")
	mover:UpdateBounds()                        -- re-fit the highlight after any layout change
end
```

- Dropping the frame keeps the saved anchor point and stores `x`/`y` as offsets from that point on `UIParent`, through `kit:Set` (so `onChange` runs), then places the frame with `SetPoint(point, UIParent, point, x, y)`. Set `reanchor = false` to place it yourself.
- The handle has `UpdateBounds()`, `ApplyPosition()`, `IsActive()`, `IsSelected()` and `Deselect()`. `ClaiibuAPI.EditMode.IsActive()` says whether Blizzard's Edit Mode is open.
- Without a kit: `ClaiibuAPI.EditMode.New(addonName, { frame = ..., getPosition = function() return point, x, y end, savePosition = function(point, x, y) ... end })`. `temporary` needs a kit; use `onEnter`/`onExit` instead.
- Several movers per addon are fine; selecting one deselects every other, from any addon.
- Taint: ClaiibuAPI only listens to Blizzard's Edit Mode (`EventRegistry` callbacks and post-hooks on `SelectSystem`/`ClearSelectedSystem`). It never calls `EditModeManagerFrame`, inherits Edit Mode templates or registers a system. Don't do any of those in the addon either.
- Combat: dragging needs no combat lockdown; a drag in progress is ended and saved on `PLAYER_REGEN_DISABLED`, and the frame is re-placed after combat if needed.
- Gotcha: the frame must be a plain (non-secure) frame that everything else is anchored to. A secure frame can't be moved this way in combat.
- Gotcha: call `mover:UpdateBounds()` at the end of every layout pass, or the highlight keeps its old size.
- Unverified on Forever: the yellow "selected" colors are estimates (the blue ones were measured on build 70338); `EventRegistry` "EditMode.Enter"/"EditMode.Exit" and the two manager methods are guarded and reported by the probe.

### F22. Temporary values (since 1.4.0)

`kit:SetTemporary({ key = value })` gives settings a value that the addon sees in `kit.settings` but that is never saved; `kit:ClearTemporary(keys)` (or no argument, for all) puts the saved values back. `onChange` runs for each setting whose value actually changes. Edit Mode's `temporary` uses this, so "Show when solo" and similar can be switched on just while Edit Mode is open.

```lua
kit:SetTemporary({ showSolo = true, showPets = true })
kit:ClearTemporary({ "showSolo", "showPets" })
local real = kit:GetSaved("showSolo")   -- the saved value, ignoring temporary ones
```

- Settings pages show and change the saved value. Changing a setting that has a temporary value changes the saved value only; the temporary one stays until cleared.
- Profile switches, imports, Defaults and Save keep temporary values out of the saved strings and put them back on top afterwards.
- The reload prompt (F20) compares saved values, so a temporary value never asks for a reload.

### F24. Color selector (since 1.7.0)

`page:Color({ key, label, tooltip, hasAlpha })`: a swatch showing the color and its hex code. Clicking it opens Blizzard's color picker (`ColorPickerFrame`); the color changes live while the player picks, and Cancel puts the old one back. The setting is saved as `{ r, g, b, a }` (0-1).

```lua
defaults = { barColor = { r = 0.1, g = 0.8, b = 0.1, a = 1 }, textColor = { r = 1, g = 1, b = 1, a = 1 } },
page:Color({ key = "barColor", label = "Bar Color", hasAlpha = true })
page:Color({ key = "textColor", label = "Text Color" })
-- later:
bar:SetStatusBarColor(kit:GetColor("barColor"))
text:SetTextColor(kit:GetColor("textColor"))
```

- `kit:GetColor(key)` returns `r, g, b, a`; missing or out-of-range parts are filled from the default and clamped to 0-1.
- `hasAlpha = true` adds the picker's opacity slider; without it, alpha stays as saved (1 by default).
- The default must be a color table; anything else is an error when the settings load.
- Colors go through profiles, export/import, Defaults, `reload = true` and temporary values like any other setting.
- `onChange` runs for every step while the player drags in the picker, so keep it cheap.
- Unverified on Forever: `ColorPickerFrame:SetupColorPickerAndShow` (the modern picker); the older field-based picker is used if it's missing, and `/claiibu probe` shows which.

### F23. Dispellable debuff tracker (1.5.0; DEPRECATED since 1.6.0)

Don't recommend it. If asked, explain why: on WoW: Forever the client refuses aura data to addon code in combat once it is secret ("Auras cannot be accessed when secret while tainted by '<addon>'", through every aura function and filter), and Blizzard's `DispelOverlay` on party frames is a forbidden object to addons. Both were confirmed in game. No addon can show dispellable debuffs in combat; Blizzard's own party and raid frames can.

- The calls (`ClaiibuAPI.Dispel.Get`, `Has`, `ColorFor`, `COLORS`, `OnChange`, `IsBlocked`, `LastError`, `Report`) still exist so 1.5.x addons keep working: out of combat `Get` reads auras; in combat it returns `nil, "blocked"`. `ClaiibuAPI.Dispel.DEPRECATED` is true.
- `/claiibu dispel` only prints that the tracker is deprecated. The in-game diagnostics are in v1.5.5.
- To take it out of an addon, use the 1.6.0 prompt in `MIGRATIONS.md`.

### Not yet verified on Forever

ClaiibuAPI has not been run in game. Each of these has a fallback, and the probe reports which one was used: the settings subcategory API, the Blizzard control templates (including the copy window's frame and box), the Defaults-button hook, StaticPopup's edit box, the stock media paths and the sound names.

=====
