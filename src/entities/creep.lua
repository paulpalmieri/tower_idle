-- src/entities/creep.lua
-- Void Spawn enemy entity - amorphous shadowy creature from the void
-- Rendered in pixel art style matching the void rift

local Object = require("lib.classic")
local Config = require("src.config")
local Procedural = require("src.rendering.procedural")
local PixelDraw = require("src.rendering.pixel_draw")
local StatusEffects = require("src.systems.status_effects")
local VoidRenderer = require("src.rendering.void_renderer")

local Creep = Object:extend()

-- OPTIMIZATION: Local references to frequently used math functions
local sin, cos, sqrt, floor, ceil, atan2, min, max, abs =
    math.sin, math.cos, math.sqrt, math.floor, math.ceil, math.atan2, math.min, math.max, math.abs
local random = math.random
local pi = math.pi

-- Unique seed counter for each creep instance
local seedCounter = 0

-- Perspective scale for ground elements (from centralized config)
local PERSPECTIVE_Y_SCALE = Config.PERSPECTIVE_Y_SCALE

function Creep:new(x, y, creepType, healthMultiplier, speedMultiplier)
    self.x = x
    self.y = y
    self.creepType = creepType

    local stats = Config.CREEPS[creepType]
    -- Apply health multiplier (later spawns in wave have more HP)
    local hpMult = healthMultiplier or 1.0
    self.maxHp = math.floor(stats.hp * hpMult)
    self.hp = self.maxHp
    -- Apply speed multiplier (tier bonuses)
    local spdMult = speedMultiplier or 1.0
    self.baseSpeed = stats.speed * spdMult
    self.speed = self.baseSpeed      -- Current speed (modified by effects)
    self.reward = stats.reward
    self.color = stats.color
    self.size = stats.size

    self.dead = false
    self.reachedBase = false

    -- Status effects tracking
    self.statusEffects = {}
    self.statusParticles = {}        -- Visual particles for status effects

    -- Spawn animation state
    self.spawnPhase = "tear_open"  -- tear_open → emerging → tear_close → active
    self.spawnTimer = 0
    self.spawnX = x  -- Track spawn position for tear effect
    self.spawnY = y

    -- Animation state for void effects
    self.time = 0
    seedCounter = seedCounter + 1
    self.seed = seedCounter * 17 + random(1000)

    -- Hit feedback
    self.hitFlashTimer = 0
    self.hitParticles = {}

    -- Death animation state
    self.dying = false
    self.deathTimer = 0
    self.deathDuration = 0.4  -- Seconds for death animation

    -- Exit animation state (red rift when reaching base)
    self.exitPhase = nil       -- nil, "tear_open", "devouring", "tear_close", "consumed"
    self.exitTimer = 0
    self.exitX = 0             -- Position where exit tear opens
    self.exitY = 0
    self.exitPortalX = 0       -- Center of exit portal (for pull effect)
    self.exitPortalY = 0

    -- Spider-specific state
    self.distanceTraveled = 0  -- For leg animation phase
    self.lastX = x
    self.lastY = y

    -- Path wobble for natural movement variation
    self.wobbleOffset = {
        x = (random() - 0.5) * 2,  -- -1 to 1
        y = (random() - 0.5) * 2,
    }
    self.wobbleScale = Config.CREEP_WOBBLE_SCALE or 10  -- Pixels of variation

    -- OPTIMIZATION: Cache config reference for this creep type
    if creepType == "voidSpider" then
        self.cfg = Config.VOID_SPIDER
        self.pixelSize = self.cfg.pixelSize or 2
        self:generateSpiderPixels()
    elseif creepType == "voidBoss" then
        self.cfg = Config.VOID_BOSS
        self.pixelSize = self.cfg.pixelSize or 4
        self.isBoss = true
        self:generatePixelPool()  -- Uses VoidRenderer
    elseif creepType == "redBoss" then
        self.cfg = Config.RED_BOSS
        self.pixelSize = self.cfg.pixelSize or 4
        self.isBoss = true
        self.isRedBoss = true
        self:generatePixelPool()  -- Uses VoidRenderer
    else
        self.cfg = Config.VOID_SPAWN
        self.pixelSize = self.cfg.pixelSize or 3
        self:generatePixelPool()  -- Uses VoidRenderer
    end
end

-- Generate pixel pool using VoidRenderer (for blob-style creeps)
function Creep:generatePixelPool()
    local cfg = self.cfg

    self.pixelPool = VoidRenderer.createPixelPool({
        radius = self.size,
        pixelSize = self.pixelSize,
        seed = self.seed,
        expandFactor = 1.3,
        distortionFrequency = cfg.distortionFrequency,
        octaves = cfg.octaves,
        wobbleFrequency = cfg.wobbleFrequency,
        wobbleAmount = cfg.wobbleAmount,
    })
end

