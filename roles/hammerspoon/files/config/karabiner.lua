-- karabiner.lua - Keep Karabiner responsive after sleep/wake
local M = {}

local KARABINER_SERVICES = {
  'org.pqrs.service.agent.karabiner_console_user_server',
  'org.pqrs.service.agent.karabiner_session_monitor',
}

local RESTART_DELAY_SECONDS = 2
local MIN_RESTART_INTERVAL_SECONDS = 5

local pending_restart_timer = nil
local last_restart_epoch = 0
local missing_services_notice_shown = false

local function trim(value)
  return (value or ''):gsub('%s+$', '')
end

local function run(command)
  local output, ok, _, rc = hs.execute(command, true)
  return ok, trim(output), rc or (ok and 0 or 1)
end

local function current_uid()
  local ok, output = run('/usr/bin/id -u')
  if not ok or output == '' then
    return nil
  end
  return output
end

local function service_is_running(uid, service)
  local check_cmd = string.format(
    "/bin/launchctl print gui/%s/%s | /usr/bin/awk '$1==\"pid\"{found=1} END{exit(found ? 0 : 1)}'",
    uid,
    service
  )
  local ok = run(check_cmd)
  return ok
end

local function restart_service(uid, service)
  local cmd = string.format('/bin/launchctl kickstart -k gui/%s/%s', uid, service)
  local ok, output, rc = run(cmd)
  return ok, output, rc
end

local function restart_karabiner(reason)
  local uid = current_uid()
  if not uid then
    hs.alert.show('Karabiner restart failed: unable to resolve uid', 4)
    hs.console.printStyledtext('Karabiner: /usr/bin/id -u failed')
    return
  end

  local failures = {}
  for _, service in ipairs(KARABINER_SERVICES) do
    local ok, output, rc = restart_service(uid, service)
    if not ok then
      table.insert(failures, {
        service = service,
        rc = rc,
        output = output ~= '' and output or '<empty>',
      })
    end
  end

  if #failures == #KARABINER_SERVICES then
    local all_missing = true
    for _, failure in ipairs(failures) do
      if failure.rc ~= 113 then
        all_missing = false
        break
      end
    end

    if all_missing then
      if not missing_services_notice_shown then
        hs.alert.show('Karabiner services not found; skipping auto-restart.', 5)
        hs.console.printStyledtext('Karabiner services missing (launchctl rc=113)')
        missing_services_notice_shown = true
      end
      return
    end
  end

  missing_services_notice_shown = false

  local console_service = KARABINER_SERVICES[1]
  local running = service_is_running(uid, console_service)

  if #failures == 0 and running then
    hs.console.printStyledtext(string.format('Karabiner: restarted after %s', reason))
    return
  end

  local summary = table.concat(hs.fnutils.map(failures, function(failure)
    return string.format('%s rc=%s output=%s', failure.service, tostring(failure.rc), failure.output)
  end), ' | ')
  if summary == '' then
    summary = string.format('%s is not running after restart', console_service)
  end

  hs.alert.show('Karabiner restart incomplete. Open Karabiner-Elements to re-authorize if needed.', 5)
  hs.console.printStyledtext(string.format('Karabiner restart issue (%s): %s', reason, summary))
end

local function schedule_restart(reason, delay_seconds)
  local now = hs.timer.secondsSinceEpoch()
  if now - last_restart_epoch < MIN_RESTART_INTERVAL_SECONDS then
    return
  end

  if pending_restart_timer then
    pending_restart_timer:stop()
    pending_restart_timer = nil
  end

  pending_restart_timer = hs.timer.doAfter(delay_seconds, function()
    last_restart_epoch = hs.timer.secondsSinceEpoch()
    pending_restart_timer = nil
    restart_karabiner(reason)
  end)
end

function M.start()
  if M.watcher then
    M.watcher:stop()
  end

  M.watcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
      schedule_restart('wake', RESTART_DELAY_SECONDS)
    elseif event == hs.caffeinate.watcher.screensDidUnlock then
      schedule_restart('unlock', 1)
    end
  end)

  M.watcher:start()
  return M
end

return M
