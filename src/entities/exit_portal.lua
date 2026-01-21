-- src/entities/exit_portal.lua
-- Organic procedural black hole at the base zone (player base)
-- Uses pixel-pool approach like Void entity with gravity particles

local Object = require("lib.classic")
local Config = require("src.config")
local Procedural = require("src.rendering.procedural")

local ExitPortal = Object:extend()

function ExitPortal:new(x, y)
    self.x = x
    self.y = y

    local cfg = Config.VOID_CORE
    self.size = cfg.baseSize
    self.pixelSize = cfg.pixelSize
    self.time = 0
    self.seed = math.random(1000) + 5000

    -- Exit tracking
    self.activeExits = {}

    -- Gravity pull particles
    self.gravityParticles = {}
    self:spawnGravityParticles()

    -- Generate pixel pool (organic boundary)
    self:generatePixels()
end

function ExitPortal:generatePixels()
    self.pixels = {}
    local ps = self.pixelSize
    local radius = self.size
    local cfg = Config.VOID_CORE

    local expandedRadius = radius * 1.3
    local gridSize = math.ceil(expandedRadius * 2 / ps)
    local halfGrid = gridSize / 2

    for py = 0, gridSize - 1 do
        for px = 0, gridSize - 1 do
            local relX = (px - halfGrid + 0.5) * ps
            local relY = (py - halfGrid + 0.5) * ps
            local dist = math.sqrt(relX * relX + relY * relY)
            local angle = math.atan2(relY, relX)

            local baseEdgeNoise = Procedural.fbm(
                math.cos(angle) * cfg.distortionFrequency,
                math.sin(angle) * cfg.distortionFrequency,
                self.seed, cfg.octaves
            )

            local wobblePhase = Procedural.fbm(
                angle * cfg.wobbleFrequency, 0,
                self.seed + 500, 2
            ) * math.pi * 2

            local maxEdgeRadius = radius * (0.7 + 0.5 + cfg.wobbleAmount * 0.5)
            if dist < maxEdgeRadius then
                table.insert(self.pixels, {
                    relX = relX, relY = relY,
                    px = px, py = py,
                    dist = dist,
                    distNorm = dist / radius,
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

function ExitPortal:spawnGravityParticles()
    local cfg = Config.VOID_CORE.particles
    for i = 1, cfg.count do
        self:spawnGravityParticle()
    end
end

function ExitPortal:spawnGravityParticle()
    local cfg = Config.VOID_CORE
    local pcfg = cfg.particles
    local angle = math.random() * math.pi * 2
    local dist = self.size * (pcfg.spawnRadius * (0.8 + math.random() * 0.4))

    table.insert(self.gravityParticles, {
        angle = angle,
        dist = dist,
        speed = pcfg.pullSpeed * (0.7 + math.random() * 0.6),
        brightness = 0.3 + math.random() * 0.5,
    })
end

function ExitPortal:update(dt)
    self.time = self.time + dt

    -- Update gravity particles (pull inward)
    local cfg = Config.VOID_CORE
    for i = #self.gravityParticles, 1, -1 do
        local p = self.gravityParticles[i]
        p.dist = p.dist - p.speed * dt

        -- Respawn when reaching core
        if p.dist < cfg.coreSize then
            table.remove(self.gravityParticles, i)
            self:spawnGravityParticle()
        end
    end

    -- Clean up finished exit animations
    for i = #self.activeExits, 1, -1 do
        local creep = self.activeExits[i]
        if creep.dead or not creep:isExiting() then
            table.remove(self.activeExits, i)
        end
    end
end

-- Register a creep that is exiting for tear effect rendering
function ExitPortal:registerExit(creep)
    table.insert(self.activeExits, creep)

    -- Trigger breach effects
    self:triggerBreach(creep.x, creep.y)
end

-- Trigger breach effects when a creep enters (simplified)
function ExitPortal:triggerBreach(creepX, creepY)
    -- Simplified: no tendrils, surge, or burst particles
end

function ExitPortal:draw()
    local cfg = Config.VOID_CORE
    local colors = cfg.colors
    local ps = self.pixelSize
    local t = self.time
    local radius = self.size
    local effectiveRadius = radius

    -- 1. Draw shadow
    local shadowCfg = cfg.shadow
    love.graphics.setColor(0, 0, 0, shadowCfg.alpha)
    love.graphics.ellipse("fill", self.x, self.y + radius * shadowCfg.offsetY,
        radius * shadowCfg.width, radius * shadowCfg.height)

    -- 2. Draw gravity particles (behind main body)
    self:drawGravityParticles()

    -- 3. Draw organic boundary (pixel-pool approach like Void)
    local wobbleTime = t * cfg.wobbleSpeed
    local sparkleTimeX = math.floor(t * 8)
    local sparkleTimeY = math.floor(t * 5)

    for _, p in ipairs(self.pixels) do
        local wobbleNoise = math.sin(wobbleTime + p.wobblePhase) * 0.5 + 0.5
        local animatedEdgeRadius = effectiveRadius * (0.7 + p.baseEdgeNoise * 0.5 + wobbleNoise * cfg.wobbleAmount * 0.3)

        if p.dist >= animatedEdgeRadius then
            goto continue
        end

        local isEdge = p.dist > animatedEdgeRadius - ps * 1.5
        local screenX = self.x + p.relX - ps / 2
        local screenY = self.y + p.relY - ps / 2

        -- Check if in squared core region
        local inCore = math.abs(p.relX) < cfg.coreSize and math.abs(p.relY) < cfg.coreSize

        local r, g, b

        -- Sparkles
        local sparkle = Procedural.hash(p.px + sparkleTimeX, p.py + sparkleTimeY, self.seed + 333)
        if sparkle > cfg.sparkleThreshold then
            r, g, b = colors.sparkle[1], colors.sparkle[2], colors.sparkle[3]
        elseif inCore then
            -- Deep void core (very dark)
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

        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", screenX, screenY, ps, ps)

        ::continue::
    end
end

function ExitPortal:drawGravityParticles()
    local cfg = Config.VOID_CORE
    local pcfg = cfg.particles
    local ps = pcfg.size

    for _, p in ipairs(self.gravityParticles) do
        local x = self.x + math.cos(p.angle) * p.dist
        local y = self.y + math.sin(p.angle) * p.dist
        local distNorm = p.dist / (self.size * pcfg.spawnRadius)
        -- Stronger alpha for more visible trails, brighter when far, still visible when close
        local alpha = p.brightness * (0.3 + distNorm * 0.7)

        -- Brighter color with slight additive feel
        love.graphics.setColor(pcfg.color[1], pcfg.color[2], pcfg.color[3], alpha)
        love.graphics.rectangle("fill", x - ps/2, y - ps/2, ps, ps)

        -- Add a subtle glow/trail behind each particle
        if distNorm > 0.3 then
            local glowAlpha = alpha * 0.3
            love.graphics.setColor(pcfg.color[1], pcfg.color[2], pcfg.color[3], glowAlpha)
            love.graphics.rectangle("fill", x - ps, y - ps, ps * 2, ps * 2)
        end
    end
end

-- Draw tear effects for exiting creeps (simplified - no tears)
function ExitPortal:drawTears()
    -- No tear effects - creeps just get sucked into the void
end

-- Draw a single tear/rift (no longer used)
function ExitPortal:drawSingleTear(cx, cy, progress)
    -- No tears
end

-- Draw spark particles (simplified - no longer used)
function ExitPortal:drawExitParticles()
    -- No particles
end

-- Draw breach effects (simplified - no longer used)
function ExitPortal:drawBreachEffects()
    -- No tendrils
end

-- Get light parameters for the lighting system (purple glow)
function ExitPortal:getLightParams()
    -- Purple light color (matches void core theme)
    local color = {0.6, 0.3, 0.8}

    -- Calculate pulsing intensity
    local minIntensity = 1.5
    local maxIntensity = 2.5
    local pulse1 = math.sin(self.time * 2) * 0.5 + 0.5
    local pulse2 = math.sin(self.time * 3.7) * 0.3 + 0.7
    local pulse = pulse1 * pulse2
    local intensity = minIntensity + (maxIntensity - minIntensity) * pulse

    return {
        x = self.x,
        y = self.y,
        radius = 400,
        color = color,
        intensity = intensity,
        pulse = true,
        pulseSpeed = 2.5,
        pulseAmount = 0.4,
    }
end

return ExitPortal
