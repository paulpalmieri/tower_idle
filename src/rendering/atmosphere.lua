-- src/rendering/atmosphere.lua
-- Atmospheric effects: vignette, fog particles, ambient dust

local Config = require("src.config")
local Settings = require("src.ui.settings")

local Atmosphere = {}

-- State for particles
local particles = {}

-- Configuration
local VIGNETTE = {
    color = {0.12, 0.04, 0.18},  -- Purple tint
    intensity = 0.45,            -- Edge darkness
    edgeSize = 200,              -- How far vignette extends from edges
}

local FOG_PARTICLES = {
    count = 25,                   -- Number of fog wisps
    minSize = 6,
    maxSize = 14,
    minSpeed = 5,
    maxSpeed = 15,
    minAlpha = 0.06,
    maxAlpha = 0.12,
    color = {0.35, 0.20, 0.45},  -- Purple-ish fog
    driftAngle = math.rad(-15),  -- Slight upward drift
}

local DUST_PARTICLES = {
    count = 20,
    minSize = 2,
    maxSize = 3,
    minSpeed = 8,
    maxSpeed = 20,
    minAlpha = 0.20,
    maxAlpha = 0.40,
    color = {0.50, 0.35, 0.60},  -- Lighter purple motes
}

-- Initialize atmosphere system
function Atmosphere.init()
    Atmosphere.initParticles()
end

-- Create initial particle set
function Atmosphere.initParticles()
    particles = {}

    local screenW = Config.SCREEN_WIDTH
    local screenH = Config.SCREEN_HEIGHT

    -- Create fog wisps
    for _ = 1, FOG_PARTICLES.count do
        table.insert(particles, {
            x = math.random() * screenW,
            y = math.random() * screenH,
            size = FOG_PARTICLES.minSize + math.random() * (FOG_PARTICLES.maxSize - FOG_PARTICLES.minSize),
            speed = FOG_PARTICLES.minSpeed + math.random() * (FOG_PARTICLES.maxSpeed - FOG_PARTICLES.minSpeed),
            alpha = FOG_PARTICLES.minAlpha + math.random() * (FOG_PARTICLES.maxAlpha - FOG_PARTICLES.minAlpha),
            type = "fog",
            wobbleOffset = math.random() * math.pi * 2,
            wobbleSpeed = 0.5 + math.random() * 0.5,
        })
    end

    -- Create dust motes
    for _ = 1, DUST_PARTICLES.count do
        table.insert(particles, {
            x = math.random() * screenW,
            y = math.random() * screenH,
            size = DUST_PARTICLES.minSize + math.random() * (DUST_PARTICLES.maxSize - DUST_PARTICLES.minSize),
            speed = DUST_PARTICLES.minSpeed + math.random() * (DUST_PARTICLES.maxSpeed - DUST_PARTICLES.minSpeed),
            alpha = DUST_PARTICLES.minAlpha + math.random() * (DUST_PARTICLES.maxAlpha - DUST_PARTICLES.minAlpha),
            type = "dust",
            wobbleOffset = math.random() * math.pi * 2,
            wobbleSpeed = 1.0 + math.random() * 1.0,
        })
    end
end

-- Update particle positions
function Atmosphere.update(dt)
    local screenW = Config.SCREEN_WIDTH
    local screenH = Config.SCREEN_HEIGHT
    local time = love.timer.getTime()

    for _, p in ipairs(particles) do
        -- Base movement (slow drift to the right and slightly up)
        local angle = FOG_PARTICLES.driftAngle
        p.x = p.x + math.cos(angle) * p.speed * dt
        p.y = p.y + math.sin(angle) * p.speed * dt

        -- Add subtle wobble
        local wobble = math.sin(time * p.wobbleSpeed + p.wobbleOffset) * 0.5
        p.y = p.y + wobble * dt * 10

        -- Wrap around screen edges
        if p.x > screenW + p.size then
            p.x = -p.size
            p.y = math.random() * screenH
        end
        if p.x < -p.size then
            p.x = screenW + p.size
            p.y = math.random() * screenH
        end
        if p.y > screenH + p.size then
            p.y = -p.size
        end
        if p.y < -p.size then
            p.y = screenH + p.size
        end
    end
end

-- Draw fog/dust particles (call before vignette)
function Atmosphere.drawParticles()
    local fogEnabled = Settings.isFogParticlesEnabled()
    local dustEnabled = Settings.isDustParticlesEnabled()

    if not fogEnabled and not dustEnabled then return end

    love.graphics.setBlendMode("alpha")

    for _, p in ipairs(particles) do
        if p.type == "fog" and fogEnabled then
            -- Soft fog blob
            love.graphics.setColor(FOG_PARTICLES.color[1], FOG_PARTICLES.color[2], FOG_PARTICLES.color[3], p.alpha)
            love.graphics.circle("fill", p.x, p.y, p.size)
        elseif p.type == "dust" and dustEnabled then
            -- Sharp dust mote
            love.graphics.setColor(DUST_PARTICLES.color[1], DUST_PARTICLES.color[2], DUST_PARTICLES.color[3], p.alpha)
            love.graphics.rectangle("fill", p.x - p.size/2, p.y - p.size/2, p.size, p.size)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw vignette overlay (call last in render pipeline)
-- Uses corner rectangles with alpha gradients for a subtle edge darkening
function Atmosphere.drawVignette()
    if not Settings.isVignetteEnabled() then return end

    local screenW = Config.SCREEN_WIDTH
    local screenH = Config.SCREEN_HEIGHT

    -- Draw corner shadows as overlapping rectangles with low alpha
    love.graphics.setBlendMode("alpha")

    local r, g, b = VIGNETTE.color[1], VIGNETTE.color[2], VIGNETTE.color[3]
    local intensity = VIGNETTE.intensity
    local edgeSize = VIGNETTE.edgeSize

    -- Edge gradients - draw from outside in with decreasing alpha
    local steps = 6

    for i = 1, steps do
        local t = i / steps
        local alpha = intensity * (1 - t) * 0.5
        local size = edgeSize * t

        love.graphics.setColor(r, g, b, alpha)

        -- Top edge
        love.graphics.rectangle("fill", 0, 0, screenW, size)
        -- Bottom edge
        love.graphics.rectangle("fill", 0, screenH - size, screenW, size)
        -- Left edge
        love.graphics.rectangle("fill", 0, 0, size, screenH)
        -- Right edge (stop before panel)
        local playAreaW = screenW * Config.PLAY_AREA_RATIO
        love.graphics.rectangle("fill", playAreaW - size, 0, size, screenH)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Atmosphere
