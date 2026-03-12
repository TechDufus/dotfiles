--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

lilHyper = { 'cmd', 'alt', 'ctrl' }             -- or D+F 🤘
Hyper = { 'shift', 'cmd', 'alt', 'ctrl' } -- or S+D+F 😅

local function reloadConfig(files)
  local shouldReload = false

  for _, file in ipairs(files) do
    if file:match('%.lua$') then
      shouldReload = true
      break
    end
  end

  if shouldReload then
    hs.reload()
  end
end

configWatcher = hs.pathwatcher.new(os.getenv('HOME') .. '/.hammerspoon/', reloadConfig):start()

require('helpers')

positions = require('positions')
apps  = require('apps')
layouts = require('layouts')
summon = require('summon')
chain = require('chain')
require('karabiner').start()

--------------------------------------------------------------------------------
-- Misc Macros
--------------------------------------------------------------------------------
-- F16 to open macros modal (created first so summon modal can reference it)

local macros = {
  s = function() hs.eventtap.keyStroke({ 'cmd', 'ctrl', 'shift' }, '4') end,  -- screenshot to clipboard
  e = function() hs.eventtap.keyStroke({ 'cmd', 'ctrl' }, 'space') end, -- emoji picker
  a = function() hs.eventtap.keyStroke({ 'cmd' }, '`') end,           -- next window of focused app
  -- c = function() hs.eventtap.keyStroke({ 'cmd', 'ctrl' }, 'c') end,   -- color picker app
  -- x = function() hs.eventtap.keyStroke({ 'cmd', 'ctrl' }, 'x') end,   -- color picker eye dropper
  b = function() hs.eventtap.keyStroke(Hyper, 'b') end, -- browser bookmark search (raycast)
  t = function() hs.eventtap.keyStroke(Hyper, 't') end, -- browser current tab search (raycast)
  g = function() hs.eventtap.keyStroke(Hyper, 'g') end, -- gif search (raycast)
}

local macroModal = registerModalBindings(nil, 'f16', macros, true)

--------------------------------------------------------------------------------
-- Summon Specific Apps
--------------------------------------------------------------------------------
-- F13 (CapsLock via Karabiner) to open summon modal
-- Double-tap F13/CapsLock to switch to macro modal
-- See `apps.lua` for `summon` modal bindings

local summonModalBindings = tableFlip(hs.fnutils.map(apps, function(app)
  return app.summon
end))

local summonModal = registerModalBindings(nil, 'f13', hs.fnutils.map(summonModalBindings, function(app)
  return function() summon(app) end
end), true)

-- Double-tap detection: F13 pressed while summon modal is open -> switch to macro modal
summonModal:bind('', 'f13', function()
  summonModal:exit()
  macroModal:enter()
end)

--------------------------------------------------------------------------------
-- Window Management
--------------------------------------------------------------------------------
-- a     unhide [a]ll application windows
-- p     [p]ick layout
-- u     warp [u]nder another window cell
-- ;     toggle alternate layout
-- '     reset layout

hs.window.animationDuration = 0

local layout = hs.loadSpoon('GridLayout')
    :start()
    :setLayouts(layouts)
    :setApps(apps)
    :setGrid(positions.full_grid)
    :setMargins('5x5')

local function isBuiltInDisplay(screen)
  local name = ((screen and screen:name()) or ''):lower()
  return name:find('built%-in', 1, false) ~= nil
end

local function selectDefaultLayout()
  local screen = hs.screen.primaryScreen()
  if not screen then
    return
  end

  local mode = screen:currentMode()
  local aspectRatio = mode.w / math.max(mode.h, 1)
  local layoutIndex

  if isBuiltInDisplay(screen) then
    layoutIndex = 2  -- Fullscreen for the internal display
  elseif mode.w >= 5000 or aspectRatio >= 2.8 then
    layoutIndex = 4  -- Ultrawide workspace
  elseif mode.w >= 3840 or mode.h >= 2160 then
    layoutIndex = 1  -- 4K workspace
  else
    layoutIndex = 3  -- Standard external monitor
  end

  layout:selectLayout(layoutIndex)
end

local pendingLayoutSelection = nil

local function scheduleLayoutSelection(delaySeconds)
  if pendingLayoutSelection then
    pendingLayoutSelection:stop()
    pendingLayoutSelection = nil
  end

  pendingLayoutSelection = hs.timer.doAfter(delaySeconds or 0, function()
    pendingLayoutSelection = nil
    selectDefaultLayout()
  end)
end

scheduleLayoutSelection(0)

hs.screen.watcher.new(function()
  scheduleLayoutSelection(1)
end):start()

local windowManagementBindings = {
  ['a'] = function() hs.application.frontmostApplication():focus() end,
  ['p'] = layout.selectLayout,
  ['u'] = layout.bindToCell,
  [';'] = layout.selectNextVariant,
  ["'"] = layout.resetLayout,
}

registerKeyBindings(Hyper, hs.fnutils.map(windowManagementBindings, function(fn)
  return function() fn() end
end))


-- --------------------------------------------------------------------------------
-- -- Screencasting Customizations for 1280x720 HiDPI
-- --------------------------------------------------------------------------------
--
-- if (hs.screen.primaryScreen():name() == '24GL600F') then
--   layout:setMargins('12x12')
-- end


--------------------------------------------------------------------------------
-- Single Window Movements
--------------------------------------------------------------------------------
-- hl    side column movements
-- k     fullscreen and middle column movements
-- j     centered window movements
-- yu    top corner movements
-- nm    bottom corner movements
-- i     insert/snap to nearest grid region

local chainX = { 'thirds', 'halves', 'twoThirds', 'fiveSixths', 'sixths' }
local chainY = { 'full', 'thirds' }

-- local singleWindowMovements = {
--   ['h'] = chain(getPositions(chainX, 'left')),
--   ['k'] = chain(getPositions(chainY, 'center')),
--   ['j'] = chain({ positions.center.large, positions.center.medium, positions.center.small, positions.center.tiny,
--     positions.center.mini }),
--   ['l'] = chain(getPositions(chainX, 'right')),
--   ['y'] = chain(getPositions(chainX, 'left', 'top')),
--   ['u'] = chain(getPositions(chainX, 'right', 'top')),
--   ['n'] = chain(getPositions(chainX, 'left', 'bottom')),
--   ['m'] = chain(getPositions(chainX, 'right', 'bottom')),
--   -- ['i'] = function() hs.grid.snap(hs.window.focusedWindow()) end, -- seems buggy?
-- }

-- registerKeyBindings(bigHyper, hs.fnutils.map(singleWindowMovements, function(fn)
--   return function() fn() end
-- end))


--------------------------------------------------------------------------------
-- The End
--------------------------------------------------------------------------------

hs.notify.show('Hammerspoon loaded', '', '...more like hammerspork')
