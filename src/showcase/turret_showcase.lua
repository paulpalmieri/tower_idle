-- src/showcase/turret_showcase.lua
-- Procedural Turret Concepts Showcase Scene
-- Launch with: love . --turret-concepts
-- Shows 8 different perspective variations to find the right 2.5D look

local Config = require("src.config")
local Fonts = require("src.rendering.fonts")
local TurretConcepts = require("src.rendering.turret_concepts")

local Showcase = {}

-- =============================================================================
-- STATE
-- =============================================================================

local STATE_IDLE = 1
local STATE_ROTATING = 2
local STATE_SHOOTING = 3

local STATE_NAMES = {
    [STATE_IDLE] = "IDLE",
    [STATE_ROTATING] = "ROTATING",
    [STATE_SHOOTING] = "SHOOTING",
}

local state = {
    currentState = STATE_IDLE,
    time = 0,
    turrets = {},
    targetX = 0,
    targetY = 0,
    targetAngle = 0,
    fireTimer = 0,
}

-- 5 void entity shapes on ancient stone bases
local PERSPECTIVE_VARIANTS = {
    { name = "Void Orb", shape = "orb" },
    { name = "Void Ring", shape = "ring" },
    { name = "Void Bolt", shape = "bolt" },
    { name = "Void Eye", shape = "eye" },
    { name = "Void Star", shape = "star" },
}

-- =============================================================================
-- TURRET INSTANCE
-- =============================================================================

local function createTurret(variantIndex, x, y)
    local variant = PERSPECTIVE_VARIANTS[variantIndex]
    return {
        variantIndex = variantIndex,
        variant = variant,
        x = x,
        y = y,
        rotation = -math.pi / 2,      -- Start pointing up
        targetRotation = -math.pi / 2,
        recoilOffset = 0,
        recoilTimer = 0,
        seed = math.random(1000),
        isFiring = false,
        muzzleFlashTimer = 0,
    }
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

function Showcase.load()
    -- Set up graphics
    love.graphics.setBackgroundColor(Config.SHOWCASE.backgroundColor)
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Initialize fonts
    Fonts.init()

    -- Initialize turret concepts renderer
    TurretConcepts.init()

    -- Create 5 turret instances in a single row
    local screenW = Config.SCREEN_WIDTH
    local screenH = Config.SCREEN_HEIGHT

    local numTurrets = 5
    local spacingX = screenW / (numTurrets + 1)
    local centerY = screenH * 0.45  -- Slightly above center to show levitation

    for i = 1, numTurrets do
        local x = i * spacingX
        local y = centerY
        local turret = createTurret(i, x, y)
        table.insert(state.turrets, turret)
    end

    -- Initialize target position
    state.targetX = screenW / 2
    state.targetY = screenH * 0.3
    state.targetAngle = 0
end

-- =============================================================================
-- UPDATE
-- =============================================================================

local function lerpAngle(from, to, t)
    local diff = to - from
    while diff > math.pi do diff = diff - 2 * math.pi end
    while diff < -math.pi do diff = diff + 2 * math.pi end
    return from + diff * t
end

local function updateTurret(turret, dt)
    -- Update recoil animation
    if turret.recoilTimer > 0 then
        turret.recoilTimer = turret.recoilTimer - dt
        if turret.recoilTimer <= 0 then
            turret.recoilTimer = 0
            turret.recoilOffset = 0
        else
            local progress = turret.recoilTimer / 0.12
            turret.recoilOffset = 3 * progress * progress
        end
    end

    -- Update muzzle flash
    if turret.muzzleFlashTimer > 0 then
        turret.muzzleFlashTimer = turret.muzzleFlashTimer - dt
    end

    -- Smooth rotation toward target
    if state.currentState == STATE_ROTATING or state.currentState == STATE_SHOOTING then
        local dx = state.targetX - turret.x
        local dy = state.targetY - turret.y
        turret.targetRotation = math.atan2(dy, dx)
        turret.rotation = lerpAngle(turret.rotation, turret.targetRotation, dt * 5)
    end
end

