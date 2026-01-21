-- src/rendering/background.lua
-- Procedural pixelated ground texture (Corrupted Grove style)

local Config = require("src.config")
local Procedural = require("src.rendering.procedural")

local Background = {}

-- Private state
local state = {
    canvas = nil,
    seed = 0,
    width = 0,
    height = 0,
}

-- =============================================================================
-- BACKGROUND GENERATOR
-- =============================================================================

local function generate(cols, rows, ps, seed)
    local cfg = Config.BACKGROUND
    local colors = cfg.colors
    local yRatio = cfg.perspectiveYRatio
    local mossIntensity = cfg.mossIntensity or 1.0

    for py = 0, rows - 1 do
        for px = 0, cols - 1 do
            local screenX = px * ps
            local screenY = py * ps

            -- Voronoi for plate structure
            local vor = Procedural.voronoi(px, py, seed, cfg.cellSize, yRatio)

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

function Background.generate(width, height)
    state.seed = math.random(10000)

    -- Use world dimensions if available (for scrollable camera)
    local worldWidth = Config.WORLD_WIDTH or width
    local worldHeight = Config.WORLD_HEIGHT or height

    state.width = worldWidth
    state.height = worldHeight

    local ps = Config.BACKGROUND.pixelSize
    local cols = math.ceil(worldWidth / ps)
    local rows = math.ceil(worldHeight / ps)

    state.canvas = love.graphics.newCanvas(worldWidth, worldHeight)
    state.canvas:setFilter("nearest", "nearest")

    love.graphics.setCanvas(state.canvas)
    love.graphics.clear(Config.BACKGROUND.colors.base)

    generate(cols, rows, ps, state.seed)

    love.graphics.setCanvas()
end

function Background.update(dt)
    -- No animation needed for static background
end

function Background.draw()
    if state.canvas then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(state.canvas, 0, 0)
    end
end

-- Draw background to fill letterbox areas (called before scaling transform)
-- Draws a portion of the background texture scaled to fill the window
function Background.drawLetterbox(windowW, windowH, offsetX, offsetY, scale)
    if not state.canvas then return end
    if offsetX <= 0 and offsetY <= 0 then return end

    love.graphics.setColor(1, 1, 1)

    -- Draw left letterbox
    if offsetX > 0 then
        -- Sample from left edge of background, tile vertically
        local quad = love.graphics.newQuad(0, 0, 32, state.height, state.width, state.height)
        love.graphics.draw(state.canvas, quad, 0, offsetY, 0, offsetX / 32, scale)
        -- Right letterbox
        local rightX = offsetX + Config.SCREEN_WIDTH * scale
        love.graphics.draw(state.canvas, quad, rightX, offsetY, 0, (windowW - rightX) / 32, scale)
    end

    -- Draw top letterbox
    if offsetY > 0 then
        local quad = love.graphics.newQuad(0, 0, state.width, 32, state.width, state.height)
        love.graphics.draw(state.canvas, quad, offsetX, 0, 0, scale, offsetY / 32)
        -- Bottom letterbox
        local bottomY = offsetY + Config.SCREEN_HEIGHT * scale
        love.graphics.draw(state.canvas, quad, offsetX, bottomY, 0, scale, (windowH - bottomY) / 32)
    end

    -- Fill corners if both offsets exist
    if offsetX > 0 and offsetY > 0 then
        local bgColor = Config.BACKGROUND.colors.base
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3])
        -- Top-left
        love.graphics.rectangle("fill", 0, 0, offsetX, offsetY)
        -- Top-right
        love.graphics.rectangle("fill", offsetX + Config.SCREEN_WIDTH * scale, 0, offsetX, offsetY)
        -- Bottom-left
        love.graphics.rectangle("fill", 0, offsetY + Config.SCREEN_HEIGHT * scale, offsetX, offsetY)
        -- Bottom-right
        love.graphics.rectangle("fill", offsetX + Config.SCREEN_WIDTH * scale, offsetY + Config.SCREEN_HEIGHT * scale, offsetX, offsetY)
    end
end

function Background.getBaseColor()
    return Config.BACKGROUND.colors.base
end

function Background.regenerate(width, height)
    Background.generate(width or state.width, height or state.height)
end

return Background
