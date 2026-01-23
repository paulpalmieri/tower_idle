-- src/rendering/void_renderer.lua
-- Centralized void/portal procedural rendering
-- Provides pixel pool generation and drawing for all void-style entities

local Procedural = require("src.rendering.procedural")
local PixelDraw = require("src.rendering.pixel_draw")

local VoidRenderer = {}

-- Local references to frequently used math functions
local sin, cos, sqrt, floor, ceil, atan2, min, max, abs =
    math.sin, math.cos, math.sqrt, math.floor, math.ceil, math.atan2, math.min, math.max, math.abs

-- =============================================================================
-- SHAPE FUNCTIONS
-- Each shape function returns (isInside, edgeFactor) for a normalized position
-- normX, normY are in range -1 to 1 (relative to radius)
-- =============================================================================

VoidRenderer.shapes = {}

-- Circle shape (default)
function VoidRenderer.shapes.circle(normX, normY)
    local dist = sqrt(normX * normX + normY * normY)
    return dist < 1.0, dist
end

-- Ellipse shape (stretched circle)
function VoidRenderer.shapes.ellipse(normX, normY, aspectRatio)
    aspectRatio = aspectRatio or 1.5
    local adjustedX = normX / aspectRatio
    local dist = sqrt(adjustedX * adjustedX + normY * normY)
    return dist < 1.0, dist
end

-- Arrow shape (points in direction)
function VoidRenderer.shapes.arrow(normX, normY, dirX, dirY)
    -- Dot product with direction: how far along the arrow direction
    local alongDir = normX * dirX + normY * dirY

    -- Perpendicular distance from arrow axis
    local perpX = normX - alongDir * dirX
    local perpY = normY - alongDir * dirY
    local perpDist = sqrt(perpX * perpX + perpY * perpY)

    -- Arrow shape: narrower at tip (front), wider at base (back)
    -- alongDir ranges from -1 (back) to +1 (front/tip)
    local arrowWidth = (1.0 - alongDir) * 0.5
    arrowWidth = max(0.1, arrowWidth)

    local isInside = perpDist < arrowWidth
    return isInside, perpDist / arrowWidth
end

-- Triangle shape (equilateral pointing in direction)
function VoidRenderer.shapes.triangle(normX, normY, dirX, dirY)
    -- Rotate to align with direction
    local angle = atan2(dirY, dirX)
    local cosA, sinA = cos(-angle), sin(-angle)
    local rotX = normX * cosA - normY * sinA
    local rotY = normX * sinA + normY * cosA

    -- Triangle pointing right: tip at (1,0), base from (-0.5, -0.7) to (-0.5, 0.7)
    -- Linear taper from base to tip
    local taper = 0.7 * (1.0 - (rotX + 0.5) / 1.5)
    local isInside = rotX > -0.5 and rotX < 1.0 and abs(rotY) < taper
    local edgeFactor = abs(rotY) / max(0.01, taper)
    return isInside, edgeFactor
end

-- =============================================================================
-- PIXEL POOL CREATION
-- Creates a pixel pool for an entity (expensive, called once at spawn)
-- =============================================================================

