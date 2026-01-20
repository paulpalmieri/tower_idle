-- src/rendering/skill_tree_background.lua
-- Procedural pixelated ground texture for skill tree (Voronoi stone style)
-- Adapted from background.lua for skill tree world space

local Config = require("src.config")
local Procedural = require("src.rendering.procedural")

local SkillTreeBackground = {}

-- Private state
local state = {
    canvas = nil,
    seed = 0,
    worldRadius = 0,
    canvasSize = 0,
}

-- =============================================================================
-- BACKGROUND GENERATOR
-- =============================================================================

local function generate(canvasSize, ps, seed, cfg)
    local colors = Config.BACKGROUND.colors  -- Reuse game background colors
    local yRatio = cfg.perspectiveYRatio
    local mossIntensity = cfg.mossIntensity or 1.0
    local cellSize = cfg.cellSize

    local cols = math.ceil(canvasSize / ps)
    local rows = math.ceil(canvasSize / ps)

    for py = 0, rows - 1 do
        for px = 0, cols - 1 do
            local screenX = px * ps
            local screenY = py * ps

            -- Voronoi for plate structure
            local vor = Procedural.voronoi(px, py, seed, cellSize, yRatio)

            -- Base plate color with per-cell variation
            local cellVar = (vor.cellId - 0.5) * 2 * colors.plateVariation
            local r = colors.base[1] + cellVar
            local g = colors.base[2] + cellVar * 0.8
            local b = colors.base[3] + cellVar * 1.2

            -- Add subtle noise variation within plates
            local detail = Procedural.hash(px, py, seed + 100)
            r = r + (detail - 0.5) * 0.015
            g = g + (detail - 0.5) * 0.012
            b = b + (detail - 0.5) * 0.018

            -- Fissures with moss
            if vor.edgeDistance < cfg.fissureThreshold then
                if vor.edgeDistance < colors.glowFalloff then
                    -- Deep fissure - dark greenish
                    r = colors.fissure[1]
                    g = colors.fissure[2]
                    b = colors.fissure[3]
                else
                    -- Moss growth zone
                    local mossNoise = Procedural.fbm(px * 0.2, py * 0.2 * yRatio, seed + 200, 2)
                    mossNoise = mossNoise * mossIntensity
                    if mossNoise > 0.4 then
                        local mossT = math.min((mossNoise - 0.4) / 0.6, 1)
                        r = colors.moss[1] * (1 - mossT) + colors.mossLight[1] * mossT
                        g = colors.moss[2] * (1 - mossT) + colors.mossLight[2] * mossT
                        b = colors.moss[3] * (1 - mossT) + colors.mossLight[3] * mossT
                    else
                        r = colors.moss[1]
                        g = colors.moss[2]
                        b = colors.moss[3]
                    end
                end
            end

            love.graphics.setColor(r, g, b)
            love.graphics.rectangle("fill", screenX, screenY, ps, ps)
        end
    end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

-- Generate background canvas centered at origin (0,0) in world space
-- Canvas covers worldRadius in all directions
function SkillTreeBackground.generate()
    local cfg = Config.SKILL_TREE.background
    state.seed = math.random(10000)
    state.worldRadius = cfg.worldRadius

    -- Canvas size in pixels (covers 2x worldRadius in each dimension)
    local ps = cfg.pixelSize
    state.canvasSize = math.ceil(cfg.worldRadius * 2 / ps) * ps

    state.canvas = love.graphics.newCanvas(state.canvasSize, state.canvasSize)
    state.canvas:setFilter("nearest", "nearest")

    love.graphics.setCanvas(state.canvas)
    love.graphics.clear(Config.BACKGROUND.colors.base)

    generate(state.canvasSize, ps, state.seed, cfg)

    love.graphics.setCanvas()
end

-- Draw the background at the correct world position
-- Camera offset is applied externally via _applyCameraTransform
function SkillTreeBackground.draw()
    if not state.canvas then return end

    -- Draw canvas centered at world origin (0,0)
    -- The canvas center should be at world (0,0)
    local halfSize = state.canvasSize / 2
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(state.canvas, -halfSize, -halfSize)
end

-- Check if background is generated
function SkillTreeBackground.isGenerated()
    return state.canvas ~= nil
end

-- Get canvas size for bounds checking
function SkillTreeBackground.getWorldRadius()
    return state.worldRadius
end

return SkillTreeBackground
