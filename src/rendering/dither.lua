-- src/rendering/dither.lua
-- Dithering effects for grounding visual elements (towers, etc.)

local Config = require("src.config")

local Dither = {}

-- 4x4 Bayer ordered dithering matrix (normalized 0-1)
-- Classic pixel-art dithering pattern
local BAYER_4x4 = {
    { 0/16,  8/16,  2/16, 10/16 },
    { 12/16, 4/16, 14/16,  6/16 },
    { 3/16, 11/16,  1/16,  9/16 },
    { 15/16, 7/16, 13/16,  5/16 },
}

-- Get dither threshold for a pixel position
local function getDitherThreshold(x, y)
    local bx = (math.floor(x) % 4) + 1
    local by = (math.floor(y) % 4) + 1
    return BAYER_4x4[by][bx]
end

-- Draw a corruption stain dithered shadow beneath a tower
-- x, y: center position
-- radiusX, radiusY: ellipse radii
-- towerColor: {r, g, b} tower's accent color (for edge bleed)
-- alpha: base opacity
function Dither.drawGroundingRing(x, y, radiusX, radiusY, _, towerColor, alpha)
    local cfg = Config.TOWER_DITHER
    if not cfg or not cfg.enabled then return end

    local pixelSize = cfg.pixelSize or 4
    local coreColor = cfg.coreColor or {0.02, 0.01, 0.04}
    local coreRadius = cfg.coreRadius or 0.5
    local towerBlend = cfg.towerColorBlend or 0.4

    -- Calculate bounding box for the dither area
    local left = math.floor((x - radiusX) / pixelSize) * pixelSize
    local right = math.ceil((x + radiusX) / pixelSize) * pixelSize
    local top = math.floor((y - radiusY) / pixelSize) * pixelSize
    local bottom = math.ceil((y + radiusY) / pixelSize) * pixelSize

    -- Iterate through pixels in the bounding box
    for py = top, bottom, pixelSize do
        for px = left, right, pixelSize do
            -- Calculate normalized distance from center (ellipse)
            local dx = (px + pixelSize/2 - x) / radiusX
            local dy = (py + pixelSize/2 - y) / radiusY
            local dist = math.sqrt(dx * dx + dy * dy)

            -- Only draw within the ellipse
            if dist <= 1.0 then
                -- Get dither threshold for this pixel
                local threshold = getDitherThreshold(px / pixelSize, py / pixelSize)

                -- Calculate density based on distance (dense core, sparse edges)
                -- Core is full, edges dither out to transparency
                local density
                if dist <= coreRadius then
                    -- Core: full density
                    density = 1.0
                else
                    -- Edge zone: dither from full to nothing
                    density = 1.0 - ((dist - coreRadius) / (1.0 - coreRadius))
                end

                -- Only draw if density passes dither threshold
                if density > threshold then
                    -- Color: blend from core color to tower color based on distance
                    local colorBlend = 0
                    if dist > coreRadius * 0.7 then
                        -- Start blending tower color in outer portion
                        colorBlend = ((dist - coreRadius * 0.7) / (1.0 - coreRadius * 0.7)) * towerBlend
                    end

                    local r = coreColor[1] * (1 - colorBlend) + towerColor[1] * colorBlend
                    local g = coreColor[2] * (1 - colorBlend) + towerColor[2] * colorBlend
                    local b = coreColor[3] * (1 - colorBlend) + towerColor[3] * colorBlend

                    love.graphics.setColor(r, g, b, alpha)
                    love.graphics.rectangle("fill", px, py, pixelSize, pixelSize)
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw a simple dithered shadow/contact point
-- More concentrated at the center, fading outward
function Dither.drawContactShadow(x, y, radius, color, alpha)
    local cfg = Config.TOWER_DITHER
    if not cfg or not cfg.enabled then return end

    local pixelSize = cfg.pixelSize or 2
    local yRatio = cfg.yRatio or 0.5  -- Squash for perspective
    local r, g, b = color[1], color[2], color[3]

    local radiusX = radius
    local radiusY = radius * yRatio

    local left = math.floor((x - radiusX) / pixelSize) * pixelSize
    local right = math.ceil((x + radiusX) / pixelSize) * pixelSize
    local top = math.floor((y - radiusY) / pixelSize) * pixelSize
    local bottom = math.ceil((y + radiusY) / pixelSize) * pixelSize

    for py = top, bottom, pixelSize do
        for px = left, right, pixelSize do
            local dx = (px + pixelSize/2 - x) / radiusX
            local dy = (py + pixelSize/2 - y) / radiusY
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= 1.0 then
                -- Falloff from center (1.0 at center, 0.0 at edge)
                local falloff = 1.0 - dist

                local threshold = getDitherThreshold(px / pixelSize, py / pixelSize)

                if falloff > threshold then
                    love.graphics.setColor(r, g, b, alpha * falloff)
                    love.graphics.rectangle("fill", px, py, pixelSize, pixelSize)
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw a dithered cylinder shadow beneath a floating object
-- Creates the illusion of depth with a cylinder connecting top to shadow
-- x, y: center position of the object
-- topRadius: radius of the object
-- perspectiveRatio: ratio of bottom radius to top radius (0.9 = bottom is 0.9x top)
-- height: vertical distance from object to shadow
-- color: {r, g, b} shadow color
-- alpha: base opacity
function Dither.drawCylinderShadow(x, y, topRadius, perspectiveRatio, height, color, alpha)
    local cfg = Config.TOWER_DITHER
    if not cfg or not cfg.enabled then return end

    local pixelSize = cfg.pixelSize or 4
    local r, g, b = color[1], color[2], color[3]

    -- Bottom ellipse is smaller due to perspective
    local bottomRadius = topRadius * perspectiveRatio
    local yRatio = 0.4  -- Squash factor for ellipse (top-down perspective)

    -- Top and bottom ellipse parameters
    local topY = y  -- Top of cylinder (at object)
    local bottomY = y + height  -- Bottom of cylinder (shadow on ground)

    local topRadiusY = topRadius * yRatio
    local bottomRadiusY = bottomRadius * yRatio

    -- Calculate bounding box
    local maxRadiusX = math.max(topRadius, bottomRadius)
    local left = math.floor((x - maxRadiusX) / pixelSize) * pixelSize
    local right = math.ceil((x + maxRadiusX) / pixelSize) * pixelSize
    local top = math.floor((topY - topRadiusY) / pixelSize) * pixelSize
    local bottom = math.ceil((bottomY + bottomRadiusY) / pixelSize) * pixelSize

    for py = top, bottom, pixelSize do
        for px = left, right, pixelSize do
            local centerX = px + pixelSize / 2
            local centerY = py + pixelSize / 2

            -- Calculate vertical progress (0 at top, 1 at bottom)
            local vertProgress = (centerY - topY) / height
            vertProgress = math.max(0, math.min(1, vertProgress))

            -- Interpolate radius at this height
            local radiusAtY = topRadius + (bottomRadius - topRadius) * vertProgress
            local radiusYAtY = topRadiusY + (bottomRadiusY - topRadiusY) * vertProgress

            -- Calculate normalized distance from center axis (ellipse)
            local dx = (centerX - x) / radiusAtY
            local dyFromAxis = 0  -- Cylinder, so we ignore Y for width check

            -- Check if inside cylinder width
            if math.abs(dx) <= 1.0 then
                -- For the bottom cap (shadow on ground)
                local isBottomCap = centerY >= bottomY - bottomRadiusY
                local isInBottomEllipse = false
                if isBottomCap then
                    local dyBottom = (centerY - bottomY) / bottomRadiusY
                    local distBottom = math.sqrt(dx * dx + dyBottom * dyBottom)
                    isInBottomEllipse = distBottom <= 1.0
                end

                -- For the top cap (connected to object)
                local isTopCap = centerY <= topY + topRadiusY
                local isInTopEllipse = false
                if isTopCap then
                    local dyTop = (centerY - topY) / topRadiusY
                    local distTop = math.sqrt(dx * dx + dyTop * dyTop)
                    isInTopEllipse = distTop <= 1.0
                end

                -- Cylinder body (between top and bottom)
                local isInBody = centerY > topY and centerY < bottomY

                -- Determine if we should draw this pixel
                local shouldDraw = isInBody or isInBottomEllipse

                if shouldDraw then
                    -- Get dither threshold
                    local threshold = getDitherThreshold(px / pixelSize, py / pixelSize)

                    -- Density: higher at center (dx = 0), fading to edges
                    local edgeDist = math.abs(dx)
                    local density = 1.0 - edgeDist * 0.7

                    -- Fade towards bottom (shadow is more solid near object)
                    local fadeFromBottom = 1.0 - vertProgress * 0.5

                    -- Combine density factors
                    local finalDensity = density * fadeFromBottom

                    if finalDensity > threshold then
                        -- Alpha fades with vertical distance
                        local finalAlpha = alpha * (1.0 - vertProgress * 0.3)
                        love.graphics.setColor(r, g, b, finalAlpha)
                        love.graphics.rectangle("fill", px, py, pixelSize, pixelSize)
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Dither
