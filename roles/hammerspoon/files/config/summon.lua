local previousApp = nil
local currentApp = nil

local function appIdentity(app)
  if not app then
    return nil
  end

  return app:bundleID() or app:name()
end

local function resolveApp(identifier)
  if not identifier then
    return nil
  end

  return hs.application.get(identifier) or hs.application.find(identifier)
end

local function appMatches(app, identifier, fallbackName)
  if not app then
    return false
  end

  local bundleId = app:bundleID()
  local name = app:name()

  return bundleId == identifier or name == identifier or bundleId == fallbackName or name == fallbackName
end

hs.window.filter.new():subscribe(hs.window.filter.windowFocused, function(win)
  local app = win and win:application()
  local identity = appIdentity(app)

  if not identity or identity == currentApp then
    return
  end

  if currentApp then
    previousApp = currentApp
  end

  currentApp = identity
end)

return function(appName)
  local target = (_G.apps and _G.apps[appName]) or {}
  local id = target.id or appName
  local frontmostApp = hs.application.frontmostApplication()
  local app = resolveApp(id) or resolveApp(appName)

  if appMatches(frontmostApp, id, appName) and previousApp and not appMatches(frontmostApp, previousApp, previousApp) then
    local prevApp = resolveApp(previousApp)
    if prevApp then
      prevApp:activate()
    else
      hs.application.open(previousApp)
    end
  elseif app and next(app:allWindows()) then
    app:activate()
  else
    local opened = hs.application.open(id)
    if not opened and appName ~= id then
      hs.application.open(appName)
    end
  end
end
