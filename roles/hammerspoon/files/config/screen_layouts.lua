return {
  layouts = {
    -- Optional per-screen defaults.
    -- Keys can be screen UUIDs, screen names, "primary", "screen:<index>",
    -- "profile:<name>", or "all".
    -- Values can be layout keys from layouts.lua ("fourk", "fullscreen", "hd", "standard")
    -- or the human-readable layout names.
    --
    -- Profile defaults:
    -- - built-in laptop display -> single fullscreen cell
    -- - standard/4K/ultrawide external displays -> Standard Dev
    ['profile:builtin'] = 'fullscreen',
    ['profile:standard'] = 'standard',
    ['profile:fourk'] = 'standard',
    ['profile:ultrawide'] = 'standard',
  },
}
