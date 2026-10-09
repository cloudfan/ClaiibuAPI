# Updating addons to new ClaiibuAPI versions

Each entry is a prompt for an AI assistant. Paste the prompt, then the addon's `.toc` and `.lua` files under it. Newest first.

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
