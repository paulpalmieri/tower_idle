-- src/rendering/bloom.lua
-- Bloom effect: extracts emissive sources, blurs them, and composites

local Config = require("src.config")
local Settings = require("src.ui.settings")
local Camera = require("src.core.camera")

local Bloom = {}

local state = {
    enabled = true,
    glowCanvas = nil,       -- Half-resolution glow extraction canvas
    blurCanvasA = nil,      -- Ping-pong blur canvas A
    blurCanvasB = nil,      -- Ping-pong blur canvas B
    blurShaderH = nil,      -- Horizontal blur shader
    blurShaderV = nil,      -- Vertical blur shader
    glowWidth = 0,
    glowHeight = 0,
    time = 0,
}

function Bloom.init()
    -- Half resolution for glow (performance optimization)
    local gameWidth, gameHeight = Settings.getGameDimensions()
    state.glowWidth = math.floor(gameWidth / 2)
    state.glowHeight = math.floor(gameHeight / 2)

    -- Create canvases with linear filtering for smooth blur
    state.glowCanvas = love.graphics.newCanvas(state.glowWidth, state.glowHeight)
    state.glowCanvas:setFilter("linear", "linear")

    state.blurCanvasA = love.graphics.newCanvas(state.glowWidth, state.glowHeight)
    state.blurCanvasA:setFilter("linear", "linear")

    state.blurCanvasB = love.graphics.newCanvas(state.glowWidth, state.glowHeight)
    state.blurCanvasB:setFilter("linear", "linear")

    -- Load blur shaders
    local shaderPath = "src/rendering/shaders/"
    state.blurShaderH = love.graphics.newShader(shaderPath .. "blur_h.glsl")
    state.blurShaderV = love.graphics.newShader(shaderPath .. "blur_v.glsl")

    -- Read initial setting from config
    if Config.POST_PROCESSING and Config.POST_PROCESSING.bloom then
        state.enabled = Config.POST_PROCESSING.bloom.enabled
    end
end

function Bloom.resize()
    local gameWidth, gameHeight = Settings.getGameDimensions()
    state.glowWidth = math.floor(gameWidth / 2)
    state.glowHeight = math.floor(gameHeight / 2)

    state.glowCanvas = love.graphics.newCanvas(state.glowWidth, state.glowHeight)
    state.glowCanvas:setFilter("linear", "linear")

    state.blurCanvasA = love.graphics.newCanvas(state.glowWidth, state.glowHeight)
    state.blurCanvasA:setFilter("linear", "linear")

    state.blurCanvasB = love.graphics.newCanvas(state.glowWidth, state.glowHeight)
    state.blurCanvasB:setFilter("linear", "linear")
end

-- Draw a soft glow circle at given position (world coordinates)
local function drawGlowCircle(x, y, radius, r, g, b, intensity, pulse)
    -- Convert world coordinates to screen coordinates, then scale to half resolution
    local screenX, screenY = Camera.worldToScreen(x, y)
    local hx = screenX / 2
    local hy = screenY / 2
    local hr = radius / 2

    -- Apply pulsing if enabled
    local finalIntensity = intensity
    if pulse then
        local pulseFactor = math.sin(state.time * 2.5) * 0.2 + 0.8
        finalIntensity = intensity * pulseFactor
    end

    -- Draw glow as a single circle - keep it tight around the entity
    love.graphics.setColor(r * finalIntensity, g * finalIntensity, b * finalIntensity, 1.0)
    love.graphics.circle("fill", hx, hy, hr)
end

