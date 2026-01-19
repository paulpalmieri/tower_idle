-- src/world/grid.lua
-- Grid state and queries

local Config = require("src.config")

local Grid = {}

local state = {
    cells = {},
    cols = 0,
    rows = 0,
    cellSize = 0,
    offsetX = 0,
    offsetY = 0,
    playAreaWidth = 0,
    panelWidth = 0,
}

function Grid.init(screenWidth, screenHeight)
    state.playAreaWidth = math.floor(screenWidth * Config.PLAY_AREA_RATIO)
    state.panelWidth = screenWidth - state.playAreaWidth
    state.cellSize = Config.CELL_SIZE

    state.cols = math.floor(state.playAreaWidth / state.cellSize)
    state.rows = math.floor((screenHeight - Config.UI.hudHeight) / state.cellSize)

    state.offsetX = math.floor((state.playAreaWidth - (state.cols * state.cellSize)) / 2)
    state.offsetY = math.floor(((screenHeight - Config.UI.hudHeight) - (state.rows * state.cellSize)) / 2)

    -- Initialize cells: 0=empty, 1=tower, 2=spawn, 3=base
    state.cells = {}
    for y = 1, state.rows do
        state.cells[y] = {}
        for x = 1, state.cols do
            if y <= Config.SPAWN_ROWS then
                state.cells[y][x] = 2  -- spawn zone
            elseif y > state.rows - Config.BASE_ROWS then
                state.cells[y][x] = 3  -- base zone
            else
                state.cells[y][x] = 0  -- empty
            end
        end
    end
end

function Grid.getPlayAreaWidth()
    return state.playAreaWidth
end

function Grid.getPanelWidth()
    return state.panelWidth
end

function Grid.gridToScreen(gridX, gridY)
    local screenX = state.offsetX + (gridX - 0.5) * state.cellSize
    local screenY = state.offsetY + (gridY - 0.5) * state.cellSize
    return screenX, screenY
end

function Grid.screenToGrid(screenX, screenY)
    local gridX = math.floor((screenX - state.offsetX) / state.cellSize) + 1
    local gridY = math.floor((screenY - state.offsetY) / state.cellSize) + 1
    return gridX, gridY
end

function Grid.isValidCell(x, y)
    return x >= 1 and x <= state.cols and y >= 1 and y <= state.rows
end

function Grid.canPlaceTower(x, y)
    if not Grid.isValidCell(x, y) then return false end
    return state.cells[y][x] == 0
end

function Grid.placeTower(gridX, gridY, tower)
    if not Grid.canPlaceTower(gridX, gridY) then return false end
    state.cells[gridY][gridX] = 1
    return true
end

function Grid.draw()
    -- Draw grid
    love.graphics.setColor(Config.COLORS.grid)
    for y = 0, state.rows do
        local screenY = state.offsetY + y * state.cellSize
        love.graphics.line(state.offsetX, screenY, state.offsetX + state.cols * state.cellSize, screenY)
    end
    for x = 0, state.cols do
        local screenX = state.offsetX + x * state.cellSize
        love.graphics.line(screenX, state.offsetY, screenX, state.offsetY + state.rows * state.cellSize)
    end

    -- Draw zones
    for y = 1, state.rows do
        for x = 1, state.cols do
            local screenX = state.offsetX + (x - 1) * state.cellSize
            local screenY = state.offsetY + (y - 1) * state.cellSize
            local cell = state.cells[y][x]

            if cell == 2 then
                love.graphics.setColor(Config.COLORS.spawnZone)
                love.graphics.rectangle("fill", screenX + 1, screenY + 1, state.cellSize - 2, state.cellSize - 2)
            elseif cell == 3 then
                love.graphics.setColor(Config.COLORS.baseZone)
                love.graphics.rectangle("fill", screenX + 1, screenY + 1, state.cellSize - 2, state.cellSize - 2)
            end
        end
    end
end

function Grid.drawHover(mouseX, mouseY, canAfford)
    local gridX, gridY = Grid.screenToGrid(mouseX, mouseY)
    if not Grid.isValidCell(gridX, gridY) then return end

    local screenX = state.offsetX + (gridX - 1) * state.cellSize
    local screenY = state.offsetY + (gridY - 1) * state.cellSize
    local canPlace = Grid.canPlaceTower(gridX, gridY) and canAfford

    if canPlace then
        love.graphics.setColor(0, 1, 0, 0.3)
    else
        love.graphics.setColor(1, 0, 0, 0.3)
    end
    love.graphics.rectangle("fill", screenX + 1, screenY + 1, state.cellSize - 2, state.cellSize - 2)
end

-- Expose state for pathfinding
function Grid.getCells() return state.cells end
function Grid.getCols() return state.cols end
function Grid.getRows() return state.rows end
function Grid.getBaseRow() return state.rows end

return Grid
