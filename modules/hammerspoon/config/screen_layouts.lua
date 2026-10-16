return {
  layouts = {
    -- Optional per-screen defaults.
    -- Keys can be screen UUIDs, screen names, "primary", "screen:<index>",
    -- "profile:<name>", or "all".
    -- Values can be layout keys from layouts.lua ("fourk", "fullscreen", "hd", "standard")
    -- or the human-readable layout names.
    --
    -- Defaults:
    -- - built-in laptop display -> single fullscreen cell
    -- - every external display -> Standard Dev
    ['profile:builtin'] = 'fullscreen',
    all = 'standard',
  },
}
