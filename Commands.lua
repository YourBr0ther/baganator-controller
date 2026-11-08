local _, addonTable = ...

-- /bgrc prints a status report that is useful in bug reports;
-- /bgrc debug toggles verbose chat output.

local Core = addonTable.Core
local L = addonTable.Locales

local function YesNo(value)
  return value and "|cff00ff00yes|r" or "|cffff4040no|r"
end

local function PrintStatus()
  Core.Print(L.STATUS_HEADER)
  if not Core.IsForever() then
    print("  " .. L.REQUIRES_FOREVER)
    return
  end
  print("  " .. L.STATUS_GAMEPAD_API .. ": " .. YesNo(Core.HasGamepadAPI()))
  print("  " .. L.STATUS_GAMEPAD_ENABLED .. ": " .. YesNo(Core.IsGamepadUIEnabled()))
  print("  " .. L.STATUS_RESTRICTED .. ": " .. YesNo(Core.IsRestricted()))
  if not Core.IsInitialized() then
    return
  end
  local known, tracked = addonTable.Frames.GetCounts()
  print("  " .. L.STATUS_FRAMES .. ": " .. known)
  print("  " .. L.STATUS_TRACKED .. ": " .. tracked)
  local focused = Core.GetFocusedFrame()
  print("  " .. L.STATUS_FOCUSED .. ": " .. (focused and Core.GetFrameName(focused) or L.STATUS_NONE))
end

local function OnSlashCommand(message)
  message = (message or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if message == "debug" then
    Core.DEBUG = not Core.DEBUG
    Core.Print("debug " .. (Core.DEBUG and "on" or "off"))
    return
  end
  PrintStatus()
end

SLASH_BAGANATOR_CONTROLLER1 = "/bgrc"
SLASH_BAGANATOR_CONTROLLER2 = "/baganatorcontroller"
SlashCmdList["BAGANATOR_CONTROLLER"] = OnSlashCommand
