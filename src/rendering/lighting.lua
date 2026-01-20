-- src/rendering/lighting.lua
-- Simple canvas-based lighting: creeps, towers, and void glow

local Config = require("src.config")
local Settings = require("src.ui.settings")

local Lighting = {}

local state = {
    canvas = nil,
    glowCanvas = nil,  -- Pre-lighting glow layer
    time = 0,
}

function Lighting.init()
    state.canvas = love.graphics.newCanvas(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    state.glowCanvas = love.graphics.newCanvas(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    state.time = 0
end

-- Recreate canvases when window size changes (e.g., borderless toggle)
function Lighting.resize()
    state.canvas = love.graphics.newCanvas(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    state.glowCanvas = love.graphics.newCanvas(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
end

function Lighting.update(dt)
    state.time = state.time + dt
end

function Lighting.toggle()
    return Settings.toggleLighting()
end

function Lighting.isActive()
    return Settings.isLightingEnabled()
end

-- Draw a diffuse radial light (additive) - soft falloff, wide spread
local function drawLight(x, y, radius, r, g, b, intensity)
    intensity = intensity or 1.0
    -- More layers for smoother, more diffuse light
    love.graphics.setColor(r * intensity * 0.15, g * intensity * 0.15, b * intensity * 0.15, 0.9)
    love.graphics.circle("fill", x, y, radius * 1.4)  -- Outer diffuse halo
    love.graphics.setColor(r * intensity * 0.3, g * intensity * 0.3, b * intensity * 0.3, 0.7)
    love.graphics.circle("fill", x, y, radius)
    love.graphics.setColor(r * intensity * 0.5, g * intensity * 0.5, b * intensity * 0.5, 0.5)
    love.graphics.circle("fill", x, y, radius * 0.65)
    love.graphics.setColor(r * intensity * 0.8, g * intensity * 0.8, b * intensity * 0.8, 0.4)
    love.graphics.circle("fill", x, y, radius * 0.35)
    love.graphics.setColor(r * intensity, g * intensity, b * intensity, 0.3)
    love.graphics.circle("fill", x, y, radius * 0.15)
end

-- Render the full light map
function Lighting.render(towers, creeps, projectiles, void, groundEffects, chainLightnings)
    if not Settings.isLightingEnabled() then return end

    love.graphics.setCanvas(state.canvas)
    love.graphics.clear()

    -- Use ambient from config (brighter to not crush sprites)
    local ambient = Config.LIGHTING.ambient
    love.graphics.setColor(ambient[1], ambient[2], ambient[3], 1)
    love.graphics.rectangle("fill", 0, 0, Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)

    love.graphics.setBlendMode("add")

    -- Void: large atmospheric diffuse glow
    if void then
        local voidCfg = Config.LIGHTING
        local cx = void.x  -- x,y are now center coordinates
        local cy = void.y
        local anger = void:getAngerLevel()

        -- Slow pulse for atmospheric feel
        local pulse = math.sin(state.time * 1.5) * 0.1 + 0.9
        local pulse2 = math.sin(state.time * 0.8 + 1) * 0.08 + 0.92

        -- Color shifts with anger (more saturated)
        local vr = 0.5 + anger * 0.15
        local vg = 0.15
        local vb = 0.6 - anger * 0.1

        -- Very large diffuse outer atmosphere
        local outerRadius = voidCfg.radii.void * pulse
        love.graphics.setColor(vr * 0.1, vg * 0.05, vb * 0.15, 0.6)
        love.graphics.circle("fill", cx, cy, outerRadius * 1.5)  -- Huge diffuse halo
        love.graphics.setColor(vr * 0.15, vg * 0.08, vb * 0.2, 0.5)
        love.graphics.circle("fill", cx, cy, outerRadius * 1.2)
        love.graphics.setColor(vr * 0.25, vg * 0.12, vb * 0.35, 0.45)
        love.graphics.circle("fill", cx, cy, outerRadius * pulse2)
        love.graphics.setColor(vr * 0.4, vg * 0.2, vb * 0.5, 0.35)
        love.graphics.circle("fill", cx, cy, outerRadius * 0.6)
        love.graphics.setColor(vr * 0.6, vg * 0.3, vb * 0.7, 0.25)
        love.graphics.circle("fill", cx, cy, outerRadius * 0.3)
    end

    -- Ground effects: poison clouds, burning ground emit light
    if groundEffects then
        for _, effect in ipairs(groundEffects) do
            if effect.getLightParams then
                local params = effect:getLightParams()
                if params then
                    drawLight(params.x, params.y, params.radius, params.color[1], params.color[2], params.color[3], params.intensity)
                end
            end
        end
    end

    -- Chain lightnings: brief bright flashes
    if chainLightnings then
        for _, chain in ipairs(chainLightnings) do
            if chain.getLightParams then
                local params = chain:getLightParams()
                if params then
                    drawLight(params.x, params.y, params.radius, params.color[1], params.color[2], params.color[3], params.intensity)
                end
            end
        end
    end

    -- Towers: medium lights
    for _, tower in ipairs(towers) do
        local cfg = Config.LIGHTING
        local radius = cfg.radii.tower[tower.towerType] or 100
        local color = cfg.colors.tower[tower.towerType] or {0.5, 0.5, 0.5}
        local intensity = cfg.intensities.tower[tower.towerType] or 0.8
        drawLight(tower.x, tower.y, radius, color[1], color[2], color[3], intensity)
    end

    -- Creeps: pulsing lights with bloom layer
    for _, creep in ipairs(creeps) do
        if not creep.dead and not creep:isSpawning() then
            local cfg = Config.LIGHTING
            local radius = cfg.radii.creep
            local color = cfg.colors.creep
            local intensity = cfg.intensities.creep

            -- Pulsing effect for creeps (like void but faster)
            local creepPulse = math.sin(state.time * 3.5 + creep.seed * 0.1) * 0.15 + 1.0
            local pulseIntensity = intensity * creepPulse

            -- Bloom layer: larger, fainter glow behind main light
            drawLight(creep.x, creep.y, radius * 1.6, color[1], color[2], color[3], pulseIntensity * 0.4)

            -- Main creep light
            drawLight(creep.x, creep.y, radius, color[1], color[2], color[3], pulseIntensity)
        end
    end

    -- Projectiles: bright small lights
    for _, proj in ipairs(projectiles) do
        local cfg = Config.LIGHTING
        local radius = cfg.radii.projectile
        local color = cfg.colors.projectile[proj.towerType] or {1, 0.8, 0.5}
        local intensity = cfg.intensities.projectile
        drawLight(proj.x, proj.y, radius, color[1], color[2], color[3], intensity)
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()
end

-- Apply light map over the scene
function Lighting.apply()
    if not Settings.isLightingEnabled() then return end
    if not state.canvas then return end

    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.canvas, 0, 0)
    love.graphics.setBlendMode("alpha")
end

-- Show toggle indicator briefly
local indicatorTimer = 0

function Lighting.showIndicator()
    indicatorTimer = 1.5
end

function Lighting.drawIndicator()
    if indicatorTimer <= 0 then return end
    indicatorTimer = indicatorTimer - love.timer.getDelta()

    local alpha = math.min(1, indicatorTimer / 0.3)
    local text = Settings.isLightingEnabled() and "LIGHTING: ON" or "LIGHTING: OFF"

    local playAreaWidth = Config.SCREEN_WIDTH * Config.PLAY_AREA_RATIO
    local x = playAreaWidth / 2

    love.graphics.setColor(0, 0, 0, 0.6 * alpha)
    love.graphics.rectangle("fill", x - 80, 55, 160, 30, 4, 4)
    love.graphics.setColor(0.9, 0.85, 0.7, alpha)
    love.graphics.printf(text, x - 70, 62, 140, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

return Lighting
