# ClaiibuAPI

Shared code for World of Warcraft: Forever addons (`## Interface: 16001`).

## Pillars Settings Kit

`PillarsSettingsKit/` is a settings framework plus a demo addon that uses it. It gives every addon the same settings window:

- One entry in Options → AddOns, with Blizzard tabs along the top: **About**, your pages, then **Profiles**.
- Blizzard's own controls: `TabSystemTemplate` tabs, `MinimalSliderWithSteppersTemplate` sliders, `SettingsCheckboxTemplate` checkboxes, `UIPanelButtonTemplate` buttons and `SettingsDropdownWithButtonsTemplate` dropdowns (left and right steppers around a `WowStyle1DropdownTemplate` menu). Each has a fallback if the client lacks it.
- Dropdowns are one scrolling column. Media dropdowns (Font, Bar Texture, Border, Background, Sound) list a **Blizzard** section first, then one section per addon that registered media with LibSharedMedia-3.0, titled with that addon's name.
- Profiles stored as compact strings, with **Default-Global** holding the defaults.
- A standard landing page: name and version, description and features, and the footer "Created for use by a lazy sack of shit, Maiibu. (And Friends)".

### Try the demo

Copy `PillarsSettingsKit` into:

```
World of Warcraft\_classic_beta_\Interface\AddOns\PillarsSettingsKit\
```

Restart the client if a new addon folder doesn't show up (`/reload` is not enough). Then:

| Command | What it does |
| --- | --- |
| `/psk` | Open the settings |
| `/psk profiles` | Open the Profiles tab |
| `/psk probe` | List which APIs and templates this client has, and which ones the kit is using |

### Use it in an addon

1. Copy the `Kit` folder into your addon.
2. List the kit files in your `.toc` before your own files, in this order, and declare two saved variables:

```
## Interface: 16001
## SavedVariables: MyAddonDB
## SavedVariablesPerCharacter: MyAddonCharDB

Kit\Events.lua
Kit\Compat.lua
Kit\Serializer.lua
Kit\Media.lua
Kit\Widgets.lua
Kit\Profiles.lua
Kit\Kit.lua
MyAddon.lua
```

3. Declare the settings at file scope (see `Demo.lua` for a complete example):

```lua
local addonName, ns = ...

local kit = ns.SettingsKit.New({
	title = "My Addon",                 -- default: the .toc ## Title
	description = "What the addon does.",
	features = { "First feature", "Second feature" },
	savedVariable = "MyAddonDB",
	charSavedVariable = "MyAddonCharDB",
	defaults = { scale = 1, font = "default", locked = false },
	onChange = function(key, value, kit) end,      -- after any change
	onProfileChanged = function(kit) end,          -- after a switch, delete or reset
	onMediaRegistered = function(kit) end,         -- a SharedMedia pack loaded late
})

local page = kit:AddPage("General")
page:Header("Frame")
page:Checkbox({ key = "locked", label = "Lock Frame", tooltip = "..." })
page:Slider({ key = "scale", label = "Scale", min = 0.5, max = 2, step = 0.05, format = "%.2f" })
page:Dropdown({ key = "mode", label = "Mode", options = { { key = "a", label = "A" }, { key = "b", label = "B" } } })
page:MediaDropdown({ key = "font", mediaType = "font" })   -- font, statusbar, border, background, sound
page:Button({ label = "", text = "Do Something", onClick = function(kit) end })
page:Text("A note under the controls.")

kit:OnReady(function(kit)
	-- Settings are loaded (ADDON_LOADED). Build your frames here.
	local fontFile = kit:GetMedia("font", "font").file
end)
```

Every `key` must exist in `defaults`, with a value of the same type. The kit raises an error at load if a page uses a key that isn't there.

| Call | What it does |
| --- | --- |
| `kit.settings`, `kit:Get(key)` | The live settings of the active profile |
| `kit:Set(key, value)` | Change a setting from code. Saves it and refreshes the pages |
| `kit:GetMedia(mediaType, key)` | `{ file, tile, tileSize, label }` for a media setting. Unknown or removed media gives the default |
| `kit:PlaySound(key)` | Play a sound setting |
| `kit:Open(tabIndex)` | Open the settings. Waits for combat to end |
| `kit:ResetProfile()` | Put the active profile back to the defaults |
| `kit:ProbeRows()` | Lines for a probe command |
| `ns.SettingsKit.Events.On(event, fn)` | Register for an event on the addon's single event frame (use this instead of making your own) |
| `ns.SettingsKit.Events.AfterCombat(key, fn)` | Run now, or once combat ends |

### Profiles

- Each profile is a string such as `PSK1:{s5:scalen1.5;s6:lockedT}` in the account-wide saved variable. Only settings that differ from the defaults are written. Each character remembers its active profile in the per-character saved variable.
- Changes are written to the active profile as soon as you make them.
- **Save current settings...** asks for a name, prefilled with `Name-Realm`, then creates that profile from the current settings and switches to it. If the name is already taken, it asks before replacing that profile.
- **Delete current profile...** asks "Are you sure?" first. If no profile is left afterwards, Default-Global is created again with the defaults.
- Blizzard's **Defaults** button in the settings panel resets the active profile.
- If a profile string can't be read, the kit uses the defaults and keeps the old text under `corrupt` in the saved variable.

### Not yet verified on Forever

The demo has not been run in game. Run `/psk probe` on your build and check:

- `TabSystemTemplate` and its methods (`AddTab`, `SetTabSelectedCallback`, `SetTab`). If they differ, the kit falls back to `PanelTopTabButtonTemplate`, then to plain buttons. The probe says which one it used.
- `SettingsCheckboxTemplate`, `SettingsDropdownWithButtonsTemplate` (and its `Dropdown`, `DecrementButton`, `IncrementButton` children), `MinimalSliderWithSteppersTemplate`, `ScrollFrameTemplate`.
- The `OnDefault`/`OnRefresh` hooks that the settings panel calls on a canvas frame.
- StaticPopup: the edit box is read through `GetEditBox()`, `editBox` or `EditBox`, whichever the client has.
- The stock texture paths in `Kit\Media.lua` (Mainline paths) and the `SOUNDKIT` names. Sounds this client doesn't have are left out of the list.
- LibSharedMedia doesn't record which addon registered an entry, so the section comes from the file path (`Interface\AddOns\<Folder>\...`). Entries that point at Blizzard files go in the Blizzard section, and copies of Blizzard entries that are already listed are left out.

If settings don't persist between sessions, the beta client may be the cause. It was reported losing saved data before build 70009.
