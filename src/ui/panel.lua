-- src/ui/panel.lua
-- Right-side UI panel for tower/enemy selection

local Config = require("src.config")

local Panel = {}

local state = {
    x = 0,
    width = 0,
    height = 0,
    selectedTower = "basic",
    towerButtons = {},
    enemyButtons = {},
    hoverButton = nil,
}

-- Tower types in order
local TOWER_ORDER = {"basic", "rapid", "sniper", "cannon"}
local TOWER_KEYS = {"1", "2", "3", "4"}

-- Enemy types in order
local ENEMY_ORDER = {"triangle", "square", "pentagon", "hexagon"}
local ENEMY_KEYS = {"Q", "W", "E", "R"}

function Panel.init(playAreaWidth, panelWidth, height)
    state.x = playAreaWidth
    state.width = panelWidth
    state.height = height

    -- Build tower button layouts (top half)
    local padding = Config.UI.padding
    local buttonHeight = Config.UI.buttonHeight
    local buttonSpacing = Config.UI.buttonSpacing
    local buttonWidth = panelWidth - padding * 2

    local towerStartY = 50  -- After "TOWERS" title

    state.towerButtons = {}
    for i, towerType in ipairs(TOWER_ORDER) do
        state.towerButtons[i] = {
            type = towerType,
            x = state.x + padding,
            y = towerStartY + (i - 1) * (buttonHeight + buttonSpacing),
            width = buttonWidth,
            height = buttonHeight,
            hotkey = TOWER_KEYS[i],
        }
    end

    -- Build enemy button layouts (bottom half)
    local enemyStartY = height / 2 + 30  -- After "SEND TO VOID" title

    state.enemyButtons = {}
    for i, enemyType in ipairs(ENEMY_ORDER) do
        state.enemyButtons[i] = {
            type = enemyType,
            x = state.x + padding,
            y = enemyStartY + (i - 1) * (buttonHeight + buttonSpacing),
            width = buttonWidth,
            height = buttonHeight,
            hotkey = ENEMY_KEYS[i],
        }
    end
end

function Panel.update(mouseX, mouseY)
    state.hoverButton = nil

    -- Check tower buttons
    for _, btn in ipairs(state.towerButtons) do
        if mouseX >= btn.x and mouseX <= btn.x + btn.width and
           mouseY >= btn.y and mouseY <= btn.y + btn.height then
            state.hoverButton = btn
            return
        end
    end

    -- Check enemy buttons
    for _, btn in ipairs(state.enemyButtons) do
        if mouseX >= btn.x and mouseX <= btn.x + btn.width and
           mouseY >= btn.y and mouseY <= btn.y + btn.height then
            state.hoverButton = btn
            return
        end
    end
end

function Panel.handleClick(x, y, economy)
    -- Check tower buttons
    for _, btn in ipairs(state.towerButtons) do
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            state.selectedTower = btn.type
            return nil
        end
    end

    -- Check enemy buttons
    for _, btn in ipairs(state.enemyButtons) do
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            local creepConfig = Config.CREEPS[btn.type]
            if economy.canAfford(creepConfig.sendCost) then
                return {action = "send_enemy", type = btn.type}
            end
            return nil
        end
    end

    return nil
end

-- Draw a polygon shape for enemy preview
local function drawEnemyShape(x, y, size, sides, color)
    local vertices = {}
    for i = 1, sides do
        local angle = (i - 1) * (2 * math.pi / sides) - math.pi / 2
        table.insert(vertices, x + math.cos(angle) * size)
        table.insert(vertices, y + math.sin(angle) * size)
    end

    love.graphics.setColor(color)
    love.graphics.polygon("fill", vertices)
end

