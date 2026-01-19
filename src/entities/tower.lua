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
    local Projectile = require("src.entities.projectile")

    -- Decrement cooldown
    if self.cooldown > 0 then
        self.cooldown = self.cooldown - dt
    end

    -- Find closest non-dead creep within range
    local closestCreep = nil
    local closestDist = math.huge

    for _, creep in ipairs(creeps) do
        if not creep.dead then
            local dx = creep.x - self.x
            local dy = creep.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= self.range and dist < closestDist then
                closestDist = dist
                closestCreep = creep
            end
        end
    end

    self.target = closestCreep

    -- Rotate barrel toward target
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local targetRotation = math.atan2(dy, dx)

        -- Smooth rotation
        local rotDiff = targetRotation - self.rotation
        while rotDiff > math.pi do rotDiff = rotDiff - 2 * math.pi end
        while rotDiff < -math.pi do rotDiff = rotDiff + 2 * math.pi end
        self.rotation = self.rotation + rotDiff * math.min(1, dt * 10)
    end

    -- Fire if cooldown expired and target exists
    if self.cooldown <= 0 and self.target then
        local proj = Projectile(
            self.x,
            self.y,
            self.rotation,
            self.projectileSpeed,
            self.damage,
            self.color,
            self.splashRadius
        )
        table.insert(projectiles, proj)
        self.cooldown = 1 / self.fireRate
    end
end

function Tower:draw()
    -- Draw base circle (dark)
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.circle("fill", self.x, self.y, Config.TOWER_SIZE)

    -- Draw turret body (tower color)
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, Config.TOWER_SIZE * 0.7)

    -- Draw barrel toward rotation
    local barrelLength = Config.TOWER_SIZE * Config.TOWER_BARREL_LENGTH
    local barrelEndX = self.x + math.cos(self.rotation) * barrelLength
    local barrelEndY = self.y + math.sin(self.rotation) * barrelLength

    love.graphics.setLineWidth(4)
    love.graphics.setColor(self.color[1] * 0.8, self.color[2] * 0.8, self.color[3] * 0.8)
    love.graphics.line(self.x, self.y, barrelEndX, barrelEndY)

    -- Draw range indicator when targeting
    if self.target then
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.1)
        love.graphics.circle("fill", self.x, self.y, self.range)
    end
end

return Tower
