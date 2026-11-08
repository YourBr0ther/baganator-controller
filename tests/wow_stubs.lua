-- Minimal stand-in for the parts of the WoW Forever client, Blizzard's gamepad
-- UI and Baganator that Baganator_Controller touches. Only used by tests.

local Stubs = {}
_G.Stubs = Stubs

Stubs.log = {}
function Stubs.Log(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  table.insert(Stubs.log, table.concat(parts, " "))
end
function Stubs.LogContains(needle)
  for _, line in ipairs(Stubs.log) do
    if line:find(needle, 1, true) then
      return true
    end
  end
  return false
end
function Stubs.ClearLog()
  Stubs.log = {}
end

Stubs.combat = false
Stubs.gamepadUI = true
Stubs.cursorHasItem = false
Stubs.nextFrameQueue = {}
Stubs.timers = {}
Stubs.eventFrames = {}

function Stubs.RunNextFrames()
  local queue = Stubs.nextFrameQueue
  Stubs.nextFrameQueue = {}
  for _, fn in ipairs(queue) do
    fn()
  end
end

function Stubs.RunTimers()
  local timers = Stubs.timers
  Stubs.timers = {}
  for _, fn in ipairs(timers) do
    fn()
  end
end

function Stubs.FireEvent(event, ...)
  for frame in pairs(Stubs.eventFrames) do
    if frame.registeredEvents[event] and frame.scripts.OnEvent then
      frame.scripts.OnEvent(frame, event, ...)
    end
  end
end

----------------------------------------------------------------------------
-- Frames
----------------------------------------------------------------------------

local frameCounter = 0
local FrameMixin = {}
FrameMixin.__index = FrameMixin

function Stubs.CreateFrame(frameType, name, parent, template)
  frameCounter = frameCounter + 1
  local frame = setmetatable({
    frameType = frameType or "Frame",
    name = name,
    parent = parent,
    template = template,
    children = {},
    scripts = {},
    hooks = {},
    registeredEvents = {},
    shown = true,
    left = 100, top = 500, bottom = 200,
    width = 100, height = 100,
    scale = 1,
    id = frameCounter,
  }, FrameMixin)
  if parent and parent.children then
    table.insert(parent.children, frame)
  end
  if name then
    _G[name] = frame
  end
  return frame
end
_G.CreateFrame = Stubs.CreateFrame

function FrameMixin:GetName() return self.name end
function FrameMixin:GetParent() return self.parent end
function FrameMixin:SetParent(parent)
  if self.parent and self.parent.children then
    for i, child in ipairs(self.parent.children) do
      if child == self then table.remove(self.parent.children, i) break end
    end
  end
  self.parent = parent
  if parent and parent.children then table.insert(parent.children, self) end
end
function FrameMixin:GetChildren() return unpack(self.children) end
function FrameMixin:IsObjectType(t)
  if t == "Button" then return self.frameType == "Button" or self.frameType == "ItemButton" end
  return self.frameType == t
end
function FrameMixin:IsShown() return self.shown end
function FrameMixin:IsVisible()
  if not self.shown then return false end
  if self.parent then return self.parent:IsVisible() end
  return true
end
function FrameMixin:Show()
  if self.shown then return end
  local wasVisible = self:IsVisible()
  self.shown = true
  if not wasVisible and self:IsVisible() then self:RunScript("OnShow") end
end
function FrameMixin:Hide()
  if not self.shown then return end
  local wasVisible = self:IsVisible()
  self.shown = false
  if wasVisible then self:RunScript("OnHide") end
end
function FrameMixin:SetShown(shown) if shown then self:Show() else self:Hide() end end
function FrameMixin:RunScript(handler, ...)
  if self.scripts[handler] then self.scripts[handler](self, ...) end
  for _, hook in ipairs(self.hooks[handler] or {}) do hook(self, ...) end
end
function FrameMixin:SetScript(handler, fn) self.scripts[handler] = fn end
function FrameMixin:GetScript(handler) return self.scripts[handler] end
function FrameMixin:HookScript(handler, fn)
  self.hooks[handler] = self.hooks[handler] or {}
  table.insert(self.hooks[handler], fn)
end
function FrameMixin:RegisterEvent(event)
  self.registeredEvents[event] = true
  Stubs.eventFrames[self] = true
end
function FrameMixin:UnregisterEvent(event) self.registeredEvents[event] = nil end
function FrameMixin:SetSize(w, h) self.width, self.height = w, h end
function FrameMixin:GetSize() return self.width, self.height end
function FrameMixin:SetPoint() end
function FrameMixin:ClearAllPoints() end
function FrameMixin:SetAlpha(a) self.alpha = a end
function FrameMixin:EnableMouse(enabled) self.mouseEnabled = enabled end
function FrameMixin:RegisterForClicks(...) self.clicks = { ... } end
function FrameMixin:GetLeft() return self.left end
function FrameMixin:GetTop() return self.top end
function FrameMixin:GetBottom() return self.bottom end
function FrameMixin:GetEffectiveScale() return self.scale end
function FrameMixin:GetBagID() return self.bagID end
function FrameMixin:GetID() return self.slotID or 0 end
function FrameMixin:IsReadable() return self.readable == true end
function FrameMixin:Click(button, down)
  Stubs.Log("Click", self.name or self.id, button or "LeftButton")
  self:RunScript("OnClick", button or "LeftButton", down or false)
end

----------------------------------------------------------------------------
-- Globals
----------------------------------------------------------------------------

_G.UIParent = Stubs.CreateFrame("Frame", "UIParent")
_G.GetBuildInfo = function() return "1.60.1", "70862", "Nov 7 2026", 16001 end
_G.InCombatLockdown = function() return Stubs.combat end
_G.C_RestrictedActions = { IsAddOnRestrictionActive = function() return Stubs.combat end }
_G.Enum = {
  AddOnRestrictionType = { Combat = 0 },
  PlayerInteractionType = { Banker = 8, Merchant = 5 },
  InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 },
}
_G.C_Timer = { After = function(_, fn) table.insert(Stubs.timers, fn) end }
_G.RunNextFrame = function(fn) table.insert(Stubs.nextFrameQueue, fn) end
_G.CursorHasItem = function() return Stubs.cursorHasItem end
_G.ClearCursor = function() Stubs.cursorHasItem = false Stubs.Log("ClearCursor") end
_G.InRepairMode = function() return Stubs.repairMode == true end
_G.SlashCmdList = {}
_G.print = function(...) Stubs.Log("print", ...) end
_G.debugstack = function() return Stubs.fakeStack or "" end
_G.hooksecurefunc = function(tableOrName, name, hook)
  if type(tableOrName) == "string" then
    hook, name, tableOrName = name, tableOrName, _G
  end
  local original = tableOrName[name]
  tableOrName[name] = function(...)
    local results = { original(...) }
    hook(...)
    return unpack(results)
  end