local function fireTurret(turret)
    turret.isFiring = true
    turret.recoilOffset = 3
    turret.recoilTimer = 0.12
    turret.muzzleFlashTimer = 0.1
end

function Showcase.update(dt)
    state.time = state.time + dt

    -- Update target position (circular motion)
    if state.currentState == STATE_ROTATING or state.currentState == STATE_SHOOTING then
        state.targetAngle = state.targetAngle + dt * 0.5
        local centerX = Config.SCREEN_WIDTH / 2
        local centerY = Config.SCREEN_HEIGHT * 0.35
        local radius = 150
        state.targetX = centerX + math.cos(state.targetAngle) * radius
        state.targetY = centerY + math.sin(state.targetAngle * 0.7) * radius * 0.3
    end

    -- Update fire timer for shooting state
    if state.currentState == STATE_SHOOTING then
        state.fireTimer = state.fireTimer + dt
        if state.fireTimer >= 1.0 then
            state.fireTimer = 0
            for _, turret in ipairs(state.turrets) do
                fireTurret(turret)
            end
        end
    end

    -- Update individual turrets
    for _, turret in ipairs(state.turrets) do
        updateTurret(turret, dt)
    end
end

-- =============================================================================
-- DRAWING
-- =============================================================================

local function drawControls()
    local font = Fonts.get("medium")
    love.graphics.setFont(font)

    local y = Config.SCREEN_HEIGHT - 50

    -- State indicator
    love.graphics.setColor(0.8, 0.8, 0.8)
    local stateText = "State: " .. STATE_NAMES[state.currentState]
    love.graphics.print(stateText, 40, 20)

    -- Controls
    love.graphics.setColor(0.6, 0.6, 0.6)
    local controls = "[1] Idle   [2] Rotating   [3] Shooting   [SPACE] Fire   [ESC] Exit"
    local controlsWidth = font:getWidth(controls)
    love.graphics.print(controls, (Config.SCREEN_WIDTH - controlsWidth) / 2, y)
end

local function drawTarget()
    if state.currentState == STATE_ROTATING or state.currentState == STATE_SHOOTING then
        local size = 10
        love.graphics.setColor(1, 0.3, 0.3, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.line(state.targetX - size, state.targetY, state.targetX + size, state.targetY)
        love.graphics.line(state.targetX, state.targetY - size, state.targetX, state.targetY + size)
    end
end

local function drawTurretLabel(turret)
    local font = Fonts.get("small")
    love.graphics.setFont(font)

    local name = turret.variant.name
    local textWidth = font:getWidth(name)
    local x = turret.x - textWidth / 2
    local y = turret.y + 55

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(name, x, y)
end

function Showcase.draw()
    -- Draw target
    drawTarget()

    -- Draw turrets (sorted by Y for depth)
    local sortedTurrets = {}
    for _, t in ipairs(state.turrets) do
        table.insert(sortedTurrets, t)
    end
    table.sort(sortedTurrets, function(a, b) return a.y < b.y end)

    for _, turret in ipairs(sortedTurrets) do
        TurretConcepts.drawVariant(
            turret.variantIndex,
            turret.x,
            turret.y,
            turret.rotation,
            turret.recoilOffset,
            state.time,
            turret.seed
        )

        if turret.muzzleFlashTimer > 0 then
            TurretConcepts.drawMuzzleFlashVariant(
                turret.variantIndex,
                turret.x,
                turret.y,
                turret.rotation,
                state.time,
                turret.seed
            )
        end

        drawTurretLabel(turret)
    end

    -- Draw UI
    drawControls()
end

-- =============================================================================
-- INPUT
-- =============================================================================

function Showcase.keypressed(key)
    if key == "1" then
        state.currentState = STATE_IDLE
        for _, turret in ipairs(state.turrets) do
            turret.targetRotation = -math.pi / 2
        end
    elseif key == "2" then
        state.currentState = STATE_ROTATING
    elseif key == "3" then
        state.currentState = STATE_SHOOTING
        state.fireTimer = 0
    elseif key == "space" then
        for _, turret in ipairs(state.turrets) do
            fireTurret(turret)
        end
    elseif key == "escape" then
        love.event.quit()
    end
end

return Showcase
