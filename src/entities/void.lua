-- src/entities/void.lua
-- The Void Portal entity: circular procedural pixel art portal
-- Uses the same rendering approach as creeps for visual consistency

local Object = require("lib.classic")
local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Procedural = require("src.rendering.procedural")
local Settings = require("src.ui.settings")

local Void = Object:extend()

function Void:new(x, y)
    -- Position (center of portal)
    self.x = x
    self.y = y

    -- Health state
    self.maxHealth = Config.VOID.maxHealth
    self.health = self.maxHealth

    -- Anger state
    self.permanentAnger = 0
    self.currentAnger = 0

    -- Animation state
    self.clickFlash = 0
    self.time = 0

    -- Size state (for growth animation)
    self.size = Config.VOID_PORTAL.baseSize
    self.targetSize = Config.VOID_PORTAL.baseSize
    self.maxSize = Config.VOID_PORTAL.maxSize

    -- Pixel art scale (size of each "pixel")
    self.pixelSize = Config.VOID_PORTAL.pixelSize

    -- Unique seed for procedural effects
    self.seed = math.random(1000)

    -- Spawn animation tracking
    self.activeSpawns = {}
    self.spawnParticles = {}

    -- Generate pixel pool for creep-style rendering
    self:generatePixels()
end

-- Generate pixel pool for creep-style rendering (copied from creep.lua)
function Void:generatePixels()
    self.pixels = {}
    local ps = self.pixelSize
    local radius = self.size
    local cfg = Config.VOID_PORTAL

    -- Create a grid of pixels within an expanded area (to allow membrane breathing)
    local expandedRadius = radius * 1.3
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

            -- Base edge noise on ANGLE (creep style)
            local baseEdgeNoise = Procedural.fbm(
                math.cos(angle) * cfg.distortionFrequency,
                math.sin(angle) * cfg.distortionFrequency,
                self.seed,
                cfg.octaves
            )

            -- Only include pixels that could potentially be visible
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
                    baseEdgeNoise = baseEdgeNoise,
                    rnd = Procedural.hash(px, py, self.seed + 888),
                    rnd2 = Procedural.hash(px * 2.1, py * 1.7, self.seed + 777),
                })
            end
        end
    end
end

function Void:update(dt)
    self.time = self.time + dt

    -- Animated growth toward target
    if self.size ~= self.targetSize then
        local growthSpeed = Config.VOID_PORTAL.growthSpeed
        if self.size < self.targetSize then
            self.size = math.min(self.targetSize, self.size + growthSpeed * dt)
        end
        self:generatePixels()
    end

    -- Decay click flash
    if self.clickFlash > 0 then
        self.clickFlash = self.clickFlash - dt / Config.VOID.clickFlashDuration
        if self.clickFlash < 0 then
            self.clickFlash = 0
        end
    end

    -- Clean up finished spawns
    for i = #self.activeSpawns, 1, -1 do
        local creep = self.activeSpawns[i]
        if creep.dead or not creep:isSpawning() then
            table.remove(self.activeSpawns, i)
        end
    end

    -- Spawn particles during tear_open phase
    local spawnCfg = Config.SPAWN_ANIMATION
    for _, creep in ipairs(self.activeSpawns) do
        if creep.spawnPhase == "tear_open" then
            local tearProgress = creep:getTearProgress()
            local tearHeight = spawnCfg.tearHeight * tearProgress
            local tearWidth = spawnCfg.tearWidth * tearProgress

            -- Spawn particles at tear edges
            for _ = 1, spawnCfg.particles.spawnRate do
                if math.random() < 0.7 then
                    local side = math.random() < 0.5 and -1 or 1
                    local yOffset = (math.random() - 0.5) * tearHeight
                    table.insert(self.spawnParticles, {
                        x = creep.spawnX + side * tearWidth / 2,
                        y = creep.spawnY + yOffset,
                        vx = side * spawnCfg.particles.speed * (0.5 + math.random() * 0.5),
                        vy = (math.random() - 0.5) * spawnCfg.particles.speed * 0.5,
                        life = spawnCfg.particles.life,
                        maxLife = spawnCfg.particles.life,
                    })
                end
            end
        end
    end

    -- Update particles
    for i = #self.spawnParticles, 1, -1 do
        local p = self.spawnParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.spawnParticles, i)
        end
    end
end

-- Register a spawning creep for tear effect rendering
function Void:registerSpawn(creep)
    table.insert(self.activeSpawns, creep)
end

