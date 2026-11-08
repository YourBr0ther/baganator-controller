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

  Module layout (load order is the TOC):
    Locales         strings, with Blizzard/Baganator translations preferred
    Constants       names, kinds, internal event names
    Core            environment checks, shared helpers, internal events, init
    Legend          button prompt footer under the focused window
    Actions         A/B/X/Y behaviour and the X/Y override bindings
    Frames          discovery of Baganator windows and focus registration
    BlizzardCompat  radial menu and hidden Blizzard frame fixes
    Commands        /bgrc status command
]]

addonTable.Core = {}
local Core = addonTable.Core
local L = addonTable.Locales

Core.ADDON_NAME = ADDON_NAME
Core.DEBUG = false

----------------------------------------------------------------------------
-- Output
----------------------------------------------------------------------------

local function Colorize(text)
  return "|cff80c0ff" .. text .. "|r"
end

function Core.Print(message)
  print(Colorize(L.ADDON_NAME) .. ": " .. tostring(message))
end

function Core.Debug(...)
  if Core.DEBUG then
    print(Colorize("BGRC"), ...)
  end
end

----------------------------------------------------------------------------
-- Environment checks
----------------------------------------------------------------------------

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

----------------------------------------------------------------------------
-- Focus manager accessors
----------------------------------------------------------------------------

function Core.GetFocusManager()
  return GamepadMode.FrameControlsManager
end

-- Reading the focus manager's bookkeeping is harmless (reads never taint
-- Blizzard's state); only writes must go through FrameShown and FrameHidden.
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

function Core.GetFrameName(frame)
  if type(frame) == "table" and type(frame.GetName) == "function" then
    return frame:GetName() or tostring(frame)
  end
  return tostring(frame)
end

----------------------------------------------------------------------------
-- Internal events (plain Lua, no Blizzard registries involved)
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
    Core.Debug("Gamepad UI API not present on this client build; staying dormant.")
    return
  end
  if type(Baganator) ~= "table" or type(Baganator.API) ~= "table" or type(Baganator.API.Skins) ~= "table" then
    Core.Debug("Baganator API not available yet.")
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

local eventFrame = CreateFrame("Frame")
Core.eventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event)
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
-- Not every build exposes this event; RegisterEvent errors on unknown names.
pcall(eventFrame.RegisterEvent, eventFrame, "INPUT_DEVICE_INTERFACE_TRANSITION")
