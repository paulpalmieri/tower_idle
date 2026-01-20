-- src/entities/poison_cloud.lua
-- Poison cloud ground effect entity (from void_orb projectile impact)

local Object = require("lib.classic")
local Config = require("src.config")
local StatusEffects = require("src.systems.status_effects")
local GroundEffects = require("src.rendering.ground_effects")
local EventBus = require("src.core.event_bus")

local PoisonCloud = Object:extend()

-- Unique seed counter for each cloud instance
local seedCounter = 0


function PoisonCloud:new(x, y)
    self.x = x
    self.y = y

    -- Get config from tower attack settings
    local cfg = Config.TOWER_ATTACKS.void_orb
    self.radius = cfg.cloudRadius
    self.duration = cfg.cloudDuration
    self.damagePerTick = cfg.cloudDamagePerTick
    self.tickInterval = cfg.cloudTickInterval

    self.remaining = self.duration
    self.tickTimer = 0
    self.time = 0
    self.dead = false

    -- Unique seed for procedural rendering
    seedCounter = seedCounter + 1
    self.seed = seedCounter * 31 + math.random(1000)

    -- Track creeps that are currently inside the cloud
    self.creepsInside = {}

    -- Particles for visual effect
    self.particles = {}
    self:spawnInitialParticles()
end

function PoisonCloud:spawnInitialParticles()
    local cfg = Config.GROUND_EFFECTS.poison_cloud
    for i = 1, cfg.particleCount do
        local angle = math.random() * math.pi * 2
        local dist = math.random() * self.radius * 0.8
        table.insert(self.particles, {
            x = self.x + math.cos(angle) * dist,
            y = self.y + math.sin(angle) * dist * Config.GROUND_EFFECTS.perspectiveYScale,
            vx = (math.random() - 0.5) * cfg.particleSpeed,
            vy = -cfg.particleSpeed * (0.5 + math.random() * 0.5) * Config.GROUND_EFFECTS.perspectiveYScale,
            life = 0.5 + math.random() * 0.5,
            maxLife = 1.0,
            size = 2 + math.random() * 2,
        })
    end
end

function PoisonCloud:update(dt, creeps)
    -- Update animation time
    self.time = self.time + dt

    -- Update remaining duration
    self.remaining = self.remaining - dt
    if self.remaining <= 0 then
        self.dead = true
        return
    end

    -- Update damage tick timer
    self.tickTimer = self.tickTimer + dt

    -- Check for creeps inside the cloud
    for _, creep in ipairs(creeps) do
        if not creep.dead and not creep.dying then
            local dx = creep.x - self.x
            local dy = creep.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= self.radius then
                -- Creep is inside the cloud
                -- Apply tick damage if timer is ready
                if self.tickTimer >= self.tickInterval then
                    -- Apply poison status effect instead of direct damage
                    StatusEffects.apply(creep, StatusEffects.POISON, {
                        damagePerTick = self.damagePerTick,
                        tickInterval = self.tickInterval,
                        duration = Config.STATUS_EFFECTS.poison.duration,
                    })
                end
            end
        end
    end

    -- Reset tick timer if it triggered
    if self.tickTimer >= self.tickInterval then
        self.tickTimer = self.tickTimer - self.tickInterval
    end

    -- Update particles
    local cfg = Config.GROUND_EFFECTS.poison_cloud
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt

        if p.life <= 0 then
            -- Respawn particle
            local angle = math.random() * math.pi * 2
            local dist = math.random() * self.radius * 0.8
            p.x = self.x + math.cos(angle) * dist
            p.y = self.y + math.sin(angle) * dist * Config.GROUND_EFFECTS.perspectiveYScale
            p.vx = (math.random() - 0.5) * cfg.particleSpeed
            p.vy = -cfg.particleSpeed * (0.5 + math.random() * 0.5) * Config.GROUND_EFFECTS.perspectiveYScale
            p.life = 0.5 + math.random() * 0.5
        end
    end
end

function PoisonCloud:draw()
    -- Calculate fade progress
    local progress = self.remaining / self.duration

    -- Draw the poison cloud effect
    GroundEffects.drawPoisonCloud(self.x, self.y, self.radius, progress, self.time, self.seed)

    -- Draw particles
    local colors = Config.GROUND_EFFECTS.poison_cloud.colors
    for _, p in ipairs(self.particles) do
        local alpha = (p.life / p.maxLife) * progress
        -- Glow
        love.graphics.setColor(colors.particle[1], colors.particle[2], colors.particle[3], alpha * 0.4)
        love.graphics.circle("fill", p.x, p.y, p.size * 1.5)
        -- Core
        love.graphics.setColor(colors.particle[1], colors.particle[2], colors.particle[3], alpha)
        love.graphics.rectangle("fill", p.x - p.size / 2, p.y - p.size / 2, p.size, p.size)
    end
end

-- Get light parameters for the lighting system
function PoisonCloud:getLightParams()
    local progress = self.remaining / self.duration
    local color = Config.STATUS_EFFECTS.poison.color

    return {
        x = self.x,
        y = self.y,
        radius = self.radius * 1.2,
        color = color,
        intensity = 0.5 * progress,
        flicker = true,
    }
end

return PoisonCloud
