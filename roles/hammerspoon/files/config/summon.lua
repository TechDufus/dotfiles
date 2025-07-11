-- Simplified summon with reliable toggle and proper activation
local previousApp = nil

-- Track what we switch TO (more reliable than tracking what we leave)
hs.window.filter.new():subscribe(hs.window.filter.windowFocused, function(win)
  if win and win:application() then
    local currentApp = hs.application.frontmostApplication():bundleID()
    if currentApp ~= previousApp then
      previousApp = currentApp
    end
  end
end)

return function(appName)
  -- Get app ID
  local id = (_G.apps and _G.apps[appName] and _G.apps[appName].id) or appName
  
  local app = hs.application.find(id)
  local currentId = hs.application.frontmostApplication():bundleID()
  
  -- Case 1: Target app is focused and we have history - toggle back
  if currentId == id and previousApp and previousApp ~= id then
    local prevApp = hs.application.find(previousApp)
    if prevApp then
      prevApp:activate()  -- Use activate for existing apps
    else
      hs.application.open(previousApp)
    end
  -- Case 2: App exists with windows - activate it (don't create new window)
  elseif app and next(app:allWindows()) then
    app:activate()  -- SECRET SAUCE: activate existing instead of open
  -- Case 3: App not running or no windows - open it
  else
    hs.application.open(id)
  end
end