-- src/entities/void.lua
-- The Void Portal entity: circular procedural pixel art portal
-- Uses click-based anger system with 4 tiers

local Object = require("lib.classic")
local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Procedural = require("src.rendering.procedural")

local Void = Object:extend()

function Void:new(x, y)
    -- Position (center of portal)
    self.x = x
    self.y = y

    -- Click-based anger state
    self.clickCount = 0
    self.maxClicks = Config.VOID.maxClicks
    self.currentTier = 0
    self.redBossesSpawned = false  -- Track if tier 4 bosses were spawned

    -- Threshold pulse animation
    self.thresholdPulseTimer = 0
    self.thresholdPulseActive = false

    -- Hover state (like skill tree void)
    self.isHovered = false
    self.hoverScale = 1.0

    -- Click animation state (quick expand/contract)
    self.clickScale = 1.0
    self.clickScaleVelocity = 0

    -- Animation state
    self.clickFlash = 0
    self.time = 0

    -- Size state (fixed, no growth)
    self.size = Config.VOID_PORTAL.baseSize

    -- Pixel art scale (size of each "pixel")
    self.pixelSize = Config.VOID_PORTAL.pixelSize

    -- Unique seed for procedural effects
    self.seed = math.random(1000)

    -- Spawn animation tracking
    self.activeSpawns = {}
    self.spawnParticles = {}

    -- Outward spewing particles
    self.spewParticles = {}
    self:spawnSpewParticles()

    -- Generate pixel pool for creep-style rendering
    self:generatePixels()
end

-- Generate pixel pool for creep-style rendering (copied from creep.lua)
-- OPTIMIZED: Pre-computes wobble phase for faster draw
function Void:generatePixels()
    self.pixels = {}
    local ps = self.pixelSize
    local radius = self.size
    local cfg = Config.VOID_PORTAL

    -- Create a grid of pixels within an expanded area (to allow membrane breathing)
    -- Must account for maximum combined scale: hover(1.05) * click(1.2) * pulse(1.15) ≈ 1.45
    -- Plus wobble amount, so use 1.6 to be safe
    local expandedRadius = radius * 1.6
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

            -- Pre-compute wobble phase offset (OPTIMIZATION)
            local wobblePhase = Procedural.fbm(
                angle * cfg.wobbleFrequency,
                0,
                self.seed + 500,
                2
            ) * math.pi * 2

            -- Only include pixels that could potentially be visible
            -- Account for max scale (1.45x) and wobble
            local maxEdgeRadius = radius * 1.6
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
                    wobblePhase = wobblePhase,
                    rnd = Procedural.hash(px, py, self.seed + 888),
                    rnd2 = Procedural.hash(px * 2.1, py * 1.7, self.seed + 777),
                })
            end
        end
    end
end

function Void:spawnSpewParticles()
    local cfg = Config.VOID_PORTAL.spewParticles
    if not cfg then return end
    for i = 1, cfg.count do
        self:spawnSpewParticle()
    end
end

function Void:spawnSpewParticle()
    local cfg = Config.VOID_PORTAL.spewParticles
    if not cfg then return end
    local angle = math.random() * math.pi * 2
    -- Start from core area
    local dist = self.size * (cfg.coreRadius * (0.8 + math.random() * 0.4))

    table.insert(self.spewParticles, {
        angle = angle,
        dist = dist,
        speed = cfg.speed * (0.7 + math.random() * 0.6),
        brightness = 0.4 + math.random() * 0.5,
        maxDist = self.size * cfg.maxRadius,
    })
end

function Void:update(dt)
    self.time = self.time + dt

    -- Update threshold pulse animation
    if self.thresholdPulseActive then
        self:updateThresholdPulse(dt)
    end

    -- Smoothly interpolate hover scale (like skill tree void)
    local targetHoverScale = self.isHovered and 1.15 or 1.0
    self.hoverScale = self.hoverScale + (targetHoverScale - self.hoverScale) * dt * 10

    -- Update click scale animation (spring-like expand/contract)
    if self.clickScale ~= 1.0 or self.clickScaleVelocity ~= 0 then
        -- Spring physics: pull toward 1.0
        local springForce = (1.0 - self.clickScale) * 80  -- Stiffness
        local damping = self.clickScaleVelocity * 8       -- Damping
        self.clickScaleVelocity = self.clickScaleVelocity + (springForce - damping) * dt
        self.clickScale = self.clickScale + self.clickScaleVelocity * dt

        -- Settle when close enough
        if math.abs(self.clickScale - 1.0) < 0.001 and math.abs(self.clickScaleVelocity) < 0.01 then
            self.clickScale = 1.0
            self.clickScaleVelocity = 0
        end
    end

    -- Decay click flash
    if self.clickFlash > 0 then
        self.clickFlash = self.clickFlash - dt / Config.VOID.clickFlashDuration
        if self.clickFlash < 0 then
            self.clickFlash = 0
        end
    end

    -- Update spew particles (move outward)
    local spewCfg = Config.VOID_PORTAL.spewParticles
    if spewCfg then
        for i = #self.spewParticles, 1, -1 do
            local p = self.spewParticles[i]
            p.dist = p.dist + p.speed * dt

            -- Respawn when reaching max distance
            if p.dist > p.maxDist then
                table.remove(self.spewParticles, i)
                self:spawnSpewParticle()
            end
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

