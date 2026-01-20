-- src/entities/burning_ground.lua
-- Burning ground effect entity (from void_star projectile impact)

local Object = require("lib.classic")
local Config = require("src.config")
local StatusEffects = require("src.systems.status_effects")
local GroundEffects = require("src.rendering.ground_effects")
local EventBus = require("src.core.event_bus")

local BurningGround = Object:extend()

-- Unique seed counter for each fire instance
local seedCounter = 0

-- Perspective scale (must match ground_effects.lua)
local PERSPECTIVE_Y_SCALE = 0.9

function BurningGround:new(x, y)
    self.x = x
    self.y = y

    -- Get config from tower attack settings
    local cfg = Config.TOWER_ATTACKS.void_star
    self.radius = cfg.fireRadius
    self.duration = cfg.fireDuration
    self.damagePerTick = cfg.fireDamagePerTick
    self.tickInterval = cfg.fireTickInterval

    self.remaining = self.duration
    self.tickTimer = 0
    self.time = 0
    self.dead = false

    -- Unique seed for procedural rendering
    seedCounter = seedCounter + 1
    self.seed = seedCounter * 47 + math.random(1000)

    -- Ember particles
    self.embers = {}
    self:spawnInitialEmbers()
end

function BurningGround:spawnInitialEmbers()
    local cfg = Config.GROUND_EFFECTS.burning_ground
    for i = 1, cfg.emberCount do
        local angle = math.random() * math.pi * 2
        local dist = math.random() * self.radius * 0.7
        table.insert(self.embers, {
            x = self.x + math.cos(angle) * dist,
            y = self.y + math.sin(angle) * dist * PERSPECTIVE_Y_SCALE,
            vx = (math.random() - 0.5) * cfg.emberSpeed * 0.5,
            vy = -cfg.emberSpeed * (0.5 + math.random() * 0.8) * PERSPECTIVE_Y_SCALE,
            life = 0.3 + math.random() * 0.4,
            maxLife = 0.7,
            size = 2 + math.random() * 2,
        })
    end
end

function BurningGround:update(dt, creeps)
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

    -- Check for creeps inside the fire
    for _, creep in ipairs(creeps) do
        if not creep.dead and not creep.dying then
            local dx = creep.x - self.x
            local dy = creep.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= self.radius then
                -- Creep is inside the fire
                -- Apply tick damage if timer is ready
                if self.tickTimer >= self.tickInterval then
                    -- Apply burn status effect
                    StatusEffects.apply(creep, StatusEffects.BURN, {
                        damagePerTick = self.damagePerTick,
                        tickInterval = self.tickInterval,
                        duration = 1.5,  -- Burn lingers after leaving fire
                    })
                end
            end
        end
    end

    -- Reset tick timer if it triggered
    if self.tickTimer >= self.tickInterval then
        self.tickTimer = self.tickTimer - self.tickInterval
    end

    -- Update ember particles
    local cfg = Config.GROUND_EFFECTS.burning_ground
    for i = #self.embers, 1, -1 do
        local e = self.embers[i]
        e.x = e.x + e.vx * dt
        e.y = e.y + e.vy * dt
        e.life = e.life - dt

        if e.life <= 0 then
            -- Respawn ember
            local angle = math.random() * math.pi * 2
            local dist = math.random() * self.radius * 0.7
            e.x = self.x + math.cos(angle) * dist
            e.y = self.y + math.sin(angle) * dist * PERSPECTIVE_Y_SCALE
            e.vx = (math.random() - 0.5) * cfg.emberSpeed * 0.5
            e.vy = -cfg.emberSpeed * (0.5 + math.random() * 0.8) * PERSPECTIVE_Y_SCALE
            e.life = 0.3 + math.random() * 0.4
        end
    end
end

function BurningGround:draw()
    -- Calculate fade progress
    local progress = self.remaining / self.duration

    -- Draw the burning ground effect
    GroundEffects.drawBurningGround(self.x, self.y, self.radius, progress, self.time, self.seed)

    -- Draw ember particles
    local colors = Config.GROUND_EFFECTS.burning_ground.colors
    for _, e in ipairs(self.embers) do
        local alpha = (e.life / e.maxLife) * progress

        -- Ember flicker
        local flicker = math.sin(self.time * 15 + e.x * 0.1) * 0.3 + 0.7

        -- Glow
        love.graphics.setColor(colors.ember[1], colors.ember[2] * 0.7, colors.ember[3] * 0.3, alpha * 0.5 * flicker)
        love.graphics.circle("fill", e.x, e.y, e.size * 2)

        -- Core
        love.graphics.setColor(colors.ember[1], colors.ember[2], colors.ember[3], alpha * flicker)
        love.graphics.rectangle("fill", e.x - e.size / 2, e.y - e.size / 2, e.size, e.size)
    end
end

-- Get light parameters for the lighting system
function BurningGround:getLightParams()
    local progress = self.remaining / self.duration
    local color = Config.STATUS_EFFECTS.burn.color

    return {
        x = self.x,
        y = self.y,
        radius = self.radius * 1.3,
        color = color,
        intensity = 0.7 * progress,
        flicker = true,
    }
end

return BurningGround
