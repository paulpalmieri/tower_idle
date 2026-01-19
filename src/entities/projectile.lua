-- src/entities/projectile.lua
-- Tower projectile entity

local Object = require("lib.classic")
local Config = require("src.config")

local Projectile = Object:extend()

function Projectile:new(x, y, angle, speed, damage, color, splashRadius)
    self.x = x
    self.y = y
    self.angle = angle
    self.speed = speed
    self.damage = damage
    self.color = color
    self.splashRadius = splashRadius

    self.vx = math.cos(angle) * speed
    self.vy = math.sin(angle) * speed
    self.dead = false
end

function Projectile:update(dt, creeps)
    -- Move projectile
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Bounds check - mark dead if off screen
    if self.x < -50 or self.x > Config.SCREEN_WIDTH + 50 or
       self.y < -50 or self.y > Config.SCREEN_HEIGHT + 50 then
        self.dead = true
        return
    end

    -- Collision detection with creeps
    for _, creep in ipairs(creeps) do
        if not creep.dead then
            local dx = creep.x - self.x
            local dy = creep.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local hitRadius = Config.PROJECTILE_SIZE + creep.size

            if dist < hitRadius then
                -- Hit! Apply damage
                if self.splashRadius and self.splashRadius > 0 then
                    -- Splash damage: full damage at center, falloff with distance
                    for _, target in ipairs(creeps) do
                        if not target.dead then
                            local tx = target.x - self.x
                            local ty = target.y - self.y
                            local targetDist = math.sqrt(tx * tx + ty * ty)

                            if targetDist < self.splashRadius then
                                -- Linear falloff from center
                                local falloff = 1 - (targetDist / self.splashRadius)
                                local splashDamage = self.damage * falloff
                                target:takeDamage(splashDamage)
                            end
                        end
                    end
                else
                    -- Single target damage
                    creep:takeDamage(self.damage)
                end

                self.dead = true
                return
            end
        end
    end
end

function Projectile:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, Config.PROJECTILE_SIZE)
end

return Projectile
