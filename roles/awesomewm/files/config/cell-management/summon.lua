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
  if not app_config then return end

  local current_client = client.focus
  local current_class = current_client and current_client.class or nil
  local previous_class = state.get_previous_client_class()

  -- Find existing client matching app
  local target_client = helpers.find_client_by_class(app_config.class)

  -- Case 1: Target app is focused and we have history → toggle back
  if current_class and
     current_class:lower() == app_config.class:lower() and
     previous_class and
     previous_class:lower() ~= app_config.class:lower() then

    local prev_client = helpers.find_client_by_class(previous_class)
    if prev_client then
      prev_client:jump_to()
      prev_client:raise()
    end

  -- Case 2: App exists with windows → activate
  elseif target_client then
    target_client:jump_to()
    target_client:raise()

  -- Case 3: App not running → launch (positioning via awful.rules)
  else
    awful.spawn(app_config.exec)
  end
end
