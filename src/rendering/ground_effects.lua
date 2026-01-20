-- src/rendering/ground_effects.lua
-- Procedural rendering for ground effects (poison cloud, burning ground)

local Config = require("src.config")
local Procedural = require("src.rendering.procedural")

local GroundEffects = {}

-- Perspective scale for ground effects (0.9 = 10% Y compression for subtle depth)
local PERSPECTIVE_Y_SCALE = 0.9

-- Draw a poison cloud effect
-- @param x, y: Center position
-- @param radius: Effect radius
-- @param progress: Remaining life (1 = full, 0 = expired) for fade
-- @param time: Animation time
-- @param seed: Random seed for this effect
function GroundEffects.drawPoisonCloud(x, y, radius, progress, time, seed)
    local cfg = Config.GROUND_EFFECTS.poison_cloud
    local colors = cfg.colors
    local ps = cfg.pixelSize

    -- Alpha fade based on remaining life
    local alpha = progress

    -- Generate pixel grid for the cloud (expanded for perspective)
    local gridSize = math.ceil(radius * 2 / ps)
    local halfGrid = gridSize / 2

    for py = 0, gridSize - 1 do
        for px = 0, gridSize - 1 do
            local relX = (px - halfGrid + 0.5) * ps
            local relY = (py - halfGrid + 0.5) * ps
            -- Use elliptical distance for perspective (scale Y for distance calc)
            local dist = math.sqrt(relX * relX + (relY / PERSPECTIVE_Y_SCALE) * (relY / PERSPECTIVE_Y_SCALE))
            local angle = math.atan2(relY / PERSPECTIVE_Y_SCALE, relX)

            -- Skip pixels outside radius
            if dist > radius then
                goto continue
            end

            -- Animated boundary wobble
            local wobbleNoise = Procedural.fbm(
                angle * 3 + time * cfg.wobbleSpeed,
                time * cfg.wobbleSpeed * 0.5,
                seed,
                2
            )
            local edgeRadius = radius * (0.8 + wobbleNoise * cfg.wobbleAmount)

            if dist > edgeRadius then
                goto continue
            end

            -- Noise for swirling effect
            local n1 = Procedural.fbm(px * 0.2 + time * 0.5, py * 0.2 + time * 0.3, seed, 3)
            local n2 = Procedural.smoothNoise(px * 0.3 - time * 0.4, py * 0.3 + time * 0.2, seed + 50)

            -- Distance from center (normalized)
            local distNorm = dist / radius

            -- Color blend based on distance and noise
            local r, g, b, a

            if distNorm > 0.7 then
                -- Edge: bright green glow
                local pulse = math.sin(time * cfg.pulseSpeed + angle * 2) * 0.2 + 0.8
                r = colors.edge[1] * pulse
                g = colors.edge[2] * pulse
                b = colors.edge[3] * pulse
                a = colors.edge[4] * alpha * (1 - (distNorm - 0.7) / 0.3)
            elseif distNorm > 0.4 then
                -- Mid: swirling green
                local blend = n1 * 0.5 + n2 * 0.5
                r = colors.mid[1] + blend * 0.1
                g = colors.mid[2] + blend * 0.15
                b = colors.mid[3] + blend * 0.05
                a = colors.mid[4] * alpha
            else
                -- Core: dark green
                r = colors.core[1] + n1 * 0.05
                g = colors.core[2] + n1 * 0.1
                b = colors.core[3] + n1 * 0.03
                a = colors.core[4] * alpha
            end

            -- Draw pixel (apply perspective compression to Y)
            local screenX = x + relX - ps / 2
            local screenY = y + relY * PERSPECTIVE_Y_SCALE - ps / 2
            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", screenX, screenY, ps, ps)

            ::continue::
        end
    end
end

