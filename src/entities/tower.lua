-- src/entities/tower.lua
-- Tower entity

local Object = require("lib.classic")
local Config = require("src.config")
local Projectile = require("src.entities.projectile")
local Combat = require("src.systems.combat")

local Tower = Object:extend()

function Tower:new(x, y, towerType, gridX, gridY)
    self.x = x
    self.y = y
    self.gridX = gridX
    self.gridY = gridY
    self.towerType = towerType

    local stats = Config.TOWERS[towerType]
    self.baseDamage = stats.damage
    self.baseRange = stats.range
    self.baseFireRate = stats.fireRate
    self.color = stats.color
    self.projectileSpeed = stats.projectileSpeed
    self.splashRadius = stats.splashRadius

    -- Upgrade tracking
    self.upgrades = { range = 0, fireRate = 0, damage = 0 }
    self:recalculateStats()

    self.cooldown = 0
    self.target = nil
    self.rotation = 0
    self.dead = false
end

function Tower:recalculateStats()
    local bonuses = Config.UPGRADES.bonusPerLevel
    self.damage = self.baseDamage * (1 + self.upgrades.damage * bonuses.damage)
    self.range = self.baseRange * (1 + self.upgrades.range * bonuses.range)
    self.fireRate = self.baseFireRate * (1 + self.upgrades.fireRate * bonuses.fireRate)
end

function Tower:getUpgradeCost(stat)
    local level = self.upgrades[stat]
    if level >= Config.UPGRADES.maxLevel then
        return nil  -- Maxed out
    end
    local baseCost = Config.UPGRADES.baseCost[stat]
    return math.floor(baseCost * (Config.UPGRADES.costMultiplier ^ level))
end

function Tower:canUpgrade(stat)
    return self.upgrades[stat] < Config.UPGRADES.maxLevel
end

function Tower:upgrade(stat)
    if not self:canUpgrade(stat) then
        return false
    end
    self.upgrades[stat] = self.upgrades[stat] + 1
    self:recalculateStats()
    return true
end

function Tower:getTotalUpgradeLevel()
    return self.upgrades.damage + self.upgrades.range + self.upgrades.fireRate
end

function Tower:update(dt, creeps, projectiles)
    -- Non-attacking towers (walls) skip combat logic
    if not self.fireRate or self.fireRate == 0 then
        return
    end

    -- Decrement cooldown
    if self.cooldown > 0 then
        self.cooldown = self.cooldown - dt
    end

    -- Find closest non-dead creep within range
    self.target = Combat.findTarget(self, creeps)

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
    love.graphics.setColor(Config.COLORS.towerBase)
    love.graphics.circle("fill", self.x, self.y, Config.TOWER_SIZE)

    -- Draw turret body (tower color)
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, Config.TOWER_SIZE * 0.7)

    -- Non-attacking towers (walls) don't have a barrel
    if not self.fireRate or self.fireRate == 0 then
        return
    end

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
