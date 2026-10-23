--------------------------------------------------------------------------------
-- Debug Helpers
--------------------------------------------------------------------------------

function printi(...)
  return print(hs.inspect(...))
end


--------------------------------------------------------------------------------
-- Lua Helpers
--------------------------------------------------------------------------------

function tableFlip(t)
  local n = {}

  for k,v in pairs(t) do
    n[v] = k
  end

  return n;
end

function tableKeys(t)
  local n = {}

  for k,_ in pairs(t) do
    table.insert(n, k)
  end

  return n;
end

function tableMapWithKeys(t, fn)
  local n = {}

  for _,v in pairs(t) do
    local keyPair = fn(v)
    n[keyPair[1]] = keyPair[2]
  end

  return n;
end


--------------------------------------------------------------------------------
-- Application Helpers
--------------------------------------------------------------------------------

function getApp(appName)
  return hs.application.get(apps[appName].id)
end

function isAppVisible(appName)
  local app = getApp(appName)
  return app and not app:isHidden()
end

function isAppOpen(appName)
  return getApp(appName) ~= nil
end

function isAppClosed(appName)
  return not isAppOpen(appName)
end

function focusNextWindowOfFrontmostApp()
  local app = hs.application.frontmostApplication()
  local focusedWindow = app and app:focusedWindow()
  if not focusedWindow then
    return false
  end

  local focusedWindowId = focusedWindow:id()
  if not focusedWindowId then
    return false
  end

  local firstWindow
  local firstWindowId
  local nextWindow
  local nextWindowId

  for _, window in ipairs(app:allWindows()) do
    local windowId = window:id()
    if windowId and window:isStandard() and not window:isMinimized() then
      if not firstWindowId or windowId < firstWindowId then
        firstWindow = window
        firstWindowId = windowId
      end

      if windowId > focusedWindowId and (not nextWindowId or windowId < nextWindowId) then
        nextWindow = window
        nextWindowId = windowId
      end
    end
  end

  local targetWindow = nextWindow or firstWindow
  if not targetWindow or targetWindow:id() == focusedWindowId then
    return false
  end

  targetWindow:focus()
  return true
end

-- function appIs(appName)
--     return hs.application.frontmostApplication():name() == appName
-- end


--------------------------------------------------------------------------------
-- Modal Helpers
--------------------------------------------------------------------------------

function activateModal(mods, key, timeoutSeconds)
  local modal = hs.hotkey.modal.new(mods, key)
  local hasTimeout = type(timeoutSeconds) == 'number' and timeoutSeconds > 0
  local timer = hasTimeout and hs.timer.new(timeoutSeconds, function() modal:exit() end) or nil
  modal:bind('', 'escape', nil, function() modal:exit() end)
  modal:bind('ctrl', 'c', nil, function() modal:exit() end)
  function modal:entered()
    if timer then
      timer:start()
    end
  end
  function modal:exited()
    if timer then
      timer:stop()
    end
  end
  return modal
end

function modalBind(modal, key, fn, exitAfter)
  exitAfter = exitAfter or false
  modal:bind('', key, nil, function()
    fn()
    if exitAfter then
      modal:exit()
    end
  end)
end


--------------------------------------------------------------------------------
-- Binding Helpers
--------------------------------------------------------------------------------

function registerKeyBindings(mods, bindings)
  for key,binding in pairs(bindings) do
    hs.hotkey.bind(mods, key, binding)
  end
end

function registerModalBindings(mods, key, bindings, exitAfter, timeoutSeconds)
  exitAfter = exitAfter or false
  local modal = activateModal(mods, key, timeoutSeconds)
  for modalKey,binding in pairs(bindings) do
    modalBind(modal, modalKey, binding, exitAfter)
  end
  return modal
end

