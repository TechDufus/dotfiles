-- summon.lua - Summon/toggle logic for applications
local awful = require("awful")
local helpers = require("cell-management.helpers")
local apps = require("cell-management.apps")
local state = require("cell-management.state")

-- Track the class we're currently focused on (to detect class changes)
local current_focused_class = nil

-- Track previous app and specific client via focus signal
client.connect_signal("focus", function(c)
  if c.class then
    -- Only update previous_class when switching to a DIFFERENT class
    -- This preserves toggle history (Browser → Terminal, previous stays Browser)
    if current_focused_class and c.class:lower() ~= current_focused_class:lower() then
      state.set_previous_client_class(current_focused_class)
    end
    current_focused_class = c.class
    -- Track this specific client as the last-focused for its class
    state.set_last_focused_client(c.class, c)
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
  -- Prefer last-focused client of this class (for multi-window apps like Discord)
  local last_focused = state.get_last_focused_client(app_config.class)
  local target_client
  if last_focused and last_focused.valid then
    target_client = last_focused
  else
    -- Fallback to first matching client
    target_client = helpers.find_client_by_class(app_config.class)
  end

  -- Case 1: Target app is focused and we have history → toggle back
  if current_class and
     current_class:lower() == app_config.class:lower() and
     previous_class and
     previous_class:lower() ~= app_config.class:lower() then

    -- Prefer last-focused client of previous class (for multi-window apps)
    local prev_last_focused = state.get_last_focused_client(previous_class)
    local prev_client
    if prev_last_focused and prev_last_focused.valid then
      prev_client = prev_last_focused
    else
      prev_client = helpers.find_client_by_class(previous_class)
    end
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
