# Prompt: add ClaiibuAPI to an addon

Copy everything between the two `=====` lines into an AI assistant. Then fill in the `<ADDON>` block at the end, and attach or paste the addon's existing `.toc` and `.lua` files if it already exists.

For explanations of each feature rather than code, use `AI_GUIDE.md`.

=====

You are adding settings to a World of Warcraft: Forever addon using **ClaiibuAPI** (repository `cloudfan/ClaiibuAPI`, API level 1). ClaiibuAPI is a separate addon that this addon depends on; do not copy its code into the addon. Follow this specification exactly. Do not invent API functions that are not listed here.

## Platform rules

- Client: WoW: Forever. `.toc` line: `## Interface: 16001`. Lua 5.1: no `goto`, no `//`, no bitwise operators (use `bit.band` etc.), no `require`/`dofile`/`io`/`os`.
- Every Lua file starts with `local addonName, ns = ...`. Shared state lives on `ns`. Load order is the `.toc`.
- Do not create your own event frame. Use `kit.events.On(event, fn)` (several handlers per event are allowed). Do not poll with `OnUpdate` when an event exists.
- Saved variables exist only from `ADDON_LOADED`. Never read settings at file scope; use `kit:OnReady(fn)`.
- Before showing, hiding or moving a protected frame, check `InCombatLockdown()`; queue the work with `kit.events.AfterCombat(key, fn)`.
- Unit health, names and some booleans can be secret values. Never compare, branch on or print them without `issecretvalue`; pass health straight into `StatusBar:SetMinMaxValues`/`SetValue`.
- Do not use the combat log, `GetSpellInfo`/`GetItemInfo` globals (use `C_Spell`/`C_Item`), `ChatFrame_OpenChat`, or secure attributes on Blizzard frames.

## Files

The `.toc` must contain:

```
## Interface: 16001
## Title: <Title>
## Version: <x.y.z>
## Dependencies: ClaiibuAPI
## SavedVariables: <Name>DB
## SavedVariablesPerCharacter: <Name>CharDB

Settings.lua
<the addon's own files>
```

Put the settings setup in `Settings.lua`. It exposes the kit as `ns.kit` for the addon's other files.

## Settings.lua template

