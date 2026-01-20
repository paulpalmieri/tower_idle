-- src/rendering/pixel_draw.lua
-- Pixel-perfect drawing utilities
-- Snaps coordinates to integers to prevent sub-pixel rendering artifacts

local PixelDraw = {}

-- Draw a filled rectangle with pixel-snapped coordinates
-- Uses floor for position and round-to-nearest for size to minimize jitter
function PixelDraw.rect(x, y, w, h)
    love.graphics.rectangle("fill",
        math.floor(x),
        math.floor(y),
        math.floor(w + 0.5),
        math.floor(h + 0.5))
end

-- Draw a rectangle with explicit mode (fill/line)
function PixelDraw.rectangle(mode, x, y, w, h)
    love.graphics.rectangle(mode,
        math.floor(x),
        math.floor(y),
        math.floor(w + 0.5),
        math.floor(h + 0.5))
end

-- Draw a filled circle with pixel-snapped center
function PixelDraw.circle(x, y, radius)
    love.graphics.circle("fill", math.floor(x), math.floor(y), radius)
end

-- Draw an ellipse with pixel-snapped center
function PixelDraw.ellipse(mode, x, y, radiusX, radiusY)
    love.graphics.ellipse(mode, math.floor(x), math.floor(y), radiusX, radiusY)
end

-- Snap a value to the pixel grid (floor)
function PixelDraw.snap(value)
    return math.floor(value)
end

-- Snap a size value (round to nearest to minimize jitter)
function PixelDraw.snapSize(value)
    return math.floor(value + 0.5)
end

return PixelDraw
