--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

lilHyper = { 'cmd', 'alt', 'ctrl' }             -- or D+F 🤘
Hyper = { 'shift', 'cmd', 'alt', 'ctrl' } -- or S+D+F 😅

hs.loadSpoon('ReloadConfiguration'):start()

require('helpers')

positions = require('positions')
apps  = require('apps')
layouts = require('layouts')
summon = require('summon')
chain = require('chain')

--------------------------------------------------------------------------------
-- Summon Specific Apps
--------------------------------------------------------------------------------
-- F13 to open summon modal
-- See `apps.lua` for `summon` modal bindings

local summonModalBindings = tableFlip(hs.fnutils.map(apps, function(app)
  return app.summon
end))

registerModalBindings(nil, 'f13', hs.fnutils.map(summonModalBindings, function(app)
  return function() summon(app) end
end), true)


--------------------------------------------------------------------------------
-- Misc Macros
--------------------------------------------------------------------------------
-- F14 to open macros modal

local macros = {
  s = function() hs.eventtap.keyStroke({ 'cmd', 'shift' }, '4') end,  -- screenshot
  e = function() hs.eventtap.keyStroke({ 'cmd', 'ctrl' }, 'space') end, -- emoji picker
  a = function() hs.eventtap.keyStroke({ 'cmd' }, '`') end,           -- next window of focused app
  -- c = function() hs.eventtap.keyStroke({ 'cmd', 'ctrl' }, 'c') end,   -- color picker app
  -- x = function() hs.eventtap.keyStroke({ 'cmd', 'ctrl' }, 'x') end,   -- color picker eye dropper
  b = function() hs.eventtap.keyStroke(Hyper, 'b') end, -- browser bookmark search (raycast)
  t = function() hs.eventtap.keyStroke(Hyper, 't') end, -- browser current tab search (raycast)
  g = function() hs.eventtap.keyStroke(Hyper, 'g') end, -- gif search (raycast)
}

registerModalBindings(nil, 'f16', macros, true)

--------------------------------------------------------------------------------
-- Multi Window Management
--------------------------------------------------------------------------------
-- hjkl  focus window west/south/north/east
-- a     unide [a]ll application windows
-- p     [p]ick layout
-- m     [m]aximize window
-- n     [n]ext window in current cell, like `n/p` in vim
-- u     warp [u]nder another window cell
-- ;     toggle alternate layout

hs.window.animationDuration = 0

local layout = hs.loadSpoon('GridLayout')
    :start()
    :setLayouts(layouts)
    :setApps(apps)
    :setGrid(positions.full_grid)
    :setMargins('0x0')

if (hs.screen.primaryScreen():name() ~= 'Built-in Retina Display') then
  layout:selectLayout(1)
end

local windowManagementBindings = {
  ['h'] = function() hs.window.focusedWindow():focusWindowWest(nil, true) end,
  ['j'] = function() hs.window.focusedWindow():focusWindowSouth(nil, true) end,
  ['k'] = function() hs.window.focusedWindow():focusWindowNorth(nil, true) end,
  ['l'] = function() hs.window.focusedWindow():focusWindowEast(nil, true) end,
  ['a'] = function() hs.application.frontmostApplication():focus() end,
  ['p'] = layout.selectLayout,
  ['u'] = layout.bindToCell,
  [';'] = layout.selectNextVariant,
  ["'"] = layout.resetLayout,
  -- ['m'] = toggleMaximized, -- Re-implement in GridLayout?
  -- ['n'] = focusNextCellWindow, -- Re-implement in GridLayout?
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
