-- src/rendering/turret_concepts.lua
-- Void Entity Turret Concepts
-- Ancient stone bases with void creatures on top

local Config = require("src.config")
local Procedural = require("src.rendering.procedural")
local PixelDraw = require("src.rendering.pixel_draw")

local TurretConcepts = {}

-- =============================================================================
-- SCALING (derived from cell size - tuned at 64px)
-- =============================================================================

local TURRET_SCALE = Config.CELL_SIZE / 64  -- Scale factor for all turret dimensions
local BASE_RADIUS = 20 * TURRET_SCALE       -- Stone base radius
local VOID_RADIUS = 14 * TURRET_SCALE       -- Void entity radius
local PIXEL_SIZE = math.max(2, math.floor(3 * TURRET_SCALE))  -- Pixel art granularity (min 2)

-- =============================================================================
-- CANVAS CACHING FOR PERFORMANCE
-- =============================================================================

-- Cache for pre-rendered stone bases (keyed by "seed_level")
local baseCanvasCache = {}
local BASE_CANVAS_SIZE = Config.CELL_SIZE  -- Size of cached base canvas

-- Get or create cached base canvas
local function getCachedBase(seed, level)
    local key = seed .. "_" .. (level or 1)
    if not baseCanvasCache[key] then
        -- Create and render base to canvas
        local canvas = love.graphics.newCanvas(BASE_CANVAS_SIZE, BASE_CANVAS_SIZE)
        -- Use nearest-neighbor filtering to match direct pixel drawing
        canvas:setFilter("nearest", "nearest")
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        -- Will be populated on first draw
        love.graphics.setCanvas()
        baseCanvasCache[key] = {
            canvas = canvas,
            rendered = false,
            level = level or 1,
        }
    end
    return baseCanvasCache[key]
end

-- Clear cache (call on tower destruction or level change)
function TurretConcepts.clearCache(seed, level)
    if seed then
        local key = seed .. "_" .. (level or 1)
        if baseCanvasCache[key] then
            baseCanvasCache[key].canvas:release()
            baseCanvasCache[key] = nil
        end
    else
        -- Clear all
        for k, v in pairs(baseCanvasCache) do
            v.canvas:release()
        end
        baseCanvasCache = {}
    end
end

-- =============================================================================
-- VARIANT DEFINITIONS
-- =============================================================================

local VARIANTS = {
    { name = "Void Orb",      shape = "orb",  sizeMultiplier = 0.8 },
    { name = "Void Ring",     shape = "ring", sizeMultiplier = 1.0 },
    { name = "Void Bolt",     shape = "bolt", sizeMultiplier = 1.0 },
    { name = "Void Eye",      shape = "eye",  sizeMultiplier = 1.0 },
    { name = "Void Star",     shape = "star", sizeMultiplier = 1.0 },
}

-- =============================================================================
-- COLORS
-- =============================================================================

-- Ancient stone base colors
local BASE_COLORS = {
    dark = {0.12, 0.11, 0.10},
    mid = {0.22, 0.20, 0.18},
    light = {0.32, 0.30, 0.27},
    highlight = {0.42, 0.38, 0.34},
}

-- Per-variant elemental color palettes
local VARIANT_COLORS = {
    -- 1: Orb (Poison - green)
    { core = {0.02, 0.08, 0.02}, mid = {0.08, 0.25, 0.08}, edge = {0.4, 0.95, 0.3}, glow = {0.7, 1.0, 0.5} },
    -- 2: Ring (Ice - cyan)
    { core = {0.02, 0.06, 0.10}, mid = {0.08, 0.20, 0.30}, edge = {0.4, 0.85, 1.0}, glow = {0.8, 0.95, 1.0} },
    -- 3: Bolt (Electric - blue)
    { core = {0.02, 0.02, 0.12}, mid = {0.08, 0.12, 0.35}, edge = {0.3, 0.6, 1.0}, glow = {0.7, 0.85, 1.0} },
    -- 4: Eye (Shadow - purple, original)
    { core = {0.05, 0.02, 0.10}, mid = {0.18, 0.08, 0.28}, edge = {0.75, 0.45, 0.95}, glow = {0.90, 0.70, 1.0} },
    -- 5: Star (Fire - orange)
    { core = {0.12, 0.04, 0.02}, mid = {0.35, 0.15, 0.05}, edge = {1.0, 0.6, 0.2}, glow = {1.0, 0.85, 0.4} },
}

-- Default fallback (purple - same as eye)
local DEFAULT_COLORS = VARIANT_COLORS[4]

-- =============================================================================
-- UTILITIES
-- =============================================================================

local function clampColor(r, g, b)
    return math.max(0, math.min(1, r)),
           math.max(0, math.min(1, g)),
           math.max(0, math.min(1, b))
end

local function drawPixelEllipse(cx, cy, radiusX, radiusY, ps, colorFunc)
    local gridW = math.ceil(radiusX / ps) + 1
    local gridH = math.ceil(radiusY / ps) + 1

    for py = -gridH, gridH do
        for px = -gridW, gridW do
            local nx = (px * ps) / radiusX
            local ny = (py * ps) / radiusY
            local dist = nx * nx + ny * ny

            if dist <= 1 then
                local worldX = cx + px * ps
                local worldY = cy + py * ps
                local angle = math.atan2(py, px)
                local distNorm = math.sqrt(dist)

                local r, g, b, a = colorFunc(px, py, distNorm, angle)
                if a and a > 0 then
                    love.graphics.setColor(r, g, b, a)
                    PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
                elseif not a then
                    love.graphics.setColor(r, g, b, 1)
                    PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
                end
            end
        end
    end
end

-- =============================================================================
-- STONE BASE DRAWING
-- =============================================================================

