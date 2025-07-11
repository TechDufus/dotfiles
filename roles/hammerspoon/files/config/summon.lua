-- Simplified summon with window memory (no cycling)
require('helpers')

-- Track last focused window for each application
local appWindowTrackers = {}
local lastFocusedApp = nil

-- Window filter to track focus changes
local windowFilter = hs.window.filter.new()
windowFilter:subscribe(hs.window.filter.windowFocused, function(window)
  if window and window:application() then
    local bundleID = window:application():bundleID()
    
    -- Remember this window for the app
    appWindowTrackers[bundleID] = {
      lastWindow = window
    }
    
    -- Track the last focused app for toggle behavior
    if bundleID ~= lastFocusedApp then
      lastFocusedApp = bundleID
    end
  end
end)

-- Simple summon function with window memory
return function (appName)
  local id
  if _G.apps and _G.apps[appName] then
    id = _G.apps[appName].id
  elseif hs.application.find(appName) then
    id = hs.application.find(appName):bundleID()
  else
    id = appName
  end
  
  local app = hs.application.find(id)
  local currentApp = hs.application.frontmostApplication()
  local currentId = currentApp:bundleID()
  
  -- Case 1: App not running or no windows - open it
  if not app or not next(app:allWindows()) then
    hs.application.open(id)
    return
  end
  
  -- Case 2: Different app is frontmost - switch to target app's last window
  if currentId ~= id then
    local tracker = appWindowTrackers[id]
    
    if tracker and tracker.lastWindow and tracker.lastWindow:isStandard() and not tracker.lastWindow:isMinimized() then
      -- Focus the last used window
      tracker.lastWindow:focus()
    else
      -- No tracked window, just activate the app
      app:activate()
    end
  -- Case 3: Target app is already frontmost - toggle back
  else
    if lastFocusedApp and lastFocusedApp ~= id then
      local lastApp = hs.application.find(lastFocusedApp)
      if lastApp then
        local tracker = appWindowTrackers[lastFocusedApp]
        
        if tracker and tracker.lastWindow and tracker.lastWindow:isStandard() and not tracker.lastWindow:isMinimized() then
          tracker.lastWindow:focus()
        else
          lastApp:activate()
        end
      end
    end
  end
end