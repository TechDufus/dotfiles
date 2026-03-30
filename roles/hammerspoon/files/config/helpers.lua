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

      stop()
      return dispatch(bindings[keyName])
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
