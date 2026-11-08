# Baganator Controller

Companion addon that makes [Baganator](https://www.curseforge.com/wow/addons/baganator)
work with the **World of Warcraft: Forever** Gamepad UI (the native controller
mode that is currently in beta).

It does nothing on other clients or while the Gamepad UI is switched off, so it
is safe to leave enabled.

## Installation

Requires Baganator and Syndicator (Syndicator is Baganator's own dependency).

* **CurseForge / Wago:** install the Forever-flavoured package next to
  Baganator.
* **Manual:** copy (or clone) this repository into
  `World of Warcraft\_forever_\Interface\AddOns\Baganator_Controller`
  (`_classic_beta_` while the beta client is still in use). The folder name
  must be `Baganator_Controller` to match the `.toc` file.

Enable the Gamepad UI in Options, open your bags and press the D-pad.

## What was broken

With the Gamepad UI enabled Baganator opens, but:

* the D-pad cursor never enters the bag window, so no item can be picked up,
  used or sold with a controller;
* at a vendor or bank, RT/LT cannot switch to the bags (Blizzard's bags do this);
* the radial menu's **Bags** entry toggles Blizzard's hidden bag frame instead
  of Baganator, so it appears to do nothing;
* when the bank opens, Blizzard registers its now-invisible `BankFrame` for
  controller focus, leaving the cursor on a frame you cannot see.

### Why

Blizzard's controller mode is driven by two systems in the Forever client:

* `GamepadMode.FrameControlsManager` (`Blizzard_GamepadSharedUtility`) keeps
  the list of open windows, decides which one has focus, pages between them
  with LT/RT and shows the focus glow and LT/RT hints.
* `SmartNavigation` (`Blizzard_GamepadSmartNavigation`) scans the focused
  window for buttons and moves the D-pad cursor between them.

A window takes part by calling `FrameControlsManager:FrameShown(frame)` when
it opens (Blizzard's windows do this automatically through `ShowUIPanel`, and
`ContainerFrameCombinedBags` does it in `ContainerFrame_OnShow`). Baganator
replaces Blizzard's bag and bank frames with its own windows, which are not UI
panels and never call `FrameShown`, so the controller systems do not know they
exist.

Until recently addons could not fix this themselves: the controller code was
secure-only, which is why other bag addons reported the problem as unfixable.
In build **1.60.1.70862** (November 7) Blizzard added a secure trampoline
(`Blizzard_GamepadSmartNavigation/SecureHelper.lua`) that lets addon code call
`FrameShown`/`FrameHidden`, `SetTargetButtonForFrame`, `RefreshButtonGroups`
and the `SmartNavigation_*` marker functions while out of combat, and invokes a
registered frame's `FocusGamepad`, `UnfocusGamepad`,
`SmartNavigationCloseHandler` and related callbacks through a taint barrier.
This addon is built on exactly that surface.

## What this addon does

* Finds every Baganator window through Baganator's public skin API
  (`Baganator.API.Skins`) and registers it with the focus manager while it is
  shown. Baganator's windows inherit `ButtonFrameTemplate`, which already
  carries Blizzard's focus glow and LT/RT jump-hint widgets, so those light up
  automatically.
* Starts the cursor on the top-left item and re-scans the window whenever
  Baganator finishes laying out items, so the cursor keeps up with bag updates.
* Keeps the cursor out of the search box (it needs a keyboard).
* Shows Blizzard-style button prompts under the focused window.
* Routes the radial menu's **Bags** entry to Baganator and keeps Blizzard's
  `IsBagOpen()` state truthful so the radial shows the bag as open/closed.
* Unregisters Blizzard's hidden `BankFrame`/`GuildBankFrame`/container frames
  if the client registers them for focus while Baganator is hiding them.
* Defers every call that Blizzard refuses in combat and re-syncs when combat
  ends (`PLAYER_REGEN_ENABLED`).

## Controls

| Button | Action |
| --- | --- |
| D-pad | Move the cursor between items, bag slots and toolbar buttons |
| A | Pick up / place / swap the item, or press the button under the cursor |
| B | Drop a held item; otherwise close the window |
| X | Context action on the item: **Sell** or **Repair** at a vendor, **Move** while the bank is open, otherwise **Open**, **Read**, **Equip** or **Use** |
| Y | More actions: Split Stack, Clean Up Bags, Bag Slots, Bank, All Characters, Currencies, Customise Baganator |
| LT / RT | Switch focus between the bags and other open windows (vendor, bank, character frame) |
| View / Back (left menu button) | Toggle UI focus on and off, as everywhere else in the Gamepad UI |

A and B are handled by Blizzard's own SmartNavigation bindings. X and Y are
bound through `SetOverrideBindingClick` on `UIParent` with the same priority
Blizzard's gamepad binding stack uses, so Blizzard's own rebinding of those
keys always wins; the handler also checks that a Baganator window is still the
focused frame before doing anything.

## Limitations

* Requires WoW Forever build 1.60.1.70862 or later. On earlier builds the
  controller code rejects addon calls outright and this addon stays dormant.
* Nothing can be registered or unregistered while you are in combat (Blizzard
  blocks those calls). Windows opened in combat become navigable when combat
  ends; windows closed in combat are cleaned up then.
* Typing into the search box still needs a keyboard.
* The guild bank window gets focus, cursor navigation and A/B; X performs a
  right click (withdraw) on the focused item.
* Destroying an item is intentionally not offered from the controller menu.

## Troubleshooting

Type `/bgrc` for a status report (whether the gamepad API was found, whether
the Gamepad UI is on, how many Baganator frames are known and registered, and
which frame is focused). `/bgrc debug` toggles verbose chat output.

If the chat shows "Interface action failed because of an AddOn", please
include the `/bgrc` output and what you were doing in a bug report.

## Compatibility notes for Forever

* Forever's interface number is `16001` (game version 1.60.1); the game type
  is `camelot`, with `forever` as an alias. The TOC declares both
  `## Interface: 16001` and `## AllowLoadGameType: camelot`, so the addon is
  never loaded on Retail or Classic clients even with "load out of date addons"
  enabled.
* `## Group: Baganator` nests the addon under Baganator in the AddOn list;
  the `## Category-*` lines mirror Baganator's so both sit in *Inventory*.
* Forever uses the modern (Midnight) API: `C_Item`, `C_Container`, the menu
  system (`MenuUtil`) and secret values. This addon only reads container item
  info and merchant/bank state, none of which are secret.

## Repository layout

```
Baganator_Controller.toc   load order and metadata
Locales.lua                strings, preferring Blizzard/Baganator translations
Constants.lua              names, window kinds, internal event names
Core.lua                   environment checks, shared helpers, internal events, init
Legend.lua                 button prompt footer under the focused window
Actions.lua                A/B/X/Y behaviour and the X/Y override bindings
Frames.lua                 discovery of Baganator windows, focus registration
BlizzardCompat.lua         radial menu and hidden Blizzard frame fixes
Commands.lua               /bgrc status command
tests/                     stub WoW environment and scripted smoke tests
.luacheckrc                static analysis configuration
.pkgmeta                   BigWigs packager configuration
.github/workflows/         CI: luacheck + smoke tests; release packaging on tags
```

## Development

The Lua files are plain WoW addon code (Lua 5.1). Two checks run in CI and can
be run locally:

```
# static analysis (https://github.com/lunarmodules/luacheck)
luacheck .

# scripted smoke tests against tests/wow_stubs.lua (Lua 5.1 via lupa)
pip install lupa
python3 tests/run.py
```

The stubs model only what this addon touches; they are a smoke test for load
order, undefined globals and control flow, not a substitute for testing in the
client. Any read of a global the stubs do not define fails the run.

### Releasing

Pushing an annotated tag such as `v1.0.0` runs the
[BigWigs packager](https://github.com/BigWigsMods/packager), which substitutes
`@project-version@` in the TOC, builds `Baganator_Controller.zip` and attaches
it to a GitHub release. The packager recognises the `16xxx` interface number and
tags the build for Forever. To also upload to CurseForge or Wago, add the
`CF_API_KEY` / `WAGO_API_TOKEN` repository secrets and the
`## X-Curse-Project-ID` / `## X-Wago-ID` lines to the TOC.

## License

MIT. This addon contains no Baganator code; Baganator is copyright plusmouse,
all rights reserved, and must be installed separately.
