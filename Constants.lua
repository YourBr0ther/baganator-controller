local _, addonTable = ...

local Constants = {}
addonTable.Constants = Constants

-- Name of the hidden button that X/Y override bindings click into.
Constants.PROXY_BUTTON_NAME = "BaganatorController_InputButton"

-- buttonContext value inherited from ContainerFrameItemButtonTemplate.
Constants.ITEM_BUTTON_CONTEXT = "ButtonContext_ContainerFrameItemButton"

-- Window kinds, derived from the tags Baganator passes to its skin API.
Constants.Kind = {
  Backpack = "backpack",
  Bank = "bank",
  Guild = "guild",
  Customise = "customise",
  Panel = "panel", -- character select, currency panel, guild log windows
}

Constants.KIND_BY_SKIN_TAG = {
  backpack = Constants.Kind.Backpack,
  bank = Constants.Kind.Bank,
  guild = Constants.Kind.Guild,
  customise = Constants.Kind.Customise,
}

-- Click button names delivered to the proxy by the X/Y override bindings.
Constants.VirtualButton = {
  Context = "Context",
  More = "More",
}

-- Internal events dispatched through Core.TriggerEvent.
Constants.Events = {
  FrameVisibilityChanged = "FrameVisibilityChanged", -- (info, shown)
  FrameFocused = "FrameFocused", -- (frame)
  FrameUnfocused = "FrameUnfocused", -- (frame)
}

-- Blizzard frames Baganator parents into a hidden frame.
Constants.ORPHANED_BLIZZARD_FRAMES = {
  BankFrame = true,
  GuildBankFrame = true,
  ContainerFrameCombinedBags = true,
}
Constants.ORPHANED_BLIZZARD_FRAME_PATTERN = "^ContainerFrame%d+$"

-- Screen height (px) below which the prompt legend is placed above the window.
Constants.LEGEND_FLIP_THRESHOLD = 56
