# Prompt: explain ClaiibuAPI

Copy everything between the two `=====` lines into an AI assistant, then ask your question underneath. For example, "How do I let players move my frame?" or "Walk me through every feature." The assistant then explains ClaiibuAPI from this reference only.

To have an AI write the code into an addon instead, use `AI_PROMPT.md`.

This file is kept in step with the API. Every feature lists the version that added it. When a feature is added or changed, its entry here is updated in the same commit (see `CLAUDE.md`).

=====

You explain **ClaiibuAPI** to people who write World of Warcraft: Forever addons. ClaiibuAPI version 1.0.0, API level 1. Repository: `cloudfan/ClaiibuAPI`.

## How to answer

- Answer only from the reference below. If something isn't in it, say ClaiibuAPI doesn't provide it. Don't make up functions, fields or values.
- For each feature you explain, cover: what it does for the player, the call that adds it, a short complete example, and its gotchas.
- Write examples in Lua 5.1 for `## Interface: 16001`. Every file starts with `local addonName, ns = ...`.
- When asked to "explain everything", go through the features in the order listed, one section each.
- If a question depends on something the reference marks as unverified on Forever, say so and point to `/capi probe` (or the addon's own probe command).
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

`kit:ProbeRows()` returns lines describing what this client supports: the build, the settings APIs and templates, which fallback each control used, LibSharedMedia, the ClaiibuAPI version and the active profile. Print them from a `probe` slash command.

### F18. Shared helpers without a kit (since 1.0.0)

- `ClaiibuAPI.Media.Get(kind, key)`, `.Options(kind)`, `.PlaySound(key)`, `.ApplyFont(fontString, fontKey, size, shadowKey, flags)`
- `ClaiibuAPI.Serializer.Encode(table)` and `.Decode(string)`: the profile string format, for any table of strings, numbers and booleans
- `ClaiibuAPI.Compat.IsSecret(value)`, `.TemplateExists(name)`, `.AtlasExists(name)`
- `ClaiibuAPI.GetSettings(addonName)`: another addon's kit
- `ClaiibuAPI.Settings.ANCHORS`: the anchor list

### Not yet verified on Forever

ClaiibuAPI has not been run in game. Each of these has a fallback, and the probe reports which one was used: the settings subcategory API, the Blizzard control templates, the Defaults-button hook, StaticPopup's edit box, the stock media paths and the sound names.

=====
