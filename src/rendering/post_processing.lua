-- src/rendering/post_processing.lua
-- Post-processing pipeline: orchestrates canvas rendering and bloom effects

local Config = require("src.config")
local Bloom = require("src.rendering.bloom")
local Display = require("src.core.display")

local PostProcessing = {}

local state = {
    sceneCanvas = nil,
    enabled = true,
    time = 0,
}

function PostProcessing.init()
    -- Create scene canvas at dynamic game resolution
    local gameWidth, gameHeight = Display.getGameDimensions()
    state.sceneCanvas = love.graphics.newCanvas(gameWidth, gameHeight)
    state.sceneCanvas:setFilter("nearest", "nearest")

    -- Initialize bloom system
    Bloom.init()

    -- Read initial setting from config
    if Config.POST_PROCESSING then
        state.enabled = Config.POST_PROCESSING.enabled
    end
end

-- Recreate canvases when window size changes
function PostProcessing.resize()
    local gameWidth, gameHeight = Display.getGameDimensions()
    state.sceneCanvas = love.graphics.newCanvas(gameWidth, gameHeight)
    state.sceneCanvas:setFilter("nearest", "nearest")

    Bloom.resize()
end

function PostProcessing.update(dt)
    state.time = state.time + dt
end

-- Begin rendering to scene canvas (call BEFORE transform is applied)
function PostProcessing.beginFrame()
    if not state.enabled then return end

    love.graphics.setCanvas(state.sceneCanvas)
    love.graphics.clear(Config.COLORS.background[1], Config.COLORS.background[2], Config.COLORS.background[3], 1)
end

-- End scene rendering, prepare for compositing (call BEFORE transform pop)
function PostProcessing.endFrame()
    if not state.enabled then return end

    love.graphics.setCanvas()
end

-- Collect glow sources from game entities and render bloom
function PostProcessing.renderBloom(void, creeps, towers, projectiles, groundEffects, lobbedProjectiles, lightningProjectiles, blackholes)
    if not state.enabled then return end
    if not Bloom.isEnabled() then return end

    Bloom.render(void, creeps, towers, projectiles, groundEffects, lobbedProjectiles, lightningProjectiles, blackholes, state.time)
end

-- Draw final composited result
function PostProcessing.drawResult()
    if not state.enabled then
        return
    end

    -- Draw scene canvas
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.sceneCanvas, 0, 0)
    love.graphics.setBlendMode("alpha")

    -- Composite bloom on top (additive)
    if Bloom.isEnabled() then
        Bloom.composite()
    end
end

function PostProcessing.isEnabled()
    return state.enabled
end

function PostProcessing.toggle()
    state.enabled = not state.enabled
    return state.enabled
end

function PostProcessing.setEnabled(enabled)
    state.enabled = enabled
end

-- Get the scene canvas for direct access if needed
function PostProcessing.getSceneCanvas()
    return state.sceneCanvas
end

return PostProcessing