end

_G.GAMEPAD_FACE_RIGHT = "PAD2"
_G.GAMEPAD_FACE_BOTTOM = "PAD1"
_G.GAMEPAD_FACE_LEFT = "PAD3"
_G.GAMEPAD_FACE_TOP = "PAD4"

Stubs.overrides = {}
_G.SetOverrideBindingClick = function(owner, isPriority, key, buttonName, mouseButton)
  assert(not Stubs.combat, "SetOverrideBindingClick in combat")
  Stubs.overrides[key] = "CLICK " .. buttonName .. ":" .. (mouseButton or "LeftButton")
  Stubs.Log("SetOverrideBindingClick", key, Stubs.overrides[key])
end
_G.SetOverrideBinding = function(owner, isPriority, key, command)
  assert(not Stubs.combat, "SetOverrideBinding in combat")
  Stubs.overrides[key] = command
  Stubs.Log("SetOverrideBinding", key, tostring(command))
end
_G.GetBindingAction = function(key) return Stubs.overrides[key] or "" end

_G.MerchantFrame = Stubs.CreateFrame("Frame", "MerchantFrame", UIParent)
MerchantFrame.selectedTab = 1
MerchantFrame:Hide()

Stubs.items = {}
_G.C_Container = {
  GetContainerItemInfo = function(bag, slot) return Stubs.items[bag .. ":" .. slot] end,
  GetContainerItemDurability = function() return 5, 10 end,
  SplitContainerItem = function(...) Stubs.Log("SplitContainerItem", ...) end,
}
_G.C_Item = {
  IsEquippableItem = function(itemID) return itemID == 2000 end,
  IsUsableItem = function(itemID) return itemID == 3000 end,
}
Stubs.bankOpen = false
_G.C_PlayerInteractionManager = {
  IsInteractingWithNpcOfType = function(kind) return kind == Enum.PlayerInteractionType.Banker and Stubs.bankOpen end,
}
_G.StackSplitFrame = Stubs.CreateFrame("Frame", "StackSplitFrame", UIParent)
function StackSplitFrame:OpenStackSplitFrame(count, owner) Stubs.Log("OpenStackSplitFrame", count, owner.name or owner.id) end
_G.ShowUIPanel = function(frame) Stubs.Log("ShowUIPanel", frame.name) end