local function drawStoneBase(x, y, ps, time, seed, level)
    level = level or 1
    local baseRadius = BASE_RADIUS
    local topVisible = 0.9
    -- Base height grows with level (adds floors upward)
    local heightRatio = 0.20 + (level - 1) * 0.08

    local ellipseRadiusX = baseRadius
    local ellipseRadiusY = baseRadius * topVisible
    local baseHeight = baseRadius * 2 * heightRatio

    -- Fixed bottom position based on level 1 height (anchor point that never moves)
    local level1Height = baseRadius * 2 * 0.20
    local baseBottomY = y + level1Height * 0.5

    -- Ground shadow stays at same position
    local shadowY = baseBottomY + ps * 3
    drawPixelEllipse(x, shadowY, ellipseRadiusX * 1.3, ellipseRadiusY * 0.7, ps,
        function(px, py, distNorm, angle)
            local fade = (1 - distNorm) * 0.5
            return 0, 0, 0, fade
        end)

    -- Base layers (bottom to top, anchored at baseBottomY)
    local numLayers = math.max(2, math.floor(baseHeight / ps))
    for layer = 0, numLayers - 1 do
        local layerProgress = layer / numLayers
        local layerY = baseBottomY - layer * (baseHeight / numLayers)

        -- Slight taper
        local taperFactor = 1.0 - layerProgress * 0.08
        local layerRadiusX = ellipseRadiusX * taperFactor
        local layerRadiusY = ellipseRadiusY * taperFactor

        drawPixelEllipse(x, layerY, layerRadiusX, layerRadiusY, ps,
            function(px, py, distNorm, angle)
                -- Stone texture noise
                local noise = Procedural.fbm(px * 0.3 + seed, py * 0.3, seed, 2)

                -- Vertical gradient
                local vertBright = 0.6 + layerProgress * 0.4

                -- Rim lighting
                local rimLight = math.cos(angle + math.pi * 0.75) * 0.2 + 0.8

                local baseMix = vertBright * rimLight
                local r = BASE_COLORS.dark[1] + (BASE_COLORS.mid[1] - BASE_COLORS.dark[1]) * baseMix
                local g = BASE_COLORS.dark[2] + (BASE_COLORS.mid[2] - BASE_COLORS.dark[2]) * baseMix
                local b = BASE_COLORS.dark[3] + (BASE_COLORS.mid[3] - BASE_COLORS.dark[3]) * baseMix

                -- Add noise variation
                r = r + noise * 0.06 - 0.03
                g = g + noise * 0.05 - 0.025
                b = b + noise * 0.04 - 0.02

                -- Edge darkening
                if distNorm > 0.8 then
                    local edgeDark = (distNorm - 0.8) / 0.2
                    r = r * (1 - edgeDark * 0.3)
                    g = g * (1 - edgeDark * 0.3)
                    b = b * (1 - edgeDark * 0.3)
                end

                return clampColor(r, g, b)
            end)
    end

    -- Top surface (positioned at bottom minus full height)
    local topY = baseBottomY - baseHeight
    drawPixelEllipse(x, topY, ellipseRadiusX * 0.92, ellipseRadiusY * 0.92, ps,
        function(px, py, distNorm, angle)
            local noise = Procedural.fbm(px * 0.25 + seed, py * 0.25 + seed * 0.5, seed, 2)

            local centerBright = 0.85 + (1 - distNorm) * 0.15
            local r = BASE_COLORS.mid[1] * centerBright + noise * 0.05
            local g = BASE_COLORS.mid[2] * centerBright + noise * 0.04
            local b = BASE_COLORS.mid[3] * centerBright + noise * 0.03

            -- Subtle rim
            if distNorm > 0.75 then
                local rimFactor = (distNorm - 0.75) / 0.25
                r = r + BASE_COLORS.highlight[1] * rimFactor * 0.2
                g = g + BASE_COLORS.highlight[2] * rimFactor * 0.2
                b = b + BASE_COLORS.highlight[3] * rimFactor * 0.2
            end

            return clampColor(r, g, b)
        end)

    return topY  -- Return top Y for void entity positioning
end