-- Generate pixel pool for spider variant (elongated rift body + void shard legs)
-- OPTIMIZED: Pre-computes wobble phase for each pixel
function Creep:generateSpiderPixels()
    self.bodyPixels = {}
    self.legPixels = {}
    local ps = self.pixelSize
    local cfg = Config.VOID_SPIDER
    local bodySize = self.size

    -- Elongated rift body dimensions (gash style)
    local bodyWidth = bodySize * cfg.body.width
    local bodyHeight = bodySize * cfg.body.height

    -- Generate body pixels (elongated ellipse - rift shape)
    -- Using integer grid positions for pixel-perfect rendering
    local expandedH = bodyHeight * 1.3
    local expandedW = bodyWidth * 1.3
    local gridH = ceil(expandedH * 2 / ps)
    local gridW = ceil(expandedW * 2 / ps)

    for py = 0, gridH - 1 do
        for px = 0, gridW - 1 do
            -- Grid position relative to body center (in pixel units, integers)
            local gridX = px - floor(gridW / 2)
            local gridY = py - floor(gridH / 2)

            -- Use center of pixel for shape test
            local testX = (gridX + 0.5) * ps
            local testY = (gridY + 0.5) * ps

            -- Ellipse distance (normalized so edge = 1)
            local normX = testX / bodyWidth
            local normY = testY / bodyHeight
            local ellipseDist = sqrt(normX * normX + normY * normY)

            if ellipseDist < 1.3 then
                local angle = atan2(testY, testX)

                local baseEdgeNoise = Procedural.fbm(
                    cos(angle) * cfg.distortionFrequency,
                    sin(angle) * cfg.distortionFrequency,
                    self.seed,
                    cfg.octaves
                )

                -- Pre-compute wobble phase offset (OPTIMIZATION)
                local wobblePhase = Procedural.fbm(
                    angle * cfg.wobbleFrequency,
                    0,
                    self.seed + 500,
                    2
                ) * pi * 2

                table.insert(self.bodyPixels, {
                    -- Grid offset from body center (integer pixel units)
                    gridX = gridX,
                    gridY = gridY,
                    -- World-relative position
                    relX = testX,
                    relY = testY,
                    px = px,
                    py = py,
                    angle = angle,
                    dist = ellipseDist,
                    distNorm = ellipseDist,  -- Already normalized (edge = 1)
                    baseEdgeNoise = baseEdgeNoise,
                    wobblePhase = wobblePhase,
                    rnd = Procedural.hash(px, py, self.seed + 888),
                    rnd2 = Procedural.hash(px * 2.1, py * 1.7, self.seed + 777),
                })
            end
        end
    end

    -- Generate leg pixels (4 void shard chunks) - pixel-perfect grid placement
    -- Each leg is a pre-generated chunk that moves as a unit (no subpixel positions)
    local legLen = bodySize * cfg.legs.length
    local legWidth = legLen * cfg.legs.width
    local legAngle = cfg.legs.angle  -- Fixed angle for all variants
    local legGap = bodySize * cfg.legs.gap

    -- Snap leg anchor positions to pixel grid
    local legGapSnapped = floor(legGap / ps + 0.5) * ps
    local legOffsetY = floor(bodyHeight * 0.4 / ps + 0.5) * ps

    -- Leg positions:  \ | /   (legs angle outward from body)
    --                 \ | /
    -- ox/oy are now snapped to pixel grid
    local legDefs = {
        {ox = -legGapSnapped, oy = -legOffsetY, angle = legAngle},   -- front-left \
        {ox = legGapSnapped,  oy = -legOffsetY, angle = -legAngle},  -- front-right /
        {ox = -legGapSnapped, oy = legOffsetY,  angle = legAngle},   -- back-left \
        {ox = legGapSnapped,  oy = legOffsetY,  angle = -legAngle},  -- back-right /
    }

    for legIdx, legDef in ipairs(legDefs) do
        -- Generate shard shape (elongated void chunk)
        -- Grid dimensions in whole pixels
        local gridLegH = ceil(legLen * 1.4 / ps)
        local gridLegW = ceil(legWidth * 1.4 / ps)

        -- Pre-compute rotation matrix
        local cosA = cos(legDef.angle)
        local sinA = sin(legDef.angle)

        for py = 0, gridLegH - 1 do
            for px = 0, gridLegW - 1 do
                -- Grid position relative to leg center (in pixel units, integers)
                local gridX = px - floor(gridLegW / 2)
                local gridY = py - floor(gridLegH / 2)

                -- Check if this grid cell is within the shard shape
                -- Use center of pixel for shape test
                local testX = (gridX + 0.5) * ps
                local testY = (gridY + 0.5) * ps
                local normX = testX / (legWidth * 0.5)
                local normY = testY / (legLen * 0.5)
                local shardDist = sqrt(normX * normX + normY * normY)

                if shardDist < 1.2 then
                    -- Apply rotation to get final grid offset (still in pixel units)
                    -- Rotate the grid offset, then snap to nearest pixel
                    local rotGridX = floor(gridX * cosA - gridY * sinA + 0.5)
                    local rotGridY = floor(gridX * sinA + gridY * cosA + 0.5)

                    local angle = atan2(testY, testX)
                    local baseEdgeNoise = Procedural.fbm(
                        cos(angle) * cfg.distortionFrequency,
                        sin(angle) * cfg.distortionFrequency,
                        self.seed + legIdx * 100,
                        cfg.octaves
                    )

                    -- Pre-compute wobble phase offset (OPTIMIZATION)
                    local wobblePhase = Procedural.fbm(
                        angle * cfg.wobbleFrequency,
                        0,
                        self.seed + legIdx * 100 + 500,
                        2
                    ) * pi * 2

                    table.insert(self.legPixels, {
                        legIdx = legIdx,
                        -- Leg anchor (already snapped to pixel grid)
                        ox = legDef.ox,
                        oy = legDef.oy,
                        -- Grid offset within leg (integer pixel units)
                        gridX = rotGridX,
                        gridY = rotGridY,
                        -- For sparkle hash
                        px = px + legIdx * 20,
                        py = py,
                        angle = angle,
                        dist = shardDist,
                        baseEdgeNoise = baseEdgeNoise,
                        wobblePhase = wobblePhase,
                        rnd = Procedural.hash(px + legIdx * 20, py, self.seed + 888),
                        rnd2 = Procedural.hash(px * 2.1 + legIdx, py * 1.7, self.seed + 777),
                    })
                end
            end
        end
    end
end

-- Easing function for smooth emergence
local function _easeOutQuad(t)
    return t * (2 - t)
end

-- Update spawn animation state machine
function Creep:updateSpawnAnimation(dt)
    local cfg = Config.SPAWN_ANIMATION

    self.spawnTimer = self.spawnTimer + dt

    if self.spawnPhase == "tear_open" then
        if self.spawnTimer >= cfg.tearOpenDuration then
            self.spawnPhase = "emerging"
            self.spawnTimer = 0
        end
    elseif self.spawnPhase == "emerging" then
        if self.spawnTimer >= cfg.emergeDuration then
            self.spawnPhase = "tear_close"
            self.spawnTimer = 0
        end
    elseif self.spawnPhase == "tear_close" then
        if self.spawnTimer >= cfg.tearCloseDuration then
            self.spawnPhase = "active"
            self.spawnTimer = 0
        end
    end
end

-- Check if creep is still spawning
function Creep:isSpawning()
    return self.spawnPhase ~= "active"
end

-- Get progress of current tear phase (0-1)
function Creep:getTearProgress()
    local cfg = Config.SPAWN_ANIMATION

    if self.spawnPhase == "tear_open" then
        return self.spawnTimer / cfg.tearOpenDuration
    elseif self.spawnPhase == "emerging" then
        return 1.0  -- Tear fully open during emergence
    elseif self.spawnPhase == "tear_close" then
        return 1.0 - (self.spawnTimer / cfg.tearCloseDuration)
    else
        return 0  -- No tear when active
    end
end

-- Get emergence progress (0-1) for scaling/alpha
function Creep:getEmergenceProgress()
    local cfg = Config.SPAWN_ANIMATION

    if self.spawnPhase == "tear_open" then
        return 0
    elseif self.spawnPhase == "emerging" then
        return _easeOutQuad(self.spawnTimer / cfg.emergeDuration)
    else
        return 1.0
    end
end

-- Start the exit animation (called when creep reaches edge)
-- For edge-based escape, just fade out in place (no portal pull)
function Creep:startExitAnimation(edgeX, edgeY)
    self.exitPhase = "fading"
    self.exitTimer = 0
    self.exitX = self.x
    self.exitY = self.y
    -- Store edge position (for potential rift effect)
    self.exitPortalX = edgeX or self.x
    self.exitPortalY = edgeY or self.y
end

-- Update exit animation - simple fade out at edge
function Creep:updateExitAnimation(dt)
    local fadeDuration = 0.3  -- Quick fade animation

    self.exitTimer = self.exitTimer + dt

    if self.exitPhase == "fading" then
        if self.exitTimer >= fadeDuration then
            self.exitPhase = "consumed"
            self.reachedBase = true  -- Keep this flag name for event compatibility
            self.dead = true
        end
    end
end

-- Check if creep is in exit animation
function Creep:isExiting()
    return self.exitPhase ~= nil and self.exitPhase ~= "consumed"
end

-- Get progress of current exit tear phase (0-1) - no longer used for tears
function Creep:getExitTearProgress()
    return 0
end

-- Get devouring progress (0-1) for visual fade/shrink during exit
function Creep:getDevouringProgress()
    if self.exitPhase ~= "fading" then return 0 end
    local fadeDuration = 0.3
    return _easeOutQuad(math.min(1, self.exitTimer / fadeDuration))
end

function Creep:update(dt, grid, flowField)
    -- Update animation time
    self.time = self.time + dt

    -- Update hit flash timer
    if self.hitFlashTimer > 0 then
        self.hitFlashTimer = self.hitFlashTimer - dt
    end

    -- Update hit particles (simple linear movement)
    for i = #self.hitParticles, 1, -1 do
        local p = self.hitParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.hitParticles, i)
        end
    end

    -- Update status effect particles
    for i = #self.statusParticles, 1, -1 do
        local p = self.statusParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.statusParticles, i)
        end
    end

    -- Update status effects and apply DOT damage
    local dotDamage = StatusEffects.update(self, dt)
    if dotDamage > 0 and not self.dead and not self.dying then
        self.hp = self.hp - dotDamage
        if self.hp <= 0 and not self.dying then
            self.dying = true
            self.deathTimer = 0
        end
    end

    -- Update speed based on slow effects
    local speedMult = StatusEffects.getSpeedMultiplier(self)
    self.speed = self.baseSpeed * speedMult

    -- Spawn status effect particles
    self:spawnStatusParticles(dt)

    -- Don't move if dead (but particles still update above)
    if self.dead then return end

    -- Handle death animation
    if self.dying then
        self.deathTimer = self.deathTimer + dt
        if self.deathTimer >= self.deathDuration then
            self.dead = true
        end
        return  -- Don't move during death animation
    end

    -- Handle spawn animation
    if self:isSpawning() then
        self:updateSpawnAnimation(dt)
        return  -- Don't move during spawn animation
    end

    -- Handle exit animation
    if self:isExiting() then
        self:updateExitAnimation(dt)
        return  -- Don't move during exit animation
    end

    -- Get current grid position
    local gridX, gridY = grid.screenToGrid(self.x, self.y)
    local cols = grid.getCols()
    local rows = grid.getRows()

    -- Get flow direction for current cell
    local flow = flowField[gridY] and flowField[gridY][gridX]

    local targetX, targetY

    -- Follow flow field toward nearest edge
    if flow and (flow.dx ~= 0 or flow.dy ~= 0) then
        -- Follow flow field - calculate target cell center
        local targetGridX = gridX + flow.dx
        local targetGridY = gridY + flow.dy

        -- Safety check: ensure target cell is walkable (not a tower)
        local cells = grid.getCells()
        if cells[targetGridY] and cells[targetGridY][targetGridX] ~= 1 then
            targetX, targetY = grid.gridToScreen(targetGridX, targetGridY)
            -- Apply per-creep wobble offset for natural movement variation
            targetX = targetX + self.wobbleOffset.x * self.wobbleScale
            targetY = targetY + self.wobbleOffset.y * self.wobbleScale
        else
            -- Target is blocked, stay in current cell center (flow field will be recomputed)
            targetX, targetY = grid.gridToScreen(gridX, gridY)
        end
    elseif grid.isValidCell(gridX, gridY) then
        -- On grid but no flow (at edge or blocked) - try to reach nearest edge
        local edgeX, edgeY = grid.getNearestEdge(gridX, gridY)
        targetX, targetY = grid.gridToScreen(edgeX, edgeY)
    else
        -- Outside grid bounds - find nearest valid cell on grid and move toward it
        local clampedX = max(1, min(cols, gridX))
        local clampedY = max(1, min(rows, gridY))
        targetX, targetY = grid.gridToScreen(clampedX, clampedY)
    end

    -- Move toward target
    local toTargetX = targetX - self.x
    local toTargetY = targetY - self.y
    local dist = math.sqrt(toTargetX * toTargetX + toTargetY * toTargetY)

    if dist > 0 then
        local moveX = (toTargetX / dist) * self.speed * dt
        local moveY = (toTargetY / dist) * self.speed * dt

        -- Don't overshoot
        if math.abs(moveX) > math.abs(toTargetX) then moveX = toTargetX end
        if math.abs(moveY) > math.abs(toTargetY) then moveY = toTargetY end

        self.x = self.x + moveX
        self.y = self.y + moveY

        -- Track distance traveled for spider leg animation
        if self.creepType == "voidSpider" then
            local dx = self.x - self.lastX
            local dy = self.y - self.lastY
            self.distanceTraveled = self.distanceTraveled + math.sqrt(dx * dx + dy * dy)
            self.lastX = self.x
            self.lastY = self.y
        end
    end
end

