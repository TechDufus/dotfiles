M = {}

local grid = require('hs.grid')
local geom = require('hs.geometry')
local screen = require('hs.screen')

local margins = geom'5x5'

M.setMargins = function(mar)
  mar=geom.new(mar)
  if geom.type(mar)=='point' then mar=geom.size(mar.x,mar.y) end
  if geom.type(mar)~='size' then error('invalid margins',2)end
  margins=mar
end

local min,max = math.min,math.max

M.getCellWithMargins = function(cell, scr)
  scr=screen.find(scr)
  if not scr then scr=hs.screen.mainScreen() end
  cell=geom.new(cell)
  local screenrect = grid.getGridFrame(scr)
  local screengrid = grid.getGrid(scr)
  -- sanitize, because why not
  cell.x=max(0,min(cell.x,screengrid.w-1)) cell.y=max(0,min(cell.y,screengrid.h-1))
  cell.w=max(1,min(cell.w,screengrid.w-cell.x)) cell.h=max(1,min(cell.h,screengrid.h-cell.y))
  local cellw, cellh = screenrect.w/screengrid.w, screenrect.h/screengrid.h
  local newframe = {
    x = (cell.x * cellw) + screenrect.x + margins.w,
    y = (cell.y * cellh) + screenrect.y + margins.h,
    w = cell.w * cellw - (margins.w * 2),
    h = cell.h * cellh - (margins.h * 2),
  }

  -- ensure windows are not spaced by a double margin
  if cell.h < screengrid.h and cell.h % 1 == 0 then
    if cell.y ~= 0 then
      newframe.h = newframe.h + margins.h / 2
      newframe.y = newframe.y - margins.h / 2
    end

    if cell.y + cell.h ~= screengrid.h then
      newframe.h = newframe.h + margins.h / 2
    end
  end

  if cell.w < screengrid.w and cell.w % 1 == 0 then
    if cell.x ~= 0 then
      newframe.w = newframe.w + margins.w / 2
      newframe.x = newframe.x - margins.w / 2
    end

    if cell.x + cell.w ~= screengrid.w then
      newframe.w = newframe.w + margins.w / 2
    end
  end

  return newframe
end

return M
