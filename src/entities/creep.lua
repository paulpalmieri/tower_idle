-- src/entities/creep.lua
-- Void Spawn enemy entity - amorphous shadowy creature from the void
-- Rendered in pixel art style matching the void rift

local Object = require("lib.classic")
local Config = require("src.config")
local Procedural = require("src.rendering.procedural")
local Settings = require("src.ui.settings")
local StatusEffects = require("src.systems.status_effects")

local Creep = Object:extend()

-- Unique seed counter for each creep instance
local seedCounter = 0

function Creep:new(x, y, creepType)
    self.x = x
    self.y = y
    self.creepType = creepType

    local stats = Config.CREEPS[creepType]
    self.maxHp = stats.hp
    self.hp = self.maxHp
    self.baseSpeed = stats.speed
    self.speed = stats.speed         -- Current speed (modified by effects)
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
    self.seed = seedCounter * 17 + math.random(1000)

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

    -- Pixel art settings
    self.pixelSize = Config.VOID_SPAWN.pixelSize or 3
    self:generatePixels()
end

-- Pre-generate pixel positions relative to center
-- Generates a pool of potential pixels; animated boundary determines visibility at draw time
function Creep:generatePixels()
    self.pixels = {}
    local ps = self.pixelSize
    local radius = self.size
    local cfg = Config.VOID_SPAWN

    -- Create a grid of pixels within an expanded area (to allow membrane breathing)
    local expandedRadius = radius * 1.3  -- Extra room for wobble expansion
    local gridSize = math.ceil(expandedRadius * 2 / ps)
    local halfGrid = gridSize / 2

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

            -- Only include pixels that could potentially be visible (within expanded bounds)
            local maxEdgeRadius = radius * (0.7 + 0.5 + cfg.wobbleAmount * 0.5)
            if dist < maxEdgeRadius then
                local distNorm = dist / radius
                table.insert(self.pixels, {
                    relX = relX,
                    relY = relY,
                    px = px,
                    py = py,
                    dist = dist,
                    distNorm = distNorm,
                    angle = angle,
                    baseEdgeNoise = baseEdgeNoise,  -- Store for animated boundary calc
                    rnd = Procedural.hash(px, py, self.seed + 888),
                    rnd2 = Procedural.hash(px * 2.1, py * 1.7, self.seed + 777),
                })
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
        targetX, targetY = grid.gridToScreen(targetGridX, targetGridY)
    elseif gridY < 1 then
        -- Above grid: find nearest valid entry point on row 1
        local cols = grid.getCols()
        local bestCol = gridX
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

        -- Move toward the best entry point on row 1
        targetX, targetY = grid.gridToScreen(bestCol, 1)
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
        love.graphics.rectangle("fill", p.x - p.size / 2, p.y - p.size / 2, p.size, p.size)
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
            love.graphics.rectangle("fill", p.x - p.size / 2, p.y - p.size / 2, p.size, p.size)
        end
    end

    -- Don't draw body if dead (only particles above)
    if self.dead then return end

    -- Skip drawing during tear_open phase (only tear is visible)
    if self.spawnPhase == "tear_open" then
        return
    end

    local cfg = Config.VOID_SPAWN
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

    -- Draw shadow (ground feel)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0, 0, 0, 0.35)
    local shadowWidth = self.size * 1.5
    local shadowHeight = self.size * 0.4
    local shadowY = self.y + self.size * 1.3
    love.graphics.ellipse("fill", self.x, shadowY, shadowWidth, shadowHeight)

    -- Draw each pixel with animated void effects
    local radius = self.size
    for _, p in ipairs(self.pixels) do
        -- Calculate animated edge boundary for this pixel's angle
        -- Combine base shape noise with time-varying wobble
        local wobbleNoise = Procedural.fbm(
            p.angle * cfg.wobbleFrequency + t * cfg.wobbleSpeed,
            t * cfg.wobbleSpeed * 0.3,
            self.seed + 500,
            2
        )
        local animatedEdgeRadius = radius * (0.7 + p.baseEdgeNoise * 0.5 + wobbleNoise * cfg.wobbleAmount * 0.3)

        -- Skip pixels outside the current animated boundary
        if p.dist >= animatedEdgeRadius then
            goto continue
        end

        -- Determine if this pixel is near the edge (for glow effect)
        local isEdge = p.dist > animatedEdgeRadius - ps * 1.5

        -- Apply scale from center (with death squash on Y axis)
        local scaledRelX = p.relX * scale
        local scaledRelY = p.relY * scale * deathSquashY
        local screenX = self.x + scaledRelX - ps * scale / 2
        local screenY = self.y + scaledRelY - ps * scale * deathSquashY / 2
        local pixelW = ps * scale
        local pixelH = ps * scale * deathSquashY

        -- Animated noise layers (like void rift)
        local n1 = Procedural.fbm(p.px * 0.3 + t * 0.8, p.py * 0.3 + t * 0.2, self.seed, 3)
        local n2 = Procedural.fbm(p.px * 0.2 - t * 0.4, p.py * 0.4 + t * 0.6, self.seed + 50, 2)
        local n3 = Procedural.hash(p.px + math.floor(t * 4), p.py, self.seed + 111)

        -- Swirling pattern
        local swirl = math.sin(p.angle * 3 + t * cfg.swirlSpeed + p.distNorm * 4) * 0.5 + 0.5

        -- Random sparkles (use config threshold for more frequent sparkles)
        local sparkle = Procedural.hash(p.px + math.floor(t * 8), p.py + math.floor(t * 5), self.seed + 333)
        local sparkleThreshold = cfg.sparkleThreshold or 0.96
        local isSpark = sparkle > sparkleThreshold

        -- Color calculation
        local r, g, b

        if isSpark then
            -- Bright sparkle
            r, g, b = colors.sparkle[1], colors.sparkle[2], colors.sparkle[3]
        elseif isEdge then
            -- Edge glow - brighter purple
            local pulse = math.sin(t * cfg.pulseSpeed + p.angle * 2) * 0.3 + 0.7
            r = colors.edgeGlow[1] * pulse
            g = colors.edgeGlow[2] * pulse
            b = colors.edgeGlow[3] * pulse
        else
            -- Interior void texture
            local v = n1 * 0.5 + n2 * 0.3 + swirl * 0.2

            -- Interpolate between core and mid based on noise and distance
            local blend = v + p.distNorm * 0.3
            r = colors.core[1] + (colors.mid[1] - colors.core[1]) * blend + p.rnd * 0.05
            g = colors.core[2] + (colors.mid[2] - colors.core[2]) * blend + p.rnd2 * 0.02
            b = colors.core[3] + (colors.mid[3] - colors.core[3]) * blend + p.rnd * 0.1

            -- Random darker spots
            if p.rnd > 0.85 then
                r, g, b = r * 0.5, g * 0.5, b * 0.7
            end

            -- Random brighter purple tints
            if p.rnd2 > 0.8 then
                r = r + 0.08
                b = b + 0.12
            end

            -- Vertical tear streaks (like void rift)
            local tear = Procedural.fbm(p.px * 0.1, p.py * 0.5 + t * 0.5, self.seed + 200, 2)
            if tear > 0.58 and p.rnd > 0.4 then
                local bright = (tear - 0.58) * 2 + n3 * 0.2
                r = r + bright * 0.3
                b = b + bright * 0.4
            end
        end

        -- Pulsing glow
        local pulse = math.sin(t * cfg.pulseSpeed + p.distNorm * 3 + p.rnd * 4) * 0.06
        r = math.max(0, math.min(1, r + pulse))
        b = math.max(0, math.min(1, b + pulse * 0.5))

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

        -- Self-illumination: boost brightness when lighting is enabled
        if Settings.isLightingEnabled() then
            local boost = Config.LIGHTING.selfIllumination and Config.LIGHTING.selfIllumination.creep or 1.35
            r = math.min(1, r * boost)
            g = math.min(1, g * boost)
            b = math.min(1, b * boost)
        end

        love.graphics.setColor(r * alpha, g * alpha, b * alpha, alpha)
        love.graphics.rectangle("fill", screenX, screenY, pixelW, pixelH)

        ::continue::
    end

    -- Draw frost tint overlay for slow effect
    if StatusEffects.hasEffect(self, StatusEffects.SLOW) and not self:isSpawning() then
        local slowColor = Config.STATUS_EFFECTS.slow.color
        local slowAlpha = 0.25
        local frostPulse = math.sin(self.time * 4) * 0.05 + 0.2

        -- Draw frost crystals around the creep
        love.graphics.setColor(slowColor[1], slowColor[2], slowColor[3], frostPulse)
        love.graphics.circle("fill", self.x, self.y, self.size * scale * 1.2)

        -- Draw small ice crystal particles
        local crystalCount = 4
        for i = 1, crystalCount do
            local angle = (i / crystalCount) * math.pi * 2 + self.time * 0.5
            local dist = self.size * scale * 0.8
            local cx = self.x + math.cos(angle) * dist
            local cy = self.y + math.sin(angle) * dist
            love.graphics.setColor(slowColor[1], slowColor[2], slowColor[3], slowAlpha + frostPulse)
            love.graphics.circle("fill", cx, cy, 2)
        end
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
            love.graphics.rectangle("fill", barX + i * ps, barY, ps, ps)
        end

        -- Health fill pixels with gradient
        local filledPixels = math.ceil(healthPercent * barPixels)
        for i = 0, filledPixels - 1 do
            local t = i / barPixels
            love.graphics.setColor(0.5 + t * 0.2, 0.1, 0.6 + t * 0.2)
            love.graphics.rectangle("fill", barX + i * ps, barY, ps, ps)
        end
    end
end

-- Get light parameters for the lighting system
function Creep:getLightParams()
    -- Don't emit light if dead or still in spawn animation
    if self.dead then return nil end
    if self:isSpawning() then return nil end

    local lightingCfg = Config.LIGHTING

    return {
        x = self.x,
        y = self.y,
        radius = lightingCfg.radii.creep or (self.size * 1.5),
        color = lightingCfg.colors.creep or {0.6, 0.3, 0.8},
        intensity = lightingCfg.intensities.creep or 0.4,
        flicker = false,
    }
end

return Creep