function Panel.draw(economy)
    -- Panel background
    love.graphics.setColor(Config.COLORS.panel)
    love.graphics.rectangle("fill", state.x, 0, state.width, state.height)

    -- Border
    love.graphics.setColor(0, 0.5, 0)
    love.graphics.setLineWidth(2)
    love.graphics.line(state.x, 0, state.x, state.height)

    -- TOWERS title
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.printf("TOWERS", state.x, 20, state.width, "center")

    -- Draw tower buttons
    for _, btn in ipairs(state.towerButtons) do
        local towerConfig = Config.TOWERS[btn.type]
        local canAfford = economy.canAfford(towerConfig.cost)
        local isSelected = state.selectedTower == btn.type
        local isHovered = state.hoverButton == btn

        -- Button background
        if isSelected then
            love.graphics.setColor(0.1, 0.3, 0.1)
        elseif isHovered and canAfford then
            love.graphics.setColor(0.15, 0.15, 0.2)
        else
            love.graphics.setColor(0.08, 0.08, 0.12)
        end
        love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 4)

        -- Selection border
        if isSelected then
            love.graphics.setColor(0, 1, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height, 4)
        end

        -- Tower icon (colored circle)
        local iconX = btn.x + 25
        local iconY = btn.y + btn.height / 2
        if canAfford then
            love.graphics.setColor(towerConfig.color)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.circle("fill", iconX, iconY, 12)

        -- Tower name
        if canAfford then
            love.graphics.setColor(Config.COLORS.textPrimary)
        else
            love.graphics.setColor(Config.COLORS.textDisabled)
        end
        love.graphics.print(towerConfig.name, btn.x + 45, btn.y + 10)

        -- Tower cost
        if canAfford then
            love.graphics.setColor(Config.COLORS.gold)
        else
            love.graphics.setColor(Config.COLORS.textDisabled)
        end
        love.graphics.print(towerConfig.cost .. "g", btn.x + 45, btn.y + 30)

        -- Hotkey
        love.graphics.setColor(Config.COLORS.textSecondary)
        love.graphics.print("[" .. btn.hotkey .. "]", btn.x + btn.width - 35, btn.y + 10)

        -- Stats (damage/range)
        love.graphics.setColor(Config.COLORS.textSecondary)
        local statsText = "DMG:" .. towerConfig.damage .. " RNG:" .. towerConfig.range
        love.graphics.print(statsText, btn.x + 45, btn.y + 48)
    end

    -- SEND TO VOID title
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.printf("SEND TO VOID", state.x, state.height / 2, state.width, "center")

    -- Draw enemy buttons
    for _, btn in ipairs(state.enemyButtons) do
        local creepConfig = Config.CREEPS[btn.type]
        local canAfford = economy.canAfford(creepConfig.sendCost)
        local isHovered = state.hoverButton == btn

        -- Button background
        if isHovered and canAfford then
            love.graphics.setColor(0.2, 0.1, 0.1)
        else
            love.graphics.setColor(0.08, 0.08, 0.12)
        end
        love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 4)

        -- Enemy shape icon
        local iconX = btn.x + 25
        local iconY = btn.y + btn.height / 2
        if canAfford then
            drawEnemyShape(iconX, iconY, 12, creepConfig.sides, creepConfig.color)
        else
            drawEnemyShape(iconX, iconY, 12, creepConfig.sides, {0.3, 0.3, 0.3})
        end

        -- Enemy name
        if canAfford then
            love.graphics.setColor(Config.COLORS.textPrimary)
        else
            love.graphics.setColor(Config.COLORS.textDisabled)
        end
        love.graphics.print(creepConfig.name, btn.x + 45, btn.y + 10)

        -- Send cost
        if canAfford then
            love.graphics.setColor(Config.COLORS.gold)
        else
            love.graphics.setColor(Config.COLORS.textDisabled)
        end
        love.graphics.print(creepConfig.sendCost .. "g", btn.x + 45, btn.y + 30)

        -- Income gain
        love.graphics.setColor(Config.COLORS.income)
        love.graphics.print("+" .. creepConfig.income .. "/tick", btn.x + 100, btn.y + 30)

        -- Hotkey
        love.graphics.setColor(Config.COLORS.textSecondary)
        love.graphics.print("[" .. btn.hotkey .. "]", btn.x + btn.width - 35, btn.y + 10)

        -- Stats (HP/speed)
        love.graphics.setColor(Config.COLORS.textSecondary)
        local statsText = "HP:" .. creepConfig.hp .. " SPD:" .. creepConfig.speed
        love.graphics.print(statsText, btn.x + 45, btn.y + 48)
    end
end

function Panel.getSelectedTower()
    return state.selectedTower
end

function Panel.getSelectedTowerCost()
    return Config.TOWERS[state.selectedTower].cost
end

function Panel.selectTower(towerType)
    state.selectedTower = towerType
end

return Panel
