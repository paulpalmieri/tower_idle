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
    if self.dead then return end

    -- Rotate shape over time for visual interest
    self.rotation = self.rotation + dt * Config.CREEP_ROTATION_SPEED

    -- Get current grid position
    local gridX, gridY = grid.screenToGrid(self.x, self.y)

    -- Check if reached base (bottom row)
    if gridY >= grid.getRows() then
        self.reachedBase = true
        self.dead = true
        return
    end

    -- Get flow direction for current cell
    local flow = flowField[gridY] and flowField[gridY][gridX]

    local dx, dy
    if flow and (flow.dx ~= 0 or flow.dy ~= 0) then
        -- Follow flow field
        dx = flow.dx
        dy = flow.dy
    else
        -- Fallback: move straight down
        dx = 0
        dy = 1
    end

    -- Calculate target cell center
    local targetGridX = gridX + dx
    local targetGridY = gridY + dy
    local targetX, targetY = grid.gridToScreen(targetGridX, targetGridY)

    -- Move toward target
    local toTargetX = targetX - self.x
    local toTargetY = targetY - self.y
    local dist = math.sqrt(toTargetX * toTargetX + toTargetY * toTargetY)

    if dist > 0 then
        local moveX = (toTargetX / dist) * self.speed * dt
        local moveY = (toTargetY / dist) * self.speed * dt

        -- Don't overshoot
        if math.abs(moveX) > math.abs(toTargetX) then moveX = toTargetX end
        if math.abs(moveY) > math.abs(toTargetY) then moveY = toTargetY end

        self.x = self.x + moveX
        self.y = self.y + moveY
    end
end

function Creep:takeDamage(amount)
    self.hp = self.hp - amount
    if self.hp <= 0 then
        self.dead = true
    end
end

function Creep:draw()
    -- Build polygon vertices based on sides
    local vertices = {}
    for i = 1, self.sides do
        local angle = self.rotation + (i - 1) * (2 * math.pi / self.sides) - math.pi / 2
        local vx = self.x + math.cos(angle) * self.size
        local vy = self.y + math.sin(angle) * self.size
        table.insert(vertices, vx)
        table.insert(vertices, vy)
    end

    -- Draw filled polygon
    love.graphics.setColor(self.color)
    love.graphics.polygon("fill", vertices)

    -- Draw outline (slightly darker)
    love.graphics.setColor(self.color[1] * 0.6, self.color[2] * 0.6, self.color[3] * 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", vertices)

    -- Draw health bar when damaged
    if self.hp < self.maxHp then
        local barWidth = self.size * 2
        local barHeight = 4
        local barX = self.x - barWidth / 2
        local barY = self.y - self.size - 8

        -- Background
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

        -- Health fill
        local healthPercent = self.hp / self.maxHp
        love.graphics.setColor(1 - healthPercent, healthPercent, 0)
        love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
    end
end

return Creep