function Creep:takeDamage(amount, bulletAngle)
    self.hp = self.hp - amount

    -- Trigger hit flash
    local hitCfg = Config.CREEP_HIT
    self.hitFlashTimer = hitCfg.flashDuration

    -- Spawn hit particles spraying in bullet direction (behind the creep)
    -- If no angle provided, fall back to radial scatter
    local baseAngle = bulletAngle or 0
    local hasDirection = bulletAngle ~= nil

    for i = 1, hitCfg.particleCount do
        local angle
        if hasDirection then
            -- Spray particles in a cone in the bullet's direction (impact spray)
            -- Particles fly "through" the creep in the bullet direction
            local spread = hitCfg.particleSpread or 0.8  -- ~45 degrees spread
            local offset = (i / hitCfg.particleCount - 0.5) * spread
            angle = baseAngle + offset + (math.random() - 0.5) * 0.3
        else
            -- Fallback: radial scatter
            angle = (i / hitCfg.particleCount) * math.pi * 2
        end

        local speed = hitCfg.particleSpeed * (0.8 + math.random() * 0.4)
        table.insert(self.hitParticles, {
            x = self.x,
            y = self.y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = hitCfg.particleLife,
            maxLife = hitCfg.particleLife,
            size = hitCfg.particleSize,
        })
    end

    if self.hp <= 0 and not self.dying then
        self.dying = true
        self.deathTimer = 0
    end
end

-- Check if creep can be removed (dead and no active particles)
function Creep:canRemove()
    return self.dead and #self.hitParticles == 0 and #self.statusParticles == 0
end

-- Spawn visual particles for active status effects
function Creep:spawnStatusParticles(dt)
    if self.dead or self.dying then return end
    if self:isSpawning() then return end

    -- Poison: green wisps floating up
    if StatusEffects.hasEffect(self, StatusEffects.POISON) then
        if math.random() < dt * 8 then  -- ~8 particles per second
            local angle = math.random() * math.pi * 2
            local dist = math.random() * self.size * 0.7
            table.insert(self.statusParticles, {
                x = self.x + math.cos(angle) * dist,
                y = self.y + math.sin(angle) * dist,
                vx = (math.random() - 0.5) * 15,
                vy = -20 - math.random() * 15,
                life = 0.4 + math.random() * 0.3,
                maxLife = 0.6,
                size = 2 + math.random() * 2,
                effectType = StatusEffects.POISON,
            })
        end
    end

    -- Burn: flame particles
    if StatusEffects.hasEffect(self, StatusEffects.BURN) then
        if math.random() < dt * 10 then  -- ~10 particles per second
            local angle = math.random() * math.pi * 2
            local dist = math.random() * self.size * 0.6
            table.insert(self.statusParticles, {
                x = self.x + math.cos(angle) * dist,
                y = self.y + math.sin(angle) * dist,
                vx = (math.random() - 0.5) * 20,
                vy = -30 - math.random() * 20,
                life = 0.3 + math.random() * 0.2,
                maxLife = 0.4,
                size = 2 + math.random() * 3,
                effectType = StatusEffects.BURN,
            })
        end
    end
end

-- Check if creep is in dying animation
function Creep:isDying()
    return self.dying and not self.dead
end

-- Get death animation progress (0 = just died, 1 = fully dead)
function Creep:getDeathProgress()
    if not self.dying then return 0 end
    return math.min(1, self.deathTimer / self.deathDuration)
end

