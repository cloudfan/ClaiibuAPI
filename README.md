# ClaiibuAPI

Shared code for World of Warcraft: Forever addons (`## Interface: 16001`). ClaiibuAPI is an addon of its own. Other addons list it under `## Dependencies`, so a fix or a new feature added here reaches every addon that uses it once players update ClaiibuAPI.

| Folder | What it is |
| --- | --- |
| `ClaiibuAPI/` | The API addon. Install it for any addon that depends on it. |
| `ClaiibuAPIDemo/` | A demo addon that uses every feature, and the template for a new addon. |
| `AI_PROMPT.md` | A prompt that has an AI add ClaiibuAPI to an addon. |
| `AI_GUIDE.md` | A prompt that has an AI explain how to use each feature. |
| `MIGRATIONS.md` | Prompts that have an AI update an existing addon after an API change, one per version. |

## What it gives an addon

- **A settings window** in Options → AddOns: the addon's landing page, with a collapsible sublist under it holding the addon's pages and then **Profiles**. These are Blizzard's settings subcategories.
- **Blizzard's own controls**: `MinimalSliderWithSteppersTemplate` sliders, `SettingsCheckboxTemplate` checkboxes, `UIPanelButtonTemplate` buttons and `SettingsDropdownWithButtonsTemplate` dropdowns (left and right steppers around a `WowStyle1DropdownTemplate` menu). Each has a fallback if the client lacks it.
- **Media dropdowns** (Font, Bar Texture, Border, Background, Sound) as one scrolling column. A **Blizzard** section comes first, including Bronze and Gold Toast borders and a Bronze Dialog border. After it come one section per addon that registered media with LibSharedMedia-3.0, titled with that addon's name.
- **Selectors** for the anchor point (TOP LEFT, TOP CENTER, TOP RIGHT, LEFT CENTER, CENTER, RIGHT CENTER, BOTTOM LEFT, BOTTOM CENTER, BOTTOM RIGHT) and the font shadow (None, Soft, Hard, Heavy).
- **Profiles** stored as compact strings. **Default-Global** holds the defaults. The Profiles page has Save, Delete, an Export box and an Import button.
- ~~A dispellable debuff tracker~~: deprecated in 1.6.0, because Forever hides auras from addons in combat.
- **Edit Mode support**: frames move in Blizzard's Edit Mode with its blue and yellow highlight, and settings can be switched on only while Edit Mode is open.
- **A reload prompt** (Reload UI / Ignore) for settings marked `reload = true`, whose changes can taint the UI until a reload.
- **A copy window** for diagnostic commands: the text opens already selected, so Ctrl+C copies it.
- **A standard landing page**: the name and version, a description and features, and the footer "Created for use by a lazy sack of shit, Maiibu. (And Friends)".

## Install

Copy both folders into:

```
World of Warcraft\_classic_beta_\Interface\AddOns\
```

so you have `AddOns\ClaiibuAPI\` and `AddOns\ClaiibuAPIDemo\`. When updating, replace **both** folders: the demo's commands only know the features of its own version. Players only need `ClaiibuAPI` plus the addons that use it. Restart the client if a new addon folder doesn't show up (`/reload` is not enough).

ClaiibuAPI's own commands (work without the demo):

| Command | What it does |
| --- | --- |
| `/claiibu probe` | Which APIs and templates this client has, and which ones ClaiibuAPI is using, in a copy window |
| `/claiibu version` | The installed ClaiibuAPI version and API level |

Demo commands (`ClaiibuAPIDemo`):

| Command | What it does |
| --- | --- |
| `/capi` | Open the demo's settings |
| `/capi profiles` | Open its Profiles page |
| `/capi probe` | The probe, with the demo's settings details |

## Use it in an addon

`.toc`:

```
## Interface: 16001
## Dependencies: ClaiibuAPI
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB

Settings.lua
MyAddon.lua
```

`Settings.lua` (see `ClaiibuAPIDemo/Demo.lua` for a complete example):

```lua
local addonName, ns = ...

