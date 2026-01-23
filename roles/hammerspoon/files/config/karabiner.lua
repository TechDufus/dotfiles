-- karabiner.lua - Restart Karabiner on wake from sleep
local M = {}

local KARABINER_SERVICE = 'org.pqrs.service.agent.karabiner_console_user_server'

local function restartKarabiner()
  local uid = hs.execute('id -u', true):gsub('%s+', '')
  local cmd = string.format('launchctl kickstart -k gui/%s/%s', uid, KARABINER_SERVICE)
  local output, status = hs.execute(cmd, true)

  if status then
    hs.console.printStyledtext('Karabiner: restarted on wake')
  else
    hs.alert.show('Karabiner restart failed!', 3)
  end
end

function M.start()
  M.watcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
      hs.timer.doAfter(2, restartKarabiner)  -- 2s delay for system stabilization
    end
  end)
  M.watcher:start()
  return M
end

return M
