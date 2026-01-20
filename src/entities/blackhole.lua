-- src/entities/blackhole.lua
-- Blackhole entity (for Void Eye tower)
-- Pulls enemies toward center, no damage

local Object = require("lib.classic")
local Config = require("src.config")

local Blackhole = Object:extend()

function Blackhole:new(x, y, sourceTower)
    self.x = x
    self.y = y
    self.sourceTower = sourceTower

    local cfg = Config.TOWER_ATTACKS.void_eye
    self.radius = cfg.blackholeRadius
    self.pullStrength = cfg.blackholePullStrength
    self.pullFalloff = cfg.blackholePullFalloff
    self.visualSize = cfg.blackholeVisualSize
    self.duration = cfg.blackholeDuration

    self.remaining = self.duration
    self.time = 0
    self.dead = false

    -- Gravity dust particles (similar to tower build animation)
    self.particles = {}
    self:spawnInitialParticles()
end

function Blackhole:spawnInitialParticles()
    -- Spawn particles at the outer edge that get pulled in
    for i = 1, 16 do
        self:spawnParticle()
    end
end

function Blackhole:spawnParticle()
    local angle = math.random() * math.pi * 2
    local dist = self.radius * (0.6 + math.random() * 0.4)
    table.insert(self.particles, {
        x = self.x + math.cos(angle) * dist,
        y = self.y + math.sin(angle) * dist,
        angle = angle,
        dist = dist,
        speed = 30 + math.random() * 40,  -- Pull speed
        size = 2 + math.random() * 2,
        brightness = 0.4 + math.random() * 0.4,
    })
end

function Blackhole:update(dt, creeps)
    self.time = self.time + dt
    self.remaining = self.remaining - dt

    if self.remaining <= 0 then
        self.dead = true
        return
    end

    -- Update gravity dust particles
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        -- Pull toward center
        p.dist = p.dist - p.speed * dt

        -- Update position
        p.x = self.x + math.cos(p.angle) * p.dist
        p.y = self.y + math.sin(p.angle) * p.dist

        -- Respawn when reaching center
        if p.dist < self.visualSize * 0.5 then
            table.remove(self.particles, i)
            self:spawnParticle()
        end
    end

    -- Pull creeps toward center (no damage)
    for _, creep in ipairs(creeps) do
        if not creep.dead and not creep.dying and not creep:isSpawning() then
            local dx = self.x - creep.x
            local dy = self.y - creep.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= self.radius and dist > 1 then
                local normalizedDist = dist / self.radius
                local strength = self.pullStrength * math.pow(1 - normalizedDist, self.pullFalloff)

                local dirX = dx / dist
                local dirY = dy / dist
                creep.x = creep.x + dirX * strength * dt
                creep.y = creep.y + dirY * strength * dt
            end
        end
    end
end

function Blackhole:draw()
    local ps = 3  -- Pixel size
    local colors = {
        core = { 0.02, 0.01, 0.04 },
        edge = { 0.75, 0.45, 0.95 },
    }

    -- Fade in/out
    local fadeAlpha = 1
    local fadeTime = 0.3
    if self.time < fadeTime then
        fadeAlpha = self.time / fadeTime
    elseif self.remaining < fadeTime then
        fadeAlpha = self.remaining / fadeTime
    end

    -- Draw gravity dust particles being pulled in
    for _, p in ipairs(self.particles) do
        local distNorm = p.dist / self.radius
        local alpha = fadeAlpha * p.brightness * distNorm
        love.graphics.setColor(colors.edge[1], colors.edge[2], colors.edge[3], alpha)
        love.graphics.rectangle("fill", p.x - ps/2, p.y - ps/2, ps, ps)
    end

    -- Draw pixelated center void
    local gridR = math.ceil(self.visualSize / ps)
    for py = -gridR, gridR do
        for px = -gridR, gridR do
            local dist = math.sqrt(px * px + py * py) * ps
            if dist <= self.visualSize then
                local worldX = self.x + px * ps - ps / 2
                local worldY = self.y + py * ps - ps / 2
                local distNorm = dist / self.visualSize

                -- Dark core with purple edge
                if distNorm > 0.5 then
                    local edgeFactor = (distNorm - 0.5) / 0.5
                    local pulse = math.sin(self.time * 4 + math.atan2(py, px) * 2) * 0.2 + 0.8
                    love.graphics.setColor(
                        colors.edge[1] * edgeFactor * pulse,
                        colors.edge[2] * edgeFactor * pulse,
                        colors.edge[3] * edgeFactor * pulse,
                        fadeAlpha
                    )
                else
                    love.graphics.setColor(colors.core[1], colors.core[2], colors.core[3], fadeAlpha)
                end
                love.graphics.rectangle("fill", worldX, worldY, ps, ps)
            end
        end
    end
end

function Blackhole:getLightParams()
    local progress = self.remaining / self.duration
    return {
        x = self.x,
        y = self.y,
        radius = self.radius * 0.5,
        color = { 0.75, 0.45, 0.95 },
        intensity = 0.5 * progress,
        flicker = false,
    }
end

return Blackhole