--[[
    Creates a pixel pool for procedural void rendering.

    params:
        radius: number - Base radius of the entity
        pixelSize: number - Size of each pixel in world units
        seed: number - Random seed for procedural generation
        expandFactor: number (optional) - How much extra radius for breathing room (default 1.3)
        distortionFrequency: number (optional) - FBM frequency for edge distortion (default 2.0)
        octaves: number (optional) - FBM octaves for edge distortion (default 3)
        wobbleFrequency: number (optional) - Angular wobble frequency (default 3.0)
        wobbleAmount: number (optional) - Maximum wobble displacement (default 0.4)

    Returns:
        pixelPool table with:
            pixels: array of pixel data
            radius: base radius
            pixelSize: pixel size
            seed: random seed
--]]
function VoidRenderer.createPixelPool(params)
    local radius = params.radius
    local ps = params.pixelSize
    local seed = params.seed or 0
    local expandFactor = params.expandFactor or 1.3
    local distortionFreq = params.distortionFrequency or 2.0
    local octaves = params.octaves or 3
    local wobbleFreq = params.wobbleFrequency or 3.0
    local wobbleAmount = params.wobbleAmount or 0.4

    local pixels = {}

    -- Create a grid of pixels within an expanded area (for breathing/wobble room)
    local expandedRadius = radius * expandFactor
    local gridSize = ceil(expandedRadius * 2 / ps)
    local halfGrid = gridSize / 2

    -- Pre-compute base radius thresholds
    local baseOuterRadius = radius * (0.7 + 0.5 + wobbleAmount * 0.5)

    for py = 0, gridSize - 1 do
        for px = 0, gridSize - 1 do
            -- Position relative to center
            local relX = (px - halfGrid + 0.5) * ps
            local relY = (py - halfGrid + 0.5) * ps

            -- Distance from center
            local dist = sqrt(relX * relX + relY * relY)
            local angle = atan2(relY, relX)

            -- Base edge noise (static shape component)
            local baseEdgeNoise = Procedural.fbm(
                cos(angle) * distortionFreq,
                sin(angle) * distortionFreq,
                seed,
                octaves
            )

            -- Pre-compute wobble phase offset
            local wobblePhase = Procedural.fbm(
                angle * wobbleFreq,
                0,
                seed + 500,
                2
            ) * math.pi * 2

            -- Only include pixels that could potentially be visible
            if dist < baseOuterRadius then
                local distNorm = dist / radius
                table.insert(pixels, {
                    relX = relX,
                    relY = relY,
                    px = px,
                    py = py,
                    dist = dist,
                    distNorm = distNorm,
                    angle = angle,
                    baseEdgeNoise = baseEdgeNoise,
                    wobblePhase = wobblePhase,
                    rnd = Procedural.hash(px, py, seed + 888),
                    rnd2 = Procedural.hash(px * 2.1, py * 1.7, seed + 777),
                })
            end
        end
    end

    return {
        pixels = pixels,
        radius = radius,
        pixelSize = ps,
        seed = seed,
    }
end

-- =============================================================================
-- DRAWING
-- Draws a void entity using a pixel pool (cheap, called every frame)
-- =============================================================================