-- Draw stone base at a given scale (for emergence animation)
-- Uses same positioning logic as drawStoneBase for visual consistency
local function drawStoneBaseScaled(x, y, ps, time, seed, scale)
    scale = scale or 1

    local baseRadius = BASE_RADIUS
    local topVisible = 0.9
    local heightRatio = 0.20  -- Always level 1 during build animation

    local ellipseRadiusX = baseRadius * scale
    local ellipseRadiusY = baseRadius * topVisible * scale
    local baseHeight = baseRadius * 2 * heightRatio * scale

    -- Use same fixed anchor as drawStoneBase (level 1 height)
    local level1Height = baseRadius * 2 * 0.20
    local baseBottomY = y + level1Height * 0.5

    -- Ground shadow (same positioning as drawStoneBase)
    local shadowY = baseBottomY + ps * 3
    drawPixelEllipse(x, shadowY, ellipseRadiusX * 1.3, ellipseRadiusY * 0.7, ps,
        function(px, py, distNorm, angle)
            local fade = (1 - distNorm) * 0.5 * scale
            return 0, 0, 0, fade
        end)

    -- Base layers (bottom to top, anchored at baseBottomY like drawStoneBase)
    local numLayers = math.max(2, math.floor(baseHeight / ps))
    for layer = 0, numLayers - 1 do
        local layerProgress = layer / numLayers
        local layerY = baseBottomY - layer * (baseHeight / numLayers)

        -- Slight taper
        local taperFactor = 1.0 - layerProgress * 0.08
        local layerRadiusX = ellipseRadiusX * taperFactor
        local layerRadiusY = ellipseRadiusY * taperFactor

        drawPixelEllipse(x, layerY, layerRadiusX, layerRadiusY, ps,
            function(px, py, distNorm, angle)
                -- Stone texture noise
                local noise = Procedural.fbm(px * 0.3 + seed, py * 0.3, seed, 2)

                -- Vertical gradient
                local vertBright = 0.6 + layerProgress * 0.4

                -- Rim lighting
                local rimLight = math.cos(angle + math.pi * 0.75) * 0.2 + 0.8

                local baseMix = vertBright * rimLight
                local r = BASE_COLORS.dark[1] + (BASE_COLORS.mid[1] - BASE_COLORS.dark[1]) * baseMix
                local g = BASE_COLORS.dark[2] + (BASE_COLORS.mid[2] - BASE_COLORS.dark[2]) * baseMix
                local b = BASE_COLORS.dark[3] + (BASE_COLORS.mid[3] - BASE_COLORS.dark[3]) * baseMix

                -- Add noise variation
                r = r + noise * 0.06 - 0.03
                g = g + noise * 0.05 - 0.025
                b = b + noise * 0.04 - 0.02

                -- Edge darkening
                if distNorm > 0.8 then
                    local edgeDark = (distNorm - 0.8) / 0.2
                    r = r * (1 - edgeDark * 0.3)
                    g = g * (1 - edgeDark * 0.3)
                    b = b * (1 - edgeDark * 0.3)
                end

                return clampColor(r, g, b)
            end)
    end

    -- Top surface (positioned at bottom minus full height)
    local topY = baseBottomY - baseHeight
    drawPixelEllipse(x, topY, ellipseRadiusX * 0.92, ellipseRadiusY * 0.92, ps,
        function(px, py, distNorm, angle)
            local noise = Procedural.fbm(px * 0.25 + seed, py * 0.25 + seed * 0.5, seed, 2)

            local centerBright = 0.85 + (1 - distNorm) * 0.15
            local r = BASE_COLORS.mid[1] * centerBright + noise * 0.05
            local g = BASE_COLORS.mid[2] * centerBright + noise * 0.04
            local b = BASE_COLORS.mid[3] * centerBright + noise * 0.03

            -- Subtle rim
            if distNorm > 0.75 then
                local rimFactor = (distNorm - 0.75) / 0.25
                r = r + BASE_COLORS.highlight[1] * rimFactor * 0.2
                g = g + BASE_COLORS.highlight[2] * rimFactor * 0.2
                b = b + BASE_COLORS.highlight[3] * rimFactor * 0.2
            end

            return clampColor(r, g, b)
        end)

    return topY
end

-- =============================================================================
-- VOID ENTITY SHADOW ON BASE
-- =============================================================================

local function drawVoidShadowOnBase(x, baseTopY, voidRadius, ps)
    local shadowRadiusX = voidRadius * 1.1
    local shadowRadiusY = voidRadius * 0.5

    drawPixelEllipse(x, baseTopY, shadowRadiusX, shadowRadiusY, ps,
        function(px, py, distNorm, angle)
            local fade = (1 - distNorm * distNorm) * 0.4
            return 0, 0, 0, fade
        end)
end

-- =============================================================================
-- VOID SHAPE HELPERS
-- =============================================================================

-- Check if point is inside a ring (hollow circle)
local function isInsideRing(px, py, outerR, innerR)
    local dist = math.sqrt(px * px + py * py)
    return dist <= outerR and dist >= innerR
end

-- Check if point is inside a lightning bolt shape
local function isInsideBolt(px, py, size)
    -- Simplified zigzag bolt
    local segments = {
        {x1 = 0, y1 = -size, x2 = -size*0.3, y2 = -size*0.2},
        {x1 = -size*0.3, y1 = -size*0.2, x2 = size*0.2, y2 = 0},
        {x1 = size*0.2, y1 = 0, x2 = -size*0.2, y2 = size*0.3},
        {x1 = -size*0.2, y1 = size*0.3, x2 = 0, y2 = size},
    }
    local thickness = size * 0.25
    for _, seg in ipairs(segments) do
        local dx = seg.x2 - seg.x1
        local dy = seg.y2 - seg.y1
        local len = math.sqrt(dx*dx + dy*dy)
        local nx, ny = -dy/len, dx/len
        local t = ((px - seg.x1) * dx + (py - seg.y1) * dy) / (len * len)
        if t >= 0 and t <= 1 then
            local closestX = seg.x1 + t * dx
            local closestY = seg.y1 + t * dy
            local distToLine = math.sqrt((px - closestX)^2 + (py - closestY)^2)
            if distToLine <= thickness then
                return true, distToLine / thickness
            end
        end
    end
    return false, 1
end

-- Check if point is inside a star shape
local function isInsideStar(px, py, outerR, innerR, points)
    local angle = math.atan2(py, px)
    local dist = math.sqrt(px * px + py * py)

    local segmentAngle = math.pi / points
    local localAngle = ((angle + math.pi) % (segmentAngle * 2))

    local t = localAngle / segmentAngle
    if t > 1 then t = 2 - t end

    local edgeRadius = innerR + (outerR - innerR) * (1 - t)
    return dist <= edgeRadius
end

-- =============================================================================
-- VOID ENTITY SHAPES
-- =============================================================================