-- Extract glow sources from entities
function Bloom.render(void, creeps, towers, projectiles, groundEffects, lobbedProjectiles, lightningProjectiles, blackholes, time)
    if not state.enabled then return end

    state.time = time

    -- Get glow config
    local glowCfg = Config.POST_PROCESSING.glow

    -- Render to glow extraction canvas
    love.graphics.setCanvas(state.glowCanvas)
    love.graphics.clear(0, 0, 0, 0)  -- Transparent background
    love.graphics.setBlendMode("alpha")  -- Use alpha blend, not additive

    -- Void portal glow (brightest, large radius, pulsing)
    if void and glowCfg.void then
        local cfg = glowCfg.void
        local params = void:getGlowParams()
        if params then
            local radius = params.radius * cfg.radius_mult
            drawGlowCircle(params.x, params.y, radius, params.color[1], params.color[2], params.color[3], cfg.intensity, true)
        end
    end

    -- Creep glow (medium, pulsing)
    if creeps and glowCfg.creep then
        local cfg = glowCfg.creep
        for _, creep in ipairs(creeps) do
            if not creep.dead and not creep:isSpawning() then
                local params = creep:getGlowParams()
                if params then
                    local radius = params.radius * cfg.radius_mult
                    -- Add per-creep phase offset for variety
                    local pulse = math.sin(time * cfg.pulse_speed + creep.seed * 0.1) * 0.15 + 0.85
                    drawGlowCircle(params.x, params.y, radius, params.color[1], params.color[2], params.color[3], cfg.intensity * pulse, false)
                end
            end
        end
    end

    -- Tower void entity glow (medium)
    if towers and glowCfg.tower then
        local cfg = glowCfg.tower
        for _, tower in ipairs(towers) do
            if not tower.dead then
                local params = tower:getGlowParams()
                if params then
                    local radius = params.radius * cfg.radius_mult
                    drawGlowCircle(params.x, params.y, radius, params.color[1], params.color[2], params.color[3], cfg.intensity, false)
                end
            end
        end
    end

    -- Projectile glow (small, bright)
    if projectiles and glowCfg.projectile then
        local cfg = glowCfg.projectile
        for _, proj in ipairs(projectiles) do
            if not proj.dead then
                local params = proj:getGlowParams()
                if params then
                    local radius = params.radius * cfg.radius_mult
                    drawGlowCircle(params.x, params.y, radius, params.color[1], params.color[2], params.color[3], cfg.intensity, false)
                end
            end
        end
    end

    -- Lobbed projectiles
    if lobbedProjectiles and glowCfg.projectile then
        local cfg = glowCfg.projectile
        for _, proj in ipairs(lobbedProjectiles) do
            if not proj.dead and proj.getGlowParams then
                local params = proj:getGlowParams()
                if params then
                    local radius = params.radius * cfg.radius_mult
                    drawGlowCircle(params.x, params.y, radius, params.color[1], params.color[2], params.color[3], cfg.intensity, false)
                end
            end
        end
    end

    -- Lightning projectiles
    if lightningProjectiles and glowCfg.projectile then
        local cfg = glowCfg.projectile
        for _, proj in ipairs(lightningProjectiles) do
            if not proj.dead and proj.getGlowParams then
                local params = proj:getGlowParams()
                if params then
                    local radius = params.radius * cfg.radius_mult
                    drawGlowCircle(params.x, params.y, radius, params.color[1], params.color[2], params.color[3], cfg.intensity, false)
                end
            end
        end
    end

    -- Blackhole glow
    if blackholes and glowCfg.tower then
        local cfg = glowCfg.tower
        for _, hole in ipairs(blackholes) do
            if not hole.dead and hole.getGlowParams then
                local params = hole:getGlowParams()
                if params then
                    local radius = params.radius * cfg.radius_mult
                    drawGlowCircle(params.x, params.y, radius, params.color[1], params.color[2], params.color[3], cfg.intensity, true)
                end
            end
        end
    end

    -- Ground effects glow (poison green, fire orange)
    if groundEffects and glowCfg.ground_effect then
        local cfg = glowCfg.ground_effect
        for _, effect in ipairs(groundEffects) do
            if not effect.dead and effect.getGlowParams then
                local params = effect:getGlowParams()
                if params then
                    local radius = params.radius * cfg.radius_mult
                    drawGlowCircle(params.x, params.y, radius, params.color[1], params.color[2], params.color[3], cfg.intensity * params.intensity, false)
                end
            end
        end
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()

    -- Apply Gaussian blur passes
    Bloom.blur()
