-- ============================================================================
-- AI USAGE WIDGET
-- Displays Claude/Codex usage metrics with compact + popup views.
-- Features:
-- - Hover/click actions (details, provider switch, usage links, quick refresh)
-- - Live countdown with local-time reset labels
-- - Trend sparkline, burn rate, ETA-to-cap insights
-- - Threshold alerts with cooldown
-- ============================================================================

local wibox = require("wibox")
local gears = require("gears")
local awful = require("awful")
local naughty = require("naughty")
local json = require("json")
local beautiful = require("beautiful")

local M = {}

function M.create(colors, fonts, spacing, icons)
    local dpi = beautiful.xresources.apply_dpi
    local status_path = os.getenv("HOME") .. "/.cache/ai-usage-monitor/status.json"
    local provider_pref_path = os.getenv("HOME") .. "/.cache/ai-usage-monitor/provider.txt"

    local usage_links = {
        claude = os.getenv("AI_USAGE_CLAUDE_URL") or "https://claude.ai/settings/usage",
        codex = os.getenv("AI_USAGE_CODEX_URL") or "https://chatgpt.com/codex/settings/usage",
    }

    local provider_defs = {
        claude = {
            label = "Claude",
            accent = colors.mauve,
            compact_keys = { "five_hour", "session", "seven_day", "weekly" },
            session_keys = { "five_hour", "session" },
            weekly_keys = { "seven_day", "weekly" },
            metrics = {
                { key = "five_hour", label = "Session (5h)" },
                { key = "seven_day", label = "Weekly (7d)" },
                { key = "seven_day_sonnet", label = "Sonnet (7d)" },
                { key = "seven_day_opus", label = "Opus (7d)" },
            },
        },
        codex = {
            label = "Codex",
            accent = colors.blue,
            compact_keys = { "session", "five_hour", "weekly", "seven_day" },
            session_keys = { "session", "five_hour" },
            weekly_keys = { "weekly", "seven_day" },
            metrics = {
                { key = "session", label = "Session" },
                { key = "five_hour", label = "Session (5h)" },
                { key = "weekly", label = "Weekly" },
                { key = "seven_day", label = "Weekly (7d)" },
            },
        },
    }

    local history_by_metric = {}
    local alert_state = {}

    local HISTORY_SAMPLE_INTERVAL_SECONDS = 60
    local HISTORY_RETENTION_SECONDS = 6 * 3600
    local ALERT_COOLDOWN_SECONDS = 20 * 60
    local POPUP_REFRESH_SECONDS = 30

    local popup_instance = nil
    local popup_refresh_timer = nil
    local popup_data = nil
    local popup_render = nil
    local update_compact

    local selected_provider = "claude"

    local function as_table(value)
        if type(value) == "table" then return value end
        return nil
    end

    local function as_number(value)
        if type(value) == "number" then return value end
        if type(value) == "string" then return tonumber(value) end
        return nil
    end

    local function colored(text, color)
        return string.format('<span foreground="%s">%s</span>', color, text)
    end

    local function usage_color(pct)
        if pct == nil then return colors.subtext0 end
        if pct < 50 then return colors.green end
        if pct <= 70 then return colors.yellow end
        if pct <= 85 then return colors.peach end
        return colors.red
    end

    local function usage_band(pct)
        if pct == nil then return "Unknown" end
        if pct < 50 then return "Cool" end
        if pct <= 70 then return "Warm" end
        if pct <= 85 then return "Hot" end
        return "Critical"
    end

    local function alert_level(pct)
        if pct == nil then return 0 end
        if pct >= 95 then return 3 end
        if pct >= 85 then return 2 end
        if pct >= 70 then return 1 end
        return 0
    end

    local function fmt_duration(seconds)
        local remaining = math.max(0, math.floor(seconds))
        local days = math.floor(remaining / 86400)
        remaining = remaining % 86400
        local hours = math.floor(remaining / 3600)
        remaining = remaining % 3600
        local mins = math.floor(remaining / 60)

        local parts = {}
        if days > 0 then
            table.insert(parts, string.format("%dd", days))
        end
        if hours > 0 or days > 0 then
            table.insert(parts, string.format("%dh", hours))
        end
        table.insert(parts, string.format("%dm", mins))

        return table.concat(parts, " ")
    end

    local function iso_to_utc_epoch(iso)
        if type(iso) ~= "string" then return nil end
        local y, m, d, hh, mm, ss = iso:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)Z$")
        if not y then return nil end

        local utc_as_local = os.time({
            year = tonumber(y),
            month = tonumber(m),
            day = tonumber(d),
            hour = tonumber(hh),
            min = tonumber(mm),
            sec = tonumber(ss),
            isdst = nil,
        })
        if not utc_as_local then return nil end

        -- os.time() interprets the table as local time; convert to true UTC epoch.
        local offset = os.difftime(utc_as_local, os.time(os.date("!*t", utc_as_local)))
        return utc_as_local + offset
    end

    local function fmt_local_time(epoch)
        local lt = os.date("*t", epoch)
        if not lt then return "N/A" end

        local h24 = lt.hour or 0
        local suffix = h24 >= 12 and "PM" or "AM"
        local h12 = h24 % 12
        if h12 == 0 then h12 = 12 end

        return string.format("%d:%02d %s", h12, lt.min or 0, suffix)
    end

    local function fmt_local_timestamp(iso)
        local epoch = iso_to_utc_epoch(iso)
        if not epoch then return tostring(iso or "N/A") end
        return os.date("%b %d %I:%M:%S %p", epoch)
    end

    local function fmt_reset(iso)
        if not iso then return "N/A" end

        local reset_epoch = iso_to_utc_epoch(iso)
        if not reset_epoch then return tostring(iso) end

        local remaining = math.floor(reset_epoch - os.time())
        if remaining <= 0 then
            return string.format("now (%s)", fmt_local_time(reset_epoch))
        end

        return string.format("in %s (%s)", fmt_duration(remaining), fmt_local_time(reset_epoch))
    end

    local function load_selected_provider()
        local f = io.open(provider_pref_path, "r")
        if not f then return "claude" end

        local value = f:read("*l")
        f:close()

        if value == "claude" or value == "codex" then
            return value
        end

        return "claude"
    end

    local function save_selected_provider(provider_key)
        if provider_key ~= "claude" and provider_key ~= "codex" then return end

        local f = io.open(provider_pref_path, "w")
        if not f then return end

        f:write(provider_key)
        f:close()
    end

    local function get_metric(provider_data, metric_key)
        local provider = as_table(provider_data)
        if not provider then return nil end

        local metric = as_table(provider[metric_key])
        if metric then return metric end

        local pct = as_number(provider[metric_key .. "_utilization"])
            or as_number(provider[metric_key .. "_percentage"])
            or as_number(provider[metric_key .. "_percent"])
            or as_number(provider[metric_key .. "_usage"])

        if pct == nil then return nil end

        return {
            utilization = pct,
            resets_at = provider[metric_key .. "_resets_at"]
                or provider[metric_key .. "_reset_at"]
                or provider[metric_key .. "_resets_on"]
                or provider[metric_key .. "_reset_on"],
        }
    end

    local function metric_pct(metric)
        local m = as_table(metric)
        if not m then return nil end

        return as_number(m.utilization)
            or as_number(m.percentage)
            or as_number(m.percent)
            or as_number(m.usage)
    end

    local function metric_reset(metric)
        local m = as_table(metric)
        if not m then return nil end

        return m.resets_at
            or m.reset_at
            or m.resets_on
            or m.reset_on
            or m.window_end
    end

    local function load_data()
        local f = io.open(status_path, "r")
        if not f then return nil end

        local content = f:read("*a")
        f:close()

        local ok, data = pcall(json.decode, content)
        if not ok or type(data) ~= "table" then return nil end

        if not as_table(data.claude) and not as_table(data.codex) then
            return nil
        end

        return data
    end

    local function first_metric_pct(provider, keys)
        for _, key in ipairs(keys) do
            local pct = metric_pct(get_metric(provider, key))
            if pct ~= nil then
                return pct
            end
        end
        return nil
    end

    local function primary_pct_for_provider(provider_key, provider_data)
        local provider = as_table(provider_data)
        local def = provider_defs[provider_key]
        if not provider or not def then return nil end

        for _, key in ipairs(def.compact_keys) do
            local pct = metric_pct(get_metric(provider, key))
            if pct ~= nil then
                return pct
            end
        end

        return as_number(provider.utilization)
            or as_number(provider.percentage)
            or as_number(provider.percent)
    end

    local function metric_history_key(provider_key, metric_key)
        return provider_key .. ":" .. metric_key
    end

    local function record_metric_sample(provider_key, metric_key, pct, sample_ts)
        if pct == nil or sample_ts == nil then return end

        local key = metric_history_key(provider_key, metric_key)
        local history = history_by_metric[key]
        if not history then
            history = {}
            history_by_metric[key] = history
        end

        local last = history[#history]
        if last and (sample_ts - last.t) < HISTORY_SAMPLE_INTERVAL_SECONDS then
            last.p = pct
            last.t = sample_ts
            return
        end

        table.insert(history, { t = sample_ts, p = pct })

        local cutoff = sample_ts - HISTORY_RETENTION_SECONDS
        while #history > 0 and history[1].t < cutoff do
            table.remove(history, 1)
        end
    end

    local function metric_rate_per_hour(provider_key, metric_key)
        local key = metric_history_key(provider_key, metric_key)
        local history = history_by_metric[key]
        if not history or #history < 2 then return nil end

        local newest = history[#history]
        local target = newest.t - 3600
        local oldest = history[1]

        for i = #history, 1, -1 do
            if history[i].t <= target then
                oldest = history[i]
                break
            end
        end

        local dt = newest.t - oldest.t
        if dt < 600 then return nil end

        return (newest.p - oldest.p) / (dt / 3600)
    end

    local spark_chars = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

    local function metric_sparkline(provider_key, metric_key, width)
        local key = metric_history_key(provider_key, metric_key)
        local history = history_by_metric[key]
        if not history or #history < 3 then return nil end

        local start_i = math.max(1, #history - (width or 16) + 1)
        local chars = {}

        for i = start_i, #history do
            local pct = math.max(0, math.min(100, history[i].p or 0))
            local idx = math.floor((pct / 100) * (#spark_chars - 1)) + 1
            table.insert(chars, spark_chars[idx])
        end

        return table.concat(chars, "")
    end

    local function metric_eta(pct, rate_per_hour)
        if pct == nil or rate_per_hour == nil then return "cap stable" end
        if rate_per_hour <= 0.05 then return "cap stable" end
        if pct >= 100 then return "cap now" end

        local secs_left = ((100 - pct) / rate_per_hour) * 3600
        if secs_left <= 0 then return "cap now" end
        if secs_left > (7 * 24 * 3600) then return "cap >7d" end

        return "cap in " .. fmt_duration(secs_left)
    end

    local function maybe_emit_alert(provider_key, metric_name, pct, sample_ts)
        local level = alert_level(pct)
        local key = provider_key .. ":" .. metric_name

        local state = alert_state[key]
        if not state then
            state = {
                initialized = false,
                level = 0,
                last_notified_at = 0,
            }
            alert_state[key] = state
        end

        if not state.initialized then
            state.initialized = true
            state.level = level
            return
        end

        if level > state.level and level > 0 then
            if (sample_ts - state.last_notified_at) >= ALERT_COOLDOWN_SECONDS then
                local def = provider_defs[provider_key] or { label = provider_key }
                local pct_str = pct and string.format("%.1f%%", pct) or "N/A"
                naughty.notify({
                    title = string.format("%s %s Usage", def.label, metric_name),
                    text = string.format("%s (%s)", pct_str, usage_band(pct)),
                    timeout = 5,
                })
                state.last_notified_at = sample_ts
            end
        end

        state.level = level
    end

    local function process_data(data)
        local sample_ts = iso_to_utc_epoch(data and data.timestamp) or os.time()

        for provider_key, def in pairs(provider_defs) do
            local provider = as_table(data[provider_key]) or {}

            for _, metric_def in ipairs(def.metrics) do
                local pct = metric_pct(get_metric(provider, metric_def.key))
                record_metric_sample(provider_key, metric_def.key, pct, sample_ts)
            end

            local session_pct = first_metric_pct(provider, def.session_keys)
            local weekly_pct = first_metric_pct(provider, def.weekly_keys)

            maybe_emit_alert(provider_key, "Session", session_pct, sample_ts)
            maybe_emit_alert(provider_key, "Weekly", weekly_pct, sample_ts)
        end
    end

    local function open_usage_link(provider_key)
        local url = usage_links[provider_key]
        if not url or url == "" then return end

        awful.spawn.with_shell(string.format("xdg-open %q >/dev/null 2>&1", url))
    end

    local function has_modifier(mods, target)
        if type(mods) ~= "table" then return false end
        for _, m in ipairs(mods) do
            if m == target then return true end
        end
        return false
    end

    local function refresh_monitor_now()
        awful.spawn.with_shell("systemctl --user restart ai-usage-monitor.service >/dev/null 2>&1 || true")
        naughty.notify({
            title = "AI Usage",
            text = "Refreshing usage monitor...",
            timeout = 2,
        })

        gears.timer.start_new(1.5, function()
            if update_compact then
                update_compact()
            end
            return false
        end)
    end

    selected_provider = load_selected_provider()

    -- Compact widget ---------------------------------------------------------
    local usage_hovered = false
    local current_primary_pct = nil

    local function compact_usage_markup(pct, hovered)
        local value_str = pct and string.format("%.0f%%", pct) or "--"
        local color = usage_color(pct)
        if hovered then
            return string.format('<span foreground="%s" underline="single">%s</span>', color, value_str)
        end
        return colored(value_str, color)
    end

    local widget = wibox.widget {
        {
            {
                {
                    {
                        id = "provider_icon",
                        markup = colored(icons.ai, provider_defs[selected_provider].accent or colors.mauve),
                        font = fonts.icon,
                        widget = wibox.widget.textbox,
                    },
                    left = 2,
                    right = spacing.icon_gap,
                    widget = wibox.container.margin,
                },
                {
                    {
                        {
                            id = "usage_value",
                            markup = colored("--", colors.subtext0),
                            font = fonts.data,
                            widget = wibox.widget.textbox,
                        },
                        left = dpi(3),
                        right = dpi(3),
                        top = dpi(1),
                        bottom = dpi(1),
                        widget = wibox.container.margin,
                    },
                    id = "usage_click_bg",
                    bg = colors.base,
                    shape = function(cr, w, h)
                        gears.shape.rounded_rect(cr, w, h, dpi(4))
                    end,
                    widget = wibox.container.background,
                },
                spacing = dpi(4),
                layout = wibox.layout.fixed.horizontal,
            },
            left = dpi(4),
            right = dpi(4),
            top = dpi(2),
            bottom = dpi(2),
            widget = wibox.container.margin,
        },
        id = "hover_bg",
        bg = colors.base,
        shape = function(cr, w, h)
            gears.shape.rounded_rect(cr, w, h, dpi(6))
        end,
        widget = wibox.container.background,
    }

    local function hide_popup()
        if popup_refresh_timer then
            popup_refresh_timer:stop()
            popup_refresh_timer = nil
        end

        if popup_instance then
            popup_instance.visible = false
            popup_instance = nil
        end

        popup_data = nil
        popup_render = nil
    end

    local function build_metric_row(label, pct, reset_str, trend_str, insight_str)
        local color = usage_color(pct)
        local value_str = pct and string.format("%.1f%%", pct) or "N/A"

        local row = {
            spacing = dpi(0),
            layout = wibox.layout.fixed.vertical,
        }

        table.insert(row, wibox.widget {
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
        })

        table.insert(row, wibox.widget {
            {
                max_value = 1,
                value = pct and (pct / 100) or 0,
                color = color,
                background_color = colors.surface0,
                forced_height = dpi(4),
                forced_width = dpi(210),
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
        })

        table.insert(row, wibox.widget {
            markup = colored("resets " .. (reset_str or "N/A"), colors.subtext1),
            font = fonts.data,
            widget = wibox.widget.textbox,
        })

        if trend_str then
            table.insert(row, wibox.widget {
                markup = colored("trend " .. trend_str, colors.subtext1),
                font = fonts.data,
                widget = wibox.widget.textbox,
            })
        end

        if insight_str then
            table.insert(row, wibox.widget {
                markup = colored(insight_str, colors.subtext1),
                font = fonts.data,
                widget = wibox.widget.textbox,
            })
        end

        return wibox.widget(row)
    end

    local function with_popup_hover(content)
        local card = wibox.widget {
            {
                content,
                left = dpi(6),
                right = dpi(6),
                top = dpi(4),
                bottom = dpi(4),
                widget = wibox.container.margin,
            },
            bg = colors.base,
            shape = function(cr, w, h)
                gears.shape.rounded_rect(cr, w, h, dpi(5))
            end,
            widget = wibox.container.background,
        }

        card:connect_signal("mouse::enter", function(w)
            w.bg = colors.surface0
        end)
        card:connect_signal("mouse::leave", function(w)
            w.bg = colors.base
        end)

        return card
    end

    local function build_info_row(message)
        return wibox.widget {
            markup = colored(message, colors.subtext1),
            font = fonts.data,
            widget = wibox.widget.textbox,
        }
    end

    local function build_separator()
        return wibox.widget {
            color = colors.surface1,
            forced_height = dpi(1),
            widget = wibox.widget.separator,
        }
    end

    local function set_provider(provider_key)
        if provider_key ~= "claude" and provider_key ~= "codex" then return end
        if provider_key == selected_provider then return end

        selected_provider = provider_key
        save_selected_provider(provider_key)

        if update_compact then
            update_compact()
        end

        if popup_instance and popup_render then
            local latest = load_data()
            if latest then
                process_data(latest)
                popup_data = latest
            end
            popup_render(popup_data or {})
        end
    end

    local function cycle_provider()
        if selected_provider == "claude" then
            set_provider("codex")
        else
            set_provider("claude")
        end
    end

    local function build_tab_button(provider_key, on_switch)
        local def = provider_defs[provider_key]
        if not def then return wibox.widget.textbox() end

        local active = selected_provider == provider_key
        local fg = active and colors.base or colors.subtext0
        local bg = active and def.accent or colors.surface0

        local tab = wibox.widget {
            {
                {
                    markup = colored(def.label, fg),
                    font = fonts.data,
                    widget = wibox.widget.textbox,
                },
                left = dpi(10),
                right = dpi(10),
                top = dpi(4),
                bottom = dpi(4),
                widget = wibox.container.margin,
            },
            bg = bg,
            shape = function(cr, w, h)
                gears.shape.rounded_rect(cr, w, h, dpi(5))
            end,
            widget = wibox.container.background,
        }

        tab:connect_signal("button::press", function(_, _, _, button)
            if button == 1 then
                on_switch(provider_key)
            end
        end)

        tab:connect_signal("mouse::enter", function(w)
            if selected_provider ~= provider_key then
                w.bg = colors.surface1
            end
        end)

        tab:connect_signal("mouse::leave", function(w)
            if selected_provider ~= provider_key then
                w.bg = colors.surface0
            end
        end)

        return tab
    end

    local function build_popup_widget(data, on_switch_provider)
        local def = provider_defs[selected_provider] or provider_defs.claude
        local provider = as_table(data[selected_provider]) or {}

        local rows = {
            layout = wibox.layout.fixed.vertical,
            spacing = dpi(8),
        }

        table.insert(rows, wibox.widget {
            {
                {
                    markup = colored(icons.ai, def.accent or colors.mauve),
                    font = fonts.icon,
                    widget = wibox.widget.textbox,
                },
                {
                    markup = colored("  " .. def.label .. " Usage", colors.text),
                    font = fonts.data,
                    widget = wibox.widget.textbox,
                },
                layout = wibox.layout.fixed.horizontal,
            },
            layout = wibox.layout.fixed.horizontal,
        })

        table.insert(rows, wibox.widget {
            build_tab_button("claude", on_switch_provider),
            build_tab_button("codex", on_switch_provider),
            spacing = dpi(6),
            layout = wibox.layout.fixed.horizontal,
        })

        table.insert(rows, build_separator())

        local any_rows = false
        for _, metric_def in ipairs(def.metrics) do
            local metric = get_metric(provider, metric_def.key)
            if metric then
                local pct = metric_pct(metric)
                local reset_fmt = fmt_reset(metric_reset(metric))
                local trend = metric_sparkline(selected_provider, metric_def.key, 16)
                local rate = metric_rate_per_hour(selected_provider, metric_def.key)

                local insight = nil
                if rate and math.abs(rate) >= 0.05 then
                    local direction = string.format("rate %+.2f%%/h", rate)
                    local eta = rate > 0 and metric_eta(pct, rate) or "cooling"
                    insight = direction .. " | " .. eta
                end

                table.insert(rows, with_popup_hover(build_metric_row(metric_def.label, pct, reset_fmt, trend, insight)))
                any_rows = true
            end
        end

        if selected_provider == "claude" then
            local extra = as_table(provider.extra_usage)
            if extra and extra.is_enabled then
                table.insert(rows, build_separator())

                local used = as_number(extra.used_credits) or 0
                local limit = as_number(extra.monthly_limit) or 0
                local credit_pct = as_number(extra.utilization)
                local credit_str = string.format("%s / %s", tostring(used), tostring(limit))
                local credit_color = usage_color(credit_pct)

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
                    spacing = dpi(0),
                    layout = wibox.layout.fixed.vertical,
                }

                if limit > 0 and credit_pct then
                    credits_row:add(wibox.widget {
                        {
                            max_value = 1,
                            value = credit_pct / 100,
                            color = credit_color,
                            background_color = colors.surface0,
                            forced_height = dpi(4),
                            forced_width = dpi(210),
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
                    })
                end

                table.insert(rows, with_popup_hover(credits_row))
                any_rows = true
            end
        end

        if not any_rows then
            local err = type(provider.error) == "string" and provider.error or nil
            if provider.available == false then
                table.insert(rows, with_popup_hover(build_info_row(err and ("Unavailable: " .. err) or "Unavailable")))
            else
                table.insert(rows, with_popup_hover(build_info_row(err and ("No usage data: " .. err) or "No usage data available")))
            end
        end

        table.insert(rows, build_separator())

        local updated = data.timestamp and fmt_local_timestamp(data.timestamp) or "N/A"
        table.insert(rows, build_info_row("Updated " .. updated))

        return rows
    end

    local function build_popup_container(content)
        return wibox.widget {
            {
                content,
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
        }
    end

    local function start_popup_refresh()
        if popup_refresh_timer then
            popup_refresh_timer:stop()
            popup_refresh_timer = nil
        end

        popup_refresh_timer = gears.timer {
            timeout = POPUP_REFRESH_SECONDS,
            autostart = true,
            call_now = false,
            callback = function()
                if not popup_instance then
                    if popup_refresh_timer then
                        popup_refresh_timer:stop()
                        popup_refresh_timer = nil
                    end
                    return
                end

                local latest = load_data()
                if latest then
                    process_data(latest)
                    popup_data = latest
                end

                if popup_render then
                    popup_render(popup_data or {})
                end
            end,
        }
    end

    local function toggle_popup()
        if popup_instance then
            hide_popup()
            return
        end

        local data = load_data()
        if data then
            process_data(data)
            popup_data = data
        else
            popup_data = {}
        end

        local mouse_coords = mouse.coords()
        local s = awful.screen.focused()

        local function on_switch_provider(provider_key)
            set_provider(provider_key)
            if popup_render then
                popup_render(popup_data or {})
            end
        end

        popup_render = function(data_for_view)
            if not popup_instance then return end
            popup_instance.widget = build_popup_container(build_popup_widget(data_for_view, on_switch_provider))
        end

        popup_instance = awful.popup {
            widget = build_popup_container(build_popup_widget(popup_data, on_switch_provider)),
            placement = function(c)
                local screen_geo = s.geometry
                local workarea = s.workarea
                local popup_width = c.width or 260

                local x = mouse_coords.x - (popup_width / 2)
                x = math.max(screen_geo.x + dpi(4), x)
                x = math.min(screen_geo.x + screen_geo.width - popup_width - dpi(4), x)

                local y = workarea.y + dpi(4)
                c.x = x
                c.y = y
            end,
            minimum_width = dpi(260),
            maximum_width = dpi(300),
            ontop = true,
            visible = true,
        }

        popup_instance:connect_signal("mouse::leave", function()
            gears.timer.start_new(0.35, function()
                if popup_instance and not mouse.current_wibox then
                    hide_popup()
                end
                return false
            end)
        end)

        start_popup_refresh()
    end

    local function update_compact_hover_state()
        local usage_bg_widget = widget:get_children_by_id("usage_click_bg")[1]
        local value_widget = widget:get_children_by_id("usage_value")[1]

        if usage_bg_widget then
            usage_bg_widget.bg = usage_hovered and colors.surface1 or colors.base
        end
        if value_widget then
            value_widget.markup = compact_usage_markup(current_primary_pct, usage_hovered)
        end
    end

    update_compact = function()
        local icon_widget = widget:get_children_by_id("provider_icon")[1]
        local value_widget = widget:get_children_by_id("usage_value")[1]
        local def = provider_defs[selected_provider] or provider_defs.claude

        if icon_widget then
            icon_widget.markup = colored(icons.ai, def.accent or colors.mauve)
        end

        local data = load_data()
        if not data then
            current_primary_pct = nil
            if value_widget then
                value_widget.markup = compact_usage_markup(current_primary_pct, usage_hovered)
            end
            return
        end

        process_data(data)

        local provider = as_table(data[selected_provider]) or {}
        current_primary_pct = primary_pct_for_provider(selected_provider, provider)

        if value_widget then
            value_widget.markup = compact_usage_markup(current_primary_pct, usage_hovered)
        end
    end

    -- Click actions:
    -- L-click: popup (or usage link when hovering the % section)
    -- Shift+L-click: refresh monitor service
    -- M-click: switch provider
    -- R-click: open provider usage link
    widget:connect_signal("button::press", function(_, _, _, button, mods)
        if button == 1 and has_modifier(mods, "Shift") then
            refresh_monitor_now()
            return
        end

        if button == 1 then
            if usage_hovered then
                open_usage_link(selected_provider)
            else
                toggle_popup()
            end
            return
        end

        if button == 2 then
            cycle_provider()
            return
        end

        if button == 3 then
            open_usage_link(selected_provider)
            return
        end
    end)

    local usage_bg_widget = widget:get_children_by_id("usage_click_bg")[1]
    if usage_bg_widget then
        usage_bg_widget:connect_signal("mouse::enter", function()
            usage_hovered = true
            update_compact_hover_state()
        end)
        usage_bg_widget:connect_signal("mouse::leave", function()
            usage_hovered = false
            update_compact_hover_state()
        end)
    end

    widget:connect_signal("mouse::enter", function()
        widget.bg = colors.surface0
        update_compact_hover_state()
    end)

    widget:connect_signal("mouse::leave", function()
        usage_hovered = false
        widget.bg = colors.base
        update_compact_hover_state()
    end)

    -- Keep a strong reference so the timer is not garbage-collected.
    widget._update_timer = gears.timer {
        timeout = 10,
        autostart = true,
        call_now = true,
        callback = update_compact,
    }

    return widget
end

return M