local function drawVoidOrb(x, y, radius, ps, time, seed, rotation, colors)
    colors = colors or DEFAULT_COLORS
    -- Animated blob like creeps
    local gridR = math.ceil(radius / ps) + 2

    -- OPTIMIZATION: Pre-compute time-based values outside loop
    local timeOffset = time * 2
    local seedOffset = seed * 0.1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local worldX = x + px * ps
            local worldY = y + py * ps
            local dist = math.sqrt((px * ps)^2 + (py * ps)^2)
            local angle = math.atan2(py, px)

            -- OPTIMIZATION: Replace fbm with cheap sin-based wobble
            local wobble = math.sin(angle * 3 + timeOffset + seedOffset) * 0.1 +
                           math.sin(angle * 5 - timeOffset * 0.7) * 0.05
            local edgeRadius = radius * (1 + wobble)

            if dist <= edgeRadius then
                local distNorm = dist / edgeRadius

                -- Swirling interior
                local swirl = math.sin(angle * 3 + timeOffset + distNorm * 4) * 0.3 + 0.7

                local r = colors.core[1] + (colors.mid[1] - colors.core[1]) * swirl * (1 - distNorm)
                local g = colors.core[2] + (colors.mid[2] - colors.core[2]) * swirl * (1 - distNorm)
                local b = colors.core[3] + (colors.mid[3] - colors.core[3]) * swirl * (1 - distNorm)

                -- Edge glow
                if distNorm > 0.7 then
                    local edgeFactor = (distNorm - 0.7) / 0.3
                    local pulse = math.sin(time * 3 + angle * 2) * 0.2 + 0.8
                    r = r + colors.edge[1] * edgeFactor * pulse
                    g = g + colors.edge[2] * edgeFactor * pulse
                    b = b + colors.edge[3] * edgeFactor * pulse
                end

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawVoidRing(x, y, radius, ps, time, seed, rotation, colors)
    colors = colors or DEFAULT_COLORS
    local outerR = radius
    local innerR = radius * 0.5
    local gridR = math.ceil(radius / ps) + 1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local worldX = x + px * ps
            local worldY = y + py * ps
            local dist = math.sqrt((px * ps)^2 + (py * ps)^2)
            local angle = math.atan2(py, px)

            if isInsideRing(dist, 0, outerR, innerR) then
                local ringMid = (outerR + innerR) / 2
                local distFromMid = math.abs(dist - ringMid)
                local ringWidth = (outerR - innerR) / 2
                local distNorm = distFromMid / ringWidth

                local pulse = math.sin(time * 2 + angle * 4 + rotation) * 0.25 + 0.75

                local r = colors.mid[1] * pulse
                local g = colors.mid[2] * pulse
                local b = colors.mid[3] * pulse

                -- Both edges glow
                if distNorm > 0.5 then
                    local edgeFactor = (distNorm - 0.5) / 0.5
                    r = r + colors.edge[1] * edgeFactor * 0.8
                    g = g + colors.edge[2] * edgeFactor * 0.8
                    b = b + colors.edge[3] * edgeFactor * 0.8
                end

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawVoidBolt(x, y, radius, ps, time, seed, rotation, colors)
    colors = colors or DEFAULT_COLORS
    local size = radius
    local gridR = math.ceil(radius * 1.2 / ps) + 1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            -- Rotate coordinates
            local cosR = math.cos(rotation - math.pi/2)
            local sinR = math.sin(rotation - math.pi/2)
            local rpx = (px * cosR + py * sinR) * ps
            local rpy = (-px * sinR + py * cosR) * ps

            local inside, edgeDist = isInsideBolt(rpx, rpy, size)

            if inside then
                local worldX = x + px * ps
                local worldY = y + py * ps

                -- Electric flicker
                local flicker = Procedural.hash(px + math.floor(time * 15), py, seed)
                local pulse = 0.7 + flicker * 0.3

                local r = colors.mid[1] * pulse
                local g = colors.mid[2] * pulse
                local b = colors.mid[3] * pulse

                -- Edge glow
                local edgeFactor = 1 - edgeDist
                r = r + colors.edge[1] * edgeFactor * 0.6
                g = g + colors.edge[2] * edgeFactor * 0.6
                b = b + colors.edge[3] * edgeFactor * 0.6

                -- Random bright sparks
                if flicker > 0.92 then
                    r = colors.glow[1]
                    g = colors.glow[2]
                    b = colors.glow[3]
                end

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawVoidEye(x, y, radius, ps, time, seed, rotation, colors)
    colors = colors or DEFAULT_COLORS
    local gridR = math.ceil(radius / ps) + 1

    -- Eye shape: ellipse with pointed ends
    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local worldX = x + px * ps
            local worldY = y + py * ps

            -- Rotate for aiming
            local cosR = math.cos(rotation)
            local sinR = math.sin(rotation)
            local rpx = px * cosR + py * sinR
            local rpy = -px * sinR + py * cosR

            -- Eye shape (wider horizontally after rotation)
            local eyeX = rpx * ps / radius
            local eyeY = rpy * ps / (radius * 0.5)
            local eyeDist = eyeX * eyeX + eyeY * eyeY

            if eyeDist <= 1 then
                local distNorm = math.sqrt(eyeDist)

                -- Pupil in center
                local pupilDist = math.sqrt((rpx * ps)^2 + (rpy * ps)^2)
                local inPupil = pupilDist < radius * 0.25

                local r, g, b
                if inPupil then
                    -- Dark pupil with void core
                    local pulse = math.sin(time * 3) * 0.1 + 0.9
                    r = colors.core[1] * pulse
                    g = colors.core[2] * pulse
                    b = colors.core[3] * pulse
                else
                    -- Glowing iris
                    local irisPulse = math.sin(time * 2 + distNorm * 4) * 0.2 + 0.8
                    r = colors.mid[1] + (colors.edge[1] - colors.mid[1]) * irisPulse * distNorm
                    g = colors.mid[2] + (colors.edge[2] - colors.mid[2]) * irisPulse * distNorm
                    b = colors.mid[3] + (colors.edge[3] - colors.mid[3]) * irisPulse * distNorm
                end

                -- Edge glow
                if distNorm > 0.75 then
                    local edgeFactor = (distNorm - 0.75) / 0.25
                    r = r + colors.glow[1] * edgeFactor * 0.5
                    g = g + colors.glow[2] * edgeFactor * 0.5
                    b = b + colors.glow[3] * edgeFactor * 0.5
                end

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawVoidStar(x, y, radius, ps, time, seed, rotation, colors)
    colors = colors or DEFAULT_COLORS
    local outerR = radius
    local innerR = radius * 0.4
    local points = 5
    local gridR = math.ceil(radius / ps) + 1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            -- Rotate coordinates
            local cosR = math.cos(rotation - math.pi/2)
            local sinR = math.sin(rotation - math.pi/2)
            local rpx = px * cosR + py * sinR
            local rpy = -px * sinR + py * cosR

            if isInsideStar(rpx * ps, rpy * ps, outerR, innerR, points) then
                local worldX = x + px * ps
                local worldY = y + py * ps
                local dist = math.sqrt((rpx * ps)^2 + (rpy * ps)^2)
                local angle = math.atan2(rpy, rpx)
                local distNorm = dist / outerR

                local pulse = math.sin(time * 2 + angle * points) * 0.2 + 0.8

                local r = colors.core[1] + (colors.mid[1] - colors.core[1]) * pulse * (1 - distNorm * 0.5)
                local g = colors.core[2] + (colors.mid[2] - colors.core[2]) * pulse * (1 - distNorm * 0.5)
                local b = colors.core[3] + (colors.mid[3] - colors.core[3]) * pulse * (1 - distNorm * 0.5)

                -- Edge glow
                if distNorm > 0.6 then
                    local edgeFactor = (distNorm - 0.6) / 0.4
                    r = r + colors.edge[1] * edgeFactor * 0.7
                    g = g + colors.edge[2] * edgeFactor * 0.7
                    b = b + colors.edge[3] * edgeFactor * 0.7
                end

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