end

-- Apply separable Gaussian blur
function Bloom.blur()
    local bloomCfg = Config.POST_PROCESSING.bloom
    local passes = bloomCfg.passes or 2
    local radius = bloomCfg.radius or 4

    -- Horizontal blur: glow -> blurA
    love.graphics.setCanvas(state.blurCanvasA)
    love.graphics.clear(0, 0, 0, 0)  -- Transparent
    love.graphics.setShader(state.blurShaderH)
    state.blurShaderH:send("direction", {radius / state.glowWidth, 0})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.glowCanvas, 0, 0)
    love.graphics.setShader()
    love.graphics.setCanvas()

    -- Vertical blur: blurA -> blurB
    love.graphics.setCanvas(state.blurCanvasB)
    love.graphics.clear(0, 0, 0, 0)  -- Transparent
    love.graphics.setShader(state.blurShaderV)
    state.blurShaderV:send("direction", {0, radius / state.glowHeight})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.blurCanvasA, 0, 0)
    love.graphics.setShader()
    love.graphics.setCanvas()

    -- Additional passes for smoother blur
    for i = 2, passes do
        -- Horizontal blur: blurB -> blurA
        love.graphics.setCanvas(state.blurCanvasA)
        love.graphics.clear(0, 0, 0, 0)  -- Transparent
        love.graphics.setShader(state.blurShaderH)
        state.blurShaderH:send("direction", {radius / state.glowWidth, 0})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(state.blurCanvasB, 0, 0)
        love.graphics.setShader()
        love.graphics.setCanvas()

        -- Vertical blur: blurA -> blurB
        love.graphics.setCanvas(state.blurCanvasB)
        love.graphics.clear(0, 0, 0, 0)  -- Transparent
        love.graphics.setShader(state.blurShaderV)
        state.blurShaderV:send("direction", {0, radius / state.glowHeight})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(state.blurCanvasA, 0, 0)
        love.graphics.setShader()
        love.graphics.setCanvas()
    end
end

-- Composite blurred glow onto scene (additive blend)
function Bloom.composite()
    if not state.enabled then return end

    local bloomCfg = Config.POST_PROCESSING.bloom
    local intensity = bloomCfg.intensity or 1.5

    -- Composite with additive blend - transparent areas (alpha=0) add nothing
    love.graphics.setBlendMode("add")
    love.graphics.setColor(intensity, intensity, intensity, 1)
    love.graphics.draw(state.blurCanvasB, 0, 0, 0, 2, 2)
    love.graphics.setBlendMode("alpha")
end

-- Draw debug minimap showing glow and blur canvases
function Bloom.drawDebug(x, y)
    if not state.enabled then return end
    if not state.glowCanvas or not state.blurCanvasB then return end

    local previewScale = 0.12  -- Small preview
    local previewW = state.glowWidth * previewScale
    local previewH = state.glowHeight * previewScale
    local spacing = 4

    -- Glow canvas (extraction)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, previewW, previewH)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.glowCanvas, x, y, 0, previewScale, previewScale)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, previewW, previewH)

    -- Blur canvas (composited)
    local x2 = x + previewW + spacing
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x2, y, previewW, previewH)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.blurCanvasB, x2, y, 0, previewScale, previewScale)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x2, y, previewW, previewH)

    -- Labels
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("G", x + 2, y + previewH - 10)
    love.graphics.print("B", x2 + 2, y + previewH - 10)
end

function Bloom.isEnabled()
    return state.enabled
end

function Bloom.toggle()
    state.enabled = not state.enabled
    return state.enabled
end

function Bloom.setEnabled(enabled)
    state.enabled = enabled
end

return Bloom
