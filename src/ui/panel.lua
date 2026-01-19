-- src/ui/panel.lua
-- Right-side UI panel for tower/enemy selection

local Config = require("src.config")

local Panel = {}

local state = {
    x = 0,
    width = 0,
    height = 0,
    selectedTower = "basic",
}

function Panel.init(playAreaWidth, panelWidth, height)
    state.x = playAreaWidth
    state.width = panelWidth
    state.height = height
end

function Panel.update(mouseX, mouseY)
    -- TODO: Update hover states
end

function Panel.handleClick(x, y, economy)
    -- TODO: Implement click handling
    return nil
end

function Panel.draw(economy)
    -- Panel background
    love.graphics.setColor(Config.COLORS.panel)
    love.graphics.rectangle("fill", state.x, 0, state.width, state.height)

    -- Border
    love.graphics.setColor(0, 0.5, 0)
    love.graphics.setLineWidth(2)
    love.graphics.line(state.x, 0, state.x, state.height)

    -- TODO: Draw tower and enemy buttons
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.printf("TOWERS", state.x, 20, state.width, "center")
    love.graphics.printf("SEND TO VOID", state.x, state.height / 2, state.width, "center")
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