-- =============================================================================
-- MAIN DRAW FUNCTIONS
-- =============================================================================

local SHAPE_DRAWERS = {
    orb = drawVoidOrb,
    ring = drawVoidRing,
    bolt = drawVoidBolt,
    eye = drawVoidEye,
    star = drawVoidStar,
}

-- Map variant index to colors
local function getVariantColors(variantIndex)
    return VARIANT_COLORS[variantIndex] or DEFAULT_COLORS
end

-- Draw build particles (called after tower is drawn)
local function drawBuildParticles(particles, ps)
    for _, p in ipairs(particles) do
        local alpha = p.life / p.maxLife
        local size = p.size or ps
        love.graphics.setColor(p.r, p.g, p.b, alpha * (p.alpha or 1))
        PixelDraw.rect(p.x - size/2, p.y - size/2, size, size)
    end
end

-- Spawn rubble particles that fly OUTWARD radially (top-down view)
local function spawnBaseRubbleParticles(particles, x, y, currentRadius, ps, count)
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        -- Spawn at the current edge of the emerging base
        local spawnDist = currentRadius * (0.8 + math.random() * 0.3)
        local px = x + math.cos(angle) * spawnDist
        local py = y + math.sin(angle) * spawnDist * 0.6  -- Squash for perspective

        -- Fly outward radially
        local speed = 40 + math.random() * 60
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed * 0.6  -- Squash for perspective

        table.insert(particles, {
            x = px,
            y = py,
            vx = vx,
            vy = vy,
            life = 0.3 + math.random() * 0.25,
            maxLife = 0.3 + math.random() * 0.25,
            size = ps * (0.4 + math.random() * 0.6),
            r = BASE_COLORS.mid[1] + (math.random() - 0.5) * 0.15,
            g = BASE_COLORS.mid[2] + (math.random() - 0.5) * 0.15,
            b = BASE_COLORS.mid[3] + (math.random() - 0.5) * 0.12,
            alpha = 0.8,
        })
    end
end

-- Spawn void materialization particles that get pulled inward
local function spawnVoidGravityParticles(particles, x, voidY, voidRadius, colors, count)
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local dist = voidRadius * (2.5 + math.random() * 1.5)  -- Start far out
        local px = x + math.cos(angle) * dist
        local py = voidY + math.sin(angle) * dist

        -- Use void entity's edge color for particles
        local colorMix = math.random()
        local r = colors.edge[1] * colorMix + colors.glow[1] * (1 - colorMix)
        local g = colors.edge[2] * colorMix + colors.glow[2] * (1 - colorMix)
        local b = colors.edge[3] * colorMix + colors.glow[3] * (1 - colorMix)

        table.insert(particles, {
            x = px,
            y = py,
            vx = 0,
            vy = 0,
            targetX = x,
            targetY = voidY,
            gravity = 200 + math.random() * 100,
            life = 0.5 + math.random() * 0.4,
            maxLife = 0.5 + math.random() * 0.4,
            size = 3 * (0.4 + math.random() * 0.4),
            r = r,
            g = g,
            b = b,
            alpha = 0.9,
        })
    end
end

