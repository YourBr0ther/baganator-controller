local _, addonTable = ...

--[[
  Gamepad actions for Baganator windows.

  A (PAD1)  SmartNavigation clicks the focused button: pick up / place / swap
            items, press toolbar buttons. Secure, nothing to do here.
  B (PAD2)  SmartNavigation asks the frame to close via
            SmartNavigationCloseHandler; we drop a held item first, like
            Blizzard's bags.
  X (PAD3)  Context action on the focused item: Sell/Repair at a vendor, Move
            while the bank is open, otherwise Open/Read/Equip/Use. Implemented
            as a right click on the item button, exactly what the mouse does.
  Y (PAD4)  "More actions" context menu: split stack, sort, toggle bag slots,
            bank, all characters, currencies, Baganator settings.

  X and Y are bound with SetOverrideBindingClick on UIParent with the same
  priority flag Blizzard's own gamepad binding stack uses, so any later Blizzard
  rebinding of those keys simply replaces ours. The proxy button checks that a
  Baganator window is still the focused frame before acting, so a stale binding
  is a no-op rather than a surprise.
]]

addonTable.Actions = {}
local Actions = addonTable.Actions
local Core = addonTable.Core
local Constants = addonTable.Constants
local L = addonTable.Locales

local Kind = Constants.Kind
local VirtualButton = Constants.VirtualButton

local KEY_TO_VIRTUAL_BUTTON = {
  [GAMEPAD_FACE_LEFT or "PAD3"] = VirtualButton.Context,
  [GAMEPAD_FACE_TOP or "PAD4"] = VirtualButton.More,
}

local proxy

----------------------------------------------------------------------------
-- Bindings
----------------------------------------------------------------------------

local function OurBindingCommand(virtualButton)
  return "CLICK " .. Constants.PROXY_BUTTON_NAME .. ":" .. virtualButton
end

function Actions.ApplyBindings()
  if not proxy or Core.IsRestricted() then
    return false
  end
  for key, virtualButton in pairs(KEY_TO_VIRTUAL_BUTTON) do
    SetOverrideBindingClick(UIParent, true, key, Constants.PROXY_BUTTON_NAME, virtualButton)
  end
  return true
end

-- Only used when leaving the Gamepad UI: in keyboard/mouse mode a lingering
-- override would swallow the player's own PAD3/PAD4 bindings. While the Gamepad
-- UI is on, Blizzard's own binding stack replaces ours whenever it rebinds.
function Actions.ClearBindingsIfOurs()
  if Core.IsRestricted() then
    return
  end
  for key, virtualButton in pairs(KEY_TO_VIRTUAL_BUTTON) do
    if GetBindingAction(key, true) == OurBindingCommand(virtualButton) then
      SetOverrideBinding(UIParent, true, key, nil)
    end
  end
end

function Actions.OnGamepadUIDisabled()
  Actions.ClearBindingsIfOurs()
end

----------------------------------------------------------------------------
-- Button inspection helpers
----------------------------------------------------------------------------

local function GetCurrentButton(frame)
  if SmartNavigation:GetActiveFrame() ~= frame then
    return nil
  end
  local button = SmartNavigation:GetCurrentButton()
  if not button or not button:IsVisible() or not Core.IsDescendant(button, frame) then
    return nil
  end
  return button
end

local function IsContainerItemButton(button)
  return button.buttonContext == Constants.ITEM_BUTTON_CONTEXT and type(button.GetBagID) == "function"
end

-- Baganator caches item details in button.BGR for both live and cached
-- (other character) buttons; live buttons also carry Blizzard's hasItem flag.
local function HasItem(button)
  if button.hasItem == true then
    return true
  end
  local bgr = button.BGR
  return bgr ~= nil and bgr.itemID ~= nil
end

local function IsAtMerchant()
  return MerchantFrame ~= nil and MerchantFrame:IsShown()
end

local function IsBankOpen()
  if C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType
    and Enum and Enum.PlayerInteractionType then
    return C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Banker)
  end
  return false
end

local function GetContainerItemInfo(button)
  return C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())
end

local function CanSplitStack(button)
  if not button or not IsContainerItemButton(button) or not HasItem(button) then
    return false
  end
  local itemInfo = GetContainerItemInfo(button)
  return itemInfo ~= nil and not itemInfo.isLocked and (itemInfo.stackCount or 0) > 1
end

----------------------------------------------------------------------------
-- Prompt labels (also used as "is this action available" predicates)
----------------------------------------------------------------------------