```lua
local addonName, ns = ...

local API = ClaiibuAPI and ClaiibuAPI.Require(1, addonName)
if not API then
	return
end

local kit = API.Settings.New(addonName, {
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

Every other file of the addon must check `if not ns.kit then return end` at the top, so it stays quiet if ClaiibuAPI is missing or too old. `ns.ApplySettings()` is written in the addon's own files. It reads `ns.kit.settings` and updates the addon's frames. It must be safe to call repeatedly and before any frames exist.

## API (complete)

`API.Settings.New(addonName, config)`: call once, at file scope. Config fields: `title` (default: the `.toc` Title), `version` (default: the `.toc` Version), `description`, `features` (list of strings), `savedVariable` (required), `charSavedVariable` (required), `defaults` (required), `onChange(key, value, kit)`, `onProfileChanged(kit)`, `onMediaRegistered(kit)`. Do not set `footer`.

`kit:AddPage(name)` returns a page. Each page appears under the addon in Options → AddOns. Page methods (all take one table unless noted):

| Method | Fields | Saved value |
| --- | --- | --- |
| `page:Header(text)` | text string | — |
| `page:Text(text)` | text string | — |
| `page:Checkbox{}` | `key`, `label`, `tooltip` | boolean |
| `page:Slider{}` | `key`, `label`, `tooltip`, `min`, `max`, `step`, `format` (`"%d"`, `"%.2f"`, `"%d%%"`, or a function) | number |
| `page:Dropdown{}` | `key`, `label`, `tooltip`, `options` = `{ { key = "a", label = "A" }, ... }` or a function returning that | string |
| `page:MediaDropdown{}` | `key`, `mediaType` (`"font"`, `"statusbar"`, `"border"`, `"background"`, `"sound"`), `label` (optional), `tooltip` | string media key |
| `page:Anchor{}` | `key`, `label` (optional, default "Anchor Point"), `tooltip` | `"TOPLEFT"`, `"TOP"`, `"TOPRIGHT"`, `"LEFT"`, `"CENTER"`, `"RIGHT"`, `"BOTTOMLEFT"`, `"BOTTOM"` or `"BOTTOMRIGHT"` |
| `page:FontShadow{}` | `key`, `label` (optional), `tooltip` | `"none"`, `"soft"`, `"hard"` or `"heavy"` |
| `page:Button{}` | `label` (row label, may be `""`), `text`, `tooltip`, `width`, `onClick(kit)`, `enabled(kit)` | — |

Rules: every `key` must exist in `defaults` with a value of the same type. Default values for media keys:

- font: `"default"`, `"friz"`, `"arialn"`, `"morpheus"` or `"skurri"`
- statusbar: `"flat"`, `"blizzard"`, `"raid"` or `"skills"`
- border: `"tooltip"`, `"dialog"`, `"dialoggold"`, `"dialogbronze"`, `"wood"`, `"party"`, `"bubble"`, `"toast"`, `"toastbronze"`, `"toastgold"`, `"solid"` or `"none"`
- background: `"solid"`, `"tooltip"`, `"dialog"`, `"dialogdark"`, `"dialoggold"`, `"marble"`, `"rock"`, `"parchment"` or `"none"`
- sound: `"none"`, `"raidwarning"`, `"readycheck"`, `"alarm"`, `"whisper"`, `"invite"` or `"mapping"`

Kit calls (only after `OnReady`):

| Call | Returns / does |
| --- | --- |
| `kit.settings.<key>` or `kit:Get(key)` | current value |
| `kit:Set(key, value)` | change a value from code (saves and refreshes the pages) |
| `kit:GetMedia(mediaType, key)` | `{ file, color = { r, g, b, a }, tile, tileSize, label }`; `file` is nil for "None" |
| `kit:ApplyFont(fontString, fontKey, sizeKeyOrNumber, shadowKey, flags)` | sets font, size, shadow (and optional `"OUTLINE"` flags) |
| `kit:ApplyAnchor(frame, pointKey, xKeyOrNumber, yKeyOrNumber, relativeTo)` | `ClearAllPoints` and `SetPoint(point, relativeTo or UIParent, point, x, y)` |
| `kit:PlaySound(key)` | plays a sound setting |
| `kit:Open(index)` | opens settings: 1 = landing page, then pages in order, then `kit:ProfilesIndex()` |
| `kit.events.On(event, fn)`, `kit.events.AfterCombat(key, fn)`, `kit.events.Defer(key, fn, delay)` | events, after-combat queue, next-frame run |
| `kit:Print(...)` | prints with the addon's name |
| `kit:ProbeRows()` | list of strings describing client API support |
| `kit:ShowProbe()` | shows the probe in a copy window (text selected, ready for Ctrl+C) |
| `kit:ShowCopy(title, linesOrString)` | shows any diagnostic text in the copy window; use it for every debug or diagnostic command instead of printing many chat lines. Never include secret values unchecked |

Applying media: for a backdrop use `bgFile = background.file`, `tile = background.tile`, `tileSize = background.tileSize`, `edgeFile = border.file`, `edgeSize = <size, or 0 when border.file is nil>`, then `frame:SetBackdropBorderColor(unpack(border.color))`. For a status bar use `bar:SetStatusBarTexture(kit:GetMedia("statusbar", "<key>").file)`. For positions use an `Anchor` setting plus two `Slider` offsets and `kit:ApplyAnchor`; if the frame is protected, wrap it in `kit.events.AfterCombat`.

Profiles (save, delete, export, import), the landing page and its footer are built by ClaiibuAPI. Do not add pages for them.

## Slash command (always include)

```lua
SLASH_<UPPERNAME>1 = "/<short>"
SlashCmdList.<UPPERNAME> = function(msg)
	if not ns.kit then return end
	local command = strlower(strtrim(msg or ""))
	if command == "probe" then
		ns.kit:ShowProbe()
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
4. A table of settings: key, type, default, page, and what it changes.
5. Install steps: copy the addon folder (named exactly like its `.toc`) and the `ClaiibuAPI` folder into `World of Warcraft\_classic_beta_\Interface\AddOns\`, then restart the client if the addon does not appear.

No fragments, no "rest unchanged". If an API the addon needs might not exist on Forever, say so and add a check for it to the probe command.

## <ADDON>

- Name / folder:
- Title:
- What it does:
- Settings wanted (name, type, range or choices, default, page):
- Existing files (paste below, or "new addon"):

=====
