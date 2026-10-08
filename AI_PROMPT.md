# Prompt: add Pillars Settings Kit to an addon

Copy everything between the two `=====` lines into an AI assistant. Then fill in the `<ADDON>` block at the end with your addon's details, and attach or paste the addon's existing `.toc` and `.lua` files if it already exists.

=====

You are adding settings to a World of Warcraft: Forever addon using **Pillars Settings Kit** (repository `cloudfan/ClaiibuAPI`, folder `PillarsSettingsKit/Kit`). Follow this specification exactly. Do not invent kit functions that are not listed here.

## Platform rules

- Client: WoW: Forever. `.toc` line: `## Interface: 16001`. Lua 5.1: no `goto`, no `//`, no bitwise operators (use `bit.band` etc.), no `require`/`dofile`/`io`/`os`.
- Every Lua file starts with `local addonName, ns = ...`. Shared state lives on `ns`. Load order is the `.toc`.
- Do not create your own event frame. Register events with `ns.SettingsKit.Events.On(event, fn)` (several handlers per event are allowed). Do not poll with `OnUpdate` when an event exists.
- Saved variables exist only from `ADDON_LOADED`. Never read settings at file scope; use `kit:OnReady(fn)`.
- Before showing, hiding or moving a protected frame, check `InCombatLockdown()`; queue the work with `ns.SettingsKit.Events.AfterCombat(key, fn)`.
- Unit health, names and some booleans can be secret values. Never compare, branch on or print them without `issecretvalue`; pass health straight into `StatusBar:SetMinMaxValues`/`SetValue`.
- Do not use the combat log, `GetSpellInfo`/`GetItemInfo` globals (use `C_Spell`/`C_Item`), `ChatFrame_OpenChat`, or secure attributes on Blizzard frames.

## Files

1. Copy the kit's `Kit` folder unchanged into the addon folder. Never edit kit files.
2. The `.toc` must contain, in this order:

```
## Interface: 16001
## Title: <Title>
## Version: <x.y.z>
## OptionalDeps: LibSharedMedia-3.0
## SavedVariables: <Name>DB
## SavedVariablesPerCharacter: <Name>CharDB

Kit\Events.lua
Kit\Compat.lua
Kit\Serializer.lua
Kit\Media.lua
Kit\Widgets.lua
Kit\Profiles.lua
Kit\Kit.lua
Settings.lua
<the addon's own files>
```

3. Put the kit setup in `Settings.lua`. It must expose the kit as `ns.kit` so the addon's other files can use it.

## Settings.lua template

```lua
local addonName, ns = ...

local kit = ns.SettingsKit.New({
	title = "<Title>",                      -- optional; defaults to ## Title
	description = "<one or two sentences>",
	features = { "<feature>", "<feature>" },
	savedVariable = "<Name>DB",
	charSavedVariable = "<Name>CharDB",
	defaults = {
		-- every setting, with its default value
	},
	onChange = function(key, value, kit) ns.ApplySettings() end,
	onProfileChanged = function(kit) ns.ApplySettings() end,
	onMediaRegistered = function(kit) ns.ApplySettings() end,
})
ns.kit = kit

local page = kit:AddPage("<Page Name>")
-- page:... calls, in display order

kit:OnReady(function()
	ns.ApplySettings()
end)
```

`ns.ApplySettings()` is written by you in the addon's own files. It reads `kit.settings` and updates the addon's frames. It must be safe to call repeatedly and before any frames exist.

## Kit API (complete)

`ns.SettingsKit.New(config)` — call once, at file scope. Config fields: `title`, `version`, `description`, `features` (list of strings), `footer` (leave unset), `savedVariable` (required), `charSavedVariable` (required), `defaults` (required), `onChange(key, value, kit)`, `onProfileChanged(kit)`, `onMediaRegistered(kit)`.

`kit:AddPage(name)` returns a page. Each page appears under the addon in Options → AddOns. Page methods (all take one table unless noted):

