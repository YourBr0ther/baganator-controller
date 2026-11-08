local _, addonTable = ...

-- English fallbacks; Locales.Get prefers Blizzard/Baganator translations.
local L = {
  ADDON_NAME = "Baganator Controller",
  SELECT = "Select",
  PLACE = "Place",
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

-- Returns the first defined global string among the candidates, else L[key].
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
