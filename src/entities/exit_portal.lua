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

    -- Exit/breach tracking (keep existing)
    self.activeExits = {}
    self.exitParticles = {}
    self.breachTendrils = {}
    self.surgePulse = 0
    self.surgeTimer = 0

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

    -- Update surge pulse
    if self.surgeTimer > 0 then
        self.surgeTimer = self.surgeTimer - dt
        self.surgePulse = self.surgeTimer / 0.4
    else
        self.surgePulse = 0
    end

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

    -- Update particles
    for i = #self.exitParticles, 1, -1 do
        local p = self.exitParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        -- Gravity for burst particles
        if p.type == "burst" then
            p.vy = p.vy + 150 * dt
        end
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.exitParticles, i)
        end
    end

    -- Update tendrils
    for i = #self.breachTendrils, 1, -1 do
        local t = self.breachTendrils[i]
        -- Tendrils extend quickly then retract
        local lifeProgress = 1 - (t.life / t.maxLife)
        if lifeProgress < 0.3 then
            t.progress = lifeProgress / 0.3  -- Extend
        else
            t.progress = 1 - ((lifeProgress - 0.3) / 0.7)  -- Retract
        end
        t.life = t.life - dt
        if t.life <= 0 then
            table.remove(self.breachTendrils, i)
        end
    end
end

-- Register a creep that is exiting for tear effect rendering
function ExitPortal:registerExit(creep)
    table.insert(self.activeExits, creep)

    -- Trigger breach effects
    self:triggerBreach(creep.x, creep.y)
end

-- Trigger dramatic breach effects when a creep enters
function ExitPortal:triggerBreach(creepX, creepY)
    -- Add void tendrils reaching toward the breach point
    local tendrilCount = 4 + math.random(3)
    for i = 1, tendrilCount do
        local angle = (i / tendrilCount) * math.pi * 2 + math.random() * 0.5
        table.insert(self.breachTendrils, {
            startX = self.x,
            startY = self.y,
            targetX = creepX + math.cos(angle) * 20,
            targetY = creepY + math.sin(angle) * 20,
            angle = angle,
            progress = 0,
            life = 0.5 + math.random() * 0.3,
            maxLife = 0.8,
            seed = math.random(1000),
            width = 3 + math.random() * 2,
        })
    end

    -- Trigger portal surge
    self.surgePulse = 1.0
    self.surgeTimer = 0.4

    -- Spawn burst of particles
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2 + math.random() * 0.3
        local speed = 80 + math.random() * 60
        table.insert(self.exitParticles, {
            x = creepX,
            y = creepY,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.4 + math.random() * 0.3,
            maxLife = 0.7,
            size = 3 + math.random() * 3,
            type = "burst",
        })
    end
end

function ExitPortal:draw()
    local cfg = Config.VOID_CORE
    local colors = cfg.colors
    local ps = self.pixelSize
    local t = self.time
    local radius = self.size

    -- Apply surge boost
    local surgeBoost = self.surgePulse * 0.15
    local effectiveRadius = radius * (1 + surgeBoost)

    -- 1. Draw shadow
    local shadowCfg = cfg.shadow
    love.graphics.setColor(0, 0, 0, shadowCfg.alpha)
    love.graphics.ellipse("fill", self.x, self.y + radius * shadowCfg.offsetY,
        radius * shadowCfg.width, radius * shadowCfg.height)

    -- Draw surge glow behind portal (purple)
    if self.surgePulse > 0 then
        love.graphics.setBlendMode("add")
        local glowAlpha = self.surgePulse * 0.6
        love.graphics.setColor(0.5, 0.2, 0.7, glowAlpha * 0.3)
        love.graphics.circle("fill", self.x, self.y, radius * 2.5)
        love.graphics.setColor(0.9, 0.7, 0.3, glowAlpha * 0.5)
        love.graphics.circle("fill", self.x, self.y, radius * 1.8)
        love.graphics.setBlendMode("alpha")
    end

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

-- Draw tear effects for exiting creeps
function ExitPortal:drawTears()
    for _, creep in ipairs(self.activeExits) do
        local tearProgress = creep:getExitTearProgress()
        if tearProgress > 0 then
            self:drawSingleTear(creep.exitX, creep.exitY, tearProgress)
        end
    end
end

