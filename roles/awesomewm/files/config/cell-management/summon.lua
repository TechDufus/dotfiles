-- summon.lua - Summon/toggle logic for applications
local awful = require("awful")
local helpers = require("cell-management.helpers")
local apps = require("cell-management.apps")
local state = require("cell-management.state")

-- Track previous app via focus signal
client.connect_signal("focus", function(c)
  if c.class then
    state.set_previous_client_class(c.class)
  end
end)

-- Main summon function
-- Toggle behavior cases:
-- 1. App focused + have history → toggle back to previous
-- 2. App exists but not focused → focus app
-- 3. App doesn't exist → launch app (positioning via awful.rules)
return function(app_name)
  local app_config = apps[app_name]
  if not app_config then
    print("[WARN] Unknown app: " .. tostring(app_name))
    return
  end

  local current_client = client.focus
  local current_class = current_client and current_client.class or nil
  local previous_class = state.get_previous_client_class()
  local current_layout = state.get_current_layout()

  print(string.format("[DEBUG SUMMON] App: %s, Looking for class: %s", app_name, app_config.class))
  print(string.format("[DEBUG SUMMON] Current class: %s, Previous class: %s",
    tostring(current_class), tostring(previous_class)))

  -- Find existing client matching app
  local target_client = helpers.find_client_by_class(app_config.class)
  print(string.format("[DEBUG SUMMON] Target client found: %s", tostring(target_client ~= nil)))

  -- Case 1: Target app is focused and we have history → toggle back
  if current_class and
     current_class:lower() == app_config.class:lower() and
     previous_class and
     previous_class:lower() ~= app_config.class:lower() then

    print("[DEBUG SUMMON] Case 1: Toggle back to previous app")
    local prev_client = helpers.find_client_by_class(previous_class)
    if prev_client then
      prev_client:jump_to()
      local prev_app_name = helpers.find_app_by_class(previous_class)
      if prev_app_name then
        helpers.position_client_in_cell(prev_client, prev_app_name, current_layout)
      end
    end

  -- Case 2: App exists with windows → activate and position
  elseif target_client then
    print("[DEBUG SUMMON] Case 2: Focus existing app")
    target_client:jump_to()
    helpers.position_client_in_cell(target_client, app_name, current_layout)

  -- Case 3: App not running → launch (positioning via awful.rules)
  else
    print("[DEBUG SUMMON] Case 3: Launching new app: " .. app_config.exec)
    awful.spawn(app_config.exec)
  end
end
