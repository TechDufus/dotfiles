local awful = require("awful")

local M = {}

local registry = setmetatable({}, { __mode = "k" })

local function resolve_control(name)
    local primary = awful.screen.primary
    if primary and registry[primary] and registry[primary][name] then
        return registry[primary][name]
    end

    for index = 1, screen.count() do
        local screen_obj = screen[index]
        local controls = screen_obj and registry[screen_obj] or nil
        if controls and controls[name] then
            return controls[name]
        end
    end

    for _, controls in pairs(registry) do
        if controls[name] then
            return controls[name]
        end
    end

    return nil
end

function M.register(screen_obj, controls)
    registry[screen_obj] = controls
end

function M.unregister(screen_obj)
    registry[screen_obj] = nil
end

function M.increase_volume(step)
    local control = resolve_control("volume")
    if control and control.inc then
        control:inc(step or 5)
    end
end

function M.decrease_volume(step)
    local control = resolve_control("volume")
    if control and control.dec then
        control:dec(step or 5)
    end
end

function M.toggle_volume()
    local control = resolve_control("volume")
    if control and control.toggle then
        control:toggle()
    end
end

function M.increase_brightness()
    local control = resolve_control("brightness")
    if control and control.inc then
        control:inc()
    end
end

function M.decrease_brightness()
    local control = resolve_control("brightness")
    if control and control.dec then
        control:dec()
    end
end

screen.connect_signal("removed", function(screen_obj)
    registry[screen_obj] = nil
end)

return M
