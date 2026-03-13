local awful = require("awful")
local gears = require("gears")
local naughty = require("naughty")

local fs_widget = require("awesome-wm-widgets.fs-widget.fs-widget")
local logout_menu_widget = require("awesome-wm-widgets.logout-menu-widget.logout-menu")

local M = {}

local function get_disk_mounts()
    local mounts = {}
    local supported_types = {
        ext4 = true,
        ext3 = true,
        ext2 = true,
        xfs = true,
        btrfs = true,
        zfs = true,
        ntfs = true,
        fuseblk = true,
        exfat = true,
        f2fs = true,
        jfs = true,
        reiserfs = true,
    }

    local handle = io.popen("df -T 2>/dev/null | tail -n +2")
    if handle then
        for line in handle:lines() do
            local _, fstype, _, _, _, _, mount =
                line:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)")
            if fstype and supported_types[fstype] and mount then
                table.insert(mounts, mount)
            end
        end
        handle:close()
    end

    table.sort(mounts, function(left, right)
        if left == "/" then
            return true
        end
        if right == "/" then
            return false
        end
        return left < right
    end)

    if #mounts == 0 then
        mounts = { "/" }
    end

    return mounts
end

local function graceful_shutdown(final_command)
    local all_clients = client.get()
    if #all_clients == 0 then
        awful.spawn.with_shell(final_command)
        return
    end

    local completed = false
    local disconnect_handler

    local function run_final_command(delay_seconds)
        gears.timer.start_new(delay_seconds, function()
            awful.spawn.with_shell(final_command)
            return false
        end)
    end

    local function finish(delay_seconds)
        if completed then
            return
        end

        completed = true
        if disconnect_handler then
            client.disconnect_signal("unmanage", disconnect_handler)
        end

        run_final_command(delay_seconds)
    end

    local timeout_timer = gears.timer {
        timeout = 10,
        single_shot = true,
        callback = function()
            if completed then
                return
            end

            naughty.notify({
                preset = naughty.config.presets.normal,
                title = "Shutdown",
                text = "Timeout reached, forcing shutdown...",
                timeout = 2,
            })
            finish(1)
        end,
    }

    disconnect_handler = function()
        if #client.get() == 0 then
            timeout_timer:stop()
            finish(0.5)
        end
    end

    client.connect_signal("unmanage", disconnect_handler)
    timeout_timer:start()

    naughty.notify({
        preset = naughty.config.presets.normal,
        title = "Shutdown",
        text = "Closing " .. #all_clients .. " application(s) gracefully...",
        timeout = 3,
    })

    for _, client_obj in ipairs(all_clients) do
        client_obj:kill()
    end
end

function M.create(shared)
    local filesystem = fs_widget({
        mounts = get_disk_mounts(),
        timeout = 60,
    })

    local logout = logout_menu_widget({
        font = shared.fonts.data,
        onlock = function()
            awful.spawn.with_shell("i3lock -c " .. shared.colors.base:gsub("#", ""))
        end,
        onpoweroff = function()
            graceful_shutdown("systemctl poweroff")
        end,
        onreboot = function()
            graceful_shutdown("systemctl reboot")
        end,
    })

    return {
        filesystem = filesystem,
        logout = logout,
    }
end

return M
