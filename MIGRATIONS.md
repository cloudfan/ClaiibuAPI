# Updating addons to new ClaiibuAPI versions

Each entry is a prompt for an AI assistant. Paste the prompt, then the addon's `.toc` and `.lua` files under it. Newest first.

## 1.5.0: dispellable debuff tracker

```
Update this World of Warcraft: Forever addon (Lua 5.1, ## Interface: 16001) to use ClaiibuAPI 1.5.0's dispellable debuff tracker.

1. Find the addon's own dispellable-debuff code: loops over C_UnitAuras.GetAuraDataByIndex, C_UnitAuras.GetAuraDataBySlot, AuraUtil.ForEachAura, UnitDebuff or UnitAura looking at dispelName/debuffType; its own dispel-type color tables; and its own UNIT_AURA handling done only for that purpose.
2. Replace the lookup with: local info = ClaiibuAPI.Dispel.Get(unit) (or ClaiibuAPI.Dispel.Get(unit, "any") where the addon wants every dispellable debuff, not just the ones this player can dispel). It returns the first dispellable debuff or nil, with name, type, icon, spellId, applications, duration, expirationTime, auraInstanceID, color ({ r, g, b, a }), secret ({ field = true }) and anySecret.
3. Use info.color for dispel-type colors and remove the addon's own color table for them. info.color is nil when the type is secret or has no color: keep the display's normal look then.
4. Refresh from ClaiibuAPI.Dispel.OnChange(function(unit) ... end) instead of the addon's own UNIT_AURA handler, if that handler only served dispel tracking. Keep UNIT_AURA handling that does other work.
5. Fields listed in info.secret are secret values: pass them straight to SetText/SetTexture; never compare, concatenate, tostring or print them.
6. Guard every use with if ClaiibuAPI.Dispel then ... end and keep the old code path in the else branch, so the addon still works on ClaiibuAPI older than 1.5.0. Keep ClaiibuAPI.Require(1, addonName). Add "Requires ClaiibuAPI 1.5.0 or newer for the dispel tracker" to the README or notes.
7. Do not change anything else. No new globals, no new event frames.

Output every changed file in full (no fragments, no "rest unchanged"), then list what you replaced.
```

## 1.4.0: Edit Mode support, temporary values, 60-second reload cooldown

```
Update this World of Warcraft: Forever addon (Lua 5.1, ## Interface: 16001) to use ClaiibuAPI 1.4.0's Edit Mode support.

1. Find the addon's own Edit Mode or mover code: anything using EventRegistry "EditMode.Enter"/"EditMode.Exit", EditModeManagerFrame, hooksecurefunc on Edit Mode, its own drag handles, highlight textures, StartMoving/StopMovingOrSizing on its main frame, or a "move"/"unlock" mode. Remove it; ClaiibuAPI replaces it. Remove any call into EditModeManagerFrame methods and any frame inheriting EditModeSystemSelectionTemplate, since those taint Edit Mode.
2. Make sure the position is stored as three settings in defaults: an anchor point and two offsets (for example point = "CENTER", x = 0, y = 0). If the addon stored its position differently, convert it once in kit:OnReady and keep the old values only for that conversion.
3. In Settings.lua, after the pages, add:
   ns.editMode = kit.AddEditMode and kit:AddEditMode({
       frame = function() return <the plain, non-secure root frame> end,
       pointKey = "<point key>", xKey = "<x key>", yKey = "<y key>",
       regions = function() return { <every visible part of the frame, including parts that stick out> } end,
       temporary = { <settings that must be on while Edit Mode is open, e.g. show when solo, show preview> },
       onEnter = function() <show sample/preview frames if the addon has them> end,
       onExit = function() <hide them> end,
   })
   Leave out temporary, onEnter and onExit if they are not needed.
4. Place the root with kit:ApplyAnchor(root, "<point key>", "<x key>", "<y key>") in the layout code, outside combat if anything secure is anchored to it, and end every layout pass with: if ns.editMode then ns.editMode:UpdateBounds() end
5. Replace any "show while unlocked/moving" flags that existed only for moving the frame with the temporary table from step 3.
6. If the addon set reloadCooldown = 300 only to copy the old default, remove it (the default is now 60).
7. Keep ClaiibuAPI.Require(1, addonName). The "kit.AddEditMode and" guard keeps older ClaiibuAPI versions working without Edit Mode. Add "Requires ClaiibuAPI 1.4.0 or newer for Edit Mode" to the README or notes.
8. Do not change anything else. No new globals, no new event frames.

Output every changed file in full (no fragments, no "rest unchanged"), then list: the root frame, the position keys, the regions, and the temporary settings you chose.
```

## 1.3.0: reload prompt cooldown after Ignore

