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
    -- TODO: Implement movement and collision
end

function Projectile:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, Config.PROJECTILE_SIZE)
end

return Projectile
