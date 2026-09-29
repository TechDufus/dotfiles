local helpersPath = 'roles/hammerspoon/files/config/helpers.lua'
local placement
local application = {}
local reportedErrors = {}
local applicationElement = {
  enhanced = true,
  setterCalls = 0,
}

function applicationElement:attributeValue(attribute)
  assert(attribute == 'AXEnhancedUserInterface')
  return self.enhanced
end

function applicationElement:setAttributeValue(attribute, value)
  assert(attribute == 'AXEnhancedUserInterface')
  self.setterCalls = self.setterCalls + 1
  if self.rejectedValue == value then
    return nil, self.setterError
  end
  self.enhanced = value
  if self.setterError then
    return nil, self.setterError
  end
  return self
end

local objectMetatable = {
  setFrame = function(window, frame, duration)
    return placement(window, frame, duration)
  end,
  setFrameWithWorkarounds = function(window, frame, duration)
    return placement(window, frame, duration)
  end,
  setTopLeft = function(window, ...)
    return placement(window, ...)
  end,
  setSize = function(window, ...)
    return placement(window, ...)
  end,
}

hs = {
  axuielement = {
    applicationElement = function(targetApplication)
      assert(targetApplication == application)
      return applicationElement
    end,
  },
  getObjectMetatable = function(typeName)
    assert(typeName == 'hs.window')
    return objectMetatable
  end,
  window = { animationDuration = 0 },
  printf = function(format, ...)
    table.insert(reportedErrors, string.format(format, ...))
  end,
}

assert(loadfile(helpersPath), 'helpers.lua must parse')()
assert(installAXEnhancedUserInterfaceFrameWorkaround())
local wrappedSetFrame = objectMetatable.setFrame
assert(installAXEnhancedUserInterfaceFrameWorkaround())
assert(objectMetatable.setFrame == wrappedSetFrame, 'installation must be idempotent')

local function makeWindow()
  local window = {}
  function window:application()
    return application
  end
  return window
end

local frame = { x = 5, y = 35, w = 1528, h = 2120 }
local window = makeWindow()
local observedEnhanced
placement = function(target, targetFrame, duration)
  assert(target == window)
  assert(targetFrame == frame)
  observedEnhanced = applicationElement.enhanced
  assert(duration == nil)
  return target, 'placed', nil
end

local first, second, third = objectMetatable.setFrame(window, frame)
assert(observedEnhanced == false, 'enhanced UI must be off while synchronously placing')
assert(first == window and second == 'placed' and third == nil, 'placement return values must be preserved')
assert(applicationElement.enhanced == true, 'enhanced UI must be restored after successful placement')
assert(applicationElement.setterCalls == 2, 'enabled state must be disabled and restored exactly once')

local placementError = {}
placement = function(target)
  observedEnhanced = applicationElement.enhanced
  error(placementError)
end
local ok, result = pcall(function()
  objectMetatable.setFrame(window, frame, 0)
end)
assert(not ok and result == placementError, 'placement failure must propagate unchanged')
assert(observedEnhanced == false, 'enhanced UI must be off during failing placement')
assert(applicationElement.enhanced == true, 'enhanced UI must be restored after placement failure')
applicationElement.setterCalls = 0
placement = function(target, x, y)
  assert(target == window)
  assert(applicationElement.enhanced == false)
  assert(x == 12 and y == 34, 'setTopLeft must preserve both numeric coordinates')
  observedEnhanced = applicationElement.enhanced
  return target, x, y
end
local topLeftTarget, x, y = objectMetatable.setTopLeft(window, 12, 34)
assert(observedEnhanced == false, 'enhanced UI must be off during setTopLeft')
assert(topLeftTarget == window and x == 12 and y == 34)
assert(applicationElement.enhanced == true, 'setTopLeft must restore enhanced UI')
assert(applicationElement.setterCalls == 2)

applicationElement.setterCalls = 0
placement = function(target, width, height)
  assert(applicationElement.enhanced == false)
  assert(width == 720 and height == 480, 'setSize must preserve both numeric dimensions')
  return target, width, height
end
local sizeTarget, width, height = objectMetatable.setSize(window, 720, 480)
assert(sizeTarget == window and width == 720 and height == 480)
assert(applicationElement.enhanced == true, 'setSize must restore enhanced UI')
assert(applicationElement.setterCalls == 2)


applicationElement.enhanced = false
applicationElement.setterCalls = 0
placement = function()
  assert(applicationElement.enhanced == false)
  return 'placed'
end
assert(objectMetatable.setFrame(window, frame, 0) == 'placed')
assert(applicationElement.setterCalls == 0, 'false enhanced UI state must remain untouched')

applicationElement.enhanced = nil
placement = function(target)
  assert(target == window)
  return 'placed'
end
assert(objectMetatable.setFrame(window, frame, 0) == 'placed')
assert(applicationElement.setterCalls == 0, 'unsupported attribute value must remain untouched')

local unsupported = {}
function unsupported:application()
  return nil
end
placement = function(target)
  assert(target == unsupported)
  return 'placed'
end
assert(objectMetatable.setFrame(unsupported, frame, 0) == 'placed')

applicationElement.enhanced = true
applicationElement.setterCalls = 0
applicationElement.setterError = 'Function or method not implemented'
placement = function(target)
  assert(applicationElement.enhanced == false, 'AX readback must confirm failed-result setters changed the flag')
  return 'placed'
end
assert(objectMetatable.setFrame(window, frame, 0) == 'placed')
assert(applicationElement.enhanced == true, 'restoration readback must confirm the original flag')
assert(applicationElement.setterCalls == 2)
assert(#reportedErrors == 0, 'matching readback must override the native setter error')
applicationElement.setterError = nil

applicationElement.setterCalls = 0
applicationElement.rejectedValue = false
applicationElement.setterError = 'attribute update rejected'
local placementCalled = false
placement = function()
  placementCalled = true
  return 'placed'
end
local disableOk, disableError = pcall(function()
  objectMetatable.setFrame(window, frame, 0)
end)
assert(not disableOk and disableError == applicationElement.setterError)
assert(not placementCalled, 'placement must not run when enhanced UI could not be disabled')
assert(applicationElement.enhanced == true, 'failed disable must preserve the original flag')
assert(applicationElement.setterCalls == 2, 'failed disable must attempt to restore the original flag')
applicationElement.rejectedValue = nil
applicationElement.setterError = nil

applicationElement.setterCalls = 0
placement = function(target, targetFrame, duration)
  assert(applicationElement.enhanced == true, 'animated placement must not change enhanced UI')
  assert(duration == 1)
  return 'animated'
end
assert(objectMetatable.setFrame(window, frame, 1) == 'animated')
assert(applicationElement.setterCalls == 0, 'animated placement must leave enhanced UI untouched')

print('ok - AX enhanced UI is scoped to synchronous frame placement')