```
Update this World of Warcraft: Forever addon (Lua 5.1, ## Interface: 16001) for ClaiibuAPI 1.3.0's reload prompt changes.

What changed in ClaiibuAPI: clicking Ignore on the "Reload UI / Ignore" prompt now starts a cooldown (default 300 seconds) during which the prompt does not appear at all, and an open prompt is never reopened. Before, Ignore muted only the listed settings until the next reload.

1. Find the ClaiibuAPI.Settings.New(addonName, { ... }) call. If the addon has settings marked reload = true that players change often (for example while dragging or stepping through values), add reloadCooldown = <seconds> to the config table only when the default of 300 seconds is clearly wrong for it. Otherwise change nothing here.
2. Find any code that works around repeated reload prompts: its own timers, flags, "already asked" checks, or StaticPopup_Hide/StaticPopup_Show calls around ns.kit:RequestReload. Remove them; ClaiibuAPI now handles both the cooldown and the open-prompt check.
3. Keep every reload = true flag and every ns.kit:RequestReload call as they are. Keep the "if ns.kit.RequestReload then" guards.
4. Keep ClaiibuAPI.Require(1, addonName). Older ClaiibuAPI versions ignore reloadCooldown, so no other check is needed. If you added reloadCooldown, add "Requires ClaiibuAPI 1.3.0 or newer for the reload prompt cooldown" to the README or notes.
5. Do not change anything else. No new globals, no new event frames, no popups of the addon's own.

Output every changed file in full (no fragments, no "rest unchanged"). If nothing needed to change, say so and output no files.
```

## 1.2.0: reload prompt for settings that can cause taint

```
Update this World of Warcraft: Forever addon (Lua 5.1, ## Interface: 16001) to use ClaiibuAPI 1.2.0's reload prompt.

1. Find every setting whose change can taint the UI until a reload: settings that hide, show, move, reparent, rescale or hook Blizzard frames (hooksecurefunc, SetScript or SetAlpha on Blizzard frames); that create, change or attach secure/protected frames, secure attributes, state drivers or unit watches; or that enable or disable a whole module doing any of those.
2. On each such setting's page control (page:Checkbox, Slider, Dropdown, MediaDropdown, Anchor or FontShadow), add reload = true. Leave purely visual settings of the addon's own plain frames alone.
3. Where code changes something taint-prone outside the settings pages (a slash command, a button), call ns.kit:RequestReload("<short description>") after making the change, guarded with: if ns.kit.RequestReload then ... end
4. Keep each setting's onChange behaviour as it is; the prompt only asks for a reload, it does not undo or delay the change. Keep InCombatLockdown checks and kit.events.AfterCombat where they already are.
5. Keep ClaiibuAPI.Require(1, addonName). Older ClaiibuAPI versions ignore reload = true, so no other check is needed. Add "Requires ClaiibuAPI 1.2.0 or newer for the reload prompt" to the README or notes.
6. Do not change anything else. No new globals, no new event frames, no popups of the addon's own.

Output every changed file in full (no fragments, no "rest unchanged"), then a list of the settings you marked and why each can cause taint.
```

## 1.1.0: diagnostic output goes to the copy window

```
Update this World of Warcraft: Forever addon (Lua 5.1, ## Interface: 16001) to ClaiibuAPI 1.1.0's copy window. Diagnostic output must go to the copy window, not chat.

1. Find every slash command or button that prints diagnostic, probe or debug output: loops of print() over rows, kit:ProbeRows() printing, dumps of settings, rosters or errors.
2. Replace them:
   - Probe output: ns.kit:ShowProbe()
   - Anything else: build a list of lines (or one string) and call ns.kit:ShowCopy("<short title>", lines). The window adds the addon name to the title, opens with the text selected for Ctrl+C, and strips color codes.
   - Code without a kit: ClaiibuAPI.ShowCopyText("<title>", lines)
3. Never put secret values in the lines. Check unit names, health and similar with ClaiibuAPI.Compat.IsSecret(value) and write "(secret)" instead.
4. Keep short one-line confirmations (e.g. "Position reset.") as kit:Print. Only multi-line or diagnostic output moves to the window.
5. ClaiibuAPI's API level is still 1, so keep ClaiibuAPI.Require(1, addonName). Before using the window, check for it with `if ns.kit.ShowCopy then ... else <old print code> end`, so the addon still works on ClaiibuAPI 1.0.0. Add "Requires ClaiibuAPI 1.1.0 or newer for the copy window" to the README or notes.
6. Do not change anything else. No new globals, no new event frames.

Output every changed file in full (no fragments, no "rest unchanged"), then a short list of which commands now use the copy window.
```

## 1.0.0: first release

Nothing to update. Use `AI_PROMPT.md` to add ClaiibuAPI to an addon.