function registerTransientLeader(mods, key, bindings, options)
  options = options or {}

  local timeoutSeconds = options.timeoutSeconds or 1
  local leader = {
    _active = false,
    _tap = nil,
    _timer = nil,
    _triggerTap = nil,
  }

  local function debugEnabled()
    return options.debug == true or hs.settings.get('leader_debug') == true
  end

  local function debugLog(message)
    if not debugEnabled() then
      return
    end

    hs.printf('leader[%s] %s', key, message)
  end

  local function flagsMatch(actualFlags)
    local expectedFlags = {}
    for _, flag in ipairs(mods or {}) do
      expectedFlags[flag] = true
    end

    -- Function-key triggers often report fn=true even when the user did not
    -- press Fn explicitly. Ignore that noise for leader matching.
    for _, flag in ipairs({ 'cmd', 'alt', 'shift', 'ctrl' }) do
      if (actualFlags[flag] or false) ~= (expectedFlags[flag] or false) then
        return false
      end
    end

    return true
  end

  local function stop()
    if leader._timer then
      leader._timer:stop()
      leader._timer = nil
    end

    if leader._tap then
      leader._tap:stop()
      leader._tap = nil
    end

    if leader._active then
      leader._active = false
      if leader.onExit then
        leader:onExit()
      end
      debugLog('exit')
    end

    return leader
  end

  local function dispatch(binding)
    if not binding then
      return false
    end

    hs.timer.doAfter(0, binding)
    return true
  end

  local function bindingKeyForEvent(keyName, flags)
    if flags.shift and type(keyName) == 'string' and #keyName == 1 then
      return string.upper(keyName)
    end

    return keyName
  end

  function leader:isActive()
    return leader._active
  end

  function leader:exit()
    return stop()
  end

  function leader:enter()
    stop()

    if leader.onEnter then
      leader:onEnter()
    end

    leader._active = true

    if timeoutSeconds and timeoutSeconds > 0 then
      leader._timer = hs.timer.doAfter(timeoutSeconds, stop)
    end

    leader._tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
      local keyName = hs.keycodes.map[event:getKeyCode()]
      local flags = event:getFlags()

      if not keyName then
        stop()
        return false
      end

      if keyName == key then
        stop()
        if leader.onRepeat then
          hs.timer.doAfter(0, function()
            leader:onRepeat()
          end)
        end
        return true
      end

      if keyName == 'escape' or (flags.ctrl and keyName == 'c') then
        stop()
        return true
      end

      local bindingKey = bindingKeyForEvent(keyName, flags)
      stop()
      return dispatch(bindings[bindingKey] or bindings[keyName])
    end):start()

    debugLog('enter')
    return leader
  end

  leader._triggerTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    local keyName = hs.keycodes.map[event:getKeyCode()]
    local flags = event:getFlags()

    if keyName ~= key or not flagsMatch(flags) then
      return false
    end

    if leader._active then
      stop()
      if leader.onRepeat then
        hs.timer.doAfter(0, function()
          leader:onRepeat()
        end)
      else
        leader:enter()
      end
      return true
    end

    leader:enter()
    return true
  end):start()

  return leader
end


--------------------------------------------------------------------------------
-- Position Helpers
--------------------------------------------------------------------------------

function getPositions(sizes, leftOrRight, topOrBottom)
  local applyLeftOrRight = function (size)
    if type(positions[size]) == 'string' then
      return positions[size]
    end
    return positions[size][leftOrRight]
  end

  local applyTopOrBottom = function (position)
    local h = math.floor(string.match(position, 'x([0-9]+)') / 2)
    position = string.gsub(position, 'x[0-9]+', 'x'..h)
    if topOrBottom == 'bottom' then
      local y = math.floor(string.match(position, ',([0-9]+)') + h)
      position = string.gsub(position, ',[0-9]+', ','..y)
    end
    return position
  end

  if (topOrBottom) then
    return hs.fnutils.map(hs.fnutils.map(sizes, applyLeftOrRight), applyTopOrBottom)
  end

  return hs.fnutils.map(sizes, applyLeftOrRight)
end


