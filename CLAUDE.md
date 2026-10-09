# ClaiibuAPI

A dependency addon for World of Warcraft: Forever (`## Interface: 16001`, Lua 5.1). Other addons list it under `## Dependencies` and use the `ClaiibuAPI` global defined in `ClaiibuAPI/API.lua`.

## Layout

- `ClaiibuAPI/`: the API addon. Load order is `ClaiibuAPI.toc`: Events, Compat, Serializer, Media, Widgets, CopyWindow, Profiles, Settings, API. Internal modules live on `ns.SettingsKit`; only `API.lua` defines globals.
- `ClaiibuAPIDemo/`: a dependent demo addon that uses every feature (`/capi`).
- `AI_PROMPT.md`: prompt for an AI to add ClaiibuAPI to an addon.
- `AI_GUIDE.md`: prompt for an AI to explain each feature.
- `MIGRATIONS.md`: prompts for an AI to update existing addons after an API change, newest first.

## Rules for every change

- When you add, change or remove a feature, update **in the same commit**:
  1. `AI_GUIDE.md`: the feature's entry (or a new `F<n>` entry), with the version that added or changed it, an example and its gotchas. Update the version line at the top of the prompt.
  2. `AI_PROMPT.md`: the API tables, valid values and template, if the call surface changed.
  3. `README.md`: the tables of controls, kit calls and global fields.
  4. `ClaiibuAPIDemo/Demo.lua`: show the feature.
- **Update prompt for addons.** Whenever an API function is added, changed or removed (anything an addon calls: the `ClaiibuAPI` global, kit methods, page controls, config fields, saved-value formats), write a short prompt that tells an AI how to update an existing addon for the change. Add it at the top of `MIGRATIONS.md` under `## <version>: <one-line summary>`, in the same commit, and also give it to the user in your reply, ready to paste. The prompt states: the platform (Forever, Lua 5.1, `## Interface: 16001`); exactly which calls to find and what replaces them; how to stay working on older ClaiibuAPI versions (feature checks, or a raised `Require` level); what not to touch; and to output every changed file in full.
- Keep existing calls working. If a change could break an addon written for the current level, raise `API_LEVEL` in `ClaiibuAPI/API.lua` and note it in `AI_GUIDE.md`, `AI_PROMPT.md` (the `Require` level) and the release notes.
- Every kit is per addon: no module-level state that belongs to one addon (popups, windows and events are keyed by `kit.addonName`).
- Follow the Forever rules: every file starts with `local addonName, ns = ...`; one event frame per addon with a handler table; no combat log; guard secret values with `issecretvalue`; `InCombatLockdown()` before touching protected frames; probe templates with `C_XMLUtil.GetTemplateInfo` and keep a fallback.
- Check syntax with `luac5.1 -p` on every Lua file before committing.
- Releases: bump `## Version` in `ClaiibuAPI/ClaiibuAPI.toc` and run the Release workflow with tag `v<version>`.
