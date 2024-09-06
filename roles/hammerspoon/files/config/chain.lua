--------------------------------------------------------------------------------
-- Chain the specified grid movement positions on the focused window
--
-- Courtesy of: https://github.com/wincent/wincent/blob/master/roles/dotfiles/files/.hammerspoon/init.lua
--------------------------------------------------------------------------------

-- This is like the "chain" feature in Slate, but with a couple of enhancements:
--
--  - Chains always start on the screen the window is currently on.
--  - A chain will be reset after 2 seconds of inactivity, or on switching from
--    one chain to another, or on switching from one app to another, or from one
--    window to another.

local lastSeenChain = nil
local lastSeenWindow = nil

return (function(movements)
  local chainResetInterval = 2 -- seconds
  local cycleLength = #movements
  local sequenceNumber = 1

  return function()
    local win = hs.window.frontmostWindow()
    local id = win:id()
    local now = hs.timer.secondsSinceEpoch()
    local screen = win:screen()

    if
      lastSeenChain ~= movements or
      lastSeenAt < now - chainResetInterval or
      lastSeenWindow ~= id
    then
      sequenceNumber = 1
      lastSeenChain = movements
--  elseif (sequenceNumber == 1) then
--    -- At end of chain, restart chain on next screen.
--    screen = screen:next()
    end
    lastSeenAt = now
    lastSeenWindow = id

    hs.grid.set(win, movements[sequenceNumber])
    sequenceNumber = sequenceNumber % cycleLength + 1
  end
end)
