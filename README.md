# Baganator Controller

Gamepad UI support for [Baganator](https://www.curseforge.com/wow/addons/baganator) on World of Warcraft: Forever.

Baganator Controller registers Baganator's bag, bank and guild bank windows with the Forever client's native controller mode, giving them D-pad navigation, button prompts, focus switching with LT/RT and a working **Bags** entry in the radial menu.

## Features

- D-pad cursor navigation over items, bag slots and toolbar buttons in every Baganator window
- Pick up, place and swap items with A; drop a held item or close the window with B
- Context-aware X action: Sell or Repair at a vendor, Move while the bank is open, otherwise Open, Read, Equip or Use
- Y menu with Split Stack, Clean Up Bags, Bag Slots, Bank, All Characters, Currencies and Customise Baganator
- LT/RT focus switching between Baganator and other open windows, with Blizzard's focus glow and jump hints
- Radial menu **Bags** entry opens and closes Baganator
- Combat-safe: deferred registration while addon actions are restricted, re-synced when combat ends
- Inert outside Forever or while the Gamepad UI is off

## Requirements

| Requirement | Version |
| --- | --- |
| World of Warcraft: Forever | 1.60.1 build 70862 or later (interface `16001`) |
| [Baganator](https://www.curseforge.com/wow/addons/baganator) | 12.1.5 or later |
| [Syndicator](https://www.curseforge.com/wow/addons/syndicator) | Installed with Baganator |

The Gamepad UI must be enabled in the game's Options. On earlier Forever builds the client rejects addon access to the controller systems and this addon stays dormant.

## Installation

### CurseForge or Wago

Install **Baganator Controller** for the Forever game version alongside Baganator.

### Manual

1. Download the latest release zip from the [Releases](../../releases) page.
2. Extract it so that the folder is named `Baganator_Controller` and sits in your AddOns directory:

   ```
   World of Warcraft\_forever_\Interface\AddOns\Baganator_Controller\
   ```

   During the beta the client directory is `_classic_beta_` instead of `_forever_`.

3. Restart the client or type `/reload`.

## Usage

Enable the Gamepad UI, open your bags and use the controller.

| Button | Action |
| --- | --- |
| D-pad | Move the cursor |
| A | Pick up, place or swap the item; press the button under the cursor |
| B | Drop the held item, otherwise close the window |
| X | Context action on the item (Sell, Repair, Move, Open, Read, Equip, Use) |
| Y | More actions menu |
| LT / RT | Switch focus between open windows |
| View / Back | Toggle UI focus on and off |

### Commands

| Command | Description |
| --- | --- |
| `/bgrc` | Print a status report: gamepad API availability, Gamepad UI state, known and registered frames, focused frame |
| `/bgrc debug` | Toggle verbose chat output |

## Troubleshooting

- **The cursor does not enter the bag window.** Run `/bgrc`. If *Gamepad UI API available* is `no`, the client build is too old. If *Registered with the gamepad focus manager* is `0` while a window is open, you were likely in combat when it opened; it registers when combat ends.
- **"Interface action failed because of an AddOn" in chat.** Please open an issue with the `/bgrc` output and the steps that led to the message.
- **Typing in the search box.** The search box is excluded from controller navigation and still requires a keyboard.

## How it works

The Forever client drives its controller mode through two Blizzard systems: `GamepadMode.FrameControlsManager`, which tracks open windows and focus, and `SmartNavigation`, which scans the focused window for buttons and moves the D-pad cursor. Windows take part by calling `FrameControlsManager:FrameShown` when they open. Baganator's windows are not UI panels and never make that call.

This addon discovers Baganator's windows through `Baganator.API.Skins`, calls `FrameShown`/`FrameHidden` as they open and close, points the cursor at the top-left item and re-scans buttons after each Baganator layout pass. Prompts use Blizzard's footer with no bound functions. X and Y are bound with `SetOverrideBindingClick` at Blizzard's own priority, so Blizzard's rebinds replace them; X performs a right click on the focused item. Blizzard's combined bag frame state is mirrored so `IsBagOpen()` and the radial menu stay consistent, and hidden Blizzard bank and container frames are unregistered if the client registers them.

## Project layout

```
Baganator_Controller.toc   load order and metadata
Locales.lua                strings, preferring Blizzard and Baganator translations
Constants.lua              names, window kinds, internal event names
Core.lua                   environment checks, shared helpers, internal events, init
Legend.lua                 button prompt footer
Actions.lua                A/B/X/Y behaviour and X/Y override bindings
Frames.lua                 window discovery and focus registration
BlizzardCompat.lua         radial menu and hidden Blizzard frame handling
Commands.lua               /bgrc
tests/                     stub environment and smoke tests
```

## Development

Lua 5.1, no build step. Two checks run in CI (`.github/workflows/test.yml`) and locally:

```sh
# static analysis
luacheck .

# smoke tests against a stub client environment
pip install lupa
python3 tests/run.py
```

The smoke tests load the addon in TOC order against `tests/wow_stubs.lua` and cover login, window show/hide, focus, X/Y actions, combat deferral and mode switches. They verify control flow, not client behaviour; test changes in game as well.

### Releasing

Push an annotated tag (`v1.2.3`). The release workflow runs the [BigWigs packager](https://github.com/BigWigsMods/packager), substitutes `@project-version@` in the TOC, and attaches the zip to a GitHub release. Uploads to CurseForge and Wago are enabled by adding the `CF_API_KEY` and `WAGO_API_TOKEN` repository secrets and the `## X-Curse-Project-ID` / `## X-Wago-ID` TOC fields.

## Contributing

Issues and pull requests are welcome. Please include the `/bgrc` output and your Forever build number in bug reports, and run `luacheck .` and `python3 tests/run.py` before opening a pull request.

## License

[MIT](LICENSE). Baganator is a separate project by plusmouse and is not included in this repository.
