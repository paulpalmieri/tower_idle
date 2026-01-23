-- src/entities/spawn_portal.lua
-- Spawn Portal entity: smaller portal at center of grid where creeps spawn
-- Part of 2x2 portal pattern, activates progressively with waves

local Object = require("lib.classic")
local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Procedural = require("src.rendering.procedural")
local VoidRenderer = require("src.rendering.void_renderer")

local SpawnPortal = Object:extend()

function SpawnPortal:new(gridX, gridY, index)
    -- Grid position (for reference)
    self.gridX = gridX
    self.gridY = gridY
    self.index = index  -- Portal index (1-4)

    -- World position (calculated from grid)
    local Grid = require("src.world.grid")
    self.x, self.y = Grid.getPortalWorldPosition(index)

    -- Portal state
    self.isActive = false        -- Inactive until wave threshold reached
    self.isGlowing = false       -- True when about to spawn
    self.glowTimer = 0
    self.glowDuration = Config.SPAWN_PORTALS.glowDuration or 1.5

    -- Charging state (portal turns red before spawning)
    self.isCharging = false
    self.chargeTimer = 0
    self.chargeDuration = Config.SPAWN_PORTALS.chargeDuration or 10.0

    -- Current charging spawn data (set by startCharging)
    self.chargingCreepType = nil
    self.chargingHealthMult = 1.0
    self.chargingSpeedMult = 1.0

    -- Visual size (smaller than main void)
    self.size = Config.SPAWN_PORTALS.size or 24

    -- Animation state
    self.time = 0
    self.seed = index * 137 + math.random(1000)

    -- Hover state
    self.isHovered = false
    self.hoverScale = 1.0

    -- Pixel art scale
    self.pixelSize = 2  -- Small pixels for detail

    -- Active spawns (for tear effect rendering)
    self.activeSpawns = {}

    -- Charge growth scale (multiplied with hoverScale for visual growth during charge)
    self.chargeScale = 1.0
    self.maxChargeScale = 1.2  -- Grow to 120% at full charge

    -- Generate pixel pool
    self:generatePixels()
end

-- Generate pixel pool using VoidRenderer
function SpawnPortal:generatePixels()
    local cfg = Config.VOID_PORTAL or {}

    self.pixelPool = VoidRenderer.createPixelPool({
        radius = self.size,
        pixelSize = self.pixelSize,
        seed = self.seed,
        expandFactor = 1.4,
        distortionFrequency = cfg.distortionFrequency or 2.0,
        octaves = cfg.octaves or 3,
        wobbleFrequency = cfg.wobbleFrequency or 3.0,
        wobbleAmount = cfg.wobbleAmount or 0.4,
    })
end

function SpawnPortal:update(dt)
    self.time = self.time + dt

    -- Smoothly interpolate hover scale
    local targetHoverScale = self.isHovered and 1.1 or 1.0
    self.hoverScale = self.hoverScale + (targetHoverScale - self.hoverScale) * dt * 10

    -- Update glow timer
    if self.isGlowing then
        self.glowTimer = self.glowTimer + dt
        if self.glowTimer >= self.glowDuration then
            self.isGlowing = false
            self.glowTimer = 0
        end
    end

    -- Update charging timer and trigger spawn when ready
    if self.isCharging then
        self.chargeTimer = self.chargeTimer + dt

        -- Grow scale during charge (1.0 -> maxChargeScale over charge duration)
        local chargeProgress = self.chargeTimer / self.chargeDuration
        self.chargeScale = 1.0 + (self.maxChargeScale - 1.0) * chargeProgress

        if self.chargeTimer >= self.chargeDuration then
            -- Charge complete - emit spawn ready event
            EventBus.emit("portal_spawn_ready", {
                portalIndex = self.index,
                creepType = self.chargingCreepType,
                healthMultiplier = self.chargingHealthMult,
                speedMultiplier = self.chargingSpeedMult,
            })

            -- Reset charging state
            self.isCharging = false
            self.chargeTimer = 0
            self.chargingCreepType = nil

            -- Reset charge scale
            self.chargeScale = 1.0
        end
    end

    -- Clean up finished spawns
    for i = #self.activeSpawns, 1, -1 do
        local creep = self.activeSpawns[i]
        if creep.dead or not creep:isSpawning() then
            table.remove(self.activeSpawns, i)
        end
    end
end

-- Activate this portal (called when wave threshold reached)
function SpawnPortal:activate()
    if not self.isActive then
        self.isActive = true
        EventBus.emit("portal_activated", { index = self.index })
    end
end

-- Start glowing (about to spawn)
function SpawnPortal:startGlow()
    self.isGlowing = true
    self.glowTimer = 0
end

-- Start charging for a spawn (called by SpawnCoordinator)
function SpawnPortal:startCharging(creepType, healthMultiplier, speedMultiplier)
    if not self.isActive then return false end

    self.isCharging = true
    self.chargeTimer = 0
    self.chargingCreepType = creepType
    self.chargingHealthMult = healthMultiplier or 1.0
    self.chargingSpeedMult = speedMultiplier or 1.0

    return true
end

-- Get charge progress (0-1, used for visuals)
function SpawnPortal:getChargeProgress()
    if not self.isCharging then return 0 end
    return math.min(1, self.chargeTimer / self.chargeDuration)
end

-- Check if portal is currently charging
function SpawnPortal:isCurrentlyCharging()
    return self.isCharging
end

-- Register a spawning creep for tear effect
function SpawnPortal:registerSpawn(creep)
    table.insert(self.activeSpawns, creep)
end

-- Click handler - just increases anger (no gold)
function SpawnPortal:click()
    if not self.isActive then return end

    EventBus.emit("portal_clicked", {
        index = self.index,
        x = self.x,
        y = self.y,
    })
end