local API = ClaiibuAPI and ClaiibuAPI.Require(1, addonName)
if not API then
	return
end

local kit = API.Settings.New(addonName, {
	description = "What the addon does.",
	features = { "First feature", "Second feature" },
	savedVariable = "MyAddonDB",
	charSavedVariable = "MyAddonCharDB",
	defaults = { point = "CENTER", x = 0, y = 0, font = "default", fontSize = 12, fontShadow = "soft", locked = false },
	onChange = function(key, value, kit) ns.Apply() end,
	onProfileChanged = function(kit) ns.Apply() end,
	onMediaRegistered = function(kit) ns.Apply() end,
})
ns.kit = kit

local page = kit:AddPage("General")
page:Header("Frame")
page:Checkbox({ key = "locked", label = "Lock Frame", tooltip = "..." })
page:Anchor({ key = "point" })
page:Slider({ key = "x", label = "X Offset", min = -500, max = 500, step = 1 })
page:Slider({ key = "y", label = "Y Offset", min = -500, max = 500, step = 1 })
page:MediaDropdown({ key = "font", mediaType = "font" })
page:Slider({ key = "fontSize", label = "Font Size", min = 8, max = 24, step = 1 })
page:FontShadow({ key = "fontShadow" })

kit:OnReady(function() ns.Apply() end)
```

Every `key` must exist in `defaults`, with a value of the same type. A page that uses a missing key raises an error at load.

### Page controls

| Method | Fields | Saved value |
| --- | --- | --- |
| `page:Header(text)` / `page:Text(text)` | — | — |
| `page:Checkbox{}` | `key`, `label`, `tooltip` | boolean |
| `page:Slider{}` | `key`, `label`, `tooltip`, `min`, `max`, `step`, `format` | number |
| `page:Dropdown{}` | `key`, `label`, `tooltip`, `options` (list of `{ key, label }`, or a function returning one) | string |
| `page:MediaDropdown{}` | `key`, `mediaType` (`font`, `statusbar`, `border`, `background`, `sound`), `label`, `tooltip` | media key |
| `page:Anchor{}` | `key`, `label`, `tooltip` | `TOPLEFT` … `BOTTOMRIGHT` |
| `page:FontShadow{}` | `key`, `label`, `tooltip` | `none`, `soft`, `hard`, `heavy` |
| `page:Color{}` | `key`, `label`, `tooltip`, `hasAlpha` | `{ r, g, b, a }` (0–1). A swatch with the hex code; clicking opens Blizzard's color picker, which previews live and restores the old color on Cancel. The default must be a color table |
| `page:Button{}` | `label`, `text`, `tooltip`, `width`, `onClick(kit)`, `enabled(kit)` | — |

Add `reload = true` to any control with a `key` whose change can taint the UI until a reload (hiding, moving or hooking Blizzard frames, secure frames, toggling whole modules). Changing it then shows a **Reload UI / Ignore** dialog that names the changed settings. It compares against the value the UI loaded with, asks once per slider drag, also asks after profile switches, imports and Defaults, and **Ignore** keeps the dialog away for a cooldown (config field `reloadCooldown`, seconds, default 60). While the dialog is open, further changes leave it as it is instead of reopening it.

### Kit calls

| Call | What it does |
| --- | --- |
| `kit.settings`, `kit:Get(key)` | The live settings of the active profile |
| `kit:Set(key, value)` | Change a setting from code. Saves it and refreshes the pages |
| `kit:GetColor(key)` | A color setting as `r, g, b, a`, e.g. `bar:SetStatusBarColor(kit:GetColor("barColor"))` |
| `kit:GetMedia(mediaType, key)` | `{ file, color, tile, tileSize, label }`. `color` is `{ r, g, b, a }`; apply a border's with `SetBackdropBorderColor` |
| `kit:ApplyFont(fontString, fontKey, size, shadowKey, flags)` | Font, size (number or setting key), shadow and optional flags |
| `kit:ApplyAnchor(frame, pointKey, x, y, relativeTo)` | `ClearAllPoints` + `SetPoint(point, relativeTo or UIParent, point, x, y)`. `x`/`y` may be setting keys |
| `kit:PlaySound(key)` | Play a sound setting |
| `kit:Open(index)` | Open the settings: 1 or nil is the landing page, then your pages in order, then Profiles (`kit:ProfilesIndex()`). Waits for combat to end |
| `kit:ResetProfile()` | Put the active profile back to the defaults |
| `kit.events` | The addon's own event frame: `On(event, fn)`, `Register(map)`, `AfterCombat(key, fn)`, `Defer(key, fn, delay)` |
| `kit:ProbeRows()` | Lines for a probe command |
| `kit:ShowProbe()` | The probe in the copy window |
| `kit:AddEditMode(spec)` | Edit Mode support for a frame; see [Edit Mode](#edit-mode). Returns a handle |
| `kit:SetTemporary(values)` / `kit:ClearTemporary(keys)` | Give settings values that apply but are never saved; clear them (all when `keys` is nil) |
| `kit:GetSaved(key)` | The saved value of a setting, ignoring temporary values |
| `kit:RequestReload(reason)` | Show the Reload UI / Ignore dialog from code, naming `reason`. Does nothing during the Ignore cooldown or while the dialog is open |
| `kit:ShowCopy(title, content, keepCodes)` | Show a string or a list of lines in the copy window, titled with the addon's name. The text opens selected for Ctrl+C; color codes are removed unless `keepCodes` is true |
| `kit:Print(...)` | Print with the addon's name |

### The ClaiibuAPI global

| Field | Contents |
| --- | --- |
| `VERSION`, `API_LEVEL` | The release version, and a number that goes up only when a change could break existing addons |
| `Require(level, addonName)` | Returns the API if it is at least that level, otherwise prints an update message and returns nil |
| `Settings.New(addonName, config)` | Creates the settings for an addon (once per addon) |
| `Settings.ANCHORS`, `Settings.FOOTER` | The anchor list and the footer text |
| `GetSettings(addonName)` | The kit an addon created |
| `Media.Get`, `Media.Options`, `Media.PlaySound`, `Media.ApplyFont`, `Media.SHADOWS`, `Media.KINDS` | Media without a kit |
| `Serializer.Encode`, `Serializer.Decode` | The profile string format, for other data |
| `Compat.IsSecret`, `Compat.TemplateExists`, `Compat.AtlasExists`, `Compat.ProbeRows` | Capability checks |
| `EditMode.New(addonName, spec)`, `EditMode.IsActive()` | Edit Mode movers without a kit (needs `getPosition`/`savePosition`); whether Blizzard's Edit Mode is open |
| `Dispel.*` | **Deprecated** (1.6.0): the dispellable debuff tracker. See [Dispellable debuffs](#dispellable-debuffs-deprecated) |
| `NewEvents()` | An event frame with a handler table, for an addon without a settings window |
| `ShowCopyText(title, content, keepCodes)`, `HideCopyText()` | The copy window without a kit |

## Edit Mode

Let players move an addon frame in Blizzard's Edit Mode, with a highlight drawn like Blizzard's own: blue while Edit Mode is open, yellow with the addon's name when clicked. Dragging saves the position.

### 1. Settings

The position is an anchor point plus two offsets. Add them to `defaults`, and optionally show them on a page:

```lua
defaults = { point = "CENTER", x = 0, y = 0, showSolo = false },
...
page:Anchor({ key = "point" })
page:Slider({ key = "x", label = "X Offset", min = -1000, max = 1000, step = 1 })
page:Slider({ key = "y", label = "Y Offset", min = -1000, max = 1000, step = 1 })
```

### 2. Register the frame

```lua
local mover = kit:AddEditMode({
	frame = function() return ns.root end,
	label = "My Addon",
	pointKey = "point", xKey = "x", yKey = "y",
	regions = function() return { ns.root, ns.nameplate } end,
	temporary = { showSolo = true },
	onEnter = function(mover) ns.ShowPreview(true) end,
	onExit = function(mover) ns.ShowPreview(false) end,
})
```

| Field | Required | What it does |
| --- | --- | --- |
| `frame` | yes | The frame to move, or a function returning it (for frames created later). A plain, non-secure frame that everything else is anchored to. |
| `label` | no | The name on the selected (yellow) highlight. Default: the addon's title. |
| `pointKey`, `xKey`, `yKey` | no | The settings holding the position. Default `"point"`, `"x"`, `"y"`. Each must be in `defaults`. |
| `getPosition()`, `savePosition(point, x, y)` | no | Use these instead of settings keys. Required with `ClaiibuAPI.EditMode.New` (no kit). |
| `regions()` | no | Returns the regions the highlight surrounds: every visible part, including parts that stick out. Default: `{ frame }`. Padding is 6. |
| `temporary` | no | `{ key = value }`: settings that hold these values only while Edit Mode is open, for example to show the frame when it is normally hidden. Never saved. |
| `onEnter(mover)`, `onExit(mover)` | no | Run when Edit Mode opens and closes, after `temporary` is applied and before it is cleared. Show and hide previews here. |
| `reanchor` | no | `false` to skip placing the frame after a drag (place it yourself in `onChange`). |

### 3. Keep it in step

```lua
function ns.Layout()
	kit:ApplyAnchor(ns.root, "point", "x", "y")  -- out of combat for secure children
	-- ... size and lay out the parts ...
	mover:UpdateBounds()                         -- re-fit the highlight, one frame later
