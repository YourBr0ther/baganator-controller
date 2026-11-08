local _, addonTable = ...

-- Strings shown by this addon. Wherever Blizzard or Baganator already ship a
-- localized string for the same concept we use theirs at runtime (see
-- addonTable.Locales.Get), so this table only has to carry English fallbacks.
local L = {
  ADDON_NAME = "Baganator Controller",
  SELECT = "Select",
  PLACE = "Place",
  PICK_UP = "Pick Up",
  CLOSE = "Close",
  BACK = "Back",
  MORE_ACTIONS = "More Actions",
  USE = "Use",
  EQUIP = "Equip",
  READ = "Read",
  OPEN = "Open",
  SELL = "Sell",
  REPAIR = "Repair",
  MOVE = "Move",
  SPLIT_STACK = "Split Stack",
  SORT = "Clean Up Bags",
  BAG_SLOTS = "Bag Slots",
  ALL_CHARACTERS = "All Characters",
  CURRENCIES = "Currencies",
  CUSTOMISE = "Customise Baganator",
  BANK = "Bank",
  STATUS_HEADER = "Baganator Controller status",
  STATUS_GAMEPAD_API = "Gamepad UI API available",
  STATUS_GAMEPAD_ENABLED = "Gamepad UI enabled",
  STATUS_RESTRICTED = "Combat restriction active",
  STATUS_FRAMES = "Baganator frames known",
  STATUS_TRACKED = "Registered with the gamepad focus manager",
  STATUS_FOCUSED = "Focused frame",
  STATUS_NONE = "none",
  REQUIRES_FOREVER = "Baganator Controller only does anything on World of Warcraft: Forever with the Gamepad UI enabled.",
}

addonTable.Locales = L

-- Returns the first non-empty string among the given candidates. Candidates
-- are looked up as global variable names first (so Blizzard/Baganator
-- translations win), then fall back to our own table, then to the literal.
function addonTable.Locales.Get(key, ...)
  for i = 1, select("#", ...) do
    local candidate = select(i, ...)
    if type(candidate) == "string" then
      local value = _G[candidate]
      if type(value) == "string" and value ~= "" then
        return value
      end
    end
  end
  return L[key] or key
end
