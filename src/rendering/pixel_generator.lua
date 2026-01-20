-- src/rendering/pixel_generator.lua
-- Shared pixel pool generation for procedural void-style entities
-- Used by: Creep, Void, ExitPortal

local Procedural = require("src.rendering.procedural")

local PixelGenerator = {}

-- Generate a circular pixel pool for procedural rendering
-- @param cfg: Config table with pixelSize, distortionFrequency, octaves, wobbleFrequency, wobbleAmount
-- @param radius: Base radius of the entity
-- @param seed: Random seed for this entity
-- @param options: Optional table with:
--   - precomputeWobblePhase: bool (default true) - pre-compute wobble phase for optimization
--   - classifyZones: bool (default false) - classify pixels as interior/boundary for drawing optimization
-- @return table of pixel data
function PixelGenerator.generateCircularPool(cfg, radius, seed, options)
    options = options or {}
    local precomputeWobblePhase = options.precomputeWobblePhase ~= false  -- default true
    local classifyZones = options.classifyZones or false

    local pixels = {}
    local ps = cfg.pixelSize

    -- Create a grid of pixels within an expanded area (to allow membrane breathing)
    local expandedRadius = radius * 1.3  -- Extra room for wobble expansion
    local gridSize = math.ceil(expandedRadius * 2 / ps)
    local halfGrid = gridSize / 2

    -- Maximum possible edge radius for visibility check
    local maxEdgeRadius = radius * (0.7 + 0.5 + (cfg.wobbleAmount or 0.3) * 0.5)

    -- For zone classification
    local baseInnerRadius = classifyZones and (radius * 0.5) or nil

    for py = 0, gridSize - 1 do
        for px = 0, gridSize - 1 do
            -- Position relative to center
            local relX = (px - halfGrid + 0.5) * ps
            local relY = (py - halfGrid + 0.5) * ps

            -- Distance from center
            local dist = math.sqrt(relX * relX + relY * relY)

            -- Only include pixels that could potentially be visible
            if dist < maxEdgeRadius then
                local angle = math.atan2(relY, relX)
                local distNorm = dist / radius

                -- Base edge noise on ANGLE (organic shape component)
                local baseEdgeNoise = Procedural.fbm(
                    math.cos(angle) * cfg.distortionFrequency,
                    math.sin(angle) * cfg.distortionFrequency,
                    seed,
                    cfg.octaves
                )

                local pixel = {
                    relX = relX,
                    relY = relY,
                    px = px,
                    py = py,
                    dist = dist,
                    distNorm = distNorm,
                    angle = angle,
                    baseEdgeNoise = baseEdgeNoise,
                    rnd = Procedural.hash(px, py, seed + 888),
                    rnd2 = Procedural.hash(px * 2.1, py * 1.7, seed + 777),
                }

                -- Pre-compute wobble phase offset (OPTIMIZATION: replaces per-frame fbm call)
                if precomputeWobblePhase and cfg.wobbleFrequency then
                    pixel.wobblePhase = Procedural.fbm(
                        angle * cfg.wobbleFrequency,
                        0,
                        seed + 500,
                        2
                    ) * math.pi * 2
                end

                -- Classify pixel zone for draw optimization
                if classifyZones then
                    if dist < baseInnerRadius then
                        pixel.zone = "interior"    -- Always visible, skip boundary check
                    else
                        pixel.zone = "boundary"    -- Needs boundary check each frame
                    end
                end

                table.insert(pixels, pixel)
            end
        end
    end

    return pixels
end

-- Generate an elliptical pixel pool for asymmetric entities (like spider body)
-- @param cfg: Config table with pixelSize, distortionFrequency, octaves
-- @param width: Half-width of ellipse
-- @param height: Half-height of ellipse
-- @param seed: Random seed
-- @param options: Same as generateCircularPool
-- @return table of pixel data
function PixelGenerator.generateEllipticalPool(cfg, width, height, seed, options)
    options = options or {}
    local precomputeWobblePhase = options.precomputeWobblePhase ~= false

    local pixels = {}
    local ps = cfg.pixelSize

    -- Expand for wobble
    local expandedWidth = width * 1.3
    local expandedHeight = height * 1.3
    local gridWidth = math.ceil(expandedWidth * 2 / ps)
    local gridHeight = math.ceil(expandedHeight * 2 / ps)
    local halfGridW = gridWidth / 2
    local halfGridH = gridHeight / 2

    for py = 0, gridHeight - 1 do
        for px = 0, gridWidth - 1 do
            local relX = (px - halfGridW + 0.5) * ps
            local relY = (py - halfGridH + 0.5) * ps

            -- Normalized ellipse distance
            local normX = relX / width
            local normY = relY / height
            local ellipseDist = math.sqrt(normX * normX + normY * normY)

            if ellipseDist < 1.3 then  -- Within expanded bounds
                local angle = math.atan2(relY, relX)

                local baseEdgeNoise = Procedural.fbm(
                    math.cos(angle) * cfg.distortionFrequency,
                    math.sin(angle) * cfg.distortionFrequency,
                    seed,
                    cfg.octaves or 3
                )

                local pixel = {
                    relX = relX,
                    relY = relY,
                    px = px,
                    py = py,
                    ellipseDist = ellipseDist,
                    angle = angle,
                    baseEdgeNoise = baseEdgeNoise,
                    rnd = Procedural.hash(px, py, seed + 888),
                    rnd2 = Procedural.hash(px * 2.1, py * 1.7, seed + 777),
                }

                if precomputeWobblePhase and cfg.wobbleFrequency then
                    pixel.wobblePhase = Procedural.fbm(
                        angle * cfg.wobbleFrequency,
                        0,
                        seed + 500,
                        2
                    ) * math.pi * 2
                end

                table.insert(pixels, pixel)
            end
        end
    end

    return pixels
end

return PixelGenerator
