-- src/ui/cursor.lua
-- Custom pixel art cursor system

local Cursor = {}

-- Cursor types
Cursor.ARROW = "arrow"
Cursor.POINTER = "pointer"
Cursor.GRAB = "grab"
Cursor.GRABBING = "grabbing"

-- Cursor metadata (hotspot offsets and scale)
local CURSOR_SCALE = 1.0

local CURSOR_DATA = {
    arrow = {
        file = "assets/cursor_standard.png",
        hotspotX = 0,
        hotspotY = 0,
        scale = CURSOR_SCALE,
    },
    pointer = {
        file = "assets/hand_point.png",
        hotspotX = 6,  -- Finger tip offset
        hotspotY = 0,
        scale = CURSOR_SCALE,
    },
    grab = {
        file = "assets/hand_open.png",
        hotspotX = 8,  -- Center of palm
        hotspotY = 8,
        scale = CURSOR_SCALE,
    },
    grabbing = {
        file = "assets/hand_closed.png",
        hotspotX = 8,  -- Center of palm
        hotspotY = 8,
        scale = CURSOR_SCALE,
    },
}

-- State
local state = {
    current = "arrow",
    images = {},
}

function Cursor.init()
    -- Hide the OS cursor first, before anything else
    love.mouse.setVisible(false)

    -- Load all cursor images from assets
    for name, data in pairs(CURSOR_DATA) do
        local ok, image = pcall(love.graphics.newImage, data.file)
        if ok and image then
            image:setFilter("nearest", "nearest")
            state.images[name] = image
        end
    end
end

function Cursor.setCursor(cursorType)
    state.current = cursorType or Cursor.ARROW
end

function Cursor.getCursor()
    return state.current
end

function Cursor.draw()
    -- Ensure OS cursor stays hidden (can reappear on focus changes)
    if love.mouse.isVisible() then
        love.mouse.setVisible(false)
    end

    local mx, my = love.mouse.getPosition()
    local cursorName = state.current
    local image = state.images[cursorName]
    local data = CURSOR_DATA[cursorName]

    -- Fallback to arrow if image not found
    if not image then
        image = state.images[Cursor.ARROW]
        data = CURSOR_DATA[Cursor.ARROW]
    end

    if image and data then
        love.graphics.setColor(1, 1, 1, 1)
        local drawX = mx - data.hotspotX * data.scale
        local drawY = my - data.hotspotY * data.scale
        love.graphics.draw(image, drawX, drawY, 0, data.scale, data.scale)
    end
end

return Cursor
