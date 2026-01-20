-- src/ui/cursor.lua
-- Custom pixel art cursor system

local Cursor = {}

-- Cursor types
Cursor.ARROW = "arrow"
Cursor.POINTER = "pointer"

-- State
local state = {
    current = "arrow",
    images = {},
    scale = 0.5,  -- Scale factor for cursor (half size)
}

function Cursor.init()
    -- Hide the OS cursor first, before anything else
    love.mouse.setVisible(false)

    -- Load cursor images from assets
    local ok, arrow = pcall(love.graphics.newImage, "assets/cursor_arrow.png")
    if ok and arrow then
        arrow:setFilter("nearest", "nearest")
        state.images.arrow = arrow
    end

    local ok2, pointer = pcall(love.graphics.newImage, "assets/cursor_hand.png")
    if ok2 and pointer then
        pointer:setFilter("nearest", "nearest")
        state.images.pointer = pointer
    end
end

function Cursor.setCursor(cursorType)
    state.current = cursorType or Cursor.ARROW
end

function Cursor.getCursor()
    return state.current
end

function Cursor.draw()
    local mx, my = love.mouse.getPosition()
    local image = state.images[state.current]

    if not image then
        image = state.images[Cursor.ARROW]
    end

    if image then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, mx, my, 0, state.scale, state.scale)
    end
end

return Cursor