-- Draw a burning ground effect
-- @param x, y: Center position
-- @param radius: Effect radius
-- @param progress: Remaining life (1 = full, 0 = expired) for fade
-- @param time: Animation time
-- @param seed: Random seed for this effect
function GroundEffects.drawBurningGround(x, y, radius, progress, time, seed)
    local cfg = Config.GROUND_EFFECTS.burning_ground
    local colors = cfg.colors
    local ps = cfg.pixelSize

    -- Alpha fade based on remaining life
    local alpha = progress

    -- Generate pixel grid for the fire
    local gridSize = math.ceil(radius * 2 / ps)
    local halfGrid = gridSize / 2

    for py = 0, gridSize - 1 do
        for px = 0, gridSize - 1 do
            local relX = (px - halfGrid + 0.5) * ps
            local relY = (py - halfGrid + 0.5) * ps
            -- Use elliptical distance for perspective (scale Y for distance calc)
            local dist = math.sqrt(relX * relX + (relY / PERSPECTIVE_Y_SCALE) * (relY / PERSPECTIVE_Y_SCALE))
            local angle = math.atan2(relY / PERSPECTIVE_Y_SCALE, relX)

            -- Skip pixels outside radius
            if dist > radius then
                goto continue
            end

            -- Animated flickering boundary
            local flickerNoise = Procedural.fbm(
                angle * 4 + time * cfg.flickerSpeed,
                time * cfg.flickerSpeed * 0.7,
                seed,
                2
            )
            local edgeRadius = radius * (0.7 + flickerNoise * 0.4)

            if dist > edgeRadius then
                goto continue
            end

            -- Noise for fire animation
            local n1 = Procedural.fbm(px * 0.25 + time * 1.5, py * 0.25 - time * 2.0, seed, 3)
            local n2 = Procedural.smoothNoise(px * 0.4 + time * 0.8, py * 0.4 - time * 1.5, seed + 100)

            -- Distance from center (normalized)
            local distNorm = dist / radius

            -- Color blend based on distance and noise
            local r, g, b, a

            -- Fire flicker
            local flicker = Procedural.hash(px + math.floor(time * cfg.flickerSpeed), py + math.floor(time * 3), seed + 200)

            if distNorm > 0.6 then
                -- Edge: bright orange flames
                local pulse = math.sin(time * cfg.pulseSpeed + angle * 3) * 0.3 + 0.7
                r = colors.edge[1] * pulse
                g = colors.edge[2] * pulse * (0.8 + flicker * 0.4)
                b = colors.edge[3] * pulse
                a = colors.edge[4] * alpha * (1 - (distNorm - 0.6) / 0.4)
            elseif distNorm > 0.3 then
                -- Mid: orange-red fire
                local blend = n1 * 0.6 + n2 * 0.4
                r = colors.mid[1] + blend * 0.2
                g = colors.mid[2] + blend * 0.15 * flicker
                b = colors.mid[3] + blend * 0.05
                a = colors.mid[4] * alpha
            else
                -- Core: dark red embers
                r = colors.core[1] + n1 * 0.15
                g = colors.core[2] + n1 * 0.08
                b = colors.core[3] + n1 * 0.02
                a = colors.core[4] * alpha
            end

            -- Draw pixel (apply perspective compression to Y)
            local screenX = x + relX - ps / 2
            local screenY = y + relY * PERSPECTIVE_Y_SCALE - ps / 2
            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", screenX, screenY, ps, ps)

            ::continue::
        end
    end
end

-- Draw chain lightning between two points
-- @param x1, y1: Start position
-- @param x2, y2: End position
-- @param progress: Animation progress (1 = full, 0 = faded)
-- @param seed: Random seed for jagged path
function GroundEffects.drawChainLightning(x1, y1, x2, y2, progress, seed)
    local cfg = Config.GROUND_EFFECTS.chain_lightning
    local color = cfg.color
    local glowColor = cfg.glowColor

    local alpha = progress

    -- Generate jagged lightning path
    local segments = cfg.segments
    local points = {}

    for i = 0, segments do
        local t = i / segments
        local baseX = x1 + (x2 - x1) * t
        local baseY = y1 + (y2 - y1) * t

        -- Add jaggedness (except at endpoints)
        local jag = 0
        if i > 0 and i < segments then
            jag = (Procedural.hash(i, seed, seed + 123) - 0.5) * cfg.jaggedness * 2
        end

        -- Perpendicular offset
        local dx = x2 - x1
        local dy = y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            local perpX = -dy / len
            local perpY = dx / len
            baseX = baseX + perpX * jag
            baseY = baseY + perpY * jag
        end

        table.insert(points, {x = baseX, y = baseY})
    end

    -- Draw glow
    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4] * alpha)
    love.graphics.setLineWidth(6)
    for i = 1, #points - 1 do
        love.graphics.line(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y)
    end

    -- Draw core lightning
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.setLineWidth(2)
    for i = 1, #points - 1 do
        love.graphics.line(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y)
    end

    -- Draw bright center
    love.graphics.setColor(1, 1, 1, alpha * 0.8)
    love.graphics.setLineWidth(1)
    for i = 1, #points - 1 do
        love.graphics.line(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y)
    end

    love.graphics.setLineWidth(1)