-- Set hover state
function SpawnPortal:setHovered(hovered)
    self.isHovered = hovered
end

-- Check if point is inside portal
function SpawnPortal:isPointInside(px, py)
    local dx = px - self.x
    local dy = py - self.y
    return (dx * dx + dy * dy) <= (self.size * self.size)
end

-- Get portal center position
function SpawnPortal:getPosition()
    return self.x, self.y
end

function SpawnPortal:draw()
    if not self.isActive then
        -- Draw inactive portal (dim, minimal)
        self:drawInactive()
        return
    end

    local cfg = Config.VOID_PORTAL or {}
    local baseColors = cfg.colors or {
        core = {0.02, 0.01, 0.05},
        mid = {0.15, 0.08, 0.25},
        edgeGlow = {0.5, 0.25, 0.7},
        sparkle = {0.9, 0.8, 1.0},
    }

    -- Calculate charge-based color transition (purple -> red)
    local chargeProgress = self:getChargeProgress()
    local colors = {}
    if chargeProgress > 0 then
        local chargeColors = Config.SPAWN_PORTALS.chargeColors or {
            start = {0.5, 0.25, 0.7},
            mid = {0.8, 0.3, 0.5},
            ready = {1.0, 0.25, 0.15},
        }
        -- Interpolate edge glow color based on charge progress
        local edgeR, edgeG, edgeB
        if chargeProgress < 0.5 then
            -- Start -> Mid
            local t2 = chargeProgress * 2
            edgeR = chargeColors.start[1] + (chargeColors.mid[1] - chargeColors.start[1]) * t2
            edgeG = chargeColors.start[2] + (chargeColors.mid[2] - chargeColors.start[2]) * t2
            edgeB = chargeColors.start[3] + (chargeColors.mid[3] - chargeColors.start[3]) * t2
        else
            -- Mid -> Ready
            local t2 = (chargeProgress - 0.5) * 2
            edgeR = chargeColors.mid[1] + (chargeColors.ready[1] - chargeColors.mid[1]) * t2
            edgeG = chargeColors.mid[2] + (chargeColors.ready[2] - chargeColors.mid[2]) * t2
            edgeB = chargeColors.mid[3] + (chargeColors.ready[3] - chargeColors.mid[3]) * t2
        end
        -- Also shift core and mid colors slightly toward red
        local redShift = chargeProgress * 0.3
        colors.core = {baseColors.core[1] + redShift * 0.1, baseColors.core[2], baseColors.core[3] * (1 - chargeProgress * 0.3)}
        colors.mid = {baseColors.mid[1] + redShift * 0.2, baseColors.mid[2], baseColors.mid[3] * (1 - chargeProgress * 0.3)}
        colors.edgeGlow = {edgeR, edgeG, edgeB}
        colors.sparkle = {1.0, 0.9 - chargeProgress * 0.2, 0.9 - chargeProgress * 0.3}
    else
        colors = baseColors
    end

    local t = self.time
    local combinedScale = self.hoverScale * self.chargeScale
    local radius = self.size * combinedScale

    -- Glow intensity when about to spawn or charging
    local glowIntensity = 0
    if self.isGlowing then
        local progress = self.glowTimer / self.glowDuration
        glowIntensity = math.sin(progress * math.pi) * 0.5
    end
    -- Add pulsing glow when charging
    if chargeProgress > 0 then
        local chargeGlow = chargeProgress * 0.4 + math.sin(t * 6) * 0.15 * chargeProgress
        glowIntensity = math.max(glowIntensity, chargeGlow)
    end

    -- Draw shadow
    local shadowY = self.y + radius * 0.8
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", self.x, shadowY, radius * 0.8, radius * 0.4)

    -- Calculate glow-based color shift
    local colorShift = nil
    if glowIntensity > 0 then
        colorShift = {glowIntensity * 0.3, glowIntensity * 0.15, glowIntensity * 0.4}
    end

    -- Draw using VoidRenderer
    VoidRenderer.draw(self.pixelPool, {
        x = self.x,
        y = self.y,
        time = self.time,
        scale = combinedScale,
        wobbleSpeed = cfg.wobbleSpeed or 2.0,
        wobbleAmount = cfg.wobbleAmount or 0.4,
        pulseSpeed = 3.0,
        swirlSpeed = 2.0,
        sparkleThreshold = 0.97,
        coreSize = 5,
        colors = colors,
        colorShift = colorShift,
    })
end

-- Draw inactive (dim) portal
function SpawnPortal:drawInactive()
    local ps = self.pixelSize
    local radius = self.size * 0.8

    -- Very dim shadow
    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.ellipse("fill", self.x, self.y + radius * 0.5, radius * 0.6, radius * 0.3)

    -- Draw dim outline only
    local t = self.time
    for _, p in ipairs(self.pixelPool.pixels) do
        local animatedEdgeRadius = radius * 0.75
        if p.dist >= animatedEdgeRadius or p.dist < animatedEdgeRadius - ps * 2 then
            goto continue
        end

        local screenX = math.floor(self.x + p.relX * 0.8 - ps / 2)
        local screenY = math.floor(self.y + p.relY * 0.8 - ps / 2)

        local pulse = math.sin(t * 0.5 + p.angle) * 0.1 + 0.2
        love.graphics.setColor(0.1, 0.05, 0.15, pulse)
        love.graphics.rectangle("fill", screenX, screenY, ps, ps)

        ::continue::
    end
end

-- Get glow parameters for bloom system
function SpawnPortal:getGlowParams()
    if not self.isActive then return nil end

    return {
        x = self.x,
        y = self.y,
        radius = self.size * 1.2,
        color = {0.5, 0.25, 0.7},
        intensity = self.isGlowing and 1.5 or 0.8,
    }
end

return SpawnPortal
