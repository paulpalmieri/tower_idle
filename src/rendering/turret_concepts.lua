-- src/rendering/turret_concepts.lua
-- Void Entity Turret Concepts
-- Ancient stone bases with void creatures on top

local Config = require("src.config")
local Procedural = require("src.rendering.procedural")

local TurretConcepts = {}

-- =============================================================================
-- VARIANT DEFINITIONS
-- =============================================================================

local VARIANTS = {
    { name = "Void Orb",      shape = "orb" },
    { name = "Void Ring",     shape = "ring" },
    { name = "Void Bolt",     shape = "bolt" },
    { name = "Void Eye",      shape = "eye" },
    { name = "Void Star",     shape = "star" },
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
                    love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
                elseif not a then
                    love.graphics.setColor(r, g, b, 1)
                    love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
                end
            end
        end
    end
end

-- =============================================================================
-- STONE BASE DRAWING
-- =============================================================================

local function drawStoneBase(x, y, ps, time, seed)
    local baseRadius = 20
    local topVisible = 0.9
    local heightRatio = 0.20

    local ellipseRadiusX = baseRadius
    local ellipseRadiusY = baseRadius * topVisible
    local baseHeight = baseRadius * 2 * heightRatio

    -- Ground shadow
    local shadowY = y + baseHeight * 0.5 + ps * 3
    drawPixelEllipse(x, shadowY, ellipseRadiusX * 1.3, ellipseRadiusY * 0.7, ps,
        function(px, py, distNorm, angle)
            local fade = (1 - distNorm) * 0.5
            return 0, 0, 0, fade
        end)

    -- Base layers (bottom to top)
    local numLayers = math.max(2, math.floor(baseHeight / ps))
    for layer = 0, numLayers - 1 do
        local layerProgress = layer / numLayers
        local layerY = y + baseHeight * 0.5 - layer * (baseHeight / numLayers)

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

    -- Top surface
    local topY = y - baseHeight * 0.5
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

-- Check if point is inside a cross/plus shape
local function isInsideCross(px, py, size, thickness)
    local inVertical = math.abs(px) <= thickness and math.abs(py) <= size
    local inHorizontal = math.abs(py) <= thickness and math.abs(px) <= size
    return inVertical or inHorizontal
end

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

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local worldX = x + px * ps
            local worldY = y + py * ps
            local dist = math.sqrt((px * ps)^2 + (py * ps)^2)
            local angle = math.atan2(py, px)

            -- Wobbling edge
            local wobble = Procedural.fbm(angle * 2 + time * 2, time * 0.5, seed, 2) * 0.2
            local edgeRadius = radius * (1 + wobble)

            if dist <= edgeRadius then
                local distNorm = dist / edgeRadius

                -- Swirling interior
                local swirl = math.sin(angle * 3 + time * 2 + distNorm * 4) * 0.3 + 0.7

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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawVoidCross(x, y, radius, ps, time, seed, rotation)
    local size = radius
    local thickness = radius * 0.35
    local gridR = math.ceil(radius / ps) + 1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            -- Rotate coordinates
            local cosR = math.cos(rotation)
            local sinR = math.sin(rotation)
            local rpx = px * cosR + py * sinR
            local rpy = -px * sinR + py * cosR

            if isInsideCross(rpx * ps, rpy * ps, size, thickness) then
                local worldX = x + px * ps
                local worldY = y + py * ps
                local dist = math.sqrt((rpx * ps)^2 + (rpy * ps)^2)
                local distNorm = dist / size

                local pulse = math.sin(time * 2.5 + distNorm * 3) * 0.2 + 0.8

                local r = VOID_COLORS.core[1] + (VOID_COLORS.mid[1] - VOID_COLORS.core[1]) * pulse
                local g = VOID_COLORS.core[2] + (VOID_COLORS.mid[2] - VOID_COLORS.core[2]) * pulse
                local b = VOID_COLORS.core[3] + (VOID_COLORS.mid[3] - VOID_COLORS.core[3]) * pulse

                -- Edge glow (check distance from cross edge)
                local edgeDistX = math.min(math.abs(math.abs(rpx * ps) - thickness), math.abs(rpx * ps))
                local edgeDistY = math.min(math.abs(math.abs(rpy * ps) - thickness), math.abs(rpy * ps))
                local edgeDist = math.min(edgeDistX, edgeDistY)

                if edgeDist < ps * 2 then
                    local edgeFactor = 1 - edgeDist / (ps * 2)
                    r = r + VOID_COLORS.edge[1] * edgeFactor * 0.7
                    g = g + VOID_COLORS.edge[2] * edgeFactor * 0.7
                    b = b + VOID_COLORS.edge[3] * edgeFactor * 0.7
                end

                love.graphics.setColor(clampColor(r, g, b))
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawVoidFlame(x, y, radius, ps, time, seed, rotation)
    local gridR = math.ceil(radius * 1.3 / ps) + 1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            -- Rotate for aiming (flame points in rotation direction)
            local cosR = math.cos(rotation - math.pi/2)
            local sinR = math.sin(rotation - math.pi/2)
            local rpx = px * cosR + py * sinR
            local rpy = -px * sinR + py * cosR

            local worldX = x + px * ps
            local worldY = y + py * ps

            -- Flame shape: wider at bottom, pointed at top
            local normalizedY = (rpy * ps + radius) / (radius * 2)  -- 0 at bottom, 1 at top
            if normalizedY < 0 or normalizedY > 1.2 then goto continue end

            local flameWidth = radius * (1 - normalizedY * 0.7) * (0.8 + math.sin(normalizedY * 3 + time * 5) * 0.2)

            -- Add noise for flickering edges
            local noise = Procedural.fbm(rpx * 0.3 + time * 3, normalizedY * 2 + time * 4, seed, 2)
            flameWidth = flameWidth * (1 + noise * 0.3)

            if math.abs(rpx * ps) <= flameWidth then
                local distFromCenter = math.abs(rpx * ps) / flameWidth

                local intensity = (1 - normalizedY) * (1 - distFromCenter * 0.5)
                local pulse = math.sin(time * 4 + normalizedY * 5) * 0.15 + 0.85

                local r = VOID_COLORS.core[1] + (VOID_COLORS.edge[1] - VOID_COLORS.core[1]) * intensity * pulse
                local g = VOID_COLORS.core[2] + (VOID_COLORS.edge[2] - VOID_COLORS.core[2]) * intensity * pulse
                local b = VOID_COLORS.core[3] + (VOID_COLORS.edge[3] - VOID_COLORS.core[3]) * intensity * pulse

                -- Bright tips
                if normalizedY > 0.7 then
                    local tipFactor = (normalizedY - 0.7) / 0.3
                    r = r + VOID_COLORS.glow[1] * tipFactor * 0.5
                    g = g + VOID_COLORS.glow[2] * tipFactor * 0.5
                    b = b + VOID_COLORS.glow[3] * tipFactor * 0.5
                end

                love.graphics.setColor(clampColor(r, g, b))
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
            end

            ::continue::
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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
            end
        end
    end
end

local function drawVoidSkull(x, y, radius, ps, time, seed, rotation)
    local gridR = math.ceil(radius / ps) + 1

    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local worldX = x + px * ps
            local worldY = y + py * ps

            -- Rotate for aiming
            local cosR = math.cos(rotation - math.pi/2)
            local sinR = math.sin(rotation - math.pi/2)
            local rpx = px * cosR + py * sinR
            local rpy = -px * sinR + py * cosR

            local pxs = rpx * ps
            local pys = rpy * ps

            -- Skull shape: rounded top, narrower jaw
            local skullTop = -radius * 0.3
            local skullBot = radius * 0.6
            local jawStart = radius * 0.1

            local inSkull = false
            local isEyeSocket = false

            if pys < jawStart then
                -- Upper skull (circular)
                local upperDist = math.sqrt(pxs^2 + (pys - skullTop * 0.5)^2)
                inSkull = upperDist < radius * 0.85

                -- Eye sockets
                local eyeOffsetX = radius * 0.35
                local eyeOffsetY = -radius * 0.1
                local eyeRadius = radius * 0.22
                local leftEyeDist = math.sqrt((pxs + eyeOffsetX)^2 + (pys - eyeOffsetY)^2)
                local rightEyeDist = math.sqrt((pxs - eyeOffsetX)^2 + (pys - eyeOffsetY)^2)
                isEyeSocket = leftEyeDist < eyeRadius or rightEyeDist < eyeRadius
            else
                -- Jaw (narrower)
                local jawWidth = radius * 0.6 * (1 - (pys - jawStart) / (skullBot - jawStart) * 0.4)
                inSkull = math.abs(pxs) < jawWidth and pys < skullBot
            end

            if inSkull then
                local dist = math.sqrt(pxs^2 + pys^2)
                local distNorm = dist / radius

                local r, g, b
                if isEyeSocket then
                    -- Glowing eye sockets
                    local pulse = math.sin(time * 3) * 0.3 + 0.7
                    r = VOID_COLORS.edge[1] * pulse
                    g = VOID_COLORS.edge[2] * pulse
                    b = VOID_COLORS.edge[3] * pulse
                else
                    -- Skull body
                    local pulse = math.sin(time * 2 + distNorm * 3) * 0.15 + 0.85
                    r = VOID_COLORS.core[1] + (VOID_COLORS.mid[1] - VOID_COLORS.core[1]) * pulse
                    g = VOID_COLORS.core[2] + (VOID_COLORS.mid[2] - VOID_COLORS.core[2]) * pulse
                    b = VOID_COLORS.core[3] + (VOID_COLORS.mid[3] - VOID_COLORS.core[3]) * pulse

                    -- Subtle edge glow
                    if distNorm > 0.7 then
                        local edgeFactor = (distNorm - 0.7) / 0.3
                        r = r + VOID_COLORS.edge[1] * edgeFactor * 0.4
                        g = g + VOID_COLORS.edge[2] * edgeFactor * 0.4
                        b = b + VOID_COLORS.edge[3] * edgeFactor * 0.4
                    end
                end

                love.graphics.setColor(clampColor(r, g, b))
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
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

local function drawVoidTurret(x, y, variant, variantIndex, rotation, recoilOffset, time, seed)
    local ps = 3
    local voidRadius = 14
    local levitateHeight = voidRadius * 1.2  -- How high the void floats above base

    -- Draw stone base and get top Y position
    local baseTopY = drawStoneBase(x, y, ps, time, seed)

    -- Void entity levitates above base
    local voidY = baseTopY - levitateHeight

    -- Draw shadow of void entity on base (shadow stays on base surface)
    drawVoidShadowOnBase(x, baseTopY, voidRadius, ps)

    -- Get colors for this variant
    local colors = getVariantColors(variantIndex)

    -- Draw the void entity shape
    local shapeDrawer = SHAPE_DRAWERS[variant.shape]
    if shapeDrawer then
        shapeDrawer(x, voidY, voidRadius, ps, time, seed, rotation, colors)
    end
end

-- =============================================================================
-- MUZZLE FLASH
-- =============================================================================

local function drawMuzzleFlash(x, y, rotation, time, seed, ps, colors)
    colors = colors or DEFAULT_COLORS
    local baseRadius = 20
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
    love.graphics.rectangle("fill", muzzleX - ps * 1.5, muzzleY - ps * 1.5, ps * 3, ps * 3)

    -- Void sparks
    for i = 1, 6 do
        local angle = rotation + (i - 3.5) * 0.3 + Procedural.hash(i, math.floor(time * 40), seed) * 0.4
        local dist = ps * (2 + Procedural.hash(i + 10, math.floor(time * 35), seed) * 2.5)
        local fx = muzzleX + math.cos(angle) * dist
        local fy = muzzleY + math.sin(angle) * dist
        love.graphics.setColor(colors.edge[1], colors.edge[2], colors.edge[3], 0.8)
        love.graphics.rectangle("fill", fx - ps/2, fy - ps/2, ps, ps)
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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
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
                love.graphics.rectangle("fill", worldX - ps/2, worldY - ps/2, ps, ps)
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

function TurretConcepts.drawVariant(variantIndex, x, y, rotation, recoilOffset, time, seed)
    local variant = VARIANTS[variantIndex]
    if not variant then return false end

    drawVoidTurret(x, y, variant, variantIndex, rotation, recoilOffset or 0, time or 0, seed or 0)
    return true
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
