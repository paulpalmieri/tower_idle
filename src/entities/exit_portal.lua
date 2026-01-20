-- src/entities/exit_portal.lua
-- Red exit portal at the base zone
-- Uses same procedural pixel art rendering as Void, but with red colors

local Object = require("lib.classic")
local Config = require("src.config")
local Procedural = require("src.rendering.procedural")
local Settings = require("src.ui.settings")

local ExitPortal = Object:extend()

function ExitPortal:new(x, y)
    -- Position (center of portal)
    self.x = x
    self.y = y

    -- Size state
    self.size = Config.EXIT_PORTAL.baseSize

    -- Pixel art scale (size of each "pixel")
    self.pixelSize = Config.EXIT_PORTAL.pixelSize

    -- Animation state
    self.time = 0

    -- Unique seed for procedural effects
    self.seed = math.random(1000) + 5000  -- Different seed range from Void

    -- Exit animation tracking
    self.activeExits = {}
    self.exitParticles = {}

    -- Breach effect tracking
    self.breachTendrils = {}     -- Void tendrils reaching out
    self.surgePulse = 0          -- Portal surge intensity (0-1)
    self.surgeTimer = 0

    -- Generate pixel pool for creep-style rendering
    self:generatePixels()
end

-- Generate pixel pool for creep-style rendering (same approach as Void)
function ExitPortal:generatePixels()
    self.pixels = {}
    local ps = self.pixelSize
    local radius = self.size
    local cfg = Config.EXIT_PORTAL

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

            -- Pre-compute wobble phase offset (OPTIMIZATION)
            local wobblePhase = Procedural.fbm(
                angle * cfg.wobbleFrequency,
                0,
                self.seed + 500,
                2
            ) * math.pi * 2

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
                    wobblePhase = wobblePhase,
                    rnd = Procedural.hash(px, py, self.seed + 888),
                    rnd2 = Procedural.hash(px * 2.1, py * 1.7, self.seed + 777),
                })
            end
        end
    end
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
    local cfg = Config.EXIT_PORTAL
    local colors = cfg.colors
    local ps = self.pixelSize
    local t = self.time
    local radius = self.size

    -- Apply surge pulse to radius
    local surgeBoost = self.surgePulse * 0.3
    local effectiveRadius = radius * (1 + surgeBoost)

    -- Draw shadow below portal (larger during surge)
    local shadowCfg = cfg.shadow
    love.graphics.setColor(0, 0, 0, shadowCfg.alpha * (1 + self.surgePulse * 0.5))
    local shadowWidth = effectiveRadius * shadowCfg.width
    local shadowHeight = effectiveRadius * shadowCfg.height
    local shadowY = self.y + effectiveRadius * shadowCfg.offsetY
    love.graphics.ellipse("fill", self.x, shadowY, shadowWidth, shadowHeight)

    -- Draw surge glow behind portal
    if self.surgePulse > 0 then
        love.graphics.setBlendMode("add")
        local glowAlpha = self.surgePulse * 0.6
        love.graphics.setColor(1, 0.3, 0.1, glowAlpha * 0.3)
        love.graphics.circle("fill", self.x, self.y, effectiveRadius * 2.5)
        love.graphics.setColor(1, 0.5, 0.2, glowAlpha * 0.5)
        love.graphics.circle("fill", self.x, self.y, effectiveRadius * 1.8)
        love.graphics.setBlendMode("alpha")
    end

    -- Draw each pixel with animated void effects (matching Void:draw)
    for _, p in ipairs(self.pixels) do
        -- Calculate animated edge boundary using pre-computed wobblePhase (OPTIMIZED)
        local wobbleNoise = math.sin(t * cfg.wobbleSpeed + p.wobblePhase) * 0.5 + 0.5
        local animatedEdgeRadius = radius * (0.7 + p.baseEdgeNoise * 0.5 + wobbleNoise * cfg.wobbleAmount * 0.3)

        -- Skip pixels outside the current animated boundary
        if p.dist >= animatedEdgeRadius then
            goto continue
        end

        -- Determine if this pixel is near the edge (for glow effect)
        local isEdge = p.dist > animatedEdgeRadius - ps * 1.5

        -- Calculate screen position
        local screenX = self.x + p.relX - ps / 2
        local screenY = self.y + p.relY - ps / 2

        -- Animated noise layers
        local n1 = Procedural.fbm(p.px * 0.3 + t * 0.8, p.py * 0.3 + t * 0.2, self.seed, 3)
        local n2 = Procedural.fbm(p.px * 0.2 - t * 0.4, p.py * 0.4 + t * 0.6, self.seed + 50, 2)
        local n3 = Procedural.hash(p.px + math.floor(t * 4), p.py, self.seed + 111)

        -- Swirling pattern
        local swirl = math.sin(p.angle * 3 + t * cfg.swirlSpeed + p.distNorm * 4) * 0.5 + 0.5

        -- Random sparkles
        local sparkle = Procedural.hash(p.px + math.floor(t * 8), p.py + math.floor(t * 5), self.seed + 333)
        local sparkleThreshold = cfg.sparkleThreshold or 0.92
        local isSpark = sparkle > sparkleThreshold

        -- Color calculation (RED palette)
        local r, g, b

        if isSpark then
            -- Bright sparkle (warm white)
            r, g, b = colors.sparkle[1], colors.sparkle[2], colors.sparkle[3]
        elseif isEdge then
            -- Edge glow - bright orange-red
            local pulse = math.sin(t * cfg.pulseSpeed + p.angle * 2) * 0.3 + 0.7
            r = colors.edgeGlow[1] * pulse
            g = colors.edgeGlow[2] * pulse
            b = colors.edgeGlow[3] * pulse
        else
            -- Interior void texture (red instead of purple)
            local v = n1 * 0.5 + n2 * 0.3 + swirl * 0.2

            -- Interpolate between core and mid based on noise and distance
            local blend = v + p.distNorm * 0.3
            r = colors.core[1] + (colors.mid[1] - colors.core[1]) * blend + p.rnd * 0.08
            g = colors.core[2] + (colors.mid[2] - colors.core[2]) * blend + p.rnd2 * 0.02
            b = colors.core[3] + (colors.mid[3] - colors.core[3]) * blend + p.rnd * 0.02

            -- Random darker spots
            if p.rnd > 0.85 then
                r, g, b = r * 0.6, g * 0.4, b * 0.4
            end

            -- Random brighter red/orange tints
            if p.rnd2 > 0.8 then
                r = r + 0.12
                g = g + 0.04
            end

            -- Vertical tear streaks
            local tear = Procedural.fbm(p.px * 0.1, p.py * 0.5 + t * 0.5, self.seed + 200, 2)
            if tear > 0.58 and p.rnd > 0.4 then
                local bright = (tear - 0.58) * 2 + n3 * 0.2
                r = r + bright * 0.4
                g = g + bright * 0.15
            end
        end

        -- Pulsing glow
        local pulse = math.sin(t * cfg.pulseSpeed + p.distNorm * 3 + p.rnd * 4) * 0.06
        r = math.max(0, math.min(1, r + pulse))
        g = math.max(0, math.min(1, g + pulse * 0.3))

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