_G.MenuUtil = {
  CreateContextMenu = function(owner, generator)
    local entries = {}
    local description = {
      SetTag = function() end,
      CreateDivider = function() table.insert(entries, { divider = true }) end,
      CreateButton = function(_, label, fn) table.insert(entries, { label = label, func = fn }) end,
    }
    generator(owner, description)
    Stubs.lastMenu = entries
    Stubs.Log("CreateContextMenu", #entries)
    return entries
  end,
}

----------------------------------------------------------------------------
-- Blizzard gamepad UI
----------------------------------------------------------------------------

_G.InputUtil = { IsGamepadUIEnabled = function() return Stubs.gamepadUI end }

local FocusManager = { shownFrames = {}, isUIFocused = false, focusedFrame = nil }
_G.GamepadMode = { FrameControlsManager = FocusManager }

local function IndexOf(list, value)
  for i, v in ipairs(list) do if v == value then return i end end
  return nil
end

function FocusManager:FrameShown(frame)
  assert(not Stubs.combat, "FrameShown in combat")
  Stubs.Log("FrameShown", frame.name or frame.id)
  if IndexOf(self.shownFrames, frame) then return false end
  table.insert(self.shownFrames, frame)
  self:Focus(frame)
  return true
end

function FocusManager:Focus(frame)
  if self.focusedFrame and self.focusedFrame ~= frame and self.focusedFrame.UnfocusGamepad then
    self.focusedFrame.UnfocusGamepad(self.focusedFrame)
  end
  self.focusedFrame = frame
  self.isUIFocused = true
  SmartNavigation:HandlePanelOpen(frame)
  if frame.FocusGamepad then frame.FocusGamepad(frame) end
end

function FocusManager:FrameHidden(frame)
  assert(not Stubs.combat, "FrameHidden in combat")
  Stubs.Log("FrameHidden", frame.name or frame.id)
  local index = IndexOf(self.shownFrames, frame)
  if not index then return false end
  table.remove(self.shownFrames, index)
  if self.focusedFrame == frame then
    if frame.UnfocusGamepad then frame.UnfocusGamepad(frame) end
    SmartNavigation:RemovePanel(frame)
    if self.shownFrames[1] then
      self:Focus(self.shownFrames[1])
    else
      self.focusedFrame = nil
      self.isUIFocused = false
    end
  end
  return true
end

local SmartNav = { panels = {}, currentButton = nil, activeFrame = nil }
_G.SmartNavigation = SmartNav
function SmartNav:HandlePanelOpen(frame)
  if not self.panels[frame] then
    self.panels[frame] = {}
    if frame.smartNavPanelInfoAddedCallback then frame.smartNavPanelInfoAddedCallback(self.panels[frame]) end
  end
  self.activeFrame = frame
  self.currentButton = self.panels[frame].target
end
function SmartNav:RemovePanel(frame)
  self.panels[frame] = nil
  if self.activeFrame == frame then self.activeFrame = nil self.currentButton = nil end
end
function SmartNav:SetTargetButtonForFrame(frame, button)
  assert(not Stubs.combat, "SetTargetButtonForFrame in combat")
  Stubs.Log("SetTargetButtonForFrame", frame.name or frame.id, button and (button.name or button.id))
  self.panels[frame] = self.panels[frame] or {}
  self.panels[frame].target = button
  if self.activeFrame == frame then self.currentButton = button end
end
function SmartNav:RefreshButtonGroups(frame)
  assert(not Stubs.combat, "RefreshButtonGroups in combat")
  Stubs.Log("RefreshButtonGroups", frame.name or frame.id)
end
function SmartNav:GetActiveFrame() return self.activeFrame end
function SmartNav:GetCurrentButton() return self.currentButton end
function SmartNav:Select(button)
  self.currentButton = button
  if self.activeFrame and self.activeFrame.SmartNavigationOnSelect then
    self.activeFrame.SmartNavigationOnSelect(self.activeFrame, button)
  end
end
function SmartNav:PressB()
  local frame = self.activeFrame
  if frame and frame.SmartNavigationCloseHandler then
    return frame.SmartNavigationCloseHandler(frame)
  end
end
_G.SmartNavigation_MarkFrameIgnored = function(frame)
  assert(not Stubs.combat, "MarkFrameIgnored in combat")
  frame.ignored = true
  Stubs.Log("MarkFrameIgnored", frame.name or frame.id)
end
_G.SmartNavigation_IsCurrentButtonClickable = function() return SmartNav.currentButton ~= nil end

_G.PromptedBindingMixin = { VISIBILITY_TYPE = { ALWAYS = 1, ONLY_IF_USABLE = 2, NEVER = 3 } }
_G.AnchorUtil = { CreateAnchor = function(...) return { ... } end }

local PromptMixin = {}
PromptMixin.__index = PromptMixin
function PromptMixin:AddFooterBinding(opts) self.opts = opts end
function PromptMixin:GetLabel()
  local label = self.opts.label
  if type(label) == "function" then return label() end
  return label
end
function PromptMixin:IsUsable()
  local cond = self.opts.conditions
  if type(cond) == "function" then return cond() end
  return true
end

local FooterMixin = {}
FooterMixin.__index = FooterMixin
function FooterMixin:AddPromptedBinding(prompt) table.insert(self.prompts, prompt) end
function FooterMixin:Finalize() self.finalized = true end
function FooterMixin:SetCustomAnchor(anchor) self.customAnchor = anchor end
function FooterMixin:ApplyInputLegendAttachment() end
function FooterMixin:ShowAndActivateBindings() self.isShown = true self.refreshes = (self.refreshes or 0) + 1 Stubs.Log("FooterShow", self.parent.name) end
function FooterMixin:HideAndDeactivateBindings() self.isShown = false Stubs.Log("FooterHide", self.parent.name) end
function FooterMixin:Refresh() self.refreshes = (self.refreshes or 0) + 1 end
function FooterMixin:VisibleLabels()
  local labels = {}
  for _, prompt in ipairs(self.prompts) do
    if prompt:IsUsable() then table.insert(labels, prompt.key .. "=" .. tostring(prompt:GetLabel())) end
  end
  return table.concat(labels, ", ")
end

Stubs.footers = {}
_G.GamepadSharedUtility = {
  CreatePromptedBinding = function(key, debugName)
    assert(type(debugName) == "string", "prompt-only bindings must pass a debug name as the second argument")
    return setmetatable({ key = key, debugName = debugName }, PromptMixin)
  end,
  CreatePromptedBindingFooter = function(parent, debugName)
    local footer = setmetatable({ parent = parent, debugName = debugName, prompts = {} }, FooterMixin)
    Stubs.footers[parent] = footer
    return footer
  end,
}

_G.ContainerFrameCombinedBags = Stubs.CreateFrame("Frame", "ContainerFrameCombinedBags")
local hiddenParent = Stubs.CreateFrame("Frame", "BaganatorHiddenParent")
hiddenParent:Hide()
ContainerFrameCombinedBags:SetParent(hiddenParent)
ContainerFrameCombinedBags:Hide()
_G.BankFrame = Stubs.CreateFrame("Frame", "BankFrame")
BankFrame:SetParent(hiddenParent)
_G.ToggleBackpack_Combined = function()
  if ContainerFrameCombinedBags:IsShown() then ContainerFrameCombinedBags:Hide() else ContainerFrameCombinedBags:Show() end
end

----------------------------------------------------------------------------
-- Baganator
----------------------------------------------------------------------------

local callbacks = {}
local CallbackRegistry = {}
function CallbackRegistry:RegisterCallback(event, fn, owner)
  callbacks[event] = callbacks[event] or {}
  table.insert(callbacks[event], fn)
end
function CallbackRegistry:TriggerEvent(event, ...)
  Stubs.Log("BaganatorEvent", event)
  for _, fn in ipairs(callbacks[event] or {}) do fn(nil, ...) end
  if event == "BagShow" then Stubs.backpack:Show() end
  if event == "BagHide" then Stubs.backpack:Hide() end
end

local function MakeView(name, tag)
  local view = Stubs.CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
  view:Hide()
  view.SearchWidget = Stubs.CreateFrame("Frame", name .. "Search", view)
  view.SearchWidget.SearchBox = Stubs.CreateFrame("EditBox", name .. "SearchBox", view.SearchWidget)
  view.Container = Stubs.CreateFrame("Frame", name .. "Container", view)
  view.CloseButton = Stubs.CreateFrame("Button", name .. "CloseButton", view)
  view.SortButton = Stubs.CreateFrame("Button", name .. "SortButton", view)
  function view:CombineStacksAndSort(isReverse) Stubs.Log("CombineStacksAndSort", self.name, tostring(isReverse)) end
  function view:ToggleBagSlots() Stubs.Log("ToggleBagSlots", self.name) end
  function view:ToggleBank() Stubs.Log("ToggleBank", self.name) end
  return view, { regionType = "ButtonFrame", region = view, tags = { tag } }
end

function Stubs.MakeItemButton(parent, name, bagID, slotID, itemID, opts)
  opts = opts or {}
  local button = Stubs.CreateFrame("ItemButton", name, parent)
  button.buttonContext = "ButtonContext_ContainerFrameItemButton"
  button.bagID, button.slotID = bagID, slotID
  button.left, button.top = opts.left or 100, opts.top or 400
  button.readable = opts.readable
  if itemID then
    button.hasItem = true
    button.BGR = { itemID = itemID }
    Stubs.items[bagID .. ":" .. slotID] = { itemID = itemID, stackCount = opts.stackCount or 1, hasLoot = opts.hasLoot, isLocked = false }
  else
    button.hasItem = false
    button.BGR = {}
  end
  button:SetScript("OnClick", function(self, mouseButton) Stubs.Log("ItemOnClick", self.name, mouseButton) end)
  return button
end

local backpack, backpackDetails = MakeView("Baganator_SingleViewBackpackViewFrameblizzard", "backpack")
local bank, bankDetails = MakeView("Baganator_SingleViewBankViewFrameblizzard", "bank")
Stubs.backpack, Stubs.bank = backpack, bank

local allFrames = { backpackDetails, bankDetails }
local listeners = {}
_G.Baganator = {
  API = {
    Skins = {
      GetAllFrames = function() return allFrames end,
      RegisterListener = function(fn) table.insert(listeners, fn) end,
    },
  },
  CallbackRegistry = CallbackRegistry,
}
function Stubs.AddBaganatorFrame(details)
  table.insert(allFrames, details)
  for _, fn in ipairs(listeners) do fn(details) end
end
Stubs.MakeView = MakeView
