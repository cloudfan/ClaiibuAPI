# ClaiibuAPI

A dependency addon for World of Warcraft: Forever (`## Interface: 16001`, Lua 5.1). Other addons list it under `## Dependencies` and use the `ClaiibuAPI` global defined in `ClaiibuAPI/API.lua`.

## Layout

- `ClaiibuAPI/`: the API addon. Load order is `ClaiibuAPI.toc`: Events, Compat, Serializer, Media, Widgets, CopyWindow, Profiles, Settings, API. Internal modules live on `ns.SettingsKit`; only `API.lua` defines globals.
- `ClaiibuAPIDemo/`: a dependent demo addon that uses every feature (`/capi`).
- `AI_PROMPT.md`: prompt for an AI to add ClaiibuAPI to an addon.
- `AI_GUIDE.md`: prompt for an AI to explain each feature.

## Rules for every change

- When you add, change or remove a feature, update **in the same commit**:
  1. `AI_GUIDE.md`: the feature's entry (or a new `F<n>` entry), with the version that added or changed it, an example and its gotchas. Update the version line at the top of the prompt.
  2. `AI_PROMPT.md`: the API tables, valid values and template, if the call surface changed.
  3. `README.md`: the tables of controls, kit calls and global fields.
  4. `ClaiibuAPIDemo/Demo.lua`: show the feature.
- Keep existing calls working. If a change could break an addon written for the current level, raise `API_LEVEL` in `ClaiibuAPI/API.lua` and note it in `AI_GUIDE.md`, `AI_PROMPT.md` (the `Require` level) and the release notes.
- Every kit is per addon: no module-level state that belongs to one addon (popups, windows and events are keyed by `kit.addonName`).
- Follow the Forever rules: every file starts with `local addonName, ns = ...`; one event frame per addon with a handler table; no combat log; guard secret values with `issecretvalue`; `InCombatLockdown()` before touching protected frames; probe templates with `C_XMLUtil.GetTemplateInfo` and keep a fallback.
- Check syntax with `luac5.1 -p` on every Lua file before committing.
- Releases: bump `## Version` in `ClaiibuAPI/ClaiibuAPI.toc` and run the Release workflow with tag `v<version>`.
