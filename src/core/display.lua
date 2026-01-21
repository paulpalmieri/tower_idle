-- src/core/display.lua
-- Core display management: canvas dimensions, scaling, coordinate conversion
-- This module is game-agnostic and should have no dependencies on UI modules

local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local Display = {}

-- Fixed 16:9 canvas resolution (the game is designed for this)
-- Canvas is always this size, scaled to fit any screen with letterboxing
local CANVAS_WIDTH = Config.CANVAS_WIDTH
local CANVAS_HEIGHT = Config.CANVAS_HEIGHT
local ASPECT_RATIO = CANVAS_WIDTH / CANVAS_HEIGHT
local PANEL_WIDTH = Config.PANEL_WIDTH

-- Private state
local state = {
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    windowWidth = CANVAS_WIDTH,
    windowHeight = CANVAS_HEIGHT,
}

-- =============================================================================
-- INTERNAL HELPERS
-- =============================================================================

local function _updateScale()
    local windowW, windowH = love.graphics.getDimensions()
    state.windowWidth = windowW
    state.windowHeight = windowH

    -- Scale to fit window, preserving 16:9 aspect ratio
    local windowAspect = windowW / windowH

    if windowAspect > ASPECT_RATIO then
        -- Window wider than 16:9: pillarbox (black bars on sides)
        state.scale = windowH / CANVAS_HEIGHT
        state.offsetX = math.floor((windowW - CANVAS_WIDTH * state.scale) / 2)
        state.offsetY = 0
    else
        -- Window taller than 16:9: letterbox (black bars top/bottom)
        state.scale = windowW / CANVAS_WIDTH
        state.offsetX = 0
        state.offsetY = math.floor((windowH - CANVAS_HEIGHT * state.scale) / 2)
    end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function Display.init()
    _updateScale()
end

-- Handle window resize - call this from love.resize or after window mode change
function Display.handleResize()
    _updateScale()

    -- Notify other systems that window size changed
    EventBus.emit("window_resized", {
        width = state.windowWidth,
        height = state.windowHeight,
        scale = state.scale,
        offsetX = state.offsetX,
        offsetY = state.offsetY,
        gameWidth = CANVAS_WIDTH,
        gameHeight = CANVAS_HEIGHT,
        playAreaWidth = CANVAS_WIDTH,
        panelWidth = PANEL_WIDTH,
    })
end

-- =============================================================================
-- DIMENSION QUERIES
-- =============================================================================

-- Get the fixed canvas size
function Display.getCanvasSize()
    return CANVAS_WIDTH, CANVAS_HEIGHT
end

-- Get the game dimensions (alias for canvas, for clarity)
function Display.getGameDimensions()
    return CANVAS_WIDTH, CANVAS_HEIGHT
end

-- Get the current scale factor
function Display.getScale()
    return state.scale
end

-- Get the offset to center the game
function Display.getOffset()
    return state.offsetX, state.offsetY
end

-- Get the current window dimensions
function Display.getWindowDimensions()
    return state.windowWidth, state.windowHeight
end

-- Get the fixed panel width
function Display.getPanelWidth()
    return PANEL_WIDTH
end

-- Get the play area width (full canvas width since panel overlays)
function Display.getPlayAreaWidth()
    return CANVAS_WIDTH
end

-- Get the panel X position (where panel overlay starts)
function Display.getPanelX()
    return CANVAS_WIDTH - PANEL_WIDTH
end

-- =============================================================================
-- COORDINATE CONVERSION
-- =============================================================================

-- Convert screen coordinates to game coordinates
function Display.screenToGame(screenX, screenY)
    local gameX = (screenX - state.offsetX) / state.scale
    local gameY = (screenY - state.offsetY) / state.scale
    return gameX, gameY
end

-- Convert game coordinates to screen coordinates
function Display.gameToScreen(gameX, gameY)
    local screenX = gameX * state.scale + state.offsetX
    local screenY = gameY * state.scale + state.offsetY
    return screenX, screenY
end

return Display