end
```

Call `ns.Layout()` from `onChange`, `onProfileChanged` and `kit:OnReady`.

### What happens

| When | ClaiibuAPI |
| --- | --- |
| Edit Mode opens | Applies `temporary` (each changed key goes through `onChange`), calls `onEnter`, shows the blue highlight around `regions()`. |
| Click on the highlight | Turns it yellow and shows `label`; deselects every other addon's highlight. |
| Drag | Moves the frame (`StartMoving`, outside combat only). |
| Drop | Stores offsets from the saved anchor point with `kit:Set(xKey)`/`kit:Set(yKey)`, then places the frame with `SetPoint(point, UIParent, point, x, y)`. |
| Blizzard frame selected, or selection cleared | Back to blue, label hidden. |
| Combat starts mid-drag | Ends the drag and saves it (`PLAYER_REGEN_DISABLED`). |
| Edit Mode closes | Hides the highlight, clears `temporary`, calls `onExit`. |

### Handle

| Call | What it does |
| --- | --- |
| `mover:UpdateBounds()` | Re-fit the highlight after a layout change |
| `mover:ApplyPosition()` | Place the frame at its saved position (after combat if needed) |
| `mover:IsActive()`, `mover:IsSelected()` | Edit Mode open for this frame; highlight selected |
| `mover:Deselect()` | Back to blue |

### Temporary values without Edit Mode

`kit:SetTemporary({ key = value })` and `kit:ClearTemporary(keys)` work on their own too. The addon sees the temporary value in `kit.settings`; settings pages, profiles and the reload prompt use the saved value (`kit:GetSaved(key)`).

### Rules

- Never call `EditModeManagerFrame` methods, inherit `EditModeSystemSelectionTemplate`, or register an Edit Mode system. ClaiibuAPI only listens (`EventRegistry` "EditMode.Enter"/"EditMode.Exit" and post-hooks), and the addon must not do more.
- The moved frame must not be secure. Secure children are fine, but place the root outside combat (`kit:ApplyAnchor` inside `kit.events.AfterCombat` when needed).
- The yellow colors are estimates; the blue ones were measured on Forever build 70338.

## Dispellable debuffs (deprecated)

`ClaiibuAPI.Dispel` is **deprecated since 1.6.0**. Don't use it in new addons.

WoW: Forever does not let addons see dispellable debuffs in combat. Tested in game with 1.5.4 and 1.5.5:

- Every aura read from addon code fails once a debuff's data is secret: "Auras cannot be accessed when secret while tainted by '<addon>'". This applies to `GetAuraDataByIndex`, `GetAuraSlots`/`GetAuraDataBySlot` and `GetUnitAuras`, with every filter (`HARMFUL`, `RAID`, `RAID_PLAYER_DISPELLABLE`, `DISPELLABLE`, `RAID_IN_COMBAT`).
- Blizzard's party frames keep their dispel highlight in `DispelOverlay`, which is a forbidden object: "Attempt to access forbidden object from code tainted by an AddOn".

Blizzard's own party and raid frames still show dispellable debuffs in combat. Fading them with `SetAlpha(0)` hides that highlight too.

The calls still exist so addons written for 1.5.x keep working: out of combat `Dispel.Get` reads auras as before, and in combat it returns `nil, "blocked"`. The `/claiibu dispel` commands and the in-game diagnostics were removed (they are in v1.5.5 and in git history). `MIGRATIONS.md` has a prompt for taking the tracker out of an addon.
## Profiles

- Each profile is a string such as `PSK1:{s5:scalen1.5;s6:lockedT}` in the addon's account-wide saved variable. Only settings that differ from the defaults are written. Each character remembers its active profile in the per-character saved variable.
- Changes are written to the active profile as soon as you make them.
- **Save current settings...** asks for a name, prefilled with `Name-Realm`, and creates a new profile from the current settings. If the name is taken, it asks before replacing that profile.
- **Delete current profile...** asks "Are you sure?" first. If no profile is left afterwards, Default-Global is created again with the defaults.
- **Export and Import**: the box shows the active profile's code. Click it and press Ctrl+C to copy. To import, paste a code into the box and click **Import**; it asks for a name and saves the code as a new profile. Text that isn't a code, and codes from a different addon, are refused with a message in chat.
- Blizzard's **Defaults** button in the settings panel resets the active profile.
- If a profile string can't be read, the defaults are used and the old text is kept under `corrupt` in the saved variable.

## Updating ClaiibuAPI

- Add features without changing existing calls, so addons keep working.
- If a change could break an addon written for the current `API_LEVEL`, raise `API_LEVEL` in `ClaiibuAPI/API.lua` and say so in the release notes. Addons ask for a level with `ClaiibuAPI.Require`.
- Keep `AI_PROMPT.md` and `AI_GUIDE.md` in step with every change, and add an update prompt to `MIGRATIONS.md` whenever an API function is added, changed or removed. `CLAUDE.md` asks AI assistants working in this repository to do that.
- To release, bump `## Version` in `ClaiibuAPI/ClaiibuAPI.toc` and run the Release workflow (or push a `vX.Y.Z` tag).