function Actions.GetSelectLabel(frame)
  local button = GetCurrentButton(frame)
  if not button then
    return nil
  end
  if SmartNavigation_IsCurrentButtonClickable and not SmartNavigation_IsCurrentButtonClickable() then
    return nil
  end
  if CursorHasItem() then
    if IsContainerItemButton(button) or button.isBag or button.GetBagID then
      return L.Get("PLACE", "CONTEXT_ACTION_LABEL_PLACE")
    end
    return nil
  end
  if IsContainerItemButton(button) and not HasItem(button) then
    return nil
  end
  return L.Get("SELECT", "ACTION_LABEL_SELECT")
end

local function GetMerchantContextLabel(button, bagID, slotID)
  if InRepairMode() then
    local durability, maxDurability = C_Container.GetContainerItemDurability(bagID, slotID)
    if durability and maxDurability and durability < maxDurability then
      return L.Get("REPAIR", "CONTEXT_ACTION_LABEL_REPAIR")
    end
    return nil
  end
  if HasItem(button) and MerchantFrame.selectedTab == 1 then
    return L.Get("SELL", "CONTEXT_ACTION_LABEL_SELL")
  end
  return nil
end

local function GetItemContextLabel(button)
  local itemInfo = GetContainerItemInfo(button)
  if itemInfo and itemInfo.hasLoot then
    return L.Get("OPEN", "CONTEXT_ACTION_LABEL_OPEN")
  end
  if button.IsReadable and button:IsReadable() then
    return L.Get("READ", "CONTEXT_ACTION_LABEL_READ")
  end
  local itemID = (itemInfo and itemInfo.itemID) or (button.BGR and button.BGR.itemID)
  if itemID and C_Item then
    if C_Item.IsEquippableItem and C_Item.IsEquippableItem(itemID) then
      return L.Get("EQUIP", "CONTEXT_ACTION_LABEL_EQUIP")
    end
    if C_Item.IsUsableItem and C_Item.IsUsableItem(itemID) then
      return L.Get("USE", "CONTEXT_ACTION_LABEL_USE")
    end
  end
  return nil
end

-- Returns the label of the X action for the focused button, or nil when X has
-- nothing to do. Mirrors what a right click on the button would achieve.
function Actions.GetContextLabel(frame)
  local button = GetCurrentButton(frame)
  if not button or CursorHasItem() then
    return nil
  end

  local info = addonTable.Frames.GetInfo(frame)
  if info and info.kind == Kind.Guild then
    if HasItem(button) and button.tabIndex ~= nil then
      return L.Get("MOVE", "CONTEXT_ACTION_LABEL_MOVE")
    end
    return nil
  end

  if not IsContainerItemButton(button) then
    return nil
  end

  if IsAtMerchant() then
    return GetMerchantContextLabel(button, button:GetBagID(), button:GetID())
  end
  if not HasItem(button) then
    return nil
  end
  if IsBankOpen() then
    return L.Get("MOVE", "CONTEXT_ACTION_LABEL_MOVE")
  end
  return GetItemContextLabel(button)
end

function Actions.CanOpenMoreActions(frame)
  if CursorHasItem() or type(MenuUtil) ~= "table" or type(MenuUtil.CreateContextMenu) ~= "function" then
    return false
  end
  local info = addonTable.Frames.GetInfo(frame)
  return info ~= nil and (info.kind == Kind.Backpack or info.kind == Kind.Bank)
end

----------------------------------------------------------------------------
-- Performing actions
----------------------------------------------------------------------------

function Actions.DoContextAction(frame)
  if not Actions.GetContextLabel(frame) then
    return
  end
  local button = GetCurrentButton(frame)
  if not button then
    return
  end
  -- Same code path as a physical right click on the item button. This runs
  -- inside a hardware (gamepad) input event, so protected item APIs such as
  -- UseContainerItem are permitted.
  button:Click("RightButton")
  addonTable.Legend.RequestRefresh(frame)
end

local function SplitStack(button)
  if not CanSplitStack(button) or not StackSplitFrame then
    return
  end
  local itemInfo = GetContainerItemInfo(button)
  if not button.SplitStack then
    button.SplitStack = function(owner, split)
      C_Container.SplitContainerItem(owner:GetBagID(), owner:GetID(), split)
    end
  end
  StackSplitFrame:OpenStackSplitFrame(itemInfo.stackCount, button, "BOTTOMRIGHT", "TOPRIGHT")
  ShowUIPanel(StackSplitFrame)
end

