local _, addonTable = ...

--[[
  Button prompt footer under the focused window. Uses Blizzard's
  PromptedBindingFooter for visuals only: prompts carry no bound functions, so
  the footer never creates a binding group. Input handling is in Actions.lua.
]]

addonTable.Legend = {}
local Legend = addonTable.Legend
local Core = addonTable.Core
local Constants = addonTable.Constants
local L = addonTable.Locales

local footers = {}
local refreshQueued = {}

local function AddPrompt(footer, key, debugName, labelOrFunc, condition)
  -- A string second argument creates a prompt with no bound function.
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
  -- Flip above windows docked at the bottom of the screen.
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
