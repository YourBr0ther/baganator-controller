local _, addonTable = ...

local Constants = {}
addonTable.Constants = Constants

-- Name of the hidden button that X/Y override bindings click into.
Constants.PROXY_BUTTON_NAME = "BaganatorController_InputButton"

-- Blizzard tags its container item buttons with this buttonContext key value;
-- Baganator's live item buttons inherit it from ContainerFrameItemButtonTemplate.
Constants.ITEM_BUTTON_CONTEXT = "ButtonContext_ContainerFrameItemButton"

-- Which Baganator window a frame is. Derived from the tags Baganator passes to
-- its skin API when it registers a "ButtonFrame" region.
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

-- Virtual mouse button names delivered to the proxy button by our override
-- bindings (SetOverrideBindingClick passes them through as the click button).
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

-- Blizzard frames that Baganator re-parents into a hidden frame. If the client
-- registers one of these for gamepad focus while it is invisible, we remove it.
Constants.ORPHANED_BLIZZARD_FRAMES = {
  BankFrame = true,
  GuildBankFrame = true,
  ContainerFrameCombinedBags = true,
}
Constants.ORPHANED_BLIZZARD_FRAME_PATTERN = "^ContainerFrame%d+$"

-- Height, in screen pixels, below which the prompt legend flips above a window.
Constants.LEGEND_FLIP_THRESHOLD = 56