--------------------------------------------------------------------------------
-- Window Frame Helpers
--------------------------------------------------------------------------------

local function reportAXEnhancedUserInterfaceError(action, err)
  if hs and type(hs.printf) == 'function' then
    pcall(hs.printf, '%s: %s', action, tostring(err or 'unknown error'))
  end
end

local function setAXEnhancedUserInterface(applicationElement, value)
  local setterOk, setterResult, setterError = pcall(
    applicationElement.setAttributeValue,
    applicationElement,
    'AXEnhancedUserInterface',
    value
  )
  local readOk, currentValue, readError = pcall(
    applicationElement.attributeValue,
    applicationElement,
    'AXEnhancedUserInterface'
  )

  if readOk and currentValue == value then
    return true
  end
  if not readOk then
    return false, currentValue
  end
  if not setterOk then
    return false, setterResult
  end
  return false, setterError or readError or string.format(
    'AXEnhancedUserInterface did not become %s',
    tostring(value)
  )
end

local function withAXEnhancedUserInterfaceDisabled(window, placement)
  local application = window:application()
  local applicationElement = application and hs.axuielement.applicationElement(application)
  if not applicationElement then
    return placement()
  end

  local readOk, wasEnabled = pcall(
    applicationElement.attributeValue,
    applicationElement,
    'AXEnhancedUserInterface'
  )
  if not readOk or wasEnabled ~= true then
    return placement()
  end

  local disableOk, disableError = setAXEnhancedUserInterface(applicationElement, false)
  if not disableOk then
    local restoreOk, restoreError = setAXEnhancedUserInterface(applicationElement, wasEnabled)
    if not restoreOk then
      reportAXEnhancedUserInterfaceError('Failed to restore AXEnhancedUserInterface', restoreError)
    end
    error(disableError or 'Failed to disable AXEnhancedUserInterface for window placement', 0)
  end

  local results = table.pack(pcall(placement))
  local restoreOk, restoreError = setAXEnhancedUserInterface(applicationElement, wasEnabled)
  if not restoreOk then
    if results[1] then
      error(restoreError or 'Failed to restore AXEnhancedUserInterface', 0)
    end
    reportAXEnhancedUserInterfaceError('Failed to restore AXEnhancedUserInterface', restoreError)
  end

  if not results[1] then
    error(results[2], 0)
  end

  return table.unpack(results, 2, results.n)
end

function installAXEnhancedUserInterfaceFrameWorkaround()
  local getObjectMetatable = hs and hs.getObjectMetatable
  if type(getObjectMetatable) ~= 'function' then
    return false
  end

  local windowMetatable = getObjectMetatable('hs.window')
  if type(windowMetatable) ~= 'table' then
    return false
  end

  local marker = '__dotfilesAXEnhancedUserInterfaceFrameWorkaround'
  if windowMetatable[marker] then
    return true
  end

  local function wrapWindowSetter(methodName, animated)
    local original = windowMetatable[methodName]
    if type(original) ~= 'function' then
      return
    end

    if animated then
      windowMetatable[methodName] = function(window, frame, duration)
        local effectiveDuration = duration
        if effectiveDuration == nil then
          effectiveDuration = hs.window.animationDuration
        end

        if type(effectiveDuration) == 'number' and effectiveDuration > 0 then
          return original(window, frame, duration)
        end

        return withAXEnhancedUserInterfaceDisabled(window, function()
          return original(window, frame, duration)
        end)
      end
    else
      windowMetatable[methodName] = function(window, ...)
        local args = table.pack(...)
        return withAXEnhancedUserInterfaceDisabled(window, function()
          return original(window, table.unpack(args, 1, args.n))
        end)
      end
    end
  end

  wrapWindowSetter('setFrame', true)
  wrapWindowSetter('setFrameWithWorkarounds', true)
  wrapWindowSetter('setTopLeft', false)
  wrapWindowSetter('setSize', false)
  windowMetatable[marker] = true
  return true
end