local function TriggerBaganator(eventName)
  if Baganator and Baganator.CallbackRegistry then
    Baganator.CallbackRegistry:TriggerEvent(eventName)
  end
end

-- Baganator exposes sorting on the view itself (backpack) or on the current
-- tab (bank views).
local function GetSorter(frame)
  if type(frame.CombineStacksAndSort) == "function" then
    return frame
  end
  local tab = frame.currentTab
  if tab and type(tab.CombineStacksAndSort) == "function" then
    return tab
  end
  return nil
end

local function PopulateMoreActionsMenu(frame, button, rootDescription)
  local info = addonTable.Frames.GetInfo(frame)
  rootDescription:SetTag("MENU_BAGANATOR_CONTROLLER_MORE_ACTIONS")

  if button and CanSplitStack(button) then
    rootDescription:CreateButton(L.Get("SPLIT_STACK", "CONTEXT_ACTION_LABEL_SPLIT_ITEM_STACK"), function()
      SplitStack(button)
    end)
    rootDescription:CreateDivider()
  end

  local sorter = GetSorter(frame)
  if sorter then
    rootDescription:CreateButton(L.Get("SORT", "BAG_CLEANUP_BAGS", "BAGANATOR_L_SORT"), function()
      sorter:CombineStacksAndSort(false)
    end)
  end

  if info.kind == Kind.Backpack then
    if type(frame.ToggleBagSlots) == "function" then
      rootDescription:CreateButton(L.Get("BAG_SLOTS", "BAGANATOR_L_BAG_SLOTS"), function()
        frame:ToggleBagSlots()
        addonTable.Frames.RequestRefresh()
      end)
    end
    if type(frame.ToggleBank) == "function" then
      rootDescription:CreateButton(L.Get("BANK", "BAGANATOR_L_BANK", "BANK"), function()
        frame:ToggleBank()
      end)
    end
    rootDescription:CreateButton(L.Get("ALL_CHARACTERS", "BAGANATOR_L_ALL_CHARACTERS"), function()
      TriggerBaganator("CharacterSelectToggle")
    end)
    rootDescription:CreateButton(L.Get("CURRENCIES", "BAGANATOR_L_CURRENCIES"), function()
      TriggerBaganator("CurrencyPanelToggle")
    end)
  end

  rootDescription:CreateDivider()
  rootDescription:CreateButton(L.Get("CUSTOMISE", "BAGANATOR_L_CUSTOMISE_BAGANATOR"), function()
    TriggerBaganator("ShowCustomise")
  end)
end

function Actions.OpenMoreActions(frame)
  if not Actions.CanOpenMoreActions(frame) then
    return
  end
  local button = GetCurrentButton(frame)
  MenuUtil.CreateContextMenu(button or frame, function(_, rootDescription)
    PopulateMoreActionsMenu(frame, button, rootDescription)
  end)
end

local function OnProxyClick(_, virtualButton)
  if not Core.IsGamepadUIEnabled() then
    return
  end
  local frame = Core.GetFocusedFrame()
  if not frame or not frame:IsVisible() or not addonTable.Frames.GetInfo(frame) then
    return
  end
  if virtualButton == VirtualButton.Context then
    Actions.DoContextAction(frame)
  elseif virtualButton == VirtualButton.More then
    Actions.OpenMoreActions(frame)
  end
end

-- Called by SmartNavigation (through Blizzard's taint barrier) when B is
-- pressed while one of our frames is active. Returning true tells Blizzard the
-- close was handled.
function Actions.CloseHandler(frame)
  if CursorHasItem() then
    ClearCursor()
    addonTable.Legend.RequestRefresh(frame)
    return true
  end
  local info = addonTable.Frames.GetInfo(frame)
  if info and info.kind == Kind.Backpack and Baganator and Baganator.CallbackRegistry then
    -- Let Baganator close its backpack the way its own close button does.
    Baganator.CallbackRegistry:TriggerEvent("BagHide")
  else
    frame:Hide()
  end
  return true
end

----------------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------------

function Actions.Initialize()
  if proxy then
    return
  end
  proxy = CreateFrame("Button", Constants.PROXY_BUTTON_NAME, UIParent)
  proxy:SetSize(1, 1)
  proxy:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -10, -10)
  proxy:SetAlpha(0)
  proxy:EnableMouse(false)
  proxy:RegisterForClicks("AnyDown")
  proxy:SetScript("OnClick", OnProxyClick)

  Core.RegisterCallback(Constants.Events.FrameFocused, Actions.ApplyBindings)
end
