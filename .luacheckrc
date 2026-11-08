std = "lua51"
max_line_length = 140
self = false

exclude_files = {
  "tests/",
  ".release/",
}

ignore = {
  "212/_.*", -- unused argument starting with underscore
}

-- Globals this addon defines
globals = {
  "SLASH_BAGANATOR_CONTROLLER1",
  "SLASH_BAGANATOR_CONTROLLER2",
}

-- WoW API and Blizzard UI globals read by this addon
read_globals = {
  -- Frames and widgets
  "CreateFrame", "UIParent", "MerchantFrame", "StackSplitFrame", "ContainerFrameCombinedBags",

  -- Addon / general API
  "GetBuildInfo", "InCombatLockdown", "C_RestrictedActions", "C_Timer", "RunNextFrame",
  "CursorHasItem", "ClearCursor", "InRepairMode", "SlashCmdList", "hooksecurefunc", "debugstack",
  "C_Container", "C_Item", "C_PlayerInteractionManager", "ShowUIPanel", "MenuUtil", "Enum",
  "SetOverrideBindingClick", "SetOverrideBinding", "GetBindingAction", "ToggleBackpack_Combined",

  -- Blizzard Gamepad UI (Forever)
  "InputUtil", "GamepadMode", "SmartNavigation", "SmartNavigation_MarkFrameIgnored",
  "SmartNavigation_IsCurrentButtonClickable", "GamepadSharedUtility", "PromptedBindingMixin",
  "AnchorUtil",
  "GAMEPAD_FACE_BOTTOM", "GAMEPAD_FACE_LEFT", "GAMEPAD_FACE_TOP", "GAMEPAD_FACE_RIGHT",

  -- Baganator public API
  "Baganator",
}