| Method | Fields | Saved value |
| --- | --- | --- |
| `page:Header(text)` | text string | — |
| `page:Text(text)` | text string | — |
| `page:Checkbox{}` | `key`, `label`, `tooltip` | boolean |
| `page:Slider{}` | `key`, `label`, `tooltip`, `min`, `max`, `step`, `format` (`"%d"`, `"%.2f"`, `"%d%%"`, or a function) | number |
| `page:Dropdown{}` | `key`, `label`, `tooltip`, `options` = `{ { key = "a", label = "A" }, ... }` or a function returning that | string |
| `page:MediaDropdown{}` | `key`, `mediaType` (`"font"`, `"statusbar"`, `"border"`, `"background"`, `"sound"`), `label` (optional), `tooltip` | string media key |
| `page:FontShadow{}` | `key`, `label` (optional), `tooltip` | `"none"`, `"soft"`, `"hard"` or `"heavy"` |
| `page:Button{}` | `label` (row label, may be `""`), `text`, `tooltip`, `width`, `onClick(kit)`, `enabled(kit)` | — |

Rules: every `key` must exist in `defaults` with a value of the same type. Default values for media keys:

- font: `"default"`, `"friz"`, `"arialn"`, `"morpheus"` or `"skurri"`
- statusbar: `"flat"`, `"blizzard"`, `"raid"` or `"skills"`
- border: `"tooltip"`, `"dialog"`, `"dialoggold"`, `"dialogbronze"`, `"wood"`, `"party"`, `"bubble"`, `"toast"`, `"toastbronze"`, `"toastgold"`, `"solid"` or `"none"`
- background: `"solid"`, `"tooltip"`, `"dialog"`, `"dialogdark"`, `"dialoggold"`, `"marble"`, `"rock"`, `"parchment"` or `"none"`
- sound: `"none"`, `"raidwarning"`, `"readycheck"`, `"alarm"`, `"whisper"`, `"invite"` or `"mapping"`

Reading settings (only after `OnReady`):

| Call | Returns / does |
| --- | --- |
| `kit.settings.<key>` or `kit:Get(key)` | current value |
| `kit:Set(key, value)` | change a value from code (saves and refreshes the pages) |
| `kit:GetMedia(mediaType, key)` | `{ file, color = { r, g, b, a }, tile, tileSize, label }`; `file` is nil for "None" |
| `kit:ApplyFont(fontString, fontKey, sizeKeyOrNumber, shadowKey, flags)` | sets font, size, shadow (and optional `"OUTLINE"` flags) |
| `kit:PlaySound(key)` | plays a sound setting |
| `kit:Open(index)` | opens settings: 1 = landing page, then pages in order, then `kit:ProfilesIndex()` |
| `kit:Print(...)` | prints with the addon's name |
| `kit:ProbeRows()` | list of strings describing client API support |

Applying media: for a backdrop use `bgFile = background.file`, `tile = background.tile`, `tileSize = background.tileSize`, `edgeFile = border.file`, `edgeSize = <size or 0 when border.file is nil>`, then `frame:SetBackdropBorderColor(unpack(border.color))`. For a status bar use `bar:SetStatusBarTexture(kit:GetMedia("statusbar", "<key>").file)`.

Profiles, export/import, the landing page and the footer are built by the kit. Do not add pages for them.

## Slash command (always include)

```lua
SLASH_<UPPERNAME>1 = "/<short>"
SlashCmdList.<UPPERNAME> = function(msg)
	local command = strlower(strtrim(msg or ""))
	if command == "probe" then
		for _, row in ipairs(ns.kit:ProbeRows()) do print(row) end
	elseif command == "profiles" then
		ns.kit:Open(ns.kit:ProfilesIndex())
	else
		ns.kit:Open()
	end
end
```

## Output

1. The complete `.toc`.
2. The complete `Settings.lua`.
3. Every other `.lua` file of the addon, complete, with the code that reads `ns.kit.settings` in `ns.ApplySettings()`.
4. A list of settings: key, type, default, page, and what it changes.
5. The install path: `World of Warcraft\_classic_beta_\Interface\AddOns\<FolderName>\` (folder name equals the `.toc` name), the reminder to copy the `Kit` folder there too, and to restart the client if the addon does not appear.

No fragments, no "rest unchanged". If an API the addon needs might not exist on Forever, say so and add a check for it to the probe command.

## <ADDON>

- Name / folder:
- Title:
- What it does:
- Settings wanted (name, type, range or choices, default, page):
- Existing files (paste below, or "new addon"):

=====
