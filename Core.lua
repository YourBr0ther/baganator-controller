local ADDON_NAME, addonTable = ...

--[[
  Baganator Controller

  WoW Forever ships a native Gamepad UI. Windows take part in it by registering
  with Blizzard's focus manager (GamepadMode.FrameControlsManager) which in turn
  drives SmartNavigation (the D-pad cursor) and the per-frame button prompts.
  Blizzard's own bag frame (ContainerFrameCombinedBags) does this; Baganator
  replaces that frame with its own windows and never registers them, so with the
  Gamepad UI on you can open Baganator but you cannot move a cursor inside it,
  cannot switch to it from a vendor with RT, and the radial menu's "Bags" entry
  toggles an invisible Blizzard frame instead.

  Since build 1.60.1.70862 Blizzard exposes the relevant entry points to
  insecure (addon) code through a secure trampoline
  (Blizzard_GamepadSmartNavigation/SecureHelper.lua): FrameShown/FrameHidden,
  SetTargetButtonForFrame, RefreshButtonGroups and the SmartNavigation_* marker
  functions are callable out of combat, and a registered frame's optional
  callbacks (FocusGamepad, UnfocusGamepad, SmartNavigationCloseHandler,
  smartNavPanelInfoAddedCallback, SmartNavigationOnSelect) are invoked through a
  taint barrier. This addon uses exactly that surface and nothing else that
  would push taint into Blizzard's binding stack.
]]

addonTable.Core = {}
local Core = addonTable.Core

Core.ADDON_NAME = ADDON_NAME
Core.DEBUG = false

local function Colorize(text)
  return "|cff80c0ff" .. text .. "|r"
end

function Core.Print(message)
  print(Colorize(addonTable.Locales.ADDON_NAME) .. ": " .. tostring(message))
end

function Core.Debug(...)
  if Core.DEBUG then
    print(Colorize("BGRC"), ...)
  end
end

-- Forever reports interface 16001 and shares the mainline project id.
function Core.IsForever()
  local build = select(4, GetBuildInfo())
  return build >= 16000 and build < 20000
end

-- All the Blizzard gamepad globals this addon relies on. If any are missing
-- (older Forever build, a different client) the addon stays dormant.
function Core.HasGamepadAPI()
  return type(InputUtil) == "table"
    and type(InputUtil.IsGamepadUIEnabled) == "function"
    and type(GamepadMode) == "table"
    and type(GamepadMode.FrameControlsManager) == "table"
    and type(GamepadMode.FrameControlsManager.FrameShown) == "function"
    and type(GamepadMode.FrameControlsManager.FrameHidden) == "function"
    and type(SmartNavigation) == "table"
    and type(SmartNavigation.SetTargetButtonForFrame) == "function"
    and type(SmartNavigation.RefreshButtonGroups) == "function"
    and type(SmartNavigation_MarkFrameIgnored) == "function"
    and type(GamepadSharedUtility) == "table"
    and type(GamepadSharedUtility.CreatePromptedBindingFooter) == "function"
    and type(GamepadSharedUtility.CreatePromptedBinding) == "function"
end

function Core.IsGamepadUIEnabled()
  return Core.HasGamepadAPI() and InputUtil.IsGamepadUIEnabled() == true
end

-- Blizzard gates every insecure entry point on this exact predicate, so we use
-- the same one to decide whether a call would be allowed right now.
function Core.IsRestricted()
  if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum and Enum.AddOnRestrictionType then
    return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat) == true
  end
  return InCombatLockdown()
end

function Core.CanTouchGamepadUI()
  return Core.IsGamepadUIEnabled() and not Core.IsRestricted()
end

function Core.GetFocusManager()
  return GamepadMode.FrameControlsManager
end

-- Reading the focus manager's bookkeeping is harmless (reads never taint
-- Blizzard's state), it is only writes that must go through FrameShown and
-- FrameHidden.
function Core.IsTracked(frame)
  local manager = Core.GetFocusManager()
  local shownFrames = manager and manager.shownFrames
  if type(shownFrames) ~= "table" then
    return false
  end
  for _, shownFrame in ipairs(shownFrames) do
    if shownFrame == frame then
      return true
    end
  end
  return false
