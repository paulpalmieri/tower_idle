-- .luacheckrc
-- Strict Luacheck configuration for Tower Idle

std = "lua51+love"

-- Be strict about warnings
max_line_length = 120

-- Ignore specific warnings
ignore = {
    "212",  -- Unused argument (common in callbacks)
    "213",  -- Unused loop variable
    "211/_.*",  -- Unused variable starting with underscore (intentional)
}

-- NO GLOBALS ALLOWED
-- If you need to add a global, justify it in a comment here
globals = {
    -- None. Keep it that way.
}

-- Read-only globals (libraries loaded elsewhere)
read_globals = {
    -- LÖVE2D
    "love",
}

-- Per-file overrides
files["main.lua"] = {
    -- Allow setting LÖVE2D callbacks
    globals = {"love"},
}

files["conf.lua"] = {
    -- Allow configuring LÖVE2D
    globals = {"love"},
}

-- Files to exclude
exclude_files = {
    "lib/*",  -- Third-party libraries
}
