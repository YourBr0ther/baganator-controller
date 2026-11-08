local _, addonTable = ...

--[[
  Smooths over the places where Blizzard's gamepad code still talks to the
  default bag and bank frames that Baganator has parented to a hidden frame.

  1. BankFrame (and GuildBankFrame) are opened with ShowUIPanel, which the
     focus manager listens to, so an invisible frame gets registered and may
     even take focus. We unregister any such frame straight after it is added.

  2. The radial menu's "Bags" segment calls ToggleBackpack_Combined directly,
     which only shows/hides the hidden ContainerFrameCombinedBags. We mirror
     that toggle onto Baganator, and keep ContainerFrameCombinedBags' shown
     state in step with Baganator's backpack so IsBagOpen() (used by the radial
     to draw the open/closed state) stays truthful.
]]

addonTable.BlizzardCompat = {}
local BlizzardCompat = addonTable.BlizzardCompat
local Core = addonTable.Core
local Constants = addonTable.Constants

----------------------------------------------------------------------------
-- Hidden Blizzard frames registered for focus
----------------------------------------------------------------------------

local function IsOrphanedBlizzardFrame(frame)
  if type(frame) ~= "table" or type(frame.GetName) ~= "function" then
    return false
  end
  local name = frame:GetName()
  if type(name) ~= "string" then
    return false
  end
  local isBagLike = Constants.ORPHANED_BLIZZARD_FRAMES[name] or name:match(Constants.ORPHANED_BLIZZARD_FRAME_PATTERN) ~= nil
  return isBagLike and not frame:IsVisible()
end

local function OnFocusManagerFrameShown(manager, frame)
  if not Core.CanTouchGamepadUI() then
    return
  end
  if IsOrphanedBlizzardFrame(frame) and Core.IsTracked(frame) then
    Core.Debug("unregistering hidden Blizzard frame", frame:GetName())
    manager:FrameHidden(frame)
  end
end

----------------------------------------------------------------------------
-- Radial menu "Bags" entry and IsBagOpen() state
----------------------------------------------------------------------------

local function AnyBackpackVisible()
  for frame, info in pairs(addonTable.Frames.infoByFrame) do
    if info.kind == Constants.Kind.Backpack and frame:IsVisible() then
      return true
    end
  end
  return false
end

-- True when Baganator has moved Blizzard's combined bag frame out of the way.
local function IsBlizzardBagFrameHiddenByBaganator()
  return ContainerFrameCombinedBags ~= nil
    and not ContainerFrameCombinedBags:IsVisible()
    and ContainerFrameCombinedBags:GetParent() ~= UIParent
end

local function SyncBaganatorToBlizzardBagState()
  if not Baganator or not Baganator.CallbackRegistry or not ContainerFrameCombinedBags then
    return
  end
  local shouldBeOpen = ContainerFrameCombinedBags:IsShown()
  if shouldBeOpen and not AnyBackpackVisible() then
    Baganator.CallbackRegistry:TriggerEvent("BagShow")
  elseif not shouldBeOpen and AnyBackpackVisible() then
    Baganator.CallbackRegistry:TriggerEvent("BagHide")
  end
end

local function OnToggleBackpackCombined()
  if not Core.IsGamepadUIEnabled() or not IsBlizzardBagFrameHiddenByBaganator() then
    return
  end
  -- Baganator already handles ToggleBackpack/ToggleAllBags/OpenAllBags/
  -- CloseAllBags itself; only react to direct callers such as the radial menu.
  local stack = debugstack(1, 10, 0) or ""
  if stack:find("`ToggleBackpack'", 1, true)
    or stack:find("ToggleAllBags", 1, true)
    or stack:find("OpenAllBags", 1, true)
    or stack:find("CloseAllBags", 1, true) then
    return
  end
  SyncBaganatorToBlizzardBagState()
end

local function OnBaganatorFrameVisibilityChanged(info, shown)
  if info.kind ~= Constants.Kind.Backpack or not Core.IsGamepadUIEnabled() then
    return
  end
  if not IsBlizzardBagFrameHiddenByBaganator() then
    return
  end
  if shown then
    if not ContainerFrameCombinedBags:IsShown() then
      ContainerFrameCombinedBags:Show()
    end
  elseif not AnyBackpackVisible() and ContainerFrameCombinedBags:IsShown() then
    ContainerFrameCombinedBags:Hide()
  end
end

----------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------

function BlizzardCompat.Initialize()
  local manager = Core.GetFocusManager()
  if manager and type(manager.FrameShown) == "function" then
    hooksecurefunc(manager, "FrameShown", OnFocusManagerFrameShown)
  end
  if type(ToggleBackpack_Combined) == "function" then
    hooksecurefunc("ToggleBackpack_Combined", OnToggleBackpackCombined)
  end
  Core.RegisterCallback(Constants.Events.FrameVisibilityChanged, OnBaganatorFrameVisibilityChanged)
end
