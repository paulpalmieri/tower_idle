-- src/core/camera.lua
-- Simple camera with center-based positioning, zoom, and drag-to-pan

local Config = require("src.config")

local Camera = {}

-- Private state
local state = {
    -- Camera position (CENTER of view in world coordinates)
    x = 0,
    y = 0,
    -- World bounds
    worldWidth = 0,
    worldHeight = 0,
    -- Viewport size (fixed canvas size)
    viewWidth = 0,
    viewHeight = 0,
    -- Zoom state
    zoom = 1.0,
    targetZoom = 1.0,
    minZoom = 0.5,
    maxZoom = 1.5,
    zoomSmoothing = 8.0,
    -- Drag-to-pan state
    isDragging = false,
    dragStartX = 0,
    dragStartY = 0,
    dragStartCamX = 0,
    dragStartCamY = 0,
}

-- =============================================================================
-- INTERNAL HELPERS
-- =============================================================================

-- Clamp camera position to keep viewport within world bounds
local function _clampPosition()
    -- Calculate visible area at current zoom
    local visibleW = state.viewWidth / state.zoom
    local visibleH = state.viewHeight / state.zoom

    -- Calculate how far camera center can move from world center
    -- When visible area equals world, maxOffset = 0 (camera locked to center)
    local maxOffsetX = math.max(0, (state.worldWidth - visibleW) / 2)
    local maxOffsetY = math.max(0, (state.worldHeight - visibleH) / 2)

    -- World center
    local worldCenterX = state.worldWidth / 2
    local worldCenterY = state.worldHeight / 2

    -- Clamp camera to valid range around world center
    state.x = math.max(worldCenterX - maxOffsetX, math.min(worldCenterX + maxOffsetX, state.x))
    state.y = math.max(worldCenterY - maxOffsetY, math.min(worldCenterY + maxOffsetY, state.y))
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

function Camera.init(worldWidth, worldHeight, viewWidth, viewHeight)
    state.worldWidth = worldWidth
    state.worldHeight = worldHeight
    state.viewWidth = viewWidth
    state.viewHeight = viewHeight

    -- Load config
    -- Note: No zoom scaling needed - Display module handles resolution independence
    -- via letterboxing. Camera always operates on fixed 1280x720 game canvas.
    local cfg = Config.CAMERA
    if cfg then
        state.minZoom = cfg.minZoom or 0.5
        state.maxZoom = cfg.maxZoom or 1.5
        state.zoomSmoothing = cfg.zoomSmoothing or 8.0
        state.zoom = cfg.defaultZoom or 1.0
        state.targetZoom = state.zoom
    end

    -- Start centered on world
    state.x = worldWidth / 2
    state.y = worldHeight / 2

    _clampPosition()
end

-- Center camera on a specific world position (e.g., void portal)
function Camera.centerOn(worldX, worldY)
    state.x = worldX
    state.y = worldY
    _clampPosition()
end

-- =============================================================================
-- UPDATE
-- =============================================================================

function Camera.update(dt)
    -- Smooth zoom interpolation
    if state.zoom ~= state.targetZoom then
        local zoomFactor = 1 - math.exp(-state.zoomSmoothing * dt)
        state.zoom = state.zoom + (state.targetZoom - state.zoom) * zoomFactor

        -- Snap when close enough
        if math.abs(state.zoom - state.targetZoom) < 0.001 then
            state.zoom = state.targetZoom
        end

        -- Clamp position after zoom change (visible area changed)
        _clampPosition()
    end
end

-- =============================================================================
-- COORDINATE CONVERSION
-- =============================================================================

-- Convert screen coordinates to world coordinates
function Camera.screenToWorld(screenX, screenY)
    local cx = state.viewWidth / 2
    local cy = state.viewHeight / 2
    -- Transform: offset from screen center, scale by zoom, add camera position
    local worldX = (screenX - cx) / state.zoom + state.x
    local worldY = (screenY - cy) / state.zoom + state.y
    return worldX, worldY
end

-- Convert world coordinates to screen coordinates
function Camera.worldToScreen(worldX, worldY)
    local cx = state.viewWidth / 2
    local cy = state.viewHeight / 2
    -- Transform: offset from camera, scale by zoom, add screen center
    local screenX = (worldX - state.x) * state.zoom + cx
    local screenY = (worldY - state.y) * state.zoom + cy
    return screenX, screenY
end

-- =============================================================================
-- ZOOM CONTROL
-- =============================================================================

function Camera.setZoom(zoom)
    state.targetZoom = math.max(state.minZoom, math.min(state.maxZoom, zoom))
end

function Camera.adjustZoom(delta)
    Camera.setZoom(state.targetZoom + delta)
end

function Camera.getZoom()
    return state.zoom
end

function Camera.getTargetZoom()
    return state.targetZoom
end

function Camera.getMinZoom()
    return state.minZoom
end

function Camera.getMaxZoom()
    return state.maxZoom
end

function Camera.resetZoom()
    state.targetZoom = 1.0
end

-- =============================================================================
-- DRAG-TO-PAN
-- =============================================================================

function Camera.startDrag(screenX, screenY)
    state.isDragging = true
    state.dragStartX = screenX
    state.dragStartY = screenY
    state.dragStartCamX = state.x
    state.dragStartCamY = state.y
end

function Camera.updateDrag(screenX, screenY)
    if not state.isDragging then return end

    -- Calculate drag delta in screen space, convert to world space
    local dx = (screenX - state.dragStartX) / state.zoom
    local dy = (screenY - state.dragStartY) / state.zoom

    -- Invert: dragging right moves camera left (view moves right)
    state.x = state.dragStartCamX - dx
    state.y = state.dragStartCamY - dy

    _clampPosition()
end

function Camera.endDrag()
    state.isDragging = false
end

function Camera.isDragging()
    return state.isDragging
end

-- =============================================================================
-- TRANSFORM HELPERS
-- =============================================================================

-- Apply camera transform for drawing
function Camera.apply()
    local cx = state.viewWidth / 2
    local cy = state.viewHeight / 2
    -- Translate to screen center, scale, translate by camera position
    love.graphics.translate(cx, cy)
    love.graphics.scale(state.zoom, state.zoom)
    love.graphics.translate(-state.x, -state.y)
end

function Camera.push()
    love.graphics.push()
    Camera.apply()
end

function Camera.pop()
    love.graphics.pop()
end

-- =============================================================================
-- GETTERS
-- =============================================================================

function Camera.getPosition()
    return state.x, state.y
end

function Camera.getWorldSize()
    return state.worldWidth, state.worldHeight
end

function Camera.getViewSize()
    return state.viewWidth, state.viewHeight
end

-- Get visible world bounds (top-left and bottom-right corners)
function Camera.getBounds()
    local visibleW = state.viewWidth / state.zoom
    local visibleH = state.viewHeight / state.zoom
    local left = state.x - visibleW / 2
    local top = state.y - visibleH / 2
    local right = state.x + visibleW / 2
    local bottom = state.y + visibleH / 2
    return left, top, right, bottom
end

return Camera