end

function Core.GetFocusedFrame()
  local manager = Core.GetFocusManager()
  if manager and manager.isUIFocused then
    return manager.focusedFrame
  end
  return nil
end

function Core.IsFocused(frame)
  return frame ~= nil and Core.GetFocusedFrame() == frame
end

function Core.NextFrame(callback)
  if RunNextFrame then
    RunNextFrame(callback)
  else
    C_Timer.After(0, callback)
  end
end

function Core.IsDescendant(region, ancestor)
  local current = region
  local depth = 0
  while current and depth < 64 do
    if current == ancestor then
      return true
    end
    current = current:GetParent()
    depth = depth + 1
  end
  return false
end

----------------------------------------------------------------------------
-- Event handling
----------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
Core.eventFrame = eventFrame

local initialized = false

local function Initialize()
  if initialized then
    return
  end
  if not Core.IsForever() then
    return
  end
  if not Core.HasGamepadAPI() then
    Core.Debug("Gamepad UI API not present on this client build; staying dormant.")
    return
  end
  if type(Baganator) ~= "table" or type(Baganator.API) ~= "table" or type(Baganator.API.Skins) ~= "table" then
    Core.Debug("Baganator API not available yet.")
    return
  end
  initialized = true

  addonTable.Actions.Initialize()
  addonTable.Frames.Initialize()
  addonTable.BlizzardCompat.Initialize()

  if Core.IsGamepadUIEnabled() then
    addonTable.Frames.Sync()
  end
end

function Core.IsInitialized()
  return initialized
end

local function OnInterfaceTransition()
  if not initialized then
    return
  end
  -- Blizzard's own transition handlers run on the same event; wait a frame so
  -- the focus manager has finished resetting before we touch it.
  Core.NextFrame(function()
    if Core.IsGamepadUIEnabled() then
      addonTable.Frames.Sync()
    else
      addonTable.Legend.HideAll()
      addonTable.Actions.OnGamepadUIDisabled()
    end
  end)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    Initialize()
    if not initialized then
      -- Baganator initializes on its own ADDON_LOADED; give it a moment.
      C_Timer.After(1, Initialize)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if initialized and Core.IsGamepadUIEnabled() then
      addonTable.Frames.Sync()
    end
  elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
    OnInterfaceTransition()
  end
end)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(eventFrame.RegisterEvent, eventFrame, "INPUT_DEVICE_INTERFACE_TRANSITION")

----------------------------------------------------------------------------
-- Slash command: /bgrc -- prints a status report useful for bug reports
----------------------------------------------------------------------------

SLASH_BAGANATOR_CONTROLLER1 = "/bgrc"
SLASH_BAGANATOR_CONTROLLER2 = "/baganatorcontroller"
SlashCmdList["BAGANATOR_CONTROLLER"] = function(message)
  local L = addonTable.Locales
  message = (message or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if message == "debug" then
    Core.DEBUG = not Core.DEBUG
    Core.Print("debug " .. (Core.DEBUG and "on" or "off"))
    return
  end

  local function YesNo(value)
    return value and "|cff00ff00yes|r" or "|cffff4040no|r"
  end

  Core.Print(L.STATUS_HEADER)
  if not Core.IsForever() then
    print("  " .. L.REQUIRES_FOREVER)
    return
  end
  print("  " .. L.STATUS_GAMEPAD_API .. ": " .. YesNo(Core.HasGamepadAPI()))
  print("  " .. L.STATUS_GAMEPAD_ENABLED .. ": " .. YesNo(Core.IsGamepadUIEnabled()))
  print("  " .. L.STATUS_RESTRICTED .. ": " .. YesNo(Core.IsRestricted()))
  if initialized then
    local known, tracked = addonTable.Frames.GetCounts()
    print("  " .. L.STATUS_FRAMES .. ": " .. known)
    print("  " .. L.STATUS_TRACKED .. ": " .. tracked)
    local focused = Core.GetFocusedFrame()
    local focusedName = focused and ((focused.GetName and focused:GetName()) or tostring(focused)) or L.STATUS_NONE
    print("  " .. L.STATUS_FOCUSED .. ": " .. focusedName)
  end
end
