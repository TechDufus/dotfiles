-- dnd.lua - Do Not Disturb state management
local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")

local M = {}

-- State
local state = {
    enabled = false,
    queue = {},           -- Notifications queued during DND
    max_queue = 50,       -- Maximum queued notifications
    timer = nil,          -- Optional: scheduled DND timer
}

-- Signals for widget updates
M.signals = {}

function M.emit_signal(name, ...)
    for _, callback in ipairs(M.signals[name] or {}) do
        callback(...)
    end
end

function M.connect_signal(name, callback)
    M.signals[name] = M.signals[name] or {}
    table.insert(M.signals[name], callback)
end

-- Check if DND is enabled
function M.is_enabled()
    return state.enabled
end

-- Enable DND
function M.enable()
    state.enabled = true
    M.emit_signal("state::changed", true)
    print("[notifications.dnd] DND enabled")
end

-- Disable DND and show queued notifications
function M.disable()
    state.enabled = false
    M.emit_signal("state::changed", false)
    print("[notifications.dnd] DND disabled, processing " .. #state.queue .. " queued notifications")

    -- Process queued notifications
    for _, n_args in ipairs(state.queue) do
        -- Re-emit the notification using naughty.notify (compatible API)
        naughty.notify(n_args)
    end
    state.queue = {}
end

-- Toggle DND state
function M.toggle()
    if state.enabled then
        M.disable()
    else
        M.enable()
    end
    return state.enabled
end

-- Queue a notification during DND
-- @param n: notification object
function M.queue_notification(n)
    -- Store notification data (not the object itself)
    local n_data = {
        app_name = n.app_name,
        title = n.title,
        text = n.message or n.text,
        icon = n.icon,
        urgency = n.urgency,
        timeout = n.timeout,
        _queued_at = os.time(),
    }

    -- FIFO eviction if at max
    if #state.queue >= state.max_queue then
        table.remove(state.queue, 1)
    end

    table.insert(state.queue, n_data)
    M.emit_signal("queue::changed", #state.queue)
    print("[notifications.dnd] Queued notification: " .. (n.title or "untitled"))
end

-- Get queue count
function M.get_queue_count()
    return #state.queue
end

-- Clear queue without showing
function M.clear_queue()
    state.queue = {}
    M.emit_signal("queue::changed", 0)
end

return M
