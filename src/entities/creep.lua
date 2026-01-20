-- src/entities/creep.lua
-- Void Spawn enemy entity - amorphous shadowy creature from the void
-- Rendered in pixel art style matching the void rift

local Object = require("lib.classic")
local Config = require("src.config")
local Procedural = require("src.rendering.procedural")
local PixelDraw = require("src.rendering.pixel_draw")
local StatusEffects = require("src.systems.status_effects")

local Creep = Object:extend()

-- OPTIMIZATION: Local references to frequently used math functions
local sin, cos, sqrt, floor, ceil, atan2, min, max, abs =
    math.sin, math.cos, math.sqrt, math.floor, math.ceil, math.atan2, math.min, math.max, math.abs
local random = math.random
local pi = math.pi

-- Unique seed counter for each creep instance
local seedCounter = 0

-- Perspective scale for ground elements (must match ground_effects.lua)
local PERSPECTIVE_Y_SCALE = 0.9

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

    -- OPTIMIZATION: Cache config reference for this creep type
    if creepType == "voidSpider" then
        self.cfg = Config.VOID_SPIDER
        self.pixelSize = self.cfg.pixelSize or 2
        self:generateSpiderPixels()
    elseif creepType == "voidBoss" then
        self.cfg = Config.VOID_BOSS
        self.pixelSize = self.cfg.pixelSize or 4
        self.isBoss = true
        self:generatePixels()  -- Uses same generation as voidSpawn but with boss config
    elseif creepType == "redBoss" then
        self.cfg = Config.RED_BOSS
        self.pixelSize = self.cfg.pixelSize or 4
        self.isBoss = true
        self.isRedBoss = true
        self:generatePixels()  -- Uses same generation as voidSpawn but with red boss config
    else
        self.cfg = Config.VOID_SPAWN
        self.pixelSize = self.cfg.pixelSize or 3
        self:generatePixels()
    end
end

-- Pre-generate pixel positions relative to center
-- Generates a pool of potential pixels; animated boundary determines visibility at draw time
-- OPTIMIZED: Pre-computes wobble phase and classifies pixels as edge/interior for faster drawing
function Creep:generatePixels()
    self.pixels = {}
    local ps = self.pixelSize
    local radius = self.size
    local cfg = Config.VOID_SPAWN

    -- Create a grid of pixels within an expanded area (to allow membrane breathing)
    local expandedRadius = radius * 1.3  -- Extra room for wobble expansion
    local gridSize = math.ceil(expandedRadius * 2 / ps)
    local halfGrid = gridSize / 2

    -- Pre-compute base radius thresholds for pixel classification
    local baseInnerRadius = radius * 0.5  -- Pixels always inside (no boundary check needed)
    local baseOuterRadius = radius * (0.7 + 0.5 + cfg.wobbleAmount * 0.5)

    for py = 0, gridSize - 1 do
        for px = 0, gridSize - 1 do
            -- Position relative to center
            local relX = (px - halfGrid + 0.5) * ps
            local relY = (py - halfGrid + 0.5) * ps

            -- Distance from center
            local dist = math.sqrt(relX * relX + relY * relY)
            local angle = math.atan2(relY, relX)

            -- Base edge noise (static shape component)
            local baseEdgeNoise = Procedural.fbm(
                math.cos(angle) * cfg.distortionFrequency,
                math.sin(angle) * cfg.distortionFrequency,
                self.seed,
                cfg.octaves
            )

            -- Pre-compute wobble phase offset (OPTIMIZATION: replaces per-frame fbm call)
            -- This creates the same organic variation but computed once at spawn
            local wobblePhase = Procedural.fbm(
                angle * cfg.wobbleFrequency,
                0,
                self.seed + 500,
                2
            ) * math.pi * 2

            -- Only include pixels that could potentially be visible (within expanded bounds)
            if dist < baseOuterRadius then
                local distNorm = dist / radius
                -- Classify pixel zone for draw optimization
                local zone = "boundary"  -- Default: needs boundary check each frame
                if dist < baseInnerRadius then
                    zone = "interior"    -- Always visible, skip boundary check
                end

                table.insert(self.pixels, {
                    relX = relX,
                    relY = relY,
                    px = px,
                    py = py,
                    dist = dist,
                    distNorm = distNorm,
                    angle = angle,
                    baseEdgeNoise = baseEdgeNoise,  -- Store for animated boundary calc
                    wobblePhase = wobblePhase,      -- Pre-computed wobble phase offset
                    zone = zone,                    -- Pixel classification for draw optimization
                    rnd = Procedural.hash(px, py, self.seed + 888),
                    rnd2 = Procedural.hash(px * 2.1, py * 1.7, self.seed + 777),
                })
            end
        end
    end
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
    local expandedH = bodyHeight * 1.3
    local expandedW = bodyWidth * 1.3
    local gridH = math.ceil(expandedH * 2 / ps)
    local gridW = math.ceil(expandedW * 2 / ps)

    for py = 0, gridH - 1 do
        for px = 0, gridW - 1 do
            local relX = (px - gridW / 2 + 0.5) * ps
            local relY = (py - gridH / 2 + 0.5) * ps

            -- Ellipse distance (normalized so edge = 1)
            local normX = relX / bodyWidth
            local normY = relY / bodyHeight
            local ellipseDist = math.sqrt(normX * normX + normY * normY)

            if ellipseDist < 1.3 then
                local angle = math.atan2(relY, relX)

                local baseEdgeNoise = Procedural.fbm(
                    math.cos(angle) * cfg.distortionFrequency,
                    math.sin(angle) * cfg.distortionFrequency,
                    self.seed,
                    cfg.octaves
                )

                -- Pre-compute wobble phase offset (OPTIMIZATION)
                local wobblePhase = Procedural.fbm(
                    angle * cfg.wobbleFrequency,
                    0,
                    self.seed + 500,
                    2
                ) * math.pi * 2

                table.insert(self.bodyPixels, {
                    relX = relX,
                    relY = relY,
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

    -- Generate leg pixels (4 floating void shards) - fixed medium legs
    local legLen = bodySize * cfg.legs.length
    local legWidth = legLen * cfg.legs.width
    local legAngle = cfg.legs.angle  -- Fixed angle for all variants
    local legGap = bodySize * cfg.legs.gap

    -- Leg positions:  \ | /   (legs angle outward from body)
    --                 \ | /
    local legDefs = {
        {ox = -legGap, oy = -bodyHeight * 0.4, angle = legAngle},   -- front-left \
        {ox = legGap,  oy = -bodyHeight * 0.4, angle = -legAngle},  -- front-right /
        {ox = -legGap, oy = bodyHeight * 0.4,  angle = legAngle},   -- back-left \
        {ox = legGap,  oy = bodyHeight * 0.4,  angle = -legAngle},  -- back-right /
    }

    for legIdx, legDef in ipairs(legDefs) do
        -- Generate shard shape (elongated void chunk)
        local shardH = legLen
        local shardW = legWidth
        local gridLegH = math.ceil(shardH * 1.4 / ps)
        local gridLegW = math.ceil(shardW * 1.4 / ps)

        for py = 0, gridLegH - 1 do
            for px = 0, gridLegW - 1 do
                local localX = (px - gridLegW / 2 + 0.5) * ps
                local localY = (py - gridLegH / 2 + 0.5) * ps

                -- Shard shape: elongated ellipse
                local normX = localX / (shardW * 0.5)
                local normY = localY / (shardH * 0.5)
                local shardDist = math.sqrt(normX * normX + normY * normY)

                if shardDist < 1.2 then
                    -- Rotate by leg angle
                    local cosA = math.cos(legDef.angle)
                    local sinA = math.sin(legDef.angle)
                    local rotX = localX * cosA - localY * sinA
                    local rotY = localX * sinA + localY * cosA

                    local angle = math.atan2(localY, localX)
                    local baseEdgeNoise = Procedural.fbm(
                        math.cos(angle) * cfg.distortionFrequency,
                        math.sin(angle) * cfg.distortionFrequency,
                        self.seed + legIdx * 100,
                        cfg.octaves
                    )

                    -- Pre-compute wobble phase offset (OPTIMIZATION)
                    local wobblePhase = Procedural.fbm(
                        angle * cfg.wobbleFrequency,
                        0,
                        self.seed + legIdx * 100 + 500,
                        2
                    ) * math.pi * 2

                    table.insert(self.legPixels, {
                        legIdx = legIdx,
                        ox = legDef.ox,
                        oy = legDef.oy,
                        localX = rotX,
                        localY = rotY,
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

-- Start the exit animation (called when creep reaches base)
function Creep:startExitAnimation(portalX, portalY)
    self.exitPhase = "tear_open"
    self.exitTimer = 0
    self.exitX = self.x
    self.exitY = self.y
    self.exitPortalX = portalX
    self.exitPortalY = portalY
end

-- Update exit animation state machine
function Creep:updateExitAnimation(dt)
    local cfg = Config.EXIT_ANIMATION

    self.exitTimer = self.exitTimer + dt

    if self.exitPhase == "tear_open" then
        if self.exitTimer >= cfg.tearOpenDuration then
            self.exitPhase = "devouring"
            self.exitTimer = 0
        end
    elseif self.exitPhase == "devouring" then
        -- Pull creep toward portal center
        local progress = self.exitTimer / cfg.devouringDuration
        local pullAmount = _easeOutQuad(progress) * cfg.pullDistance
        -- Move toward portal center
        local dx = self.exitPortalX - self.exitX
        local dy = self.exitPortalY - self.exitY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            self.x = self.exitX + (dx / dist) * pullAmount
            self.y = self.exitY + (dy / dist) * pullAmount
        end

        if self.exitTimer >= cfg.devouringDuration then
            self.exitPhase = "tear_close"
            self.exitTimer = 0
        end
    elseif self.exitPhase == "tear_close" then
        if self.exitTimer >= cfg.tearCloseDuration then
            self.exitPhase = "consumed"
            self.exitTimer = 0
            self.reachedBase = true
            self.dead = true
        end
    end
end

-- Check if creep is in exit animation
function Creep:isExiting()
    return self.exitPhase ~= nil and self.exitPhase ~= "consumed"
end

-- Get progress of current exit tear phase (0-1)
function Creep:getExitTearProgress()
    local cfg = Config.EXIT_ANIMATION

    if self.exitPhase == "tear_open" then
        return self.exitTimer / cfg.tearOpenDuration
    elseif self.exitPhase == "devouring" then
        return 1.0  -- Tear fully open during devouring
    elseif self.exitPhase == "tear_close" then
        return 1.0 - (self.exitTimer / cfg.tearCloseDuration)
    else
        return 0  -- No tear
    end
end

-- Get devouring progress (0-1) for visual fade/shrink during exit
function Creep:getDevouringProgress()
    if self.exitPhase ~= "devouring" then return 0 end
    local cfg = Config.EXIT_ANIMATION
    return _easeOutQuad(self.exitTimer / cfg.devouringDuration)
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
    local baseRow = grid.getBaseRow()
    local gridBottom = grid.getGridBottom()

    -- Get flow direction for current cell
    local flow = flowField[gridY] and flowField[gridY][gridX]

    local targetX, targetY

    -- Check if we're at or past the base row - move straight down toward exit
    if gridY >= baseRow or self.y >= gridBottom then
        -- At base row or below grid: move straight down
        targetX = self.x
        targetY = self.y + 100  -- Just go down
    elseif flow and (flow.dx ~= 0 or flow.dy ~= 0) then
        -- Follow flow field - calculate target cell center
        local targetGridX = gridX + flow.dx
        local targetGridY = gridY + flow.dy

        -- Safety check: ensure target cell is walkable (not a tower)
        local cells = grid.getCells()
        if cells[targetGridY] and cells[targetGridY][targetGridX] ~= 1 then
            targetX, targetY = grid.gridToScreen(targetGridX, targetGridY)
        else
            -- Target is blocked, stay in current cell center (flow field will be recomputed)
            targetX, targetY = grid.gridToScreen(gridX, gridY)
        end
    elseif gridY < 1 then
        -- Above grid: find a valid entry column on row 1 immediately and move toward it
        -- This prevents creeps from passing through towers on row 1
        local cols = grid.getCols()
        local bestCol = nil
        local bestDist = math.huge

        -- Search for nearest column on row 1 with a valid flow field entry
        for col = 1, cols do
            if flowField[1] and flowField[1][col] then
                local colX, _ = grid.gridToScreen(col, 1)
                local dist = math.abs(colX - self.x)
                if dist < bestDist then
                    bestDist = dist
                    bestCol = col
                end
            end
        end

        if bestCol then
            -- Move diagonally toward the valid entry point
            targetX, targetY = grid.gridToScreen(bestCol, 1)
        else
            -- No valid entry (shouldn't happen): move toward center of row 1
            targetX, targetY = grid.gridToScreen(math.ceil(cols / 2), 1)
        end
    else
        -- On grid but no flow (shouldn't happen often): move toward base row
        targetX, targetY = grid.gridToScreen(gridX, baseRow)
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

-- Check if creep is in dying animation (for cadaver creation timing)
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

    local radius = self.size

    -- Pre-compute time-based wobble factor
    local wobbleTime = t * cfg.wobbleSpeed

    -- Cache sparkle threshold
    local sparkleThreshold = cfg.sparkleThreshold or 0.96
    local sparkleTimeX = math.floor(t * 8)
    local sparkleTimeY = math.floor(t * 5)

    -- Check for slow effect - will apply blue glow tint to all pixels
    local hasSlowEffect = StatusEffects.hasEffect(self, StatusEffects.SLOW) and not self:isSpawning()
    local slowGlowIntensity = 0
    local slowColor = nil
    if hasSlowEffect then
        slowColor = Config.STATUS_EFFECTS.slow.color
        -- Pulsing glow intensity
        slowGlowIntensity = 0.25 + sin(t * 4) * 0.1
    end

    -- Draw each pixel with animated void effects (matching portal style)
    for _, p in ipairs(self.pixels) do
        local wobbleNoise = math.sin(wobbleTime + p.wobblePhase) * 0.5 + 0.5
        local animatedEdgeRadius = radius * (0.7 + p.baseEdgeNoise * 0.5 + wobbleNoise * cfg.wobbleAmount * 0.3)

        -- Skip pixels outside the current animated boundary
        if p.zone == "boundary" and p.dist >= animatedEdgeRadius then
            goto continue
        end

        local isEdge = p.dist > animatedEdgeRadius - ps * 1.5

        -- Apply scale from center (with death squash on Y axis)
        local scaledRelX = p.relX * scale
        local scaledRelY = p.relY * scale * deathSquashY
        local screenX = self.x + scaledRelX - ps * scale / 2
        local screenY = self.y + scaledRelY - ps * scale * deathSquashY / 2
        local pixelW = ps * scale
        local pixelH = ps * scale * deathSquashY

        -- Check if in squared core region (pitch black center)
        local coreSize = cfg.coreSize or 5
        local inCore = abs(p.relX) < coreSize and abs(p.relY) < coreSize

        local r, g, b

        -- Sparkles
        local sparkle = Procedural.hash(p.px + sparkleTimeX, p.py + sparkleTimeY, self.seed + 333)
        if sparkle > sparkleThreshold then
            r, g, b = colors.sparkle[1], colors.sparkle[2], colors.sparkle[3]
        elseif inCore then
            -- Deep void core (pitch black)
            local n = Procedural.hash(p.px + floor(t * 2), p.py, self.seed) * 0.01
            r = colors.core[1] + n
            g = colors.core[2] + n * 0.5
            b = colors.core[3] + n
        elseif isEdge then
            -- Edge glow
            local pulse = math.sin(t * cfg.pulseSpeed + p.angle * 2) * 0.3 + 0.7
            r = colors.edgeGlow[1] * pulse
            g = colors.edgeGlow[2] * pulse
            b = colors.edgeGlow[3] * pulse
        else
            -- Interior (dark purple)
            local swirl = math.sin(p.angle * 3 + t * cfg.swirlSpeed + p.distNorm * 4) * 0.5 + 0.5
            local v = p.rnd * 0.3 + swirl * 0.2 + p.distNorm * 0.3
            r = colors.core[1] + (colors.mid[1] - colors.core[1]) * v
            g = colors.core[2] + (colors.mid[2] - colors.core[2]) * v
            b = colors.core[3] + (colors.mid[3] - colors.core[3]) * v
        end

        -- Apply hit flash (additive white)
        if self.hitFlashTimer > 0 then
            local flashIntensity = self.hitFlashTimer / Config.CREEP_HIT.flashDuration
            r = r + flashIntensity * 0.8
            g = g + flashIntensity * 0.8
            b = b + flashIntensity * 0.6
        end

        -- Apply death desaturation (shift toward gray)
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

        ::continue::
    end

    -- Draw pixel art health bar when damaged (only when fully spawned)
    if self.hp < self.maxHp and not self:isSpawning() then
        local ps = self.pixelSize
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
            local t = i / barPixels
            love.graphics.setColor(0.5 + t * 0.2, 0.1, 0.6 + t * 0.2)
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

    -- Draw legs first (behind body) - matching portal style
    local legPhases = {0, math.pi * 0.5, math.pi, math.pi * 1.5}
    for _, lp in ipairs(self.legPixels) do
        -- Snap bob offset to pixel grid to prevent sub-pixel gaps
        local rawBob = math.sin(bobPhase + legPhases[lp.legIdx]) * legCfg.bobAmount * scale
        local bob = floor(rawBob + 0.5)

        local wobbleNoise = math.sin(wobbleTime + lp.wobblePhase) * 0.5 + 0.5
        local animatedEdge = 1.0 + lp.baseEdgeNoise * 0.2 + wobbleNoise * cfg.wobbleAmount * 0.2

        if lp.dist >= animatedEdge then
            goto continue_leg
        end

        local isEdge = lp.dist > animatedEdge - 0.3

        -- Screen position with bob
        local screenX = self.x + (lp.ox + lp.localX) * scale - ps * scale / 2
        local screenY = self.y + (lp.oy + lp.localY) * scale * deathSquashY + bob - ps * scale * deathSquashY / 2
        local pixelW = ps * scale
        local pixelH = ps * scale * deathSquashY

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

    -- Draw body pixels (elongated rift) - matching portal style
    local coreSize = cfg.coreSize or 4
    for _, p in ipairs(self.bodyPixels) do
        local wobbleNoise = math.sin(wobbleTime + p.wobblePhase) * 0.5 + 0.5
        local animatedEdge = 1.0 + p.baseEdgeNoise * 0.15 + wobbleNoise * cfg.wobbleAmount * 0.15

        if p.dist >= animatedEdge then
            goto continue_body
        end

        local isEdge = p.dist > animatedEdge - 0.25

        local screenX = self.x + p.relX * scale - ps * scale / 2
        local screenY = self.y + p.relY * scale * deathSquashY - ps * scale * deathSquashY / 2
        local pixelW = ps * scale
        local pixelH = ps * scale * deathSquashY

        -- Check if in squared core region (pitch black center)
        local inCore = abs(p.relX) < coreSize and abs(p.relY) < coreSize

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