## Not yet verified on Forever

Nothing has been run in game yet. Run `/claiibu probe` on your build and check:

- `Settings.RegisterCanvasLayoutCategory`/`Subcategory`. Without the Settings API, the pages open in a standalone window with the same list down the left.
- `EventRegistry` "EditMode.Enter"/"EditMode.Exit" and `EditModeManagerFrame.SelectSystem`/`ClearSelectedSystem` (Edit Mode). The probe shows whether ClaiibuAPI is listening.
- `BasicFrameTemplateWithInset` (the copy window's frame; a plain dialog frame is used without it).
- `SettingsCheckboxTemplate`, `SettingsDropdownWithButtonsTemplate` (and its `Dropdown`, `DecrementButton`, `IncrementButton` children), `MinimalSliderWithSteppersTemplate`, `ScrollFrameTemplate`, `InputScrollFrameTemplate`.
- The `OnDefault`/`OnRefresh` hooks that the settings panel calls on a canvas frame.
- StaticPopup: the edit box is read through `GetEditBox()`, `editBox` or `EditBox`, whichever the client has.
- The stock texture paths in `ClaiibuAPI/Media.lua` (Mainline paths) and the `SOUNDKIT` names. Sounds this client doesn't have are left out.
- LibSharedMedia doesn't record which addon registered an entry, so the section comes from the file path (`Interface\AddOns\<Folder>\...`). Entries pointing at Blizzard files go in the Blizzard section.

If settings don't persist between sessions, the beta client may be the cause. It was reported losing saved data before build 70009.
