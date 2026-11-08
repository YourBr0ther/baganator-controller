local _, addonTable = ...

--[[
  Button prompt legend ("footer") shown under a focused Baganator window.

  We reuse Blizzard's PromptedBindingFooter purely for its visuals. Every prompt
  is created without a bound function, so PromptedBindingFooterMixin never
  creates a binding group and never touches the gamepad binding stack. The
  actual button handling lives in Actions.lua (SmartNavigation handles A/B
  itself; X/Y are routed through our own override binding).
]]

addonTable.Legend = {}
local Legend = addonTable.Legend
local Core = addonTable.Core
local Constants = addonTable.Constants
local L = addonTable.Locales

local footers = {}
local refreshQueued = {}

local function AddPrompt(footer, key, debugName, labelOrFunc, condition)
  -- Passing a string as the second argument yields an "extensible" prompted
  -- binding with no bound function attached (see Blizzard's PromptedBinding.lua).
  local prompt = GamepadSharedUtility.CreatePromptedBinding(key, debugName)
  prompt:AddFooterBinding({
    label = labelOrFunc,
    conditions = condition,
    visibilityType = PromptedBindingMixin.VISIBILITY_TYPE.ONLY_IF_USABLE,
  })
  footer:AddPromptedBinding(prompt)
  return prompt
end

local function BuildFooter(frame)
  local Actions = addonTable.Actions
  local footer = GamepadSharedUtility.CreatePromptedBindingFooter(frame, "BaganatorControllerFooter")

  AddPrompt(footer, GAMEPAD_FACE_BOTTOM, "BaganatorControllerSelect",
    function() return Actions.GetSelectLabel(frame) end,
    function() return Actions.GetSelectLabel(frame) ~= nil end)

  AddPrompt(footer, GAMEPAD_FACE_LEFT, "BaganatorControllerContext",
    function() return Actions.GetContextLabel(frame) end,
    function() return Actions.GetContextLabel(frame) ~= nil end)

  AddPrompt(footer, GAMEPAD_FACE_TOP, "BaganatorControllerMore",
    L.Get("MORE_ACTIONS", "CONTEXT_ACTION_LABEL_MORE_ACTIONS"),
    function() return Actions.CanOpenMoreActions(frame) end)

  AddPrompt(footer, GAMEPAD_FACE_RIGHT, "BaganatorControllerBack",
    function()
      if CursorHasItem() then
        return L.Get("BACK", "FRAME_ACTION_BACK")
      end
      return L.Get("CLOSE", "FRAME_ACTION_CLOSE")
    end,
    function() return true end)

  footer:Finalize()
  return footer
end

local function GetOrCreateFooter(frame)
  local footer = footers[frame]
  if footer then
    return footer
  end
  local ok, result = pcall(BuildFooter, frame)
  if not ok then
    Core.Debug("Failed to build footer:", result)
    return nil
  end
  footers[frame] = result
  return result
end

local function PositionFooter(frame, footer)
  -- Baganator windows usually sit at the bottom edge of the screen where the
  -- default "below the frame" placement would be clipped, so flip above.
  local bottom = frame:GetBottom()
  local scale = frame:GetEffectiveScale()
  if bottom and scale and (bottom * scale) < Constants.LEGEND_FLIP_THRESHOLD then
    footer:SetCustomAnchor(AnchorUtil.CreateAnchor("BOTTOMLEFT", frame, "TOPLEFT", 0, 6))
  else
    footer:SetCustomAnchor(nil)
  end
  footer:ApplyInputLegendAttachment()
end

function Legend.Show(frame)
  if not Core.IsGamepadUIEnabled() then
    return
  end
  local footer = GetOrCreateFooter(frame)
  if not footer then
    return
  end
  PositionFooter(frame, footer)
  footer:ShowAndActivateBindings()
end

function Legend.Hide(frame)
  local footer = footers[frame]
  if footer and footer.isShown then
    footer:HideAndDeactivateBindings()
  end
end

function Legend.HideAll()
  for frame in pairs(footers) do
    Legend.Hide(frame)
  end
end

function Legend.Refresh(frame)
  local footer = footers[frame]
  if footer and footer.isShown then
    footer:Refresh()
  end
end

-- Coalesce bursts of refresh requests (bag updates fire several per frame).
function Legend.RequestRefresh(frame)
  if refreshQueued[frame] then
    return
  end
  refreshQueued[frame] = true
  Core.NextFrame(function()
    refreshQueued[frame] = nil
    Legend.Refresh(frame)
  end)
end

Core.RegisterCallback(Constants.Events.FrameFocused, Legend.Show)
Core.RegisterCallback(Constants.Events.FrameUnfocused, Legend.Hide)
Core.RegisterCallback(Constants.Events.FrameVisibilityChanged, function(info, shown)
  if not shown then
    Legend.Hide(info.frame)
  end
end)
