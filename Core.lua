local _, addonTable = ...

--[[
  Registers Baganator's windows with the Forever client's gamepad focus
  manager (GamepadMode.FrameControlsManager) and SmartNavigation, using only
  the entry points Blizzard exposes to addon code through SecureHelper: the
  wrapped FrameShown/FrameHidden/SetTargetButtonForFrame/RefreshButtonGroups
  calls (allowed out of combat) and the per-frame callbacks Blizzard invokes
  through a taint barrier.
]]

addonTable.Core = {}
local Core = addonTable.Core
local L = addonTable.Locales

----------------------------------------------------------------------------
-- Output
----------------------------------------------------------------------------

local function Colorize(text)
  return "|cff80c0ff" .. text .. "|r"
end

function Core.Print(message)
  print(Colorize(L.ADDON_NAME) .. ": " .. tostring(message))
end

----------------------------------------------------------------------------
-- Environment checks
----------------------------------------------------------------------------

function Core.IsForever()
  local build = select(4, GetBuildInfo())
  return build >= 16000 and build < 20000
end

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

-- The predicate Blizzard's SecureHelper uses to allow addon calls.
function Core.IsRestricted()
  if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum and Enum.AddOnRestrictionType then
    return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat) == true
  end
  return InCombatLockdown()
end

function Core.CanTouchGamepadUI()
  return Core.IsGamepadUIEnabled() and not Core.IsRestricted()
end

----------------------------------------------------------------------------
-- Focus manager accessors
----------------------------------------------------------------------------

function Core.GetFocusManager()
  return GamepadMode.FrameControlsManager
end

-- Reads of the focus manager's state are safe; writes go through FrameShown/FrameHidden.
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

----------------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------------

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
-- Internal events
----------------------------------------------------------------------------

local listeners = {}

function Core.RegisterCallback(event, callback)
  listeners[event] = listeners[event] or {}
  table.insert(listeners[event], callback)
end

function Core.TriggerEvent(event, ...)
  for _, callback in ipairs(listeners[event] or {}) do
    callback(...)
  end
end

----------------------------------------------------------------------------
-- Initialization and client events
----------------------------------------------------------------------------

local initialized = false

function Core.IsInitialized()
  return initialized
end

local function Initialize()
  if initialized then
    return
  end
  if not Core.IsForever() then
    return
  end
  if not Core.HasGamepadAPI() then
    return
  end
  if type(Baganator) ~= "table" or type(Baganator.API) ~= "table" or type(Baganator.API.Skins) ~= "table" then
    return
  end
  initialized = true

  addonTable.Actions.Initialize()
  addonTable.BlizzardCompat.Initialize()
  addonTable.Frames.Initialize()

  if Core.IsGamepadUIEnabled() then
    addonTable.Frames.Sync()
  end
end

local function OnInterfaceTransition()
  if not initialized then
    return
  end
  -- Let Blizzard's own transition handlers for this event finish first.
  Core.NextFrame(function()
    if Core.IsGamepadUIEnabled() then
      addonTable.Frames.Sync()
    else
      addonTable.Legend.HideAll()
      addonTable.Actions.OnGamepadUIDisabled()
    end
  end)
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    Initialize()
    if not initialized then
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
