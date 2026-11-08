-- Loads the addon files in TOC order against tests/wow_stubs.lua and walks
-- through the main scenarios. Run with: python3 tests/run.py

local root = ...
assert(root, "pass the addon root directory as the first argument")

dofile(root .. "/tests/wow_stubs.lua")

local function ReadToc()
  local files = {}
  for line in io.lines(root .. "/Baganator_Controller.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^##") and not line:match("^#") then
      table.insert(files, line)
    end
  end
  return files
end

-- Any read of a global the stubs do not define is a bug in the addon (a typo
-- or a missing stub), except for optional globals the addon probes on purpose
-- and the Blizzard/Baganator string constants looked up by Locales.Get.
local optionalGlobals = {
  GuildBankFrame = true,
  BankFrame = true,
  ContainerFrameCombinedBags = true,
  ToggleBackpack_Combined = true,
  RunNextFrame = true,
  C_RestrictedActions = true,
  C_PlayerInteractionManager = true,
  MenuUtil = true,
  StackSplitFrame = true,
  Baganator = true,
  SmartNavigation_IsCurrentButtonClickable = true,
}
setmetatable(_G, {
  __index = function(_, key)
    if optionalGlobals[key] or (type(key) == "string" and key:match("^[A-Z][A-Z0-9_]*$")) then
      return nil
    end
    error("read of undefined global '" .. tostring(key) .. "'", 2)
  end,
})

local addonTable = {}
for _, file in ipairs(ReadToc()) do
  local chunk = assert(loadfile(root .. "/" .. file))
  chunk("Baganator_Controller", addonTable)
end

local failures = 0
local function Check(condition, message)
  if condition then
    io.write("  ok   ", message, "\n")
  else
    failures = failures + 1
    io.write("  FAIL ", message, "\n")
  end
end
local function Section(name)
  io.write("\n== ", name, "\n")
end

local Core = addonTable.Core
local backpack, bank = Stubs.backpack, Stubs.bank
local fcm = GamepadMode.FrameControlsManager

Section("login")
Stubs.FireEvent("PLAYER_LOGIN")
Check(Core.IsInitialized(), "addon initializes on PLAYER_LOGIN")
Check(_G.BaganatorController_InputButton ~= nil, "proxy input button created")
Check(addonTable.Frames.GetInfo(backpack) ~= nil and addonTable.Frames.GetInfo(backpack).kind == "backpack", "backpack view discovered through Baganator skin API")
Check(addonTable.Frames.GetInfo(bank) ~= nil and addonTable.Frames.GetInfo(bank).kind == "bank", "bank view discovered")

Section("open backpack with gamepad UI on")
local item1 = Stubs.MakeItemButton(backpack.Container, "Item1", 0, 1, 2000, { left = 10, top = 400 })
local item2 = Stubs.MakeItemButton(backpack.Container, "Item2", 0, 2, 3000, { left = 50, top = 400, stackCount = 5 })
local item3 = Stubs.MakeItemButton(backpack.Container, "Item3", 0, 3, nil, { left = 10, top = 360 })
Stubs.ClearLog()
backpack:Show()
Check(Core.IsTracked(backpack), "FrameShown called when the backpack is shown")
Check(backpack.SearchWidget.ignored, "search widget marked ignored for SmartNavigation")
Check(SmartNavigation:GetCurrentButton() == item1, "cursor starts on the top-left item button")
Check(Stubs.footers[backpack] and Stubs.footers[backpack].isShown, "prompt footer shown on focus")
Check(Stubs.overrides.PAD3 == "CLICK BaganatorController_InputButton:Context", "X bound to context action while focused")
Check(Stubs.overrides.PAD4 == "CLICK BaganatorController_InputButton:More", "Y bound to more-actions menu while focused")
Check(ContainerFrameCombinedBags:IsShown(), "Blizzard combined bag frame mirrored as shown (radial state)")