end

-- Draw beam attack (for void_eye)
-- @param x1, y1: Tower position
-- @param x2, y2: Target position
-- @param isCharging: True if charging, false if firing
-- @param progress: Charge progress (0-1) or fire progress (1-0)
function GroundEffects.drawBeam(x1, y1, x2, y2, isCharging, progress)
    local cfg = Config.GROUND_EFFECTS.beam

    if isCharging then
        -- Charging: thin targeting laser sight
        local alpha = progress * 0.5 + 0.2
        local pulse = math.sin(love.timer.getTime() * 10) * 0.2 + 0.8

        -- Dotted line effect
        love.graphics.setColor(cfg.chargeColor[1], cfg.chargeColor[2], cfg.chargeColor[3], alpha * pulse)
        love.graphics.setLineWidth(cfg.chargeWidth)

        -- Draw dashed line
        local dx = x2 - x1
        local dy = y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        local dashLen = 8
        local gapLen = 4
        local totalDash = dashLen + gapLen

        local nx, ny = dx / len, dy / len
        local currentLen = 0

        while currentLen < len do
            local dashEnd = math.min(currentLen + dashLen, len)
            local startX = x1 + nx * currentLen
            local startY = y1 + ny * currentLen
            local endX = x1 + nx * dashEnd
            local endY = y1 + ny * dashEnd
            love.graphics.line(startX, startY, endX, endY)
            currentLen = currentLen + totalDash
        end
    else
        -- Firing: thick beam
        local alpha = progress

        -- Outer glow
        love.graphics.setColor(cfg.chargeColor[1], cfg.chargeColor[2], cfg.chargeColor[3], alpha * 0.3)
        love.graphics.setLineWidth(cfg.glowWidth)
        love.graphics.line(x1, y1, x2, y2)

        -- Main beam
        love.graphics.setColor(cfg.fireColor[1], cfg.fireColor[2], cfg.fireColor[3], alpha)
        love.graphics.setLineWidth(cfg.fireWidth)
        love.graphics.line(x1, y1, x2, y2)

        -- Bright core
        love.graphics.setColor(1, 1, 1, alpha * 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.line(x1, y1, x2, y2)
    end

    love.graphics.setLineWidth(1)
end

-- Draw slow aura ring (for void_ring)
-- @param x, y: Tower position
-- @param radius: Aura radius
-- @param time: Animation time
function GroundEffects.drawSlowAura(x, y, radius, time)
    local slowCfg = Config.STATUS_EFFECTS.slow
    local color = slowCfg.color

    -- Pulsing alpha
    local pulse = math.sin(time * 2) * 0.1 + 0.2

    -- Draw filled aura
    love.graphics.setColor(color[1], color[2], color[3], pulse * 0.15)
    love.graphics.circle("fill", x, y, radius)

    -- Draw ring outline
    local ringPulse = math.sin(time * 3) * 0.15 + 0.35
    love.graphics.setColor(color[1], color[2], color[3], ringPulse)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y, radius)

    -- Draw inner frost particles
    local particleCount = 8
    for i = 1, particleCount do
        local angle = (i / particleCount) * math.pi * 2 + time * 0.5
        local dist = radius * 0.6 + math.sin(time * 2 + i) * radius * 0.2
        local px = x + math.cos(angle) * dist
        local py = y + math.sin(angle) * dist
        local particleAlpha = math.sin(time * 4 + i * 0.5) * 0.2 + 0.3
        love.graphics.setColor(color[1], color[2], color[3], particleAlpha)
        love.graphics.circle("fill", px, py, 3)
    end

    love.graphics.setLineWidth(1)
end

return GroundEffects