local function drawVoidTurret(x, y, variant, variantIndex, rotation, recoilOffset, time, seed, buildProgress, buildParticles, level)
    local ps = PIXEL_SIZE
    local baseVoidRadius = VOID_RADIUS
    level = level or 1

    -- Apply per-variant size multiplier and level scaling
    local variantSize = variant.sizeMultiplier or 1.0
    local levelScale = 1 + (level - 1) * 0.10
    local voidRadius = baseVoidRadius * variantSize * levelScale
    local levitateHeight = baseVoidRadius * 0.7  -- Lowered to sit closer to base

    -- Default to fully built
    buildProgress = buildProgress or 1
    buildParticles = buildParticles or {}

    -- Calculate phase thresholds
    local buildCfg = Config.TOWER_BUILD
    local basePhaseEnd = buildCfg.basePhaseDuration / buildCfg.duration  -- ~0.2

    -- Base emergence progress (0 to 1 during base phase)
    local baseProgress = math.min(1, buildProgress / basePhaseEnd)
    -- Void materialization progress (0 to 1 during void phase)
    local voidProgress = math.max(0, (buildProgress - basePhaseEnd) / (1 - basePhaseEnd))

    -- ===========================================
    -- PHASE 1: Base emerges from ground (scales outward, top-down view)
    -- ===========================================

    local baseRadius = BASE_RADIUS
    -- Calculate height based on level (same formula as drawStoneBase)
    local heightRatio = 0.20 + (level - 1) * 0.08
    local baseHeight = baseRadius * 2 * heightRatio
    -- Fixed bottom anchor (level 1 position)
    local level1Height = baseRadius * 2 * 0.20
    local baseBottomY = y + level1Height * 0.5
    local fullBaseTopY = baseBottomY - baseHeight

    if baseProgress < 1 then
        -- Ease with overshoot for punchy "bursting through" feel
        local easedBase
        if baseProgress < 0.6 then
            -- Fast burst
            local t = baseProgress / 0.6
            easedBase = t * t * (3 - 2 * t) * 1.1  -- Overshoot slightly
        else
            -- Settle back
            local t = (baseProgress - 0.6) / 0.4
            easedBase = 1.1 - 0.1 * t  -- Ease back to 1.0
        end
        easedBase = math.max(0.01, math.min(1.1, easedBase))

        -- Current scale of the base
        local currentScale = easedBase
        local currentRadius = baseRadius * currentScale

        -- Draw scaled base (punching through from below)
        if currentRadius > 2 then
            drawStoneBaseScaled(x, y, ps, time, seed, currentScale)

            -- Spawn rubble at the expanding edge
            if #buildParticles < 18 and math.random() < 0.5 then
                spawnBaseRubbleParticles(buildParticles, x, y, currentRadius, ps, 3)
            end
        end
    else
        -- OPTIMIZATION: Use cached base canvas for fully built towers
        local cached = getCachedBase(seed, level)
        if not cached.rendered then
            -- Render base to canvas once
            -- Must reset transform to avoid scale/translate affecting canvas rendering
            local prevCanvas = love.graphics.getCanvas()
            love.graphics.push()
            love.graphics.origin()  -- Reset transform to identity
            love.graphics.setCanvas(cached.canvas)
            love.graphics.clear(0, 0, 0, 0)
            -- Draw base centered in canvas
            drawStoneBase(BASE_CANVAS_SIZE / 2, BASE_CANVAS_SIZE / 2, ps, 0, seed, level)
            love.graphics.setCanvas(prevCanvas)
            love.graphics.pop()  -- Restore previous transform
            cached.rendered = true
        end
        -- Draw cached base canvas
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(cached.canvas, x - BASE_CANVAS_SIZE / 2, y - BASE_CANVAS_SIZE / 2)
    end

    -- ===========================================
    -- PHASE 2: Void entity materializes
    -- ===========================================

    if voidProgress > 0 then
        local voidY = fullBaseTopY - levitateHeight

        -- Get colors for this variant (final colors)
        local colors = getVariantColors(variantIndex)

        -- Spawn gravity particles during materialization (particles drawn toward center)
        if voidProgress < 0.85 and #buildParticles < 25 and math.random() < 0.35 then
            spawnVoidGravityParticles(buildParticles, x, voidY, voidRadius, colors, 2)
        end

        -- Ease the materialization with overshoot for snappy feel
        local easedVoid
        if voidProgress < 0.5 then
            -- Fast start
            easedVoid = 2 * voidProgress * voidProgress
        else
            -- Gentle finish
            local t = voidProgress - 0.5
            easedVoid = 0.5 + 2 * t * (1 - t) + 0.5 * t * t
        end
        easedVoid = math.min(1, easedVoid)

        -- Scale effect: void grows from tiny to full size
        local currentRadius = voidRadius * easedVoid

        if currentRadius > 2 then
            -- Draw shadow on base top (scales with entity)
            local shadowAlpha = easedVoid * 0.35
            drawPixelEllipse(x, fullBaseTopY, currentRadius * 1.1, currentRadius * 0.45, ps,
                function(px, py, distNorm, angle)
                    local fade = (1 - distNorm * distNorm) * shadowAlpha
                    return 0, 0, 0, fade
                end)

            -- Draw the void entity shape at current scale
            local shapeDrawer = SHAPE_DRAWERS[variant.shape]
            if shapeDrawer then
                shapeDrawer(x, voidY, currentRadius, ps, time, seed, rotation, colors)
            end

            -- Max level effect: pulsing aura and sparkles
            if level >= 5 and easedVoid >= 1 then
                -- Pulsing outer aura ring
                local pulse = math.sin(time * 3) * 0.3 + 0.7
                local auraRadius = currentRadius * 1.4
                love.graphics.setBlendMode("add")

                -- Draw aura ring
                for i = 0, 7 do
                    local angle = (i / 8) * math.pi * 2 + time * 0.5
                    local px = x + math.cos(angle) * auraRadius
                    local py = voidY + math.sin(angle) * auraRadius * 0.9
                    local sparkAlpha = pulse * 0.6
                    love.graphics.setColor(colors.glow[1], colors.glow[2], colors.glow[3], sparkAlpha)
                    PixelDraw.rect(px - ps/2, py - ps/2, ps, ps)
                end

                -- Random sparkles around the entity
                for i = 1, 4 do
                    local sparkTime = time * 2 + i * 1.7
                    local sparkPhase = (sparkTime % 1)
                    if sparkPhase < 0.5 then
                        local sparkAngle = Procedural.hash(i, math.floor(time * 0.5), seed) * math.pi * 2
                        local sparkDist = currentRadius * (0.8 + Procedural.hash(i + 5, math.floor(time), seed) * 0.8)
                        local sx = x + math.cos(sparkAngle + time * 0.3) * sparkDist
                        local sy = voidY + math.sin(sparkAngle + time * 0.3) * sparkDist * 0.9
                        local sparkAlpha = (0.5 - sparkPhase) * 2 * 0.8
                        love.graphics.setColor(colors.glow[1], colors.glow[2], colors.glow[3], sparkAlpha)
                        PixelDraw.rect(sx - ps/2, sy - ps/2, ps, ps)
                    end
                end

                love.graphics.setBlendMode("alpha")
            end
        end
    end

    -- ===========================================
    -- Draw particles on top
    -- ===========================================
    if #buildParticles > 0 then
        drawBuildParticles(buildParticles, ps)
        love.graphics.setColor(1, 1, 1, 1)  -- Reset color
    end
end

-- =============================================================================
-- MUZZLE FLASH
-- =============================================================================