Section("prompts and X action")
local footer = Stubs.footers[backpack]
Check(footer:VisibleLabels():find("PAD1=Select", 1, true) ~= nil, "A prompt reads Select on an item")
Check(footer:VisibleLabels():find("PAD3=Equip", 1, true) ~= nil, "X prompt reads Equip for equippable item: " .. footer:VisibleLabels())
Stubs.ClearLog()
BaganatorController_InputButton:Click("Context")
Check(Stubs.LogContains("ItemOnClick Item1 RightButton"), "X right-clicks the focused item button")

SmartNavigation:Select(item2)
Check(footer:VisibleLabels():find("PAD3=Use", 1, true) ~= nil, "X prompt reads Use for usable item")
SmartNavigation:Select(item3)
Check(footer:VisibleLabels():find("PAD3=", 1, true) == nil, "no X prompt on an empty slot")
Check(footer:VisibleLabels():find("PAD1=", 1, true) == nil, "no A prompt on an empty slot without a held item")
Stubs.cursorHasItem = true
Check(footer:VisibleLabels():find("PAD1=Place", 1, true) ~= nil, "A prompt reads Place while carrying an item")
Check(footer:VisibleLabels():find("PAD2=Back", 1, true) ~= nil, "B prompt reads Back while carrying an item")
Stubs.ClearLog()
Check(SmartNavigation:PressB() == true, "close handler reports handled")
Check(Stubs.LogContains("ClearCursor") and backpack:IsVisible(), "B drops the held item instead of closing")
Stubs.cursorHasItem = false

Section("vendor and bank context")
SmartNavigation:Select(item1)
MerchantFrame:Show()
Check(footer:VisibleLabels():find("PAD3=Sell", 1, true) ~= nil, "X prompt reads Sell at a vendor")
Stubs.repairMode = true
Check(footer:VisibleLabels():find("PAD3=Repair", 1, true) ~= nil, "X prompt reads Repair in repair mode")
Stubs.repairMode = false
MerchantFrame:Hide()
Stubs.bankOpen = true
Check(footer:VisibleLabels():find("PAD3=Move", 1, true) ~= nil, "X prompt reads Move while the bank is open")
Stubs.bankOpen = false

Section("Y more actions menu")
SmartNavigation:Select(item2)
Stubs.ClearLog()
BaganatorController_InputButton:Click("More")
Check(Stubs.lastMenu ~= nil, "context menu created")
local labels = {}
for _, entry in ipairs(Stubs.lastMenu or {}) do if entry.label then labels[entry.label] = entry end end
Check(labels["Split Stack"] ~= nil, "split stack offered for a stack of 5")
Check(labels["Clean Up Bags"] ~= nil, "sort offered")
Check(labels["Bag Slots"] ~= nil and labels["All Characters"] ~= nil and labels["Currencies"] ~= nil, "backpack toggles offered")
Check(labels["Customise Baganator"] ~= nil, "customise entry offered")
if labels["Split Stack"] then
  labels["Split Stack"].func()
  Check(Stubs.LogContains("OpenStackSplitFrame 5 Item2") and Stubs.LogContains("ShowUIPanel StackSplitFrame"), "split stack opens the stack split frame")
end
if labels["Clean Up Bags"] then
  labels["Clean Up Bags"].func()
  Check(Stubs.LogContains("CombineStacksAndSort Baganator_SingleViewBackpackViewFrameblizzard false"), "sort calls Baganator's sorter")
end

Section("layout refresh")
Stubs.ClearLog()
item1:Hide()
Baganator.CallbackRegistry:TriggerEvent("ViewComplete")
Stubs.RunNextFrames()
Check(Stubs.LogContains("RefreshButtonGroups Baganator_SingleViewBackpackViewFrameblizzard"), "ViewComplete re-scans the frame")
Check(SmartNavigation:GetCurrentButton() == item2, "cursor moves off a hidden button to the next item: " .. tostring(SmartNavigation:GetCurrentButton() and SmartNavigation:GetCurrentButton().name))
item1:Show()

Section("close with B")
Stubs.ClearLog()
Check(SmartNavigation:PressB() == true, "close handler handled")
Check(not backpack:IsVisible(), "B closes the backpack through Baganator's BagHide")
Check(not Core.IsTracked(backpack), "FrameHidden called on hide")
Check(not footer.isShown, "footer hidden on hide")
Check(not ContainerFrameCombinedBags:IsShown(), "Blizzard combined bag frame mirrored as hidden")