function Creep:draw()
    -- Draw hit particles (glowing purple sparks that fade)
    for _, p in ipairs(self.hitParticles) do
        local alpha = p.life / p.maxLife
        -- Glow effect
        love.graphics.setColor(0.6, 0.3, 0.8, alpha * 0.4)
        love.graphics.circle("fill", p.x, p.y, p.size * 2)
        -- Core spark
        love.graphics.setColor(0.95, 0.85, 1.0, alpha)
        PixelDraw.rect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size)
    end

    -- Draw status effect particles
    for _, p in ipairs(self.statusParticles) do
        local alpha = p.life / p.maxLife
        local effectCfg = Config.STATUS_EFFECTS[p.effectType]
        if effectCfg then
            local color = effectCfg.color
            -- Glow
            love.graphics.setColor(color[1], color[2], color[3], alpha * 0.3)
            love.graphics.circle("fill", p.x, p.y, p.size * 1.5)
            -- Core
            love.graphics.setColor(color[1], color[2], color[3], alpha * 0.8)
            PixelDraw.rect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size)
        end
    end

    -- Don't draw body if dead (only particles above)
    if self.dead then return end

    -- Skip drawing during tear_open phase (only tear is visible)
    if self.spawnPhase == "tear_open" then
        return
    end

    -- Route to spider-specific drawing
    if self.creepType == "voidSpider" then
        self:drawSpider()
        return
    end

    -- OPTIMIZATION: Use cached config
    local cfg = self.cfg
    local colors = cfg.colors
    local ps = self.pixelSize
    local t = self.time

    -- Calculate scale and alpha for emergence
    local emergence = self:getEmergenceProgress()
    local scale = emergence
    local alpha = 0.5 + emergence * 0.5  -- 0.5 -> 1.0

    -- Death animation: fade out and collapse
    local deathProgress = self:getDeathProgress()
    local deathFade = 1.0 - deathProgress  -- 1 -> 0
    local deathSquashY = 1.0 - deathProgress * 0.4  -- 1 -> 0.6 (collapse vertically)
    local deathDesaturate = deathProgress * 0.6  -- 0 -> 0.6 (gray out colors)

    alpha = alpha * deathFade
    scale = scale * (1.0 - deathProgress * 0.2)  -- Slight shrink

    -- Exit animation: fade and shrink during devouring
    local devouringProgress = self:getDevouringProgress()
    if devouringProgress > 0 then
        alpha = alpha * (1.0 - devouringProgress * 0.8)  -- Fade out
        scale = scale * (1.0 - devouringProgress * 0.5)  -- Shrink
    end

    -- Skip if fully invisible
    if scale <= 0 or alpha <= 0.01 then return end

    -- Draw shadow (ground feel) with perspective
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, 0.35)
    local shadowSize = self.size * 1.2
    local shadowWidth = shadowSize
    local shadowHeight = shadowSize * PERSPECTIVE_Y_SCALE
    local shadowY = self.y + self.size * 1.3
    love.graphics.ellipse("fill", self.x, shadowY, shadowWidth, shadowHeight)

    -- Check for slow effect - will apply blue glow tint
    local hasSlowEffect = StatusEffects.hasEffect(self, StatusEffects.SLOW) and not self:isSpawning()
    local slowColorShift = nil
    if hasSlowEffect then
        local slowColor = Config.STATUS_EFFECTS.slow.color
        local slowGlowIntensity = 0.25 + sin(t * 4) * 0.1
        -- Convert to color shift format
        slowColorShift = {
            (slowColor[1] - 0.5) * slowGlowIntensity,
            (slowColor[2] - 0.5) * slowGlowIntensity,
            (slowColor[3] - 0.5) * slowGlowIntensity,
        }
    end

    -- Calculate flash intensity from hit timer
    local flashIntensity = 0
    if self.hitFlashTimer > 0 then
        flashIntensity = (self.hitFlashTimer / Config.CREEP_HIT.flashDuration) * 0.8
    end

    -- Draw using VoidRenderer
    VoidRenderer.draw(self.pixelPool, {
        x = self.x,
        y = self.y,
        time = self.time,
        scale = scale,
        alpha = alpha,
        wobbleSpeed = cfg.wobbleSpeed,
        wobbleAmount = cfg.wobbleAmount,
        pulseSpeed = cfg.pulseSpeed,
        swirlSpeed = cfg.swirlSpeed,
        sparkleThreshold = cfg.sparkleThreshold or 0.96,
        coreSize = cfg.coreSize or 5,
        colors = colors,
        flashIntensity = flashIntensity,
        colorShift = slowColorShift,
        desaturate = deathDesaturate,
        squashY = deathSquashY,
    })

    -- Draw pixel art health bar when damaged (only when fully spawned)
    if self.hp < self.maxHp and not self:isSpawning() then
        local barPixels = 10
        local barWidth = barPixels * ps
        local barX = self.x - barWidth / 2
        local barY = self.y - self.size - ps * 2
        local healthPercent = self.hp / self.maxHp

        -- Background pixels (dark void)
        love.graphics.setColor(0.05, 0.02, 0.08)
        for i = 0, barPixels - 1 do
            PixelDraw.rect(barX + i * ps, barY, ps, ps)
        end

        -- Health fill pixels with gradient
        local filledPixels = math.ceil(healthPercent * barPixels)
        for i = 0, filledPixels - 1 do
            local barT = i / barPixels
            love.graphics.setColor(0.5 + barT * 0.2, 0.1, 0.6 + barT * 0.2)
            PixelDraw.rect(barX + i * ps, barY, ps, ps)
        end
    end
end