local function drawMuzzleFlash(x, y, rotation, time, seed, ps, colors)
    colors = colors or DEFAULT_COLORS
    local baseRadius = BASE_RADIUS
    local baseHeight = baseRadius * 2 * 0.2
    local voidRadius = 14
    local levitateHeight = voidRadius * 1.2
    local baseTopY = y - baseHeight * 0.5
    local voidY = baseTopY - levitateHeight
    local muzzleDist = 18

    local cosR = math.cos(rotation)
    local sinR = math.sin(rotation)
    local muzzleX = x + cosR * muzzleDist
    local muzzleY = voidY + sinR * muzzleDist

    -- Bright void burst
    love.graphics.setColor(colors.glow[1], colors.glow[2], colors.glow[3], 0.95)
    PixelDraw.rect(muzzleX - ps * 1.5, muzzleY - ps * 1.5, ps * 3, ps * 3)

    -- Void sparks
    for i = 1, 6 do
        local angle = rotation + (i - 3.5) * 0.3 + Procedural.hash(i, math.floor(time * 40), seed) * 0.4
        local dist = ps * (2 + Procedural.hash(i + 10, math.floor(time * 35), seed) * 2.5)
        local fx = muzzleX + math.cos(angle) * dist
        local fy = muzzleY + math.sin(angle) * dist
        love.graphics.setColor(colors.edge[1], colors.edge[2], colors.edge[3], 0.8)
        PixelDraw.rect(fx - ps/2, fy - ps/2, ps, ps)
    end
end

-- =============================================================================
-- THUMBNAIL DRAWING (for panel UI)
-- =============================================================================