-- Deal damage to the Void and return income earned
function Void:click(damage, income)
    damage = damage or Config.VOID.clickDamage
    income = income or Config.VOID.baseIncomePerClick

    self.health = self.health - damage

    -- Trigger click flash
    self.clickFlash = 1

    -- Trigger growth (permanent, no shrink)
    local growth = damage * Config.VOID_PORTAL.growthPerDamage
    self.targetSize = math.min(self.maxSize, self.targetSize + growth)

    -- Calculate current anger from thresholds
    self:updateAnger()

    -- Check for reset
    if self.health <= 0 then
        self:reset()
    end

    -- Emit event
    EventBus.emit("void_clicked", {
        damage = damage,
        income = income,
        health = self.health,
        maxHealth = self.maxHealth,
        angerLevel = self:getAngerLevel(),
    })

    return income
end

-- Calculate anger from health thresholds
function Void:updateAnger()
    local thresholdAnger = 0
    for _, threshold in ipairs(Config.VOID.angerThresholds) do
        if self.health <= threshold then
            thresholdAnger = thresholdAnger + 1
        end
    end
    self.currentAnger = thresholdAnger
end

-- Get total anger level (threshold + permanent)
function Void:getAngerLevel()
    return math.min(self.currentAnger + self.permanentAnger, #Config.COLORS.void - 1)
end

-- Reset Void when health reaches 0
function Void:reset()
    self.permanentAnger = self.permanentAnger + 1
    self.health = self.maxHealth
    self.currentAnger = 0
    -- NOTE: Do NOT reset targetSize or size (permanent growth)

    EventBus.emit("void_reset", {
        permanentAnger = self.permanentAnger,
        angerLevel = self:getAngerLevel(),
    })
end

-- Check if a point is inside the Void (circular click detection)
function Void:isPointInside(px, py)
    local dx = px - self.x
    local dy = py - self.y
    return (dx * dx + dy * dy) <= (self.size * self.size)
end

function Void:getHealth()
    return self.health
end

function Void:getMaxHealth()
    return self.maxHealth
end

function Void:getHealthPercent()
    return self.health / self.maxHealth
end

function Void:draw()
    local cfg = Config.VOID_PORTAL
    local colors = cfg.colors
    local ps = self.pixelSize
    local t = self.time
    local anger = self:getAngerLevel()
    local radius = self.size

    -- Draw shadow below portal
    local shadowCfg = cfg.shadow
    love.graphics.setColor(0, 0, 0, shadowCfg.alpha)
    local shadowWidth = radius * shadowCfg.width
    local shadowHeight = radius * shadowCfg.height
    local shadowY = self.y + radius * shadowCfg.offsetY
    love.graphics.ellipse("fill", self.x, shadowY, shadowWidth, shadowHeight)

    -- Draw each pixel with animated void effects (matching Creep:draw)
    for _, p in ipairs(self.pixels) do
        -- Calculate animated edge boundary for this pixel's angle
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

        -- Calculate screen position (portal always at full size, no scaling)
        local screenX = self.x + p.relX - ps / 2
        local screenY = self.y + p.relY - ps / 2

        -- Animated noise layers (like creep)
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

            -- Vertical tear streaks (like creep)
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

        -- Anger-based color shift (redder with more anger)
        if anger > 0 then
            local angerShift = anger * 0.08
            r = math.min(1, r + angerShift)
            g = math.max(0, g - angerShift * 0.3)
        end

        -- Self-illumination: boost brightness when lighting is enabled
        if Settings.isLightingEnabled() then
            local boost = Config.LIGHTING.selfIllumination and Config.LIGHTING.selfIllumination.void or 1.4
            r = math.min(1, r * boost)
            g = math.min(1, g * boost)
            b = math.min(1, b * boost)
        end

        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", screenX, screenY, ps, ps)

        ::continue::
    end

    -- Click flash overlay (circular)
    if self.clickFlash > 0 then
        love.graphics.setColor(0.8, 0.5, 1, self.clickFlash * 0.5)
        love.graphics.circle("fill", self.x, self.y, self.size)
    end
end

-- Draw tear effects for spawning creeps
function Void:drawTears()
    for _, creep in ipairs(self.activeSpawns) do
        local tearProgress = creep:getTearProgress()
        if tearProgress > 0 then
            self:drawSingleTear(creep.spawnX, creep.spawnY, tearProgress)
        end
    end
end

-- Draw a single tear/rift at the given position
function Void:drawSingleTear(cx, cy, progress)
    local cfg = Config.SPAWN_ANIMATION
    local colors = cfg.tearColors
    local ps = cfg.tearPixelSize
    local t = self.time

    local maxWidth = cfg.tearWidth
    local maxHeight = cfg.tearHeight
    local width = maxWidth * progress
    local height = maxHeight * progress

    -- Number of pixels to draw
    local cols = math.ceil(width / ps)
    local rows = math.ceil(height / ps)

    -- Draw tear pixel by pixel
    for py = -rows / 2, rows / 2 do
        for px = -cols / 2, cols / 2 do
            local screenX = cx + px * ps - ps / 2
            local screenY = cy + py * ps - ps / 2

            -- Distance from center of tear
            local dx = px / (cols / 2 + 0.1)
            local dy = py / (rows / 2 + 0.1)
            local dist = math.sqrt(dx * dx + dy * dy)

            -- Skip pixels outside tear shape
            if dist > 1 then
                goto continue
            end

            -- Jagged edges using noise
            local edgeNoise = Procedural.fbm(px * 0.5 + t * 2, py * 0.3 + t, self.seed + 500, 2)
            local jaggedThreshold = 0.7 + edgeNoise * 0.3

            if dist > jaggedThreshold then
                goto continue
            end

            -- Color based on distance from center
            local r, g, b, a

            -- Outer edge glow
            if dist > jaggedThreshold - 0.3 then
                local pulse = math.sin(t * 4 + py * 0.5) * 0.3 + 0.7
                r = colors.edge[1] * pulse
                g = colors.edge[2] * pulse
                b = colors.edge[3] * pulse
                a = progress
            -- Inner glow
            elseif dist > 0.3 then
                local blend = (dist - 0.3) / (jaggedThreshold - 0.3 - 0.3)
                r = colors.inner[1] * (1 - blend * 0.5)
                g = colors.inner[2] * (1 - blend * 0.3)
                b = colors.inner[3] * (1 - blend * 0.2)
                a = progress
            else
                -- Core: dark void
                local n = Procedural.fbm(px * 0.2 + t * 0.5, py * 0.4 + t * 0.3, self.seed + 600, 2)
                r = colors.void[1] + n * 0.05
                g = colors.void[2] + n * 0.02
                b = colors.void[3] + n * 0.08
                a = progress
            end

            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", screenX, screenY, ps, ps)

            ::continue::
        end
    end
end

-- Draw spark particles from tear edges
function Void:drawSpawnParticles()
    local cfg = Config.SPAWN_ANIMATION.particles
    local ps = cfg.size

    for _, p in ipairs(self.spawnParticles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(cfg.color[1], cfg.color[2], cfg.color[3], alpha)
        love.graphics.rectangle("fill", p.x - ps / 2, p.y - ps / 2, ps, ps)
    end
end

function Void:drawUI()
    -- Health bar below the portal
    local barWidth = self.size * 2
    local barHeight = 6
    local barX = self.x - barWidth / 2
    local barY = self.y + self.size + 10

    -- Background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth + 2, barHeight + 2)

    -- Health fill
    local healthPercent = self.health / self.maxHealth
    local r = 0.5 + (1 - healthPercent) * 0.5
    local g = 0.1
    local b = 0.6 + healthPercent * 0.2
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)

    -- Border
    love.graphics.setColor(0.4, 0.2, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)

    -- Health text
    love.graphics.setColor(1, 1, 1, 0.9)
    local healthText = self.health .. "/" .. self.maxHealth
    love.graphics.printf(healthText, barX, barY - 12, barWidth, "center")

    -- Anger pips
    local pipSize = 5
    local pipSpacing = 8
    local totalPips = #Config.VOID.angerThresholds
    local pipsWidth = totalPips * pipSpacing
    local pipStartX = self.x - pipsWidth / 2
    local pipY = barY - 26

    for i = 1, totalPips do
        local pipX = pipStartX + (i - 1) * pipSpacing
        local isFilled = i <= self.currentAnger

        if isFilled then
            love.graphics.setColor(1, 0.3, 0.1)
        else
            love.graphics.setColor(0.3, 0.15, 0.3)
        end
        love.graphics.rectangle("fill", pipX, pipY, pipSize, pipSize)
    end

    -- Permanent anger
    if self.permanentAnger > 0 then
        love.graphics.setColor(1, 0.3, 0.1)
        love.graphics.print("+" .. self.permanentAnger, pipStartX + pipsWidth + 3, pipY - 1)
    end
end

-- Get light parameters for the lighting system
function Void:getLightParams()
    local lightingCfg = Config.LIGHTING
    local anger = self:getAngerLevel()

    -- Get color based on anger level
    local color = lightingCfg.colors.void[anger] or lightingCfg.colors.void[0]

    -- Calculate pulsing intensity
    local intensityCfg = lightingCfg.intensities.void
    local minIntensity = intensityCfg.min or 2.0
    local maxIntensity = intensityCfg.max or 3.5
    local pulse1 = math.sin(self.time * 2) * 0.5 + 0.5
    local pulse2 = math.sin(self.time * 3.7) * 0.3 + 0.7
    local pulse = pulse1 * pulse2
    local intensity = minIntensity + (maxIntensity - minIntensity) * pulse

    -- Strong boost with anger
    intensity = intensity * (1 + anger * 0.3)

    return {
        x = self.x,
        y = self.y,
        radius = lightingCfg.radii.void or 700,
        color = color,
        intensity = intensity,
        pulse = true,
        pulseSpeed = 2.5 + anger * 0.8,
        pulseAmount = 0.4 + anger * 0.2,
    }
end

return Void
