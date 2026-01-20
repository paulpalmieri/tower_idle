-- src/ui/shortcuts.lua
-- Keyboard shortcuts overlay (toggle with ~)

local Config = require("src.config")
local Fonts = require("src.rendering.fonts")
local PixelFrames = require("src.ui.pixel_frames")

local Shortcuts = {}

-- Private state
local state = {
    visible = false,
    x = 0,
    y = 0,
    width = 320,
    height = 400,  -- Increased for more tower shortcuts
}

-- =============================================================================
-- SHORTCUT DEFINITIONS
-- When adding a new keyboard shortcut, add it here!
-- =============================================================================
local SHORTCUTS = {
    { category = "TOWERS" },
    { key = "1", description = "Select Wall" },
    { key = "2", description = "Select Void Orb" },
    { key = "3", description = "Select Void Ring" },
    { key = "4", description = "Select Void Bolt" },
    { key = "5", description = "Select Void Eye" },
    { key = "6", description = "Select Void Star" },

    { category = "UPGRADES" },
    { key = "Q", description = "Buy Auto-Clicker" },

    { category = "GAME" },
    { key = "S", description = "Cycle game speed" },
    { key = "P", description = "Settings menu" },
    { key = "ESC", description = "Cancel / Deselect / Quit" },

    { category = "DEBUG / VISUAL" },
    { key = "L", description = "Toggle lighting" },
    { key = "G", description = "Cycle floating numbers style" },
    { key = "~", description = "Toggle this overlay" },
}

-- =============================================================================
-- HELPERS
-- =============================================================================

local function _calculateLayout()
    -- Center in window
    state.x = (Config.SCREEN_WIDTH - state.width) / 2
    state.y = (Config.SCREEN_HEIGHT - state.height) / 2
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function Shortcuts.init()
    _calculateLayout()
end

function Shortcuts.show()
    state.visible = true
end

function Shortcuts.hide()
    state.visible = false
end

function Shortcuts.toggle()
    state.visible = not state.visible
end

function Shortcuts.isVisible()
    return state.visible
end

function Shortcuts.draw()
    if not state.visible then return end

    local padding = 16
    local lineHeight = 20
    local categorySpacing = 8

    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)

    -- Main frame
    PixelFrames.draw8BitFrame(state.x, state.y, state.width, state.height, "settings")

    -- Title
    Fonts.setFont("medium")
    love.graphics.setColor(Config.COLORS.gold)
    love.graphics.print("KEYBOARD SHORTCUTS", state.x + padding, state.y + padding)

    -- Hint to close
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    love.graphics.printf("Press ~ to close", state.x, state.y + padding + 4, state.width - padding, "right")

    local y = state.y + padding + 32

    -- Draw shortcuts
    for _, item in ipairs(SHORTCUTS) do
        if item.category then
            -- Category header
            y = y + categorySpacing
            Fonts.setFont("small")
            love.graphics.setColor(Config.COLORS.amethyst)
            love.graphics.print(item.category, state.x + padding, y)
            y = y + lineHeight
        else
            -- Shortcut row
            Fonts.setFont("small")

            -- Key (left, highlighted)
            love.graphics.setColor(Config.COLORS.emerald)
            love.graphics.print(item.key, state.x + padding + 8, y)

            -- Description (right of key)
            love.graphics.setColor(Config.COLORS.textPrimary)
            love.graphics.print(item.description, state.x + padding + 60, y)

            y = y + lineHeight
        end
    end
end

return Shortcuts