-- Update tier based on click count thresholds
function Void:updateTier()
    local thresholds = Config.VOID.angerThresholds
    local maxTier = #thresholds  -- Cap at number of thresholds (4)
    local newTier = 0

    for i, threshold in ipairs(thresholds) do
        if self.clickCount >= threshold then
            newTier = i
        end
    end

    -- Cap tier at max
    newTier = math.min(newTier, maxTier)

    -- Check if tier increased
    if newTier > self.currentTier then
        self.currentTier = newTier
        self:triggerThresholdPulse()

        -- At max tier (4), spawn red bosses (only once)
        if self.currentTier >= maxTier and not self.redBossesSpawned then
            self:spawnRedBosses()
        end
    end
end

-- Trigger the threshold pulse animation
function Void:triggerThresholdPulse()
    self.thresholdPulseTimer = 0
    self.thresholdPulseActive = true
end

-- Update threshold pulse timer
function Void:updateThresholdPulse(dt)
    local cfg = Config.VOID.thresholdPulse
    self.thresholdPulseTimer = self.thresholdPulseTimer + dt

    if self.thresholdPulseTimer >= cfg.duration then
        self.thresholdPulseActive = false
        self.thresholdPulseTimer = 0
    end
end

-- Get scale multiplier for threshold pulse
function Void:getThresholdPulseScale()
    if not self.thresholdPulseActive then
        return 1.0
    end

    local cfg = Config.VOID.thresholdPulse
    local progress = self.thresholdPulseTimer / cfg.duration
    -- Pulsing sine wave that fades out
    local pulse = math.sin(progress * cfg.speed * math.pi) * (1.0 - progress)
    return 1.0 + cfg.scaleAmount * pulse
end

-- Spawn two red bosses at tier 4 (only once per game)
function Void:spawnRedBosses()
    self.redBossesSpawned = true
    EventBus.emit("spawn_red_bosses", { count = 2 })
end

-- Click the Void and return income earned
function Void:click()
    local income = Config.VOID.baseIncomePerClick

    -- Increment click counter (capped at maxClicks for display)
    if self.clickCount < self.maxClicks then
        self.clickCount = self.clickCount + 1
        -- Check for tier changes (only while not at max)
        self:updateTier()
    end
    -- After max clicks, clicking still works but anger stays at tier 4

    -- Trigger click flash (white)
    self.clickFlash = 1

    -- Trigger quick expand/contract animation
    self.clickScale = 1.2  -- Start expanded
    self.clickScaleVelocity = -2.0  -- Initial inward velocity for snappy feel

    -- Emit event
    EventBus.emit("void_clicked", {
        income = income,
        clickCount = self.clickCount,
        maxClicks = self.maxClicks,
        tier = self.currentTier,
    })

    return income
end

-- Set hover state (called from init.lua)
function Void:setHovered(hovered)
    self.isHovered = hovered
end

-- Getters for click-based system
function Void:getClickCount()
    return self.clickCount
end

function Void:getMaxClicks()
    return self.maxClicks
end

function Void:getClickPercent()
    return self.clickCount / self.maxClicks
end

function Void:getTier()
    return self.currentTier
end

function Void:hasSpawnedRedBosses()
    return self.redBossesSpawned
end

