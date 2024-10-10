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
  n = {}

  for k,v in pairs(t) do
    n[v] = k
  end

  return n;
end

function tableKeys(t)
  n = {}

  for k,_ in pairs(t) do
    table.insert(n, k)
  end

  return n;
end

function tableMapWithKeys(t, fn)
  n = {}

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

function activateModal(mods, key, timeout)
  timeout = timeout or false
  local modal = hs.hotkey.modal.new(mods, key)
  local timer = hs.timer.new(1, function() modal:exit() end)
  modal:bind('', 'escape', nil, function() modal:exit() end)
  modal:bind('ctrl', 'c', nil, function() modal:exit() end)
  function modal:entered()
    if timeout then
      timer:start()
    end
    print('modal entered')
  end
  function modal:exited()
    if timeout then
      timer:stop()
    end
    print('modal exited')
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

function registerModalBindings(mods, key, bindings, exitAfter)
  exitAfter = exitAfter or false
  local timeout = exitAfter == true
  local modal = activateModal(mods, key, timeout)
  for modalKey,binding in pairs(bindings) do
    modalBind(modal, modalKey, binding, exitAfter)
  end
  return modal
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
