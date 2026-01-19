-- src/ui/tooltip.lua
-- Tower upgrade tooltip UI component

local Config = require("src.config")

local Tooltip = {}

local state = {
    visible = false,
    tower = nil,
    x = 0,
    y = 0,
    width = 0,
    height = 0,
    buttons = {},
}

-- Upgrade types in display order
local UPGRADE_ORDER = {"damage", "fireRate", "range"}
local UPGRADE_LABELS = {
    damage = "Damage",
    fireRate = "Fire Rate",
    range = "Range",
}

local function calculateTooltipPosition(tower)
    local cfg = Config.UI.tooltip
    local screenWidth = Config.SCREEN_WIDTH
    local screenHeight = Config.SCREEN_HEIGHT

    -- Calculate total height
    local headerHeight = 35
    local buttonCount = #UPGRADE_ORDER
    local totalHeight = cfg.padding * 2 + headerHeight +
                        buttonCount * cfg.buttonHeight +
                        (buttonCount - 1) * cfg.buttonSpacing

    state.width = cfg.width
    state.height = totalHeight

    -- Position to the right of the tower by default
    local tooltipX = tower.x + cfg.offsetX
    local tooltipY = tower.y + cfg.offsetY

    -- Clamp to screen bounds
    if tooltipX + state.width > screenWidth then
        tooltipX = tower.x - state.width - cfg.offsetX
    end
    if tooltipX < 0 then
        tooltipX = 0
    end
    if tooltipY < 0 then
        tooltipY = 0
    end
    if tooltipY + state.height > screenHeight then
        tooltipY = screenHeight - state.height
    end

    state.x = tooltipX
    state.y = tooltipY
end

local function buildButtons()
    local cfg = Config.UI.tooltip
    state.buttons = {}

    local buttonY = state.y + cfg.padding + 35  -- After header
    local buttonWidth = state.width - cfg.padding * 2

    for i, stat in ipairs(UPGRADE_ORDER) do
        state.buttons[i] = {
            stat = stat,
            x = state.x + cfg.padding,
            y = buttonY,
            width = buttonWidth,
            height = cfg.buttonHeight,
        }
        buttonY = buttonY + cfg.buttonHeight + cfg.buttonSpacing
    end
end

function Tooltip.show(tower)
    -- Don't show tooltip for walls (no upgrades)
    if tower.towerType == "wall" then
        return
    end

    state.visible = true
    state.tower = tower
    calculateTooltipPosition(tower)
    buildButtons()
end

function Tooltip.hide()
    state.visible = false
    state.tower = nil
    state.buttons = {}
end

function Tooltip.isVisible()
    return state.visible
end

function Tooltip.getTower()
    return state.tower
end

function Tooltip.isPointInside(x, y)
    if not state.visible then return false end
    return x >= state.x and x <= state.x + state.width and
           y >= state.y and y <= state.y + state.height
end

function Tooltip.handleClick(x, y, economy)
    if not state.visible or not state.tower then
        return nil
    end

    for _, btn in ipairs(state.buttons) do
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            local cost = state.tower:getUpgradeCost(btn.stat)
            if cost and economy.canAfford(cost) then
                return {action = "upgrade", stat = btn.stat, cost = cost}
            end
            return nil
        end
    end

    return nil
end

function Tooltip.draw(economy)
    if not state.visible or not state.tower then
        return
    end

    local tower = state.tower
    local cfg = Config.UI.tooltip
    local colors = Config.COLORS.upgrade

    -- Background
    love.graphics.setColor(colors.tooltip)
    love.graphics.rectangle("fill", state.x, state.y, state.width, state.height, 6)

    -- Border
    love.graphics.setColor(colors.tooltipBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", state.x, state.y, state.width, state.height, 6)

    -- Header
    local towerConfig = Config.TOWERS[tower.towerType]
    love.graphics.setColor(towerConfig.color)
    local headerText = towerConfig.name .. " Upgrades"
    love.graphics.print(headerText, state.x + cfg.padding, state.y + cfg.padding)

    -- Upgrade buttons
    for _, btn in ipairs(state.buttons) do
        local stat = btn.stat
        local level = tower.upgrades[stat]
        local maxLevel = Config.UPGRADES.maxLevel
        local cost = tower:getUpgradeCost(stat)
        local canAfford = cost and economy.canAfford(cost)
        local isMaxed = level >= maxLevel
        local statColor = colors[stat]

        -- Button background
        if isMaxed then
            love.graphics.setColor(0.15, 0.15, 0.2, 0.8)
        elseif canAfford then
            love.graphics.setColor(0.1, 0.2, 0.1, 0.9)
        else
            love.graphics.setColor(0.2, 0.1, 0.1, 0.9)
        end
        love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 4)

        -- Button border (color-coded)
        love.graphics.setColor(statColor[1], statColor[2], statColor[3], 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height, 4)

        -- Stat name
        love.graphics.setColor(statColor)
        love.graphics.print(UPGRADE_LABELS[stat], btn.x + 8, btn.y + 4)

        -- Level indicator
        local levelText = "Lv." .. level .. "/" .. maxLevel
        love.graphics.setColor(Config.COLORS.textSecondary)
        love.graphics.print(levelText, btn.x + btn.width - 50, btn.y + 4)

        -- Cost or MAX
        if isMaxed then
            love.graphics.setColor(0.5, 0.8, 0.5)
            love.graphics.print("MAX", btn.x + 8, btn.y + 18)
        else
            if canAfford then
                love.graphics.setColor(Config.COLORS.gold)
            else
                love.graphics.setColor(Config.COLORS.textDisabled)
            end
            love.graphics.print(cost .. "g", btn.x + 8, btn.y + 18)
        end
    end
end

return Tooltip
