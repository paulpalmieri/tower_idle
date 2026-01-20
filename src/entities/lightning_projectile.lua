-- src/entities/lightning_projectile.lua
-- Piercing bolt projectile entity (for Void Bolt tower)
-- Fast bolt that pierces through all enemies in its path

local Object = require("lib.classic")
local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local StatusEffects = require("src.systems.status_effects")

local LightningProjectile = Object:extend()

function LightningProjectile:new(x, y, angle, damage, sourceTower)
    self.x = x
    self.y = y
    self.angle = angle
    self.damage = damage
    self.sourceTower = sourceTower
    self.towerType = "void_bolt"

    -- Get config
    local cfg = Config.TOWER_ATTACKS.void_bolt

    self.speed = cfg.boltSpeed
    self.pierceDamageMultiplier = cfg.pierceDamageMultiplier
    self.slowMultiplier = cfg.slowMultiplier
    self.slowDuration = cfg.slowDuration

    -- Movement
    self.vx = math.cos(angle) * self.speed
    self.vy = math.sin(angle) * self.speed

    -- Track hit creeps to prevent double-hits
    self.hitCreeps = {}

    -- Current damage (decreases with each pierce)
    self.currentDamage = damage

    -- State
    self.dead = false
end

function LightningProjectile:update(dt, creeps)
    if self.dead then return end

    -- Move projectile
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Bounds check
    if self.x < -50 or self.x > Config.SCREEN_WIDTH + 50 or
       self.y < -50 or self.y > Config.SCREEN_HEIGHT + 50 then
        self.dead = true
        return
    end

    -- Collision detection with creeps (pierces through all)
    local hitRadius = 8
    for _, creep in ipairs(creeps) do
        if not creep.dead and not creep.dying and not self.hitCreeps[creep] then
            local dx = creep.x - self.x
            local dy = creep.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < hitRadius + creep.size then
                -- Hit!
                self.hitCreeps[creep] = true

                creep:takeDamage(self.currentDamage, self.angle)

                if self.sourceTower then
                    creep.killedBy = self.sourceTower
                end

                -- Apply slow
                StatusEffects.apply(creep, StatusEffects.SLOW, {
                    multiplier = self.slowMultiplier,
                    duration = self.slowDuration,
                })

                EventBus.emit("creep_hit", {
                    creep = creep,
                    damage = self.currentDamage,
                    position = { x = creep.x, y = creep.y },
                    angle = self.angle,
                })

                -- Reduce damage for next pierce
                self.currentDamage = self.currentDamage * self.pierceDamageMultiplier
            end
        end
    end
end

function LightningProjectile:draw()
    local ps = 4  -- Pixel size
    local color = { 0.3, 0.6, 1.0 }  -- Electric blue

    -- Simple elongated pixel bolt
    local cosA = math.cos(self.angle)
    local sinA = math.sin(self.angle)

    -- Draw 3 pixels in a line for the bolt
    for i = -1, 1 do
        local px = self.x + cosA * i * ps
        local py = self.y + sinA * i * ps

        -- Glow
        love.graphics.setColor(color[1], color[2], color[3], 0.4)
        love.graphics.rectangle("fill", px - ps, py - ps, ps * 2, ps * 2)

        -- Core
        love.graphics.setColor(color[1] + 0.3, color[2] + 0.3, color[3] + 0.2)
        love.graphics.rectangle("fill", px - ps/2, py - ps/2, ps, ps)
    end

    -- Bright tip
    local tipX = self.x + cosA * ps * 2
    local tipY = self.y + sinA * ps * 2
    love.graphics.setColor(0.8, 0.9, 1.0)
    love.graphics.rectangle("fill", tipX - ps/2, tipY - ps/2, ps, ps)
end

function LightningProjectile:getLightParams()
    return {
        x = self.x,
        y = self.y,
        radius = 40,
        color = { 0.3, 0.6, 1.0 },
        intensity = 0.8,
        flicker = false,
    }
end

return LightningProjectile