local function drawThumbnailOrb(x, y, radius, ps, time, colors)
    colors = colors or DEFAULT_COLORS
    local gridR = math.ceil(radius / ps) + 1
    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local dist = math.sqrt((px * ps)^2 + (py * ps)^2)
            if dist <= radius then
                local worldX = x + px * ps
                local worldY = y + py * ps
                local distNorm = dist / radius

                local r = colors.core[1] + (colors.mid[1] - colors.core[1]) * (1 - distNorm)
                local g = colors.core[2] + (colors.mid[2] - colors.core[2]) * (1 - distNorm)
                local b = colors.core[3] + (colors.mid[3] - colors.core[3]) * (1 - distNorm)

                if distNorm > 0.6 then
                    local edgeFactor = (distNorm - 0.6) / 0.4
                    r = r + colors.edge[1] * edgeFactor * 0.8
                    g = g + colors.edge[2] * edgeFactor * 0.8
                    b = b + colors.edge[3] * edgeFactor * 0.8
                end

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawThumbnailRing(x, y, radius, ps, time, colors)
    colors = colors or DEFAULT_COLORS
    local outerR = radius
    local innerR = radius * 0.45
    local gridR = math.ceil(radius / ps) + 1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local dist = math.sqrt((px * ps)^2 + (py * ps)^2)
            if dist <= outerR and dist >= innerR then
                local worldX = x + px * ps
                local worldY = y + py * ps
                local ringMid = (outerR + innerR) / 2
                local distFromMid = math.abs(dist - ringMid)
                local distNorm = distFromMid / ((outerR - innerR) / 2)

                local r = colors.mid[1]
                local g = colors.mid[2]
                local b = colors.mid[3]

                if distNorm > 0.4 then
                    local edgeFactor = (distNorm - 0.4) / 0.6
                    r = r + colors.edge[1] * edgeFactor * 0.8
                    g = g + colors.edge[2] * edgeFactor * 0.8
                    b = b + colors.edge[3] * edgeFactor * 0.8
                end

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawThumbnailBolt(x, y, radius, ps, time, colors)
    colors = colors or DEFAULT_COLORS
    local size = radius
    local gridR = math.ceil(radius * 1.2 / ps) + 1
    local thickness = size * 0.3

    -- Simplified vertical bolt
    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local pxs = px * ps
            local pys = py * ps

            -- Simple zigzag check
            local inBolt = false
            if math.abs(pys) <= size then
                local normalizedY = (pys + size) / (size * 2)  -- 0 to 1
                local zigzag = math.sin(normalizedY * math.pi * 2) * thickness
                if math.abs(pxs - zigzag) <= thickness then
                    inBolt = true
                end
            end

            if inBolt then
                local worldX = x + px * ps
                local worldY = y + py * ps
                local r = colors.mid[1] + colors.edge[1] * 0.4
                local g = colors.mid[2] + colors.edge[2] * 0.4
                local b = colors.mid[3] + colors.edge[3] * 0.4

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawThumbnailEye(x, y, radius, ps, time, colors)
    colors = colors or DEFAULT_COLORS
    local gridR = math.ceil(radius / ps) + 1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local eyeX = (px * ps) / radius
            local eyeY = (py * ps) / (radius * 0.5)
            local eyeDist = eyeX * eyeX + eyeY * eyeY

            if eyeDist <= 1 then
                local worldX = x + px * ps
                local worldY = y + py * ps
                local distNorm = math.sqrt(eyeDist)

                local pupilDist = math.sqrt((px * ps)^2 + (py * ps)^2)
                local inPupil = pupilDist < radius * 0.25

                local r, g, b
                if inPupil then
                    r, g, b = colors.core[1], colors.core[2], colors.core[3]
                else
                    r = colors.mid[1] + (colors.edge[1] - colors.mid[1]) * distNorm
                    g = colors.mid[2] + (colors.edge[2] - colors.mid[2]) * distNorm
                    b = colors.mid[3] + (colors.edge[3] - colors.mid[3]) * distNorm
                end

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawThumbnailStar(x, y, radius, ps, time, colors)
    colors = colors or DEFAULT_COLORS
    local outerR = radius
    local innerR = radius * 0.4
    local points = 5
    local gridR = math.ceil(radius / ps) + 1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            if isInsideStar(px * ps, py * ps, outerR, innerR, points) then
                local worldX = x + px * ps
                local worldY = y + py * ps
                local dist = math.sqrt((px * ps)^2 + (py * ps)^2)
                local distNorm = dist / outerR

                local r = colors.core[1] + (colors.mid[1] - colors.core[1]) * (1 - distNorm * 0.5)
                local g = colors.core[2] + (colors.mid[2] - colors.core[2]) * (1 - distNorm * 0.5)
                local b = colors.core[3] + (colors.mid[3] - colors.core[3]) * (1 - distNorm * 0.5)

                if distNorm > 0.5 then
                    local edgeFactor = (distNorm - 0.5) / 0.5
                    r = r + colors.edge[1] * edgeFactor * 0.7
                    g = g + colors.edge[2] * edgeFactor * 0.7
                    b = b + colors.edge[3] * edgeFactor * 0.7
                end

                love.graphics.setColor(clampColor(r, g, b))
                PixelDraw.rect(worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local THUMBNAIL_DRAWERS = {
    orb = drawThumbnailOrb,
    ring = drawThumbnailRing,
    bolt = drawThumbnailBolt,
    eye = drawThumbnailEye,
    star = drawThumbnailStar,
}

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function TurretConcepts.init()
    -- Nothing to initialize
end

-- Pre-render any tower base canvases that haven't been rendered yet
-- Call this BEFORE the main entity draw loop to avoid canvas switching during active rendering
function TurretConcepts.preRenderCaches(towers)
    if not towers then return end

    local ps = PIXEL_SIZE
    -- Cache is used once base phase completes (baseProgress >= 1)
    -- baseProgress = buildProgress / basePhaseEnd, so cache when buildProgress >= basePhaseEnd
    local buildCfg = Config.TOWER_BUILD
    local basePhaseEnd = buildCfg.basePhaseDuration / buildCfg.duration

    for _, tower in ipairs(towers) do
        -- Pre-cache when base phase completes (this is when drawVoidTurret starts using the cache)
        if tower.buildProgress and tower.buildProgress >= basePhaseEnd then
            local towerConfig = Config.TOWERS[tower.towerType]
            if towerConfig and towerConfig.voidVariant then
                local seed = tower.voidSeed
                local level = tower.level or 1
                local cached = getCachedBase(seed, level)

                if not cached.rendered then
                    -- Render base to canvas
                    local prevCanvas = love.graphics.getCanvas()
                    love.graphics.push()
                    love.graphics.origin()
                    love.graphics.setCanvas(cached.canvas)
                    love.graphics.clear(0, 0, 0, 0)
                    drawStoneBase(BASE_CANVAS_SIZE / 2, BASE_CANVAS_SIZE / 2, ps, 0, seed, level)
                    love.graphics.setCanvas(prevCanvas)
                    love.graphics.pop()
                    cached.rendered = true
                end
            end
        end
    end

    -- Reset color after pre-rendering
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw a simplified thumbnail for the panel UI (no stone base)
function TurretConcepts.drawThumbnail(variantIndex, x, y, scale)
    local variant = VARIANTS[variantIndex]
    if not variant then return false end

    scale = scale or 1.0
    local ps = 2 * scale  -- Small pixel size for thumbnail
    local radius = 10 * scale
    local colors = getVariantColors(variantIndex)

    local drawer = THUMBNAIL_DRAWERS[variant.shape]
    if drawer then
        drawer(x, y, radius, ps, 0, colors)
        return true
    end
    return false
end

function TurretConcepts.drawVariant(variantIndex, x, y, rotation, recoilOffset, time, seed, buildProgress, buildParticles, level)
    local variant = VARIANTS[variantIndex]
    if not variant then return false end

    drawVoidTurret(x, y, variant, variantIndex, rotation, recoilOffset or 0, time or 0, seed or 0, buildProgress or 1, buildParticles, level or 1)
    return true
end

-- Draw only the void entity shape (no stone base) - used for glow effects
function TurretConcepts.drawVoidEntityOnly(variantIndex, x, y, rotation, time, seed, level)
    local variant = VARIANTS[variantIndex]
    if not variant then return false end

    local ps = PIXEL_SIZE
    local baseVoidRadius = VOID_RADIUS
    level = level or 1

    -- Apply per-variant size multiplier and level scaling
    local variantSize = variant.sizeMultiplier or 1.0
    local levelScale = 1 + (level - 1) * 0.10
    local voidRadius = baseVoidRadius * variantSize * levelScale

    -- Calculate void Y position (same as in drawVoidTurret)
    local baseRadius = BASE_RADIUS
    local heightRatio = 0.20 + (level - 1) * 0.08
    local baseHeight = baseRadius * 2 * heightRatio
    local level1Height = baseRadius * 2 * 0.20
    local baseBottomY = y + level1Height * 0.5
    local fullBaseTopY = baseBottomY - baseHeight
    local levitateHeight = baseVoidRadius * 0.7
    local voidY = fullBaseTopY - levitateHeight

    local colors = getVariantColors(variantIndex)
    local shapeDrawer = SHAPE_DRAWERS[variant.shape]
    if shapeDrawer then
        shapeDrawer(x, voidY, voidRadius, ps, time or 0, seed or 0, rotation or 0, colors)
        return true
    end
    return false
end

function TurretConcepts.drawMuzzleFlashVariant(variantIndex, x, y, rotation, time, seed)
    local colors = getVariantColors(variantIndex)
    drawMuzzleFlash(x, y, rotation, time or 0, seed or 0, 3, colors)
    return true
end

-- Legacy API
function TurretConcepts.draw(conceptKey, x, y, rotation, recoilOffset, time, seed)
    return TurretConcepts.drawVariant(1, x, y, rotation, recoilOffset, time, seed)
end

function TurretConcepts.drawMuzzleFlash(conceptKey, x, y, rotation, time, seed)
    return TurretConcepts.drawMuzzleFlashVariant(1, x, y, rotation, time, seed)
end

return TurretConcepts