-- Get total anger level (for color calculations)
function Void:getAngerLevel()
    return math.min(self.currentTier, #Config.COLORS.void - 1)
end

-- Check if a point is inside the Void (circular click detection)
function Void:isPointInside(px, py)
    local dx = px - self.x
    local dy = py - self.y
    return (dx * dx + dy * dy) <= (self.size * self.size)
end

function Void:draw()
    local cfg = Config.VOID_PORTAL
    local colors = cfg.colors
    local ps = self.pixelSize
    local t = self.time
    local anger = self:getAngerLevel()
    local radius = self.size

    -- Apply all scale effects: threshold pulse, hover, and click
    local pulseScale = self:getThresholdPulseScale()
    local totalScale = pulseScale * self.hoverScale * self.clickScale
    radius = radius * totalScale

    -- Draw flattened ellipse shadow below portal
    local shadowCfg = cfg.shadow
    local shadowColor = shadowCfg.color or {0, 0, 0}
    local shadowY = self.y + radius + shadowCfg.offsetY
    local shadowRadiusX = radius * shadowCfg.width
    local shadowRadiusY = radius * shadowCfg.height  -- Flattened (0.9 perspective ratio)
    love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowCfg.alpha)
    love.graphics.ellipse("fill", self.x, shadowY, shadowRadiusX, shadowRadiusY)

    -- Pre-compute time-based values outside loop
    local wobbleTime = t * cfg.wobbleSpeed
    local sparkleTimeX = math.floor(t * 8)
    local sparkleTimeY = math.floor(t * 5)
    local sparkleThreshold = cfg.sparkleThreshold or 0.96

    -- Scale pixel size to avoid gaps when scaled, with slight overlap
    local scaledPs = ps * totalScale + 0.5

    -- Draw each pixel with animated void effects (matching ExitPortal:draw)
    for _, p in ipairs(self.pixels) do
        local wobbleNoise = math.sin(wobbleTime + p.wobblePhase) * 0.5 + 0.5
        local animatedEdgeRadius = radius * (0.7 + p.baseEdgeNoise * 0.5 + wobbleNoise * cfg.wobbleAmount * 0.3)

        -- Skip pixels outside the current animated boundary
        if p.dist * totalScale >= animatedEdgeRadius then
            goto continue
        end

        local isEdge = p.dist * totalScale > animatedEdgeRadius - ps * 1.5
        local screenX = math.floor(self.x + p.relX * totalScale - scaledPs / 2)
        local screenY = math.floor(self.y + p.relY * totalScale - scaledPs / 2)

        -- Check if in squared core region (pitch black center)
        local inCore = math.abs(p.relX) < cfg.coreSize and math.abs(p.relY) < cfg.coreSize

        local r, g, b

        -- Sparkles
        local sparkle = Procedural.hash(p.px + sparkleTimeX, p.py + sparkleTimeY, self.seed + 333)
        if sparkle > sparkleThreshold then
            r, g, b = colors.sparkle[1], colors.sparkle[2], colors.sparkle[3]
        elseif inCore then
            -- Deep void core (pitch black)
            local n = Procedural.hash(p.px + math.floor(t * 2), p.py, self.seed) * 0.01
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

        -- Anger-based color shift (redder with more anger)
        if anger > 0 then
            local angerShift = anger * 0.08
            r = math.min(1, r + angerShift)
            g = math.max(0, g - angerShift * 0.3)
        end

        -- Click flash: blend pixels toward white
        if self.clickFlash > 0 then
            local flash = self.clickFlash
            r = r + (1 - r) * flash
            g = g + (1 - g) * flash
            b = b + (1 - b) * flash
        end

        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", screenX, screenY, scaledPs, scaledPs)

        ::continue::
    end

end

-- Draw spew particles (outward from portal)
function Void:drawSpewParticles()
    local cfg = Config.VOID_PORTAL.spewParticles
    if not cfg then return end
    local ps = cfg.size

    for _, p in ipairs(self.spewParticles) do
        local x = self.x + math.cos(p.angle) * p.dist
        local y = self.y + math.sin(p.angle) * p.dist
        local distNorm = (p.dist - self.size * cfg.coreRadius) / (p.maxDist - self.size * cfg.coreRadius)
        distNorm = math.max(0, math.min(1, distNorm))
        local alpha = p.brightness * (1 - distNorm * 0.7)  -- Fade as moves away

        love.graphics.setColor(cfg.color[1], cfg.color[2], cfg.color[3], alpha)
        love.graphics.rectangle("fill", x - ps/2, y - ps/2, ps, ps)
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

-- Get glow parameters for the bloom system
-- Returns nil to disable bloom on enemy void portal
function Void:getGlowParams()
    return nil
end

-- Alias for backward compatibility
Void.getLightParams = Void.getGlowParams

return Void
