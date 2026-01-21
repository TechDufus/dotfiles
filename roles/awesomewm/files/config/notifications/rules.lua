-- rules.lua - Per-app notification filtering configuration
-- User can edit this file to customize notification behavior
--
-- STRUCTURE:
--   defaults: Global notification settings
--   muted: List of app names to completely silence (still logged to history)
--   apps: Per-app overrides for timeout, width, urgency, etc.

return {
    -- Global defaults
    defaults = {
        max_width = 400,      -- Maximum popup width in pixels
        max_height = 200,     -- Maximum popup height in pixels
        timeout = 5,          -- Default timeout in seconds (0 = no timeout)
        position = "top_right",
        margin = 10,
        border_radius = 12,   -- Rounded corner radius
    },

    -- Apps to completely mute (notifications still appear in history)
    -- Match against notification's app_name or freedesktop_hints["desktop-entry"]
    muted = {
        "Spotify",
        "spotify",
        "com.spotify.Client",      -- Flatpak Spotify desktop-entry
        "update-manager",
        "Software Updater",
        "gnome-software",
    },

    -- Per-app customizations
    -- Keys should match notification app_name (case-sensitive)
    apps = {
        Discord = {
            timeout = 8,        -- Longer timeout for chat messages
            max_width = 350,    -- Slightly narrower
        },
        Slack = {
            urgency = "normal", -- Never allow critical
            timeout = 6,
        },
        ["Brave-browser"] = {
            timeout = 3,        -- Quick dismiss for browser notifications
        },
        Thunderbird = {
            timeout = 10,       -- Email notifications stay longer
        },
    },
}
