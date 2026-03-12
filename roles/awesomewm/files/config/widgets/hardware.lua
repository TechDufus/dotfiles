local M = {}

function M.file_exists(path)
    local handle = io.open(path, "r")
    if not handle then
        return false
    end

    handle:close()
    return true
end

function M.read_file(path)
    local handle = io.open(path, "r")
    if not handle then
        return nil
    end

    local content = handle:read("*l")
    handle:close()
    return content
end

local function read_command_output(command)
    local handle = io.popen(command)
    if not handle then
        return nil
    end

    local output = handle:read("*a")
    handle:close()
    return output
end

function M.detect_backlight()
    local output = read_command_output("ls /sys/class/backlight/ 2>/dev/null")
    return output ~= nil and output ~= ""
end

function M.detect_battery_name()
    local handle = io.popen("ls /sys/class/power_supply 2>/dev/null")
    if not handle then
        return nil
    end

    for line in handle:lines() do
        if line:match("^BAT") then
            handle:close()
            return line
        end
    end

    handle:close()
    return nil
end

function M.detect_cpu_thermal_path()
    local index = 0
    while true do
        local zone_type = M.read_file("/sys/class/thermal/thermal_zone" .. index .. "/type")
        if not zone_type then
            break
        end
        if zone_type:match("x86_pkg") then
            return "/sys/class/thermal/thermal_zone" .. index .. "/temp"
        end
        index = index + 1
    end

    index = 0
    while true do
        local name = M.read_file("/sys/class/hwmon/hwmon" .. index .. "/name")
        if not name then
            break
        end
        if name == "k10temp" or name == "coretemp" then
            local path = "/sys/class/hwmon/hwmon" .. index .. "/temp1_input"
            if M.file_exists(path) then
                return path
            end
        end
        index = index + 1
    end

    if M.file_exists("/sys/class/thermal/thermal_zone0/temp") then
        return "/sys/class/thermal/thermal_zone0/temp"
    end

    return nil
end

function M.detect_default_iface()
    local output = read_command_output("ip route show default 2>/dev/null | head -1")
    if not output or output == "" then
        return nil
    end

    return output:match("dev%s+(%S+)")
end

function M.has_nvidia_gpu()
    local output = read_command_output("which nvidia-smi 2>/dev/null")
    return output ~= nil and output ~= ""
end

return M