Section("radial menu toggle")
Stubs.ClearLog()
Stubs.fakeStack = "GamepadRadial.lua:619: in function <...>"
ToggleBackpack_Combined()
Check(backpack:IsVisible(), "radial Bags entry opens Baganator")
ToggleBackpack_Combined()
Check(not backpack:IsVisible(), "radial Bags entry closes Baganator")
Stubs.fakeStack = "ContainerFrame.lua:195: in function `ToggleBackpack'"
Stubs.ClearLog()
ToggleBackpack_Combined()
Check(not Stubs.LogContains("BaganatorEvent"), "no double toggle when called through ToggleBackpack (Baganator handles it)")
ContainerFrameCombinedBags:Hide()
Stubs.fakeStack = nil

Section("hidden Blizzard bank frame")
Stubs.ClearLog()
fcm:FrameShown(BankFrame)
Check(not Core.IsTracked(BankFrame), "invisible BankFrame is unregistered right after Blizzard registers it")

Section("combat deferral")
Stubs.combat = true
backpack:Show()
Check(not Core.IsTracked(backpack), "no FrameShown while combat restricted")
Stubs.combat = false
Stubs.FireEvent("PLAYER_REGEN_ENABLED")
Check(Core.IsTracked(backpack), "frame registered after combat ends")
Stubs.combat = true
backpack:Hide()
Check(Core.IsTracked(backpack), "no FrameHidden while combat restricted")
Stubs.combat = false
Stubs.FireEvent("PLAYER_REGEN_ENABLED")
Check(not Core.IsTracked(backpack), "stale registration cleaned up after combat")

Section("two frames and unfocus")
backpack:Show()
bank:Show()
Check(fcm.focusedFrame == bank, "newly shown bank takes focus")
Check(not Stubs.footers[backpack].isShown and Stubs.footers[bank].isShown, "only the focused frame shows a footer")
bank:Hide()
Check(fcm.focusedFrame == backpack and Stubs.footers[backpack].isShown, "focus and footer return to the backpack")

Section("leaving the gamepad UI")
Stubs.gamepadUI = false
-- Blizzard's UninitializeGamepad wipes the focus manager and SmartNavigation
-- state on this transition; emulate that before our handler runs.
fcm.shownFrames = {}
fcm.focusedFrame = nil
fcm.isUIFocused = false
SmartNavigation.panels = {}
SmartNavigation.activeFrame = nil
SmartNavigation.currentButton = nil
Stubs.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", 0, 1)
Stubs.RunNextFrames()
Check(Stubs.overrides.PAD3 == nil and Stubs.overrides.PAD4 == nil, "our X/Y overrides cleared when leaving the gamepad UI")
Check(not Stubs.footers[backpack].isShown, "footers hidden when leaving the gamepad UI")
backpack:Hide()
backpack:Show()
Check(#fcm.shownFrames == 0 or not Core.IsTracked(backpack), "no registration while gamepad UI is off")
Stubs.gamepadUI = true
Stubs.FireEvent("INPUT_DEVICE_INTERFACE_TRANSITION", 1, 0)
Stubs.RunNextFrames()
Check(Core.IsTracked(backpack), "already open frame registered when gamepad UI turns on")

Section("late frame creation (skin swap)")
local lateView, lateDetails = Stubs.MakeView("Baganator_CategoryViewBackpackViewFramedark", "backpack")
Stubs.AddBaganatorFrame(lateDetails)
Check(addonTable.Frames.GetInfo(lateView) ~= nil, "frames created later are picked up through the skin listener")

Section("slash command")
Stubs.ClearLog()
SlashCmdList["BAGANATOR_CONTROLLER"]("")
Check(Stubs.LogContains("Baganator Controller status"), "/bgrc prints a status report")

io.write("\n")
if failures > 0 then
  io.write(failures, " check(s) failed\n")
  os.exit(1)
end
io.write("all checks passed\n")