-- Draw spark particles from tear edges (orange-red)
function ExitPortal:drawExitParticles()
    local cfg = Config.EXIT_ANIMATION.particles

    for _, p in ipairs(self.exitParticles) do
        local alpha = p.life / p.maxLife
        local ps = p.size or cfg.size

        if p.type == "burst" then
            -- Burst particles: bright glowing embers
            love.graphics.setBlendMode("add")
            -- Outer glow
            love.graphics.setColor(1, 0.3, 0.1, alpha * 0.4)
            love.graphics.circle("fill", p.x, p.y, ps * 2)
            -- Core
            love.graphics.setColor(1, 0.6, 0.3, alpha * 0.8)
            love.graphics.rectangle("fill", p.x - ps / 2, p.y - ps / 2, ps, ps)
            -- Bright center
            love.graphics.setColor(1, 0.9, 0.6, alpha)
            love.graphics.rectangle("fill", p.x - ps / 4, p.y - ps / 4, ps / 2, ps / 2)
            love.graphics.setBlendMode("alpha")
        else
            -- Regular tear particles
            love.graphics.setColor(cfg.color[1], cfg.color[2], cfg.color[3], alpha)
            love.graphics.rectangle("fill", p.x - ps / 2, p.y - ps / 2, ps, ps)
        end
    end
end

-- Draw breach effects (tendrils reaching out from portal)
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

                -- Glow
                love.graphics.setColor(1, 0.3, 0.1, alpha * 0.4)
                love.graphics.setLineWidth(t.width * 2)
                love.graphics.line(prevX, prevY, segX, segY)

                -- Core
                love.graphics.setColor(1, 0.6, 0.3, alpha * 0.8)
                love.graphics.setLineWidth(t.width)
                love.graphics.line(prevX, prevY, segX, segY)

                -- Bright center
                love.graphics.setColor(1, 0.9, 0.7, alpha)
                love.graphics.setLineWidth(1)
                love.graphics.line(prevX, prevY, segX, segY)

                prevX, prevY = segX, segY
            end
            love.graphics.setBlendMode("alpha")
        end
    end

    love.graphics.setLineWidth(1)
end

-- Get light parameters for the lighting system (red glow)
function ExitPortal:getLightParams()
    local lightingCfg = Config.LIGHTING

    -- Red light color
    local color = {1.0, 0.35, 0.2}

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
