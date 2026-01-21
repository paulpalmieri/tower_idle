-- src/rendering/game_renderer.lua
-- Scene composition and game world rendering
-- This module is designed to eventually contain all Game.draw() logic from init.lua
-- For now, it provides helper functions that can be used incrementally

local Config = require("src.config")
local Display = require("src.core.display")
local Camera = require("src.core.camera")
local Fonts = require("src.rendering.fonts")

local GameRenderer = {}

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

function GameRenderer.init()
    -- Future: Initialize any rendering state
end

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

-- Draw a simple Y-sorted entity collection
function GameRenderer.drawEntitiesSortedByY(entities)
    -- Make a shallow copy for sorting
    local sorted = {}
    for _, entity in ipairs(entities) do
        if not entity.dead then
            table.insert(sorted, entity)
        end
    end

    table.sort(sorted, function(a, b) return a.y < b.y end)

    for _, entity in ipairs(sorted) do
        entity:draw()
    end
end

-- Draw all entities from a collection
function GameRenderer.drawEntities(entities)
    for _, entity in ipairs(entities) do
        if not entity.dead and entity.draw then
            entity:draw()
        end
    end
end

-- Draw cadaver (dead creep remains)
function GameRenderer.drawCadaver(cadaver)
    if not cadaver or not cadaver.pixels then return end

    local alpha = 1.0 - (cadaver.lifetime / Config.CADAVER_LIFETIME)
    local pixelSize = Config.VOID_SPAWN.pixelSize or 3

    for _, pixel in ipairs(cadaver.pixels) do
        local x = cadaver.x + pixel.relX
        local y = cadaver.y + pixel.relY

        -- Desaturated purple-gray for dead creeps
        local gray = 0.2 + pixel.brightness * 0.15
        love.graphics.setColor(gray + 0.05, gray, gray + 0.08, alpha * 0.7)
        love.graphics.rectangle("fill", x - pixelSize/2, y - pixelSize/2, pixelSize, pixelSize)
    end
end

-- Draw all cadavers
function GameRenderer.drawCadavers(cadavers)
    for _, cadaver in ipairs(cadavers) do
        GameRenderer.drawCadaver(cadaver)
    end
end

-- Draw range ellipse for a tower
function GameRenderer.drawRangeEllipse(tower, alpha)
    alpha = alpha or 0.05
    if tower and tower.range and tower.range > 0 then
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.ellipse("fill", tower.x, tower.y, tower.range, tower.range * 0.9)
    end
end

-- Draw debug overlay showing FPS, memory, entity counts
function GameRenderer.drawDebugOverlay(stats)
    local fps = love.timer.getFPS()
    local gfxStats = love.graphics.getStats()
    local memKB = collectgarbage("count")

    local lines = {
        string.format("FPS: %d", fps),
        string.format("Draw: %d", gfxStats.drawcalls),
        string.format("Mem: %.1fMB", memKB / 1024),
    }

    -- Add entity counts if provided
    if stats then
        if stats.creeps then
            table.insert(lines, string.format("Creeps: %d", stats.creeps))
        end
        if stats.towers then
            table.insert(lines, string.format("Towers: %d", stats.towers))
        end
        if stats.projectiles then
            table.insert(lines, string.format("Proj: %d", stats.projectiles))
        end
        if stats.effects then
            table.insert(lines, string.format("Effects: %d", stats.effects))
        end
        if stats.cadavers then
            table.insert(lines, string.format("Cadavers: %d", stats.cadavers))
        end
    end

    love.graphics.setFont(Fonts.get("small"))
    local lineHeight = 12
    local panelWidth = 76
    local panelHeight = #lines * lineHeight + 8

    -- Background
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 4, 4, panelWidth, panelHeight)

    -- Text
    love.graphics.setColor(1, 1, 1, 0.9)
    for i, line in ipairs(lines) do
        love.graphics.print(line, 8, 4 + (i - 1) * lineHeight + 2)
    end

    return panelWidth + 8  -- Return panel width for positioning next elements
end

-- Draw explosion burst particles
function GameRenderer.drawExplosionBursts(bursts)
    local colors = Config.GROUND_EFFECTS.burning_ground.colors
    for _, burst in ipairs(bursts) do
        for _, p in ipairs(burst.particles) do
            if p.life > 0 then
                local alpha = p.life / p.maxLife
                -- Glow
                love.graphics.setColor(colors.edge[1], colors.edge[2] * 0.7, colors.edge[3] * 0.3, alpha * 0.5)
                love.graphics.circle("fill", p.x, p.y, p.size * 2)
                -- Core
                love.graphics.setColor(p.r, p.g, p.b, alpha)
                love.graphics.rectangle("fill", p.x - p.size/2, p.y - p.size/2, p.size, p.size)
            end
        end
    end
end

-- =============================================================================
-- SCALING UTILITIES
-- =============================================================================

-- Begin scaled drawing (applies Display transform)
function GameRenderer.beginScaledDraw()
    local scale = Display.getScale()
    local offsetX, offsetY = Display.getOffset()

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)
end

-- End scaled drawing
function GameRenderer.endScaledDraw()
    love.graphics.pop()
end

-- Draw letterbox/pillarbox bars for non-16:9 screens
function GameRenderer.drawLetterbox()
    local offsetX, offsetY = Display.getOffset()
    local windowW, windowH = Display.getWindowDimensions()

    if offsetX > 0 or offsetY > 0 then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, windowW, windowH)
    end
end

return GameRenderer