-- Draw spider variant with elongated rift body and void-textured legs
-- Layout:  / | \     <- floating void-chunk legs
--          / | \
function Creep:drawSpider()
    -- OPTIMIZATION: Use cached config
    local cfg = self.cfg
    local colors = cfg.colors
    local ps = self.pixelSize
    local t = self.time

    -- Calculate scale and alpha for emergence
    local emergence = self:getEmergenceProgress()
    local scale = emergence
    local alpha = 0.5 + emergence * 0.5

    -- Death animation
    local deathProgress = self:getDeathProgress()
    local deathFade = 1.0 - deathProgress
    local deathSquashY = 1.0 - deathProgress * 0.4
    local deathDesaturate = deathProgress * 0.6

    alpha = alpha * deathFade
    scale = scale * (1.0 - deathProgress * 0.2)

    -- Exit animation
    local devouringProgress = self:getDevouringProgress()
    if devouringProgress > 0 then
        alpha = alpha * (1.0 - devouringProgress * 0.8)
        scale = scale * (1.0 - devouringProgress * 0.5)
    end

    if scale <= 0 or alpha <= 0.01 then return end

    -- Check for slow effect - will apply blue glow tint to all pixels
    local hasSlowEffect = StatusEffects.hasEffect(self, StatusEffects.SLOW) and not self:isSpawning()
    local slowGlowIntensity = 0
    local slowColor = nil
    if hasSlowEffect then
        slowColor = Config.STATUS_EFFECTS.slow.color
        -- Pulsing glow intensity
        slowGlowIntensity = 0.25 + sin(t * 4) * 0.1
    end

    -- Draw shadow
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, 0.3 * alpha)
    local shadowW = self.size * cfg.body.width * 2.5 * scale
    local shadowH = self.size * 0.4 * scale
    love.graphics.ellipse("fill", self.x, self.y + self.size * 1.2, shadowW, shadowH)

    -- Leg animation phase
    local legCfg = cfg.legs
    local bobPhase = self.distanceTraveled * 0.1 * legCfg.bobSpeed

    -- OPTIMIZATION: Pre-compute time-based values
    local wobbleTime = t * cfg.wobbleSpeed
    local sparkleTimeX = math.floor(t * 8)
    local sparkleTimeY = math.floor(t * 5)

    -- Draw legs first (behind body) - pixel-perfect grid placement
    -- Legs are rendered as chunks: each leg moves as a unit with no subpixel positions
    local legPhases = {0, pi * 0.5, pi, pi * 1.5}

    -- Snap creep position to pixel grid for consistent leg placement
    local creepSnapX = floor(self.x / ps + 0.5) * ps
    local creepSnapY = floor(self.y / ps + 0.5) * ps

    -- Pre-calculate pixel size in screen space (snapped)
    local pixelW = floor(ps * scale + 0.5)
    local pixelH = floor(ps * scale * deathSquashY + 0.5)
    if pixelH < 1 then pixelH = 1 end
    if pixelW < 1 then pixelW = 1 end

    for _, lp in ipairs(self.legPixels) do
        -- Snap bob offset to whole pixels
        local rawBob = sin(bobPhase + legPhases[lp.legIdx]) * legCfg.bobAmount
        local bob = floor(rawBob + 0.5) * floor(scale + 0.5)

        local wobbleNoise = sin(wobbleTime + lp.wobblePhase) * 0.5 + 0.5
        local animatedEdge = 1.0 + lp.baseEdgeNoise * 0.2 + wobbleNoise * cfg.wobbleAmount * 0.2

        if lp.dist >= animatedEdge then
            goto continue_leg
        end

        local isEdge = lp.dist > animatedEdge - 0.3

        -- Screen position: all components are pixel-snapped
        -- creepSnapX/Y: snapped creep position
        -- lp.ox/oy: already snapped leg anchor (from generation)
        -- lp.gridX/Y: integer grid offsets (in pixel units)
        -- bob: snapped bob offset
        local screenX = floor(creepSnapX + lp.ox * scale + lp.gridX * pixelW)
        local screenY = floor(creepSnapY + lp.oy * scale * deathSquashY + lp.gridY * pixelH + bob)

        local r, g, b

        local sparkle = Procedural.hash(lp.px + sparkleTimeX, lp.py + sparkleTimeY, self.seed + 333)
        if sparkle > cfg.sparkleThreshold then
            r, g, b = colors.sparkle[1], colors.sparkle[2], colors.sparkle[3]
        elseif isEdge then
            local pulse = math.sin(t * cfg.pulseSpeed + lp.angle * 2) * 0.3 + 0.7
            r = colors.edgeGlow[1] * pulse
            g = colors.edgeGlow[2] * pulse
            b = colors.edgeGlow[3] * pulse
        else
            -- Interior (dark - legs are small so no core check needed)
            local v = lp.rnd * 0.3 + lp.dist * 0.3
            r = colors.core[1] + (colors.mid[1] - colors.core[1]) * v
            g = colors.core[2] + (colors.mid[2] - colors.core[2]) * v
            b = colors.core[3] + (colors.mid[3] - colors.core[3]) * v
        end

        -- Hit flash
        if self.hitFlashTimer > 0 then
            local flash = self.hitFlashTimer / Config.CREEP_HIT.flashDuration
            r, g, b = r + flash * 0.8, g + flash * 0.8, b + flash * 0.6
        end

        -- Death desaturation
        if deathDesaturate > 0 then
            local gray = (r + g + b) / 3
            r = r + (gray - r) * deathDesaturate
            g = g + (gray - g) * deathDesaturate
            b = b + (gray - b) * deathDesaturate
        end

        -- Apply slow effect blue glow tint
        if hasSlowEffect then
            r = r + (slowColor[1] - r) * slowGlowIntensity
            g = g + (slowColor[2] - g) * slowGlowIntensity
            b = b + (slowColor[3] - b) * slowGlowIntensity
        end

        love.graphics.setColor(r * alpha, g * alpha, b * alpha, alpha)
        PixelDraw.rect(screenX, screenY, pixelW, pixelH)

        ::continue_leg::
    end

    -- Draw body pixels (elongated rift) - pixel-perfect grid placement
    local coreSize = cfg.coreSize or 4
    for _, p in ipairs(self.bodyPixels) do
        local wobbleNoise = sin(wobbleTime + p.wobblePhase) * 0.5 + 0.5
        local animatedEdge = 1.0 + p.baseEdgeNoise * 0.15 + wobbleNoise * cfg.wobbleAmount * 0.15

        if p.dist >= animatedEdge then
            goto continue_body
        end

        local isEdge = p.dist > animatedEdge - 0.25

        -- Screen position: all components are pixel-snapped
        -- creepSnapX/Y: snapped creep position (already calculated for legs)
        -- p.gridX/Y: integer grid offsets (in pixel units)
        local screenX = floor(creepSnapX + p.gridX * pixelW)
        local screenY = floor(creepSnapY + p.gridY * pixelH)

        -- Check if in squared core region (pitch black center)
        -- gridX/gridY are in pixel units, coreSize is in pixels
        local inCore = abs(p.gridX) < coreSize and abs(p.gridY) < coreSize

        local r, g, b

        -- Sparkles
        local sparkle = Procedural.hash(p.px + sparkleTimeX, p.py + sparkleTimeY, self.seed + 333)
        if sparkle > cfg.sparkleThreshold then
            r, g, b = colors.sparkle[1], colors.sparkle[2], colors.sparkle[3]
        elseif inCore then
            -- Deep void core (pitch black)
            local n = Procedural.hash(p.px + floor(t * 2), p.py, self.seed) * 0.01
            r = colors.core[1] + n
            g = colors.core[2] + n * 0.5
            b = colors.core[3] + n
        elseif isEdge then
            local pulse = math.sin(t * cfg.pulseSpeed + p.angle * 2) * 0.3 + 0.7
            r = colors.edgeGlow[1] * pulse
            g = colors.edgeGlow[2] * pulse
            b = colors.edgeGlow[3] * pulse
        else
            -- Interior (dark purple)
            local swirl = math.sin(p.angle * 3 + t * cfg.swirlSpeed + p.dist * 4) * 0.5 + 0.5
            local v = p.rnd * 0.3 + swirl * 0.2 + p.dist * 0.3
            r = colors.core[1] + (colors.mid[1] - colors.core[1]) * v
            g = colors.core[2] + (colors.mid[2] - colors.core[2]) * v
            b = colors.core[3] + (colors.mid[3] - colors.core[3]) * v
        end

        -- Hit flash
        if self.hitFlashTimer > 0 then
            local flash = self.hitFlashTimer / Config.CREEP_HIT.flashDuration
            r, g, b = r + flash * 0.8, g + flash * 0.8, b + flash * 0.6
        end

        -- Death desaturation
        if deathDesaturate > 0 then
            local gray = (r + g + b) / 3
            r = r + (gray - r) * deathDesaturate
            g = g + (gray - g) * deathDesaturate
            b = b + (gray - b) * deathDesaturate
        end

        -- Apply slow effect blue glow tint
        if hasSlowEffect then
            r = r + (slowColor[1] - r) * slowGlowIntensity
            g = g + (slowColor[2] - g) * slowGlowIntensity
            b = b + (slowColor[3] - b) * slowGlowIntensity
        end

        love.graphics.setColor(r * alpha, g * alpha, b * alpha, alpha)
        PixelDraw.rect(screenX, screenY, pixelW, pixelH)

        ::continue_body::
    end

    -- Health bar when damaged
    if self.hp < self.maxHp and not self:isSpawning() then
        local barPixels = 8
        local barWidth = barPixels * ps
        local barX = self.x - barWidth / 2
        local barY = self.y - self.size * 1.8
        local healthPct = self.hp / self.maxHp

        love.graphics.setColor(0.05, 0.02, 0.08)
        for i = 0, barPixels - 1 do
            PixelDraw.rect(barX + i * ps, barY, ps, ps)
        end

        local filled = math.ceil(healthPct * barPixels)
        for i = 0, filled - 1 do
            love.graphics.setColor(0.5 + i/barPixels * 0.2, 0.1, 0.6 + i/barPixels * 0.2)
            PixelDraw.rect(barX + i * ps, barY, ps, ps)
        end
    end
end

-- Get glow parameters for the bloom system
function Creep:getGlowParams()
    -- Don't emit glow if dead or still in spawn animation
    if self.dead then return nil end
    if self:isSpawning() then return nil end

    local postCfg = Config.POST_PROCESSING

    return {
        x = self.x,
        y = self.y,
        radius = postCfg.radii.creep or (self.size * 1.5),
        color = postCfg.colors.creep or {0.6, 0.3, 0.8},
        intensity = 1.0,
    }
end

-- Alias for backward compatibility
Creep.getLightParams = Creep.getGlowParams

return Creep
