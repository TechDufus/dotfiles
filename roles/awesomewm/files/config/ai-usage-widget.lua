-- ============================================================================
-- AI USAGE WIDGET
-- Displays Claude AI usage metrics from ai-usage-monitor cache
-- ============================================================================

local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local json = require("json")
local beautiful = require("beautiful")

local M = {}

function M.create(colors, fonts, spacing, icons)
    local dpi = beautiful.xresources.apply_dpi

    -- Color threshold: pick color based on utilization percentage
    local function usage_color(pct)
        if pct == nil then return colors.subtext0 end
        if pct < 50 then return colors.green end
        if pct <= 70 then return colors.yellow end
        if pct <= 85 then return colors.peach end
        return colors.red
    end

    local function colored(text, color)
        return string.format('<span foreground="%s">%s</span>', color, text)
    end

    -- Build the widget (compact: icon + session % only)
    local widget = wibox.widget {
        {
            {
                markup = colored(icons.ai, colors.mauve),
                font = fonts.icon,
                widget = wibox.widget.textbox,
            },
            left = 2,
            right = spacing.icon_gap + 2,
            widget = wibox.container.margin,
        },
        {
            id = "five_hour",
            markup = colored("--", colors.subtext0),
            font = fonts.data,
            widget = wibox.widget.textbox,
        },
        layout = wibox.layout.fixed.horizontal,
    }

    local status_path = os.getenv("HOME") .. "/.cache/ai-usage-monitor/status.json"

    -- Popup state
    local popup_instance = nil

    -- Format reset time: extract HH:MM for short resets
    local month_names = {
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    }
    local function fmt_time(iso)
        if not iso then return "N/A" end
        local hh, mm = string.match(iso, "T(%d%d):(%d%d)")
        if hh then return hh .. ":" .. mm end
        return iso
    end
    local function fmt_date(iso)
        if not iso then return "N/A" end
        local _, m, d = string.match(iso, "^(%d+)-(%d+)-(%d+)")
        if m and d then
            local mi = tonumber(m)
            local label = month_names[mi] or m
            return label .. " " .. tonumber(d)
        end
        return iso
    end

    -- Shared data loader
    local function load_data()
        local f = io.open(status_path, "r")
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        local ok, data = pcall(json.decode, content)
        if not ok or type(data) ~= "table" then return nil end
        if not data.claude or not data.claude.available then return nil end
        return data
    end

    local function hide_popup()
        if popup_instance then
            popup_instance.visible = false
            popup_instance = nil
        end
        -- mousegrabber stops itself via returning false in its callback
    end

    -- Helper: build a single metric row (label + value + progressbar + reset)
    local function build_metric_row(label, pct, reset_str)
        local color = usage_color(pct)
        local value_str = pct and string.format("%.1f%%", pct) or "N/A"

        return wibox.widget {
            -- Row 1: label ........... value%
            {
                {
                    markup = colored(label, colors.subtext0),
                    font = fonts.data,
                    widget = wibox.widget.textbox,
                },
                nil,
                {
                    markup = colored(value_str, color),
                    font = fonts.data,
                    widget = wibox.widget.textbox,
                },
                layout = wibox.layout.align.horizontal,
            },
            -- Row 2: progress bar
            {
                {
                    max_value = 1,
                    value = pct and (pct / 100) or 0,
                    color = color,
                    background_color = colors.surface0,
                    forced_height = dpi(4),
                    forced_width = dpi(200),
                    shape = function(cr, w, h)
                        gears.shape.rounded_rect(cr, w, h, dpi(2))
                    end,
                    bar_shape = function(cr, w, h)
                        gears.shape.rounded_rect(cr, w, h, dpi(2))
                    end,
                    widget = wibox.widget.progressbar,
                },
                top = dpi(2),
                bottom = dpi(2),
                widget = wibox.container.margin,
            },
            -- Row 3: reset time
            {
                markup = colored("resets " .. (reset_str or "N/A"), colors.overlay1),
                font = fonts.data,
                widget = wibox.widget.textbox,
            },
            spacing = dpi(0),
            layout = wibox.layout.fixed.vertical,
        }
    end

    -- Build the full popup widget from data
    local function build_popup_widget(data)
        local claude = data.claude
        local rows = {
            layout = wibox.layout.fixed.vertical,
            spacing = dpi(8),
        }

        -- Title row: icon + "Claude Usage"
        table.insert(rows, wibox.widget {
            {
                markup = colored(icons.ai, colors.mauve),
                font = fonts.icon,
                widget = wibox.widget.textbox,
            },
            {
                markup = colored("  Claude Usage", colors.text),
                font = fonts.data,
                widget = wibox.widget.textbox,
            },
            layout = wibox.layout.fixed.horizontal,
        })

        -- Separator
        table.insert(rows, wibox.widget {
            color = colors.surface1,
            forced_height = dpi(1),
            widget = wibox.widget.separator,
        })

        -- Session (5h)
        local five = claude.five_hour
        if five then
            local label = "Session (5h)"
            table.insert(rows, build_metric_row(label, five.utilization, fmt_time(five.resets_at)))
        end

        -- Weekly (7d)
        local seven = claude.seven_day
        if seven then
            local label = "Weekly (7d)"
            table.insert(rows, build_metric_row(label, seven.utilization, fmt_date(seven.resets_at)))
        end

        -- Sonnet (7d) — only if non-null
        local sonnet = claude.seven_day_sonnet
        if sonnet then
            local label = "Sonnet (7d)"
            table.insert(rows, build_metric_row(label, sonnet.utilization, fmt_date(sonnet.resets_at)))
        end

        -- Credits section — only if extra_usage is enabled
        local extra = claude.extra_usage
        if extra and extra.is_enabled then
            -- Separator before credits
            table.insert(rows, wibox.widget {
                color = colors.surface1,
                forced_height = dpi(1),
                widget = wibox.widget.separator,
            })

            local used = extra.used_credits or 0
            local limit = extra.monthly_limit or 0
            local credit_pct = extra.utilization
            local credit_str = string.format("%s / %s",
                tostring(used),
                tostring(limit)
            )
            local credit_color = usage_color(credit_pct)

            -- Credits header + value
            local credits_row = wibox.widget {
                {
                    {
                        markup = colored("Credits", colors.subtext0),
                        font = fonts.data,
                        widget = wibox.widget.textbox,
                    },
                    nil,
                    {
                        markup = colored(credit_str, credit_color),
                        font = fonts.data,
                        widget = wibox.widget.textbox,
                    },
                    layout = wibox.layout.align.horizontal,
                },
                layout = wibox.layout.fixed.vertical,
                spacing = dpi(0),
            }

            -- Add progress bar only if limit > 0
            if limit > 0 and credit_pct then
                local bar_row = wibox.widget {
                    {
                        max_value = 1,
                        value = credit_pct / 100,
                        color = credit_color,
                        background_color = colors.surface0,
                        forced_height = dpi(4),
                        forced_width = dpi(200),
                        shape = function(cr, w, h)
                            gears.shape.rounded_rect(cr, w, h, dpi(2))
                        end,
                        bar_shape = function(cr, w, h)
                            gears.shape.rounded_rect(cr, w, h, dpi(2))
                        end,
                        widget = wibox.widget.progressbar,
                    },
                    top = dpi(2),
                    bottom = dpi(2),
                    widget = wibox.container.margin,
                }
                credits_row:add(bar_row)
            end

            table.insert(rows, credits_row)
        end

        -- Footer separator
        table.insert(rows, wibox.widget {
            color = colors.surface1,
            forced_height = dpi(1),
            widget = wibox.widget.separator,
        })

        -- Updated timestamp
        local updated = data.timestamp or "N/A"
        table.insert(rows, wibox.widget {
            markup = colored("Updated " .. updated, colors.overlay1),
            font = fonts.data,
            widget = wibox.widget.textbox,
        })

        return rows
    end

    local function toggle_popup()
        -- Toggle off if already visible
        if popup_instance then
            hide_popup()
            return
        end

        -- Load fresh data
        local data = load_data()
        if not data then return end

        local mouse_coords = mouse.coords()
        local s = awful.screen.focused()

        -- 1. Build popup content
        local popup_content = build_popup_widget(data)

        -- 2. Create popup
        popup_instance = awful.popup {
            widget = {
                {
                    popup_content,
                    margins = dpi(12),
                    widget = wibox.container.margin,
                },
                bg = colors.base,
                shape = function(cr, w, h)
                    gears.shape.rounded_rect(cr, w, h, dpi(8))
                end,
                border_width = dpi(1),
                border_color = colors.surface1,
                widget = wibox.container.background,
            },
            placement = function(c)
                local screen_geo = s.geometry
                local workarea = s.workarea
                local popup_width = c.width or 250

                -- Center on mouse x, clamp to screen
                local x = mouse_coords.x - (popup_width / 2)
                x = math.max(screen_geo.x + dpi(4), x)
                x = math.min(screen_geo.x + screen_geo.width - popup_width - dpi(4), x)

                -- Position just below the wibar
                local y = workarea.y + dpi(4)

                c.x = x
                c.y = y
            end,
            minimum_width = dpi(250),
            maximum_width = dpi(280),
            ontop = true,
            visible = true,
        }

        -- 3. Start mousegrabber for click-away dismiss
        mousegrabber.run(function(m)
            -- If popup was already dismissed (e.g. by toggle), stop
            if not popup_instance then return false end

            -- On any mouse button press, check if click is outside popup
            if m.buttons[1] or m.buttons[2] or m.buttons[3] then
                local pg = popup_instance:geometry()
                local inside = m.x >= pg.x and m.x <= pg.x + pg.width
                    and m.y >= pg.y and m.y <= pg.y + pg.height
                if not inside then
                    hide_popup()
                    return false  -- stop grabbing
                end
            end

            return true  -- keep grabbing
        end, "arrow")
    end

    -- Click handler on widget
    widget:connect_signal("button::press", function(_, _, _, button)
        if button == 1 then toggle_popup() end
    end)

    -- Update compact wibar text only (never touches popup)
    local function update_compact()
        local data = load_data()
        if not data then
            widget:get_children_by_id("five_hour")[1].markup =
                colored("--", colors.subtext0)
            return
        end

        local five_pct = data.claude.five_hour and data.claude.five_hour.utilization or nil
        local five_str = five_pct and string.format("%d%%", five_pct) or "--"
        widget:get_children_by_id("five_hour")[1].markup =
            colored(five_str, usage_color(five_pct))
    end

    -- 10s timer updates compact wibar text only
    gears.timer {
        timeout = 10,
        autostart = true,
        call_now = true,
        callback = update_compact,
    }

    return widget
end

return M
