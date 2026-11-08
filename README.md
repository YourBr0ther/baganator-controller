# Baganator Controller

Companion addon that makes [Baganator](https://www.curseforge.com/wow/addons/baganator)
work with the **World of Warcraft: Forever** Gamepad UI (the native controller
mode that is currently in beta).

Install it next to Baganator and Syndicator. It does nothing on other clients
or while the Gamepad UI is switched off, so it is safe to leave enabled.

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

## Development

The Lua files are plain WoW addon code. `tests/` holds a stub WoW environment
and a scripted walkthrough of the main scenarios:

```
pip install lupa
python3 tests/run.py
```

The stubs model only what this addon touches; they are a smoke test for load
order, nil globals and control flow, not a substitute for testing in the
client.

## License

MIT. This addon contains no Baganator code; Baganator is copyright plusmouse,
all rights reserved, and must be installed separately.
