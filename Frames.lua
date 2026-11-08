local _, addonTable = ...

--[[
  Discovers Baganator's windows and registers them with Blizzard's gamepad
  focus manager while they are shown.

  Baganator announces every frame it creates through its public skin API
  (Baganator.API.Skins.GetAllFrames / RegisterListener). Frames of region type
  "ButtonFrame" are the top level windows: backpack and bank views (one per
  skin and view type), the guild bank, character select, currency panel and
  the customise dialog. We hook OnShow/OnHide on each of them and mirror that
  state into GamepadMode.FrameControlsManager, which gives us:

    * D-pad cursor navigation over every button in the window (item buttons,
      toolbar buttons, bag slots) via SmartNavigation,
    * A to click, B to close,
    * LT/RT paging between this window and other open windows (vendor, bank,
      character frame), including Blizzard's own LT/RT jump hint icons,
    * the focus glow, since Baganator's windows inherit ButtonFrameTemplate
      which already carries Blizzard's FocusFramesInterfaceMixin.
]]

addonTable.Frames = {}
local Frames = addonTable.Frames
local Core = addonTable.Core
local Constants = addonTable.Constants

local Events = Constants.Events

local infoByFrame = {}
Frames.infoByFrame = infoByFrame

local refreshQueued = false

----------------------------------------------------------------------------
-- Lookup
----------------------------------------------------------------------------

local function GetKind(details)
  if type(details.tags) == "table" then
    for _, tag in ipairs(details.tags) do
      local kind = Constants.KIND_BY_SKIN_TAG[tag]
      if kind then
        return kind
      end
    end
  end
  return Constants.Kind.Panel
end

function Frames.GetInfo(frame)
  return infoByFrame[frame]
end

function Frames.GetCounts()
  local known, tracked = 0, 0
  for frame in pairs(infoByFrame) do
    known = known + 1
    if Core.IsTracked(frame) then
      tracked = tracked + 1
    end
  end
  return known, tracked
end

----------------------------------------------------------------------------
-- Finding a sensible button for the cursor to start on
----------------------------------------------------------------------------

-- Top-left visible item button inside the window's item area.
function Frames.FindFirstItemButton(frame)
  local root = frame.Container or frame
  local best, bestLeft, bestTop

  local function Visit(region, depth)
    if depth > 10 or not region.IsObjectType then
      return
    end
    if region:IsObjectType("ItemButton") then
      if region:IsVisible() then
        local left, top = region:GetLeft(), region:GetTop()
        if left and top then
          local higher = not best or top > bestTop + 0.5
          local sameRowFurtherLeft = best and math.abs(top - bestTop) <= 0.5 and left < bestLeft
          if higher or sameRowFurtherLeft then
            best, bestLeft, bestTop = region, left, top
          end
        end
      end
      return
    end
    for _, child in ipairs({ region:GetChildren() }) do
      Visit(child, depth + 1)
    end
  end

  Visit(root, 0)
  return best
end

local function ApplyTarget(frame)
  local target = Frames.FindFirstItemButton(frame)
  if target then
    SmartNavigation:SetTargetButtonForFrame(frame, target)
  end
end

----------------------------------------------------------------------------
-- Registration with the focus manager
----------------------------------------------------------------------------

local function ApplyMarkers(info)
  if info.markersApplied then
    return
  end
  -- The search box needs a keyboard; keep the cursor out of it so A never
  -- hands keyboard focus to an edit box the player cannot type into.
  if info.frame.SearchWidget then
    SmartNavigation_MarkFrameIgnored(info.frame.SearchWidget)
  end
  info.markersApplied = true
end

local function Register(info)
  if Core.IsTracked(info.frame) then
    return
  end
  ApplyMarkers(info)
  Core.GetFocusManager():FrameShown(info.frame)
  Core.Debug("registered", Core.GetFrameName(info.frame))
end

local function Unregister(info)
  if not Core.IsTracked(info.frame) then
    return
  end
  Core.GetFocusManager():FrameHidden(info.frame)
  Core.Debug("unregistered", Core.GetFrameName(info.frame))
end

local function OnFrameShow(frame)
  local info = infoByFrame[frame]
  if not info then
    return
  end
  Core.TriggerEvent(Events.FrameVisibilityChanged, info, true)
  -- Registration is deferred to Frames.Sync (PLAYER_REGEN_ENABLED) in combat.
  if Core.CanTouchGamepadUI() then
    Register(info)
  end
end