--[[
    Draws a void entity using the pixel pool approach.

    pixelPool: table - Created by createPixelPool()

    params:
        x, y: number - World position to draw at
        time: number - Current time for animation
        scale: number (optional) - Scale multiplier (default 1.0)
        alpha: number (optional) - Alpha multiplier (default 1.0)

        -- Animation parameters
        wobbleSpeed: number (optional) - Edge wobble animation speed (default 2.5)
        wobbleAmount: number (optional) - Edge wobble displacement (default 0.4)
        pulseSpeed: number (optional) - Edge glow pulse speed (default 2.0)
        swirlSpeed: number (optional) - Interior swirl speed (default 0.8)
        sparkleThreshold: number (optional) - Sparkle probability threshold (default 0.96)

        -- Size parameters
        coreSize: number (optional) - Size of pitch-black core region (default 5)

        -- Colors
        colors: table - { core, mid, edgeGlow, sparkle } color arrays

        -- Morph (optional)
        morph: table (optional) - { shape, direction, progress, colors }
            shape: string - "arrow", "triangle", etc.
            direction: table - { dx, dy } normalized direction
            progress: number - 0-1 morph progress
            colors: table (optional) - target colors to lerp toward

        -- Effects (optional)
        flashIntensity: number (optional) - White flash intensity 0-1
        colorShift: table (optional) - { r, g, b } to add to colors
        desaturate: number (optional) - Desaturation amount 0-1
        squashY: number (optional) - Vertical squash factor (default 1.0)
--]]
function VoidRenderer.draw(pixelPool, params)
    local pixels = pixelPool.pixels
    local baseRadius = pixelPool.radius
    local ps = pixelPool.pixelSize
    local seed = pixelPool.seed

    local x = params.x
    local y = params.y
    local t = params.time or 0
    local scale = params.scale or 1.0
    local alpha = params.alpha or 1.0

    -- Animation parameters
    local wobbleSpeed = params.wobbleSpeed or 2.5
    local wobbleAmount = params.wobbleAmount or 0.4
    local pulseSpeed = params.pulseSpeed or 2.0
    local swirlSpeed = params.swirlSpeed or 0.8
    local sparkleThreshold = params.sparkleThreshold or 0.96

    -- Size parameters
    local coreSize = params.coreSize or 5

    -- Colors
    local colors = params.colors

    -- Effects
    local flashIntensity = params.flashIntensity or 0
    local colorShift = params.colorShift
    local desaturate = params.desaturate or 0
    local squashY = params.squashY or 1.0

    -- Morph parameters
    local morph = params.morph
    local morphDir = morph and morph.direction
    local morphProg = morph and morph.progress or 0
    local morphColors = nil

    -- Pre-compute morph colors if morphing
    if morphDir and morphProg > 0 and morph.colors then
        local mc = morph.colors
        morphColors = {
            core = {
                colors.core[1] + (mc.core[1] - colors.core[1]) * morphProg,
                colors.core[2] + (mc.core[2] - colors.core[2]) * morphProg,
                colors.core[3] + (mc.core[3] - colors.core[3]) * morphProg,
            },
            mid = {
                colors.mid[1] + (mc.mid[1] - colors.mid[1]) * morphProg,
                colors.mid[2] + (mc.mid[2] - colors.mid[2]) * morphProg,
                colors.mid[3] + (mc.mid[3] - colors.mid[3]) * morphProg,
            },
            edgeGlow = {
                colors.edgeGlow[1] + (mc.edgeGlow[1] - colors.edgeGlow[1]) * morphProg,
                colors.edgeGlow[2] + (mc.edgeGlow[2] - colors.edgeGlow[2]) * morphProg,
                colors.edgeGlow[3] + (mc.edgeGlow[3] - colors.edgeGlow[3]) * morphProg,
            },
            sparkle = {
                colors.sparkle[1] + (mc.sparkle[1] - colors.sparkle[1]) * morphProg,
                colors.sparkle[2] + (mc.sparkle[2] - colors.sparkle[2]) * morphProg,
                colors.sparkle[3] + (mc.sparkle[3] - colors.sparkle[3]) * morphProg,
            },
        }
    end

    -- Use morph colors if available, otherwise base colors
    local useColors = morphColors or colors

    -- Skip if invisible
    if scale <= 0 or alpha <= 0.01 then return end

    -- Effective radius with scale
    local radius = baseRadius * scale

    -- Pre-compute time-based values
    local wobbleTime = t * wobbleSpeed
    local sparkleTimeX = floor(t * 8)
    local sparkleTimeY = floor(t * 5)

    -- Scale pixel size to avoid gaps, with slight overlap
    local scaledPs = ps * scale + 0.5
    local scaledPsY = scaledPs * squashY

    -- Snap position to pixel grid
    local snapX = floor(x / ps + 0.5) * ps
    local snapY = floor(y / ps + 0.5) * ps

    -- Draw each pixel
    for _, p in ipairs(pixels) do
        local wobbleNoise = sin(wobbleTime + p.wobblePhase) * 0.5 + 0.5
        local animatedEdgeRadius = radius * (0.7 + p.baseEdgeNoise * 0.5 + wobbleNoise * wobbleAmount * 0.3)

        -- Skip pixels outside the current animated boundary
        if p.dist * scale >= animatedEdgeRadius then
            goto continue
        end

        -- Arrow/shape morph masking (soft fade approach)
        if morphDir and morphProg > 0 then
            local normX = p.relX / baseRadius
            local normY = p.relY / baseRadius

            local shapeFn = VoidRenderer.shapes[morph.shape or "arrow"]
            if shapeFn then
                local isInShape, distToEdge
                if morph.shape == "arrow" or morph.shape == "triangle" then
                    isInShape, distToEdge = shapeFn(normX, normY, morphDir.dx, morphDir.dy)
                else
                    isInShape, distToEdge = shapeFn(normX, normY)
                end

                if not isInShape then
                    -- Soft fade: pixels outside shape fade based on progress and distance
                    local edgeSoftness = 0.3
                    local distanceFactor = min(1, distToEdge / edgeSoftness)
                    -- Quadratic ease for smooth organic feel
                    local fadeOut = morphProg * morphProg * distanceFactor
                    if p.rnd < fadeOut * 0.9 then
                        goto continue
                    end
                end
            end
        end

        local isEdge = p.dist * scale > animatedEdgeRadius - ps * 1.5
        local screenX = floor(snapX + p.relX * scale - scaledPs / 2)
        local screenY = floor(snapY + p.relY * scale * squashY - scaledPsY / 2)

        -- Check if in squared core region (pitch black center)
        local inCore = abs(p.relX) < coreSize and abs(p.relY) < coreSize

        local r, g, b

        -- Sparkles
        local sparkle = Procedural.hash(p.px + sparkleTimeX, p.py + sparkleTimeY, seed + 333)
        if sparkle > sparkleThreshold then
            r, g, b = useColors.sparkle[1], useColors.sparkle[2], useColors.sparkle[3]
        elseif inCore then
            -- Deep void core (pitch black)
            local n = Procedural.hash(p.px + floor(t * 2), p.py, seed) * 0.01
            r = useColors.core[1] + n
            g = useColors.core[2] + n * 0.5
            b = useColors.core[3] + n
        elseif isEdge then
            -- Edge glow
            local pulse = sin(t * pulseSpeed + p.angle * 2) * 0.3 + 0.7
            r = useColors.edgeGlow[1] * pulse
            g = useColors.edgeGlow[2] * pulse
            b = useColors.edgeGlow[3] * pulse
        else
            -- Interior (swirling dark color)
            local swirl = sin(p.angle * 3 + t * swirlSpeed + p.distNorm * 4) * 0.5 + 0.5
            local v = p.rnd * 0.3 + swirl * 0.2 + p.distNorm * 0.3
            r = useColors.core[1] + (useColors.mid[1] - useColors.core[1]) * v
            g = useColors.core[2] + (useColors.mid[2] - useColors.core[2]) * v
            b = useColors.core[3] + (useColors.mid[3] - useColors.core[3]) * v
        end

        -- Apply color shift (e.g., anger-based red shift)
        if colorShift then
            r = min(1, r + colorShift[1])
            g = max(0, g + colorShift[2])
            b = max(0, b + colorShift[3])
        end

        -- Apply flash (blend toward white)
        if flashIntensity > 0 then
            r = r + (1 - r) * flashIntensity
            g = g + (1 - g) * flashIntensity
            b = b + (1 - b) * flashIntensity
        end

        -- Apply desaturation (shift toward gray)
        if desaturate > 0 then
            local gray = (r + g + b) / 3
            r = r + (gray - r) * desaturate
            g = g + (gray - g) * desaturate
            b = b + (gray - b) * desaturate
        end

        love.graphics.setColor(r * alpha, g * alpha, b * alpha, alpha)
        PixelDraw.rect(screenX, screenY, scaledPs, scaledPsY)

        ::continue::
    end
end

-- =============================================================================
-- UTILITY: Draw shadow ellipse
-- =============================================================================

function VoidRenderer.drawShadow(x, y, radius, config)
    config = config or {}
    local offsetY = config.offsetY or 10
    local width = config.width or 0.9
    local height = config.height or 0.25
    local shadowAlpha = config.alpha or 0.4
    local color = config.color or {0, 0, 0}

    love.graphics.setColor(color[1], color[2], color[3], shadowAlpha)
    love.graphics.ellipse("fill", x, y + radius * offsetY / radius + offsetY,
        radius * width, radius * height)
end

return VoidRenderer
