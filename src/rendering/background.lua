-- src/rendering/background.lua
-- Simple procedural pixelated ground texture

local Config = require("src.config")
local Procedural = require("src.rendering.procedural")

local Background = {}

local backgroundCanvas = nil
local seed = 0

function Background.generate(width, height)
    seed = math.random(10000)
    local ps = Config.BACKGROUND.pixelSize
    local colors = Config.BACKGROUND.colors

    local cols = math.ceil(width / ps)
    local rows = math.ceil(height / ps)

    backgroundCanvas = love.graphics.newCanvas(width, height)
    backgroundCanvas:setFilter("nearest", "nearest")

    love.graphics.setCanvas(backgroundCanvas)
    love.graphics.clear(colors.base)

    for py = 0, rows - 1 do
        local yNorm = py / rows

        for px = 0, cols - 1 do
            local screenX = px * ps
            local screenY = py * ps

            -- Noise layers
            local n1 = Procedural.fbm(px * 0.12, py * 0.12, seed, 3)
            local n2 = Procedural.fbm(px * 0.06, py * 0.06, seed + 50, 2)
            local detail = Procedural.hash(px, py, seed + 100)

            -- Base color with variation
            local baseVar = n1 * 0.4 + n2 * 0.3
            local r = colors.base[1] + baseVar * 0.03
            local g = colors.base[2] + baseVar * 0.025
            local b = colors.base[3] + baseVar * 0.035

            -- Dark patches
            if detail > 0.88 then
                r = colors.baseDark[1]
                g = colors.baseDark[2]
                b = colors.baseDark[3]
            end

            -- Light specks
            if detail < 0.05 then
                r = colors.baseLight[1]
                g = colors.baseLight[2]
                b = colors.baseLight[3]
            end

            -- Cracks
            local crackNoise = Procedural.fbm(px * 0.3, py * 0.25, seed + 200, 2)
            if crackNoise > 0.65 then
                r = colors.crack[1]
                g = colors.crack[2]
                b = colors.crack[3]
            end

            -- Purple clusters (more near top)
            local clusterBias = 1 - yNorm * 0.6
            local clusterNoise = Procedural.fbm(px * 0.08, py * 0.08, seed + 300, 3)

            if clusterNoise * clusterBias > 0.55 then
                local intensity = (clusterNoise * clusterBias - 0.55) * 2.5
                intensity = math.min(intensity, 1)

                if detail > 0.6 then
                    -- Bright purple
                    r = colors.clusterBright[1] + intensity * 0.1
                    g = colors.clusterBright[2]
                    b = colors.clusterBright[3] + intensity * 0.1
                else
                    -- Dark purple
                    r = colors.cluster[1] + intensity * 0.05
                    g = colors.cluster[2]
                    b = colors.cluster[3] + intensity * 0.05
                end
            end

            love.graphics.setColor(r, g, b)
            love.graphics.rectangle("fill", screenX, screenY, ps, ps)
        end
    end

    love.graphics.setCanvas()
end

function Background.update(dt)
end

function Background.draw()
    if backgroundCanvas then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(backgroundCanvas, 0, 0)
    end
end

function Background.regenerate(width, height)
    Background.generate(width, height)
end

return Background