local function OnFrameHide(frame)
  local info = infoByFrame[frame]
  if not info then
    return
  end
  Core.TriggerEvent(Events.FrameVisibilityChanged, info, false)
  if Core.CanTouchGamepadUI() then
    Unregister(info)
  end
end

----------------------------------------------------------------------------
-- Callbacks Blizzard's gamepad systems invoke on registered frames
----------------------------------------------------------------------------

local function OnFocusGamepad(frame)
  Core.TriggerEvent(Events.FrameFocused, frame)
end

local function OnUnfocusGamepad(frame)
  Core.TriggerEvent(Events.FrameUnfocused, frame)
end

local function OnSmartNavSelect(frame)
  addonTable.Legend.RequestRefresh(frame)
end

function Frames.Setup(frame, kind)
  if infoByFrame[frame] then
    return
  end
  local info = { frame = frame, kind = kind }
  infoByFrame[frame] = info

  frame:HookScript("OnShow", OnFrameShow)
  frame:HookScript("OnHide", OnFrameHide)

  frame.FocusGamepad = OnFocusGamepad
  frame.UnfocusGamepad = OnUnfocusGamepad
  frame.SmartNavigationCloseHandler = addonTable.Actions.CloseHandler
  frame.SmartNavigationOnSelect = OnSmartNavSelect
  frame.smartNavPanelInfoAddedCallback = function()
    if Core.CanTouchGamepadUI() then
      ApplyTarget(frame)
    end
  end

  Core.Debug("setup", Core.GetFrameName(frame), kind)

  if frame:IsVisible() then
    OnFrameShow(frame)
  end
end

local function OnBaganatorFrameAdded(details)
  if type(details) ~= "table" or details.regionType ~= "ButtonFrame" then
    return
  end
  local frame = details.region
  if type(frame) ~= "table" or type(frame.HookScript) ~= "function" then
    return
  end
  Frames.Setup(frame, GetKind(details))
end

----------------------------------------------------------------------------
-- Keeping Blizzard's bookkeeping in step with reality
----------------------------------------------------------------------------

-- Re-registers shown frames and unregisters hidden ones. Used after combat
-- (where none of the Blizzard calls are permitted), after the Gamepad UI is
-- switched on, and at login.
function Frames.Sync()
  if not Core.CanTouchGamepadUI() then
    return
  end
  for frame, info in pairs(infoByFrame) do
    local visible = frame:IsVisible()
    local tracked = Core.IsTracked(frame)
    if visible and not tracked then
      Register(info)
    elseif not visible and tracked then
      Unregister(info)
    end
  end
  local focused = Core.GetFocusedFrame()
  if focused and infoByFrame[focused] then
    OnFocusGamepad(focused)
  end
end

-- Baganator rebuilds and re-parents its item buttons whenever the inventory
-- changes; SmartNavigation only re-scans a frame on its own when CreateFrame
-- is called with a child, so re-scan ourselves when a view finishes laying out.
function Frames.RefreshNavigation()
  if not Core.CanTouchGamepadUI() then
    return
  end
  for frame in pairs(infoByFrame) do
    if frame:IsVisible() and Core.IsTracked(frame) then
      SmartNavigation:RefreshButtonGroups(frame)
      if SmartNavigation:GetActiveFrame() == frame then
        local current = SmartNavigation:GetCurrentButton()
        if not current or not current:IsVisible() or not Core.IsDescendant(current, frame) then
          ApplyTarget(frame)
        end
        addonTable.Legend.RequestRefresh(frame)
      end
    end
  end
end

function Frames.RequestRefresh()
  if refreshQueued then
    return
  end
  refreshQueued = true
  Core.NextFrame(function()
    refreshQueued = false
    Frames.RefreshNavigation()
  end)
end

----------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------

function Frames.Initialize()
  local skins = Baganator.API.Skins
  if type(skins.GetAllFrames) == "function" then
    local allFrames = skins.GetAllFrames()
    if type(allFrames) == "table" then
      for _, details in ipairs(allFrames) do
        OnBaganatorFrameAdded(details)
      end
    end
  end
  if type(skins.RegisterListener) == "function" then
    skins.RegisterListener(OnBaganatorFrameAdded)
  end

  if Baganator.CallbackRegistry and type(Baganator.CallbackRegistry.RegisterCallback) == "function" then
    Baganator.CallbackRegistry:RegisterCallback("ViewComplete", Frames.RequestRefresh, Frames)
  end
end
