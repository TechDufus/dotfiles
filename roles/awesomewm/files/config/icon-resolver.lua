-- icon-resolver.lua - GNOME-style high-resolution icon lookup for AwesomeWM
-- Falls back through: c.icon -> desktop file lookup -> icon theme search -> generic icon
--
-- This module solves the problem where c.icon (from _NET_WM_ICON) is either:
-- 1. Missing entirely (app doesn't set the X11 property)
-- 2. Low resolution (embedded 32x32 icon)
--
-- Instead, we use the same approach as GNOME Shell:
-- 1. Find the app's .desktop file via WM_CLASS
-- 2. Read the Icon= field
-- 3. Resolve it through the GTK icon theme system

local gears = require("gears")
local beautiful = require("beautiful")

-- Try to load lgi for GTK/GIO access
local lgi_available, lgi = pcall(require, "lgi")
local Gtk, Gio, GLib

if lgi_available then
    local gtk_ok, gtk = pcall(function() return lgi.require("Gtk", "3.0") end)
    local gio_ok, gio = pcall(function() return lgi.require("Gio") end)
    local glib_ok, glib = pcall(function() return lgi.require("GLib") end)

    if gtk_ok then Gtk = gtk end
    if gio_ok then Gio = gio end
    if glib_ok then GLib = glib end
end

local icon_resolver = {}

-- Cache for resolved icons (WM_CLASS -> icon path)
-- Avoids repeated filesystem lookups for the same app
local icon_cache = {}

-- Cache for desktop app info (WM_CLASS -> Gio.DesktopAppInfo)
local app_info_cache = {}

-- Icon size preference (larger = higher quality)
local PREFERRED_SIZE = 256

-- Common variations to try when searching for desktop files
-- Apps often have different naming conventions
local function get_desktop_file_variations(class)
    if not class then return {} end

    local lower = class:lower()
    local variations = {
        -- Exact match first
        class .. ".desktop",
        lower .. ".desktop",

        -- Common prefixes
        "com." .. lower .. ".desktop",
        "org." .. lower .. ".desktop",
        "io." .. lower .. ".desktop",

        -- With hyphens/underscores
        lower:gsub("_", "-") .. ".desktop",
        lower:gsub("-", "_") .. ".desktop",

        -- Flatpak-style IDs (reverse domain)
        "com." .. lower .. "." .. class .. ".desktop",
        "org." .. lower .. "." .. class .. ".desktop",
    }

    return variations
end

-- Search for a desktop file by WM_CLASS
local function find_desktop_app_info(class)
    if not class or not Gio then return nil end

    -- Check cache first
    if app_info_cache[class] ~= nil then
        return app_info_cache[class]
    end

    local app_info = nil

    -- Try variations of the class name
    local variations = get_desktop_file_variations(class)
    for _, desktop_id in ipairs(variations) do
        app_info = Gio.DesktopAppInfo.new(desktop_id)
        if app_info then
            break
        end
    end

    -- If not found, try searching all desktop files for matching StartupWMClass
    if not app_info then
        local all_apps = Gio.AppInfo.get_all()
        for _, info in ipairs(all_apps) do
            if Gio.DesktopAppInfo:is_type_of(info) then
                local startup_class = info:get_startup_wm_class()
                if startup_class and startup_class:lower() == class:lower() then
                    app_info = info
                    break
                end
            end
        end
    end

    -- Cache the result (even if nil, to avoid repeated lookups)
    app_info_cache[class] = app_info or false
    return app_info or nil
end

-- Resolve an icon name to a file path using GTK icon theme
local function resolve_icon_from_theme(icon_name, size)
    if not icon_name or not Gtk then return nil end

    size = size or PREFERRED_SIZE

    local theme = Gtk.IconTheme.get_default()
    if not theme then return nil end

    -- If icon_name is already a path, return it
    if icon_name:sub(1, 1) == "/" then
        local f = io.open(icon_name, "r")
        if f then
            f:close()
            return icon_name
        end
        return nil
    end

    -- Look up the icon in the theme
    local icon_info = theme:lookup_icon(icon_name, size, 0)
    if icon_info then
        return icon_info:get_filename()
    end

    -- Try without file extension if present
    local name_without_ext = icon_name:match("(.+)%.[^.]+$") or icon_name
    if name_without_ext ~= icon_name then
        icon_info = theme:lookup_icon(name_without_ext, size, 0)
        if icon_info then
            return icon_info:get_filename()
        end
    end

    return nil
end

-- Get high-resolution icon for a client
-- Returns: icon path (string) or nil
function icon_resolver.get_icon_path(c)
    if not c or not c.valid then return nil end

    local class = c.class
    if not class then return nil end

    -- Check cache first
    if icon_cache[class] ~= nil then
        -- Return cached value (false means we tried and failed)
        return icon_cache[class] or nil
    end

    local icon_path = nil

    -- Strategy 1: Find via desktop file (most reliable for high-res icons)
    local app_info = find_desktop_app_info(class)
    if app_info then
        local icon = app_info:get_icon()
        if icon then
            -- GIcon can be a ThemedIcon, FileIcon, or other types
            if Gio.ThemedIcon:is_type_of(icon) then
                -- Get the icon names and try each one
                local names = icon:get_names()
                if names then
                    for _, name in ipairs(names) do
                        icon_path = resolve_icon_from_theme(name, PREFERRED_SIZE)
                        if icon_path then break end
                    end
                end
            elseif Gio.FileIcon:is_type_of(icon) then
                -- Direct file reference
                local file = icon:get_file()
                if file then
                    icon_path = file:get_path()
                end
            else
                -- Try to_string() as fallback (works for most GIcon types)
                local icon_string = icon:to_string()
                if icon_string then
                    icon_path = resolve_icon_from_theme(icon_string, PREFERRED_SIZE)
                end
            end
        end
    end

    -- Strategy 2: Try class name directly in icon theme
    if not icon_path then
        icon_path = resolve_icon_from_theme(class, PREFERRED_SIZE)
    end

    -- Strategy 3: Try lowercase class name
    if not icon_path and class then
        icon_path = resolve_icon_from_theme(class:lower(), PREFERRED_SIZE)
    end

    -- Strategy 4: Try common name variations
    if not icon_path and class then
        local variations = {
            class:lower():gsub(" ", "-"),
            class:lower():gsub(" ", "_"),
            class:lower():gsub("-browser$", ""),
            class:lower():gsub("^com%.", ""),
            class:lower():gsub("^org%.", ""),
        }
        for _, name in ipairs(variations) do
            icon_path = resolve_icon_from_theme(name, PREFERRED_SIZE)
            if icon_path then break end
        end
    end

    -- Cache the result (false if not found, to distinguish from "not yet looked up")
    icon_cache[class] = icon_path or false

    return icon_path
end

-- Get icon surface for a client (for use with imagebox)
-- Returns: cairo surface, or nil if no icon found
-- This tries high-res lookup first, then falls back to c.icon
function icon_resolver.get_icon_surface(c, size)
    if not c or not c.valid then return nil end

    size = size or 48

    -- Try high-resolution lookup first
    local icon_path = icon_resolver.get_icon_path(c)
    if icon_path then
        -- Load the icon as a surface, scaling to requested size
        local surface = gears.surface.load_uncached(icon_path)
        if surface then
            return surface
        end
    end

    -- Fall back to c.icon (the _NET_WM_ICON property)
    if c.icon then
        return c.icon
    end

    return nil
end

-- Check if we have any icon for a client (high-res or fallback)
function icon_resolver.has_icon(c)
    if not c or not c.valid then return false end

    -- Check high-res lookup
    local icon_path = icon_resolver.get_icon_path(c)
    if icon_path then return true end

    -- Check c.icon fallback
    if c.icon then return true end

    return false
end

-- Clear the cache (useful if icon themes change)
function icon_resolver.clear_cache()
    icon_cache = {}
    app_info_cache = {}
end

-- Debug: Print what we know about a client's icon
function icon_resolver.debug(c)
    if not c or not c.valid then
        print("[icon-resolver] Invalid client")
        return
    end

    print("[icon-resolver] Debug for: " .. (c.class or "unknown"))
    print("  WM_CLASS: " .. tostring(c.class))
    print("  c.icon: " .. (c.icon and "present" or "nil"))

    local app_info = find_desktop_app_info(c.class)
    print("  Desktop file found: " .. (app_info and "yes" or "no"))

    if app_info then
        local icon = app_info:get_icon()
        print("  Icon from desktop: " .. (icon and icon:to_string() or "nil"))
    end

    local icon_path = icon_resolver.get_icon_path(c)
    print("  Resolved path: " .. (icon_path or "nil"))
end

-- Report on GTK/GIO availability
function icon_resolver.is_available()
    return lgi_available and Gtk ~= nil and Gio ~= nil
end

return icon_resolver