-- Draw a single tear/rift at the given position (RED version)
function ExitPortal:drawSingleTear(cx, cy, progress)
    local cfg = Config.EXIT_ANIMATION
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

            -- Outer edge glow (orange-red)
            if dist > jaggedThreshold - 0.3 then
                local pulse = math.sin(t * 4 + py * 0.5) * 0.3 + 0.7
                r = colors.edge[1] * pulse
                g = colors.edge[2] * pulse
                b = colors.edge[3] * pulse
                a = progress
            -- Inner glow (warm orange-white)
            elseif dist > 0.3 then
                local blend = (dist - 0.3) / (jaggedThreshold - 0.3 - 0.3)
                r = colors.inner[1] * (1 - blend * 0.3)
                g = colors.inner[2] * (1 - blend * 0.4)
                b = colors.inner[3] * (1 - blend * 0.5)
                a = progress
            else
                -- Core: dark red void
                local n = Procedural.fbm(px * 0.2 + t * 0.5, py * 0.4 + t * 0.3, self.seed + 600, 2)
                r = colors.void[1] + n * 0.08
                g = colors.void[2] + n * 0.02
                b = colors.void[3] + n * 0.02
                a = progress
            end

            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", screenX, screenY, ps, ps)

            ::continue::
        end
    end
end

-- Draw spark particles from breach (gold/purple)
function ExitPortal:drawExitParticles()
    local cfg = Config.EXIT_ANIMATION.particles

    for _, p in ipairs(self.exitParticles) do
        local alpha = p.life / p.maxLife
        local ps = p.size or cfg.size

        if p.type == "burst" then
            -- Burst particles: gold/purple embers
            love.graphics.setBlendMode("add")
            -- Purple outer glow
            love.graphics.setColor(0.6, 0.25, 0.8, alpha * 0.4)
            love.graphics.circle("fill", p.x, p.y, ps * 2)
            -- Gold core
            love.graphics.setColor(1.0, 0.85, 0.4, alpha * 0.8)
            love.graphics.rectangle("fill", p.x - ps / 2, p.y - ps / 2, ps, ps)
            -- Bright gold center
            love.graphics.setColor(1.0, 0.95, 0.7, alpha)
            love.graphics.rectangle("fill", p.x - ps / 4, p.y - ps / 4, ps / 2, ps / 2)
            love.graphics.setBlendMode("alpha")
        else
            -- Regular tear particles (gold)
            love.graphics.setColor(1.0, 0.85, 0.4, alpha)
            love.graphics.rectangle("fill", p.x - ps / 2, p.y - ps / 2, ps, ps)
        end
    end
end

-- Draw breach effects (tendrils reaching out from portal - purple with gold core)
function ExitPortal:drawBreachEffects()
    -- Draw tendrils
    for _, t in ipairs(self.breachTendrils) do
        if t.progress > 0 then
            local alpha = t.life / t.maxLife

            -- Calculate tendril endpoint based on progress
            local dx = t.targetX - t.startX
            local dy = t.targetY - t.startY
            local endX = t.startX + dx * t.progress
            local endY = t.startY + dy * t.progress

            -- Draw tendril as jagged lightning-like line
            local segments = 6
            local prevX, prevY = t.startX, t.startY

            love.graphics.setBlendMode("add")
            for i = 1, segments do
                local segProgress = i / segments
                if segProgress > t.progress then break end

                local segX = t.startX + dx * segProgress
                local segY = t.startY + dy * segProgress

                -- Add jaggedness
                if i < segments then
                    local jag = math.sin(segProgress * 10 + t.seed + self.time * 8) * 8
                    local perpX = -dy / (math.sqrt(dx*dx + dy*dy) + 0.1)
                    local perpY = dx / (math.sqrt(dx*dx + dy*dy) + 0.1)
                    segX = segX + perpX * jag
                    segY = segY + perpY * jag
                end

                -- Purple glow (outer)
                love.graphics.setColor(0.5, 0.2, 0.7, alpha * 0.4)
                love.graphics.setLineWidth(t.width * 2)
                love.graphics.line(prevX, prevY, segX, segY)

                -- Gold core
                love.graphics.setColor(1.0, 0.8, 0.3, alpha * 0.8)
                love.graphics.setLineWidth(t.width)
                love.graphics.line(prevX, prevY, segX, segY)

                -- Bright gold center
                love.graphics.setColor(1.0, 0.95, 0.6, alpha)
                love.graphics.setLineWidth(1)
                love.graphics.line(prevX, prevY, segX, segY)

                prevX, prevY = segX, segY
            end
            love.graphics.setBlendMode("alpha")
        end
    end

    love.graphics.setLineWidth(1)
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
