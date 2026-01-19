-- src/entities/creep.lua
-- Enemy creep entity

local Object = require("lib.classic")
local Config = require("src.config")

local Creep = Object:extend()

function Creep:new(x, y, creepType)
    self.x = x
    self.y = y
    self.creepType = creepType

    local stats = Config.CREEPS[creepType]
    self.sides = stats.sides
    self.maxHp = stats.hp
    self.hp = self.maxHp
    self.speed = stats.speed
    self.reward = stats.reward
    self.color = stats.color
    self.size = stats.size

    self.dead = false
    self.reachedBase = false
    self.rotation = 0
end

function Creep:update(dt, grid, flowField)
    -- TODO: Implement movement
    -- See prototype creep.lua for reference
end

function Creep:takeDamage(amount)
    self.hp = self.hp - amount
    if self.hp <= 0 then
        self.dead = true
    end
end

function Creep:draw()
    -- TODO: Implement geometric shape drawing
    -- See prototype creep.lua for reference
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, self.size)
end

return Creep
