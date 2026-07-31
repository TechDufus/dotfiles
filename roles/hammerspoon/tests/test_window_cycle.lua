local helpersPath = 'roles/hammerspoon/files/config/helpers.lua'
assert(loadfile(helpersPath), 'helpers.lua must parse')()

local function makeApp(windowSpecs, focusedWindowId)
  local app = { windows = {} }

  for _, spec in ipairs(windowSpecs) do
    local window = {
      windowId = spec.id,
      standard = spec.standard ~= false,
      minimized = spec.minimized == true,
    }

    function window:id()
      return self.windowId
    end

    function window:isStandard()
      return self.standard
    end

    function window:isMinimized()
      return self.minimized
    end

    function window:focus()
      app.focused = self
    end

    table.insert(app.windows, window)
    if spec.id == focusedWindowId then
      app.focused = window
    end
  end

  function app:focusedWindow()
    return self.focused
  end

  function app:allWindows()
    return self.windows
  end

  return app
end

local function useFrontmostApp(app)
  hs = {
    application = {
      frontmostApplication = function()
        return app
      end,
    },
  }
end

local app = makeApp({
  { id = 30 },
  { id = 10 },
  { id = 20 },
}, 10)
useFrontmostApp(app)

assert(focusNextWindowOfFrontmostApp() == true)
assert(app:focusedWindow():id() == 20, 'must focus the next window in stable order')
assert(focusNextWindowOfFrontmostApp() == true)
assert(app:focusedWindow():id() == 30, 'must reach every eligible window')
assert(focusNextWindowOfFrontmostApp() == true)
assert(app:focusedWindow():id() == 10, 'must wrap to the first eligible window')

local filteredApp = makeApp({
  { id = 10 },
  { id = 20, minimized = true },
  { id = 30, standard = false },
}, 10)
useFrontmostApp(filteredApp)

assert(focusNextWindowOfFrontmostApp() == false)
assert(filteredApp:focusedWindow():id() == 10, 'must ignore minimized and non-standard windows')

local missingIdApp = makeApp({ { id = nil } }, nil)
missingIdApp.focused = missingIdApp.windows[1]
useFrontmostApp(missingIdApp)
assert(focusNextWindowOfFrontmostApp() == false, 'must tolerate focused windows without a CG window ID')

useFrontmostApp(nil)
assert(focusNextWindowOfFrontmostApp() == false, 'must tolerate a missing frontmost application')

print('ok - circular same-app window traversal')
