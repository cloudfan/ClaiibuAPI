# ClaiibuAPI

Shared code for World of Warcraft: Forever addons (`## Interface: 16001`). ClaiibuAPI is an addon of its own. Other addons list it under `## Dependencies`, so a fix or a new feature added here reaches every addon that uses it once players update ClaiibuAPI.

| Folder | What it is |
| --- | --- |
| `ClaiibuAPI/` | The API addon. Install it for any addon that depends on it. |
| `ClaiibuAPIDemo/` | A demo addon that uses every feature, and the template for a new addon. |
| `AI_PROMPT.md` | A prompt that has an AI add ClaiibuAPI to an addon. |
| `AI_GUIDE.md` | A prompt that has an AI explain how to use each feature. |

## What it gives an addon

- **A settings window** in Options → AddOns: the addon's landing page, with a collapsible sublist under it holding the addon's pages and then **Profiles**. These are Blizzard's settings subcategories.
- **Blizzard's own controls**: `MinimalSliderWithSteppersTemplate` sliders, `SettingsCheckboxTemplate` checkboxes, `UIPanelButtonTemplate` buttons and `SettingsDropdownWithButtonsTemplate` dropdowns (left and right steppers around a `WowStyle1DropdownTemplate` menu). Each has a fallback if the client lacks it.
- **Media dropdowns** (Font, Bar Texture, Border, Background, Sound) as one scrolling column. A **Blizzard** section comes first, including Bronze and Gold Toast borders and a Bronze Dialog border. After it come one section per addon that registered media with LibSharedMedia-3.0, titled with that addon's name.
- **Selectors** for the anchor point (TOP LEFT, TOP CENTER, TOP RIGHT, LEFT CENTER, CENTER, RIGHT CENTER, BOTTOM LEFT, BOTTOM CENTER, BOTTOM RIGHT) and the font shadow (None, Soft, Hard, Heavy).
- **Profiles** stored as compact strings. **Default-Global** holds the defaults. The Profiles page has Save, Delete, an Export box and an Import button.
- **A standard landing page**: the name and version, a description and features, and the footer "Created for use by a lazy sack of shit, Maiibu. (And Friends)".

## Install

Copy both folders into:

```
World of Warcraft\_classic_beta_\Interface\AddOns\
```

so you have `AddOns\ClaiibuAPI\` and `AddOns\ClaiibuAPIDemo\`. Players only need `ClaiibuAPI` plus the addons that use it. Restart the client if a new addon folder doesn't show up (`/reload` is not enough).

Demo commands:

| Command | What it does |
| --- | --- |
| `/capi` | Open the demo's settings |
| `/capi profiles` | Open its Profiles page |
| `/capi probe` | List which APIs and templates this client has, and which ones ClaiibuAPI is using |

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
| `page:Button{}` | `label`, `text`, `tooltip`, `width`, `onClick(kit)`, `enabled(kit)` | — |

### Kit calls

| Call | What it does |
| --- | --- |
| `kit.settings`, `kit:Get(key)` | The live settings of the active profile |
| `kit:Set(key, value)` | Change a setting from code. Saves it and refreshes the pages |
| `kit:GetMedia(mediaType, key)` | `{ file, color, tile, tileSize, label }`. `color` is `{ r, g, b, a }`; apply a border's with `SetBackdropBorderColor` |
| `kit:ApplyFont(fontString, fontKey, size, shadowKey, flags)` | Font, size (number or setting key), shadow and optional flags |
| `kit:ApplyAnchor(frame, pointKey, x, y, relativeTo)` | `ClearAllPoints` + `SetPoint(point, relativeTo or UIParent, point, x, y)`. `x`/`y` may be setting keys |
| `kit:PlaySound(key)` | Play a sound setting |
| `kit:Open(index)` | Open the settings: 1 or nil is the landing page, then your pages in order, then Profiles (`kit:ProfilesIndex()`). Waits for combat to end |
| `kit:ResetProfile()` | Put the active profile back to the defaults |
| `kit.events` | The addon's own event frame: `On(event, fn)`, `Register(map)`, `AfterCombat(key, fn)`, `Defer(key, fn, delay)` |
| `kit:ProbeRows()` | Lines for a probe command |
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
| `NewEvents()` | An event frame with a handler table, for an addon without a settings window |

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
- Keep `AI_PROMPT.md` and `AI_GUIDE.md` in step with every change. `CLAUDE.md` asks AI assistants working in this repository to do that.
- To release, bump `## Version` in `ClaiibuAPI/ClaiibuAPI.toc` and run the Release workflow (or push a `vX.Y.Z` tag).

## Not yet verified on Forever

Nothing has been run in game yet. Run `/capi probe` on your build and check:

- `Settings.RegisterCanvasLayoutCategory`/`Subcategory`. Without the Settings API, the pages open in a standalone window with the same list down the left.
- `SettingsCheckboxTemplate`, `SettingsDropdownWithButtonsTemplate` (and its `Dropdown`, `DecrementButton`, `IncrementButton` children), `MinimalSliderWithSteppersTemplate`, `ScrollFrameTemplate`, `InputScrollFrameTemplate`.
- The `OnDefault`/`OnRefresh` hooks that the settings panel calls on a canvas frame.
- StaticPopup: the edit box is read through `GetEditBox()`, `editBox` or `EditBox`, whichever the client has.
- The stock texture paths in `ClaiibuAPI/Media.lua` (Mainline paths) and the `SOUNDKIT` names. Sounds this client doesn't have are left out.
- LibSharedMedia doesn't record which addon registered an entry, so the section comes from the file path (`Interface\AddOns\<Folder>\...`). Entries pointing at Blizzard files go in the Blizzard section.

If settings don't persist between sessions, the beta client may be the cause. It was reported losing saved data before build 70009.
