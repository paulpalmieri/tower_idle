-- src/entities/tower.lua
-- Tower entity

local Object = require("lib.classic")
local Config = require("src.config")

local Tower = Object:extend()

function Tower:new(x, y, towerType, gridX, gridY)
    self.x = x
    self.y = y
    self.gridX = gridX
    self.gridY = gridY
    self.towerType = towerType

    local stats = Config.TOWERS[towerType]
    self.damage = stats.damage
    self.range = stats.range
    self.fireRate = stats.fireRate
    self.color = stats.color
    self.projectileSpeed = stats.projectileSpeed
    self.splashRadius = stats.splashRadius

    self.cooldown = 0
    self.target = nil
    self.rotation = 0
    self.dead = false
end

function Tower:update(dt, creeps, projectiles)
    -- TODO: Implement targeting and firing
    -- See prototype tower.lua for reference
end

function Tower:draw()
    -- TODO: Implement drawing
    -- See prototype tower.lua for reference
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, Config.TOWER_SIZE)
end

return Tower
