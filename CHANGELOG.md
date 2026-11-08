# Changelog

## 1.0.0

Initial release for WoW Forever 1.60.1 (interface 16001), Gamepad UI beta.

* Registers Baganator's backpack, bank, guild bank, character select, currency
  and customise windows with Blizzard's gamepad focus manager while shown.
* D-pad navigation over items and buttons, A to pick up/place/press, B to drop
  a held item or close.
* Context action on X (Sell, Repair, Move, Open, Read, Equip, Use) and a
  more-actions menu on Y (Split Stack, Clean Up Bags, Bag Slots, Bank, All
  Characters, Currencies, Customise Baganator).
* Blizzard-style button prompts under the focused window; focus glow and LT/RT
  hints come from Blizzard's templates.
* Radial menu **Bags** entry opens and closes Baganator.
* Hidden Blizzard bank/bag frames are kept out of controller focus.
* Combat-safe: defers all restricted calls and re-syncs after combat.
