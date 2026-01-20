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
    -- Void positioning (void is above the grid)
    voidX = 0,
    voidY = 0,
    voidWidth = 0,
    voidHeight = 0,
}

function Grid.init(screenWidth, screenHeight)
    state.playAreaWidth = math.floor(screenWidth * Config.PLAY_AREA_RATIO)
    state.panelWidth = screenWidth - state.playAreaWidth
    state.cellSize = Config.CELL_SIZE

    -- Use fixed grid dimensions from config
    state.cols = Config.GRID_COLS or math.floor(state.playAreaWidth / state.cellSize)
    state.rows = Config.GRID_ROWS or math.floor((screenHeight - Config.UI.hudHeight) / state.cellSize)

    -- Calculate void dimensions (void is above the grid)
    local voidHeightPixels = Config.VOID_HEIGHT * state.cellSize
    local bufferHeightPixels = Config.VOID_BUFFER * state.cellSize

    -- Calculate grid dimensions
    local gridWidth = state.cols * state.cellSize
    local gridHeight = state.rows * state.cellSize

    -- Anchor to top with minimal padding (don't center - need room for exit portal at bottom)
    local topPadding = 8
    state.offsetX = math.floor((state.playAreaWidth - gridWidth) / 2)

    -- Position void at the top
    state.voidX = state.offsetX
    state.voidY = topPadding
    state.voidWidth = gridWidth
    state.voidHeight = voidHeightPixels

    -- Position grid below void + buffer
    state.offsetY = topPadding + voidHeightPixels + bufferHeightPixels

    -- Initialize cells: 0=empty, 1=tower, 3=base
    -- All rows except base are buildable - creeps enter from buffer above grid
    state.cells = {}
    for y = 1, state.rows do
        state.cells[y] = {}
        for x = 1, state.cols do
            if y > state.rows - Config.BASE_ROWS then
                state.cells[y][x] = 3  -- base zone
            else
                state.cells[y][x] = 0  -- empty (buildable)
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

function Grid.draw(showGridOverlay)
    -- Draw grid lines only when placing towers
    if showGridOverlay then
        love.graphics.setColor(Config.COLORS.grid)
        -- Draw horizontal lines (but stop before base zone)
        local buildableRows = state.rows - Config.BASE_ROWS
        for y = 0, buildableRows do
            local screenY = state.offsetY + y * state.cellSize
            love.graphics.line(state.offsetX, screenY, state.offsetX + state.cols * state.cellSize, screenY)
        end
        -- Draw vertical lines (only in buildable area)
        for x = 0, state.cols do
            local screenX = state.offsetX + x * state.cellSize
            love.graphics.line(screenX, state.offsetY, screenX, state.offsetY + buildableRows * state.cellSize)
        end

        -- Draw base zone boundary line (slightly brighter to show limit)
        local baseY = state.offsetY + buildableRows * state.cellSize
        love.graphics.setColor(Config.COLORS.grid[1] * 1.5, Config.COLORS.grid[2] * 1.5, Config.COLORS.grid[3] * 1.5, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.line(state.offsetX, baseY, state.offsetX + state.cols * state.cellSize, baseY)
        love.graphics.setLineWidth(1)
    end

    -- Base zone no longer draws tiles - exit portal draws there instead
end

function Grid.drawHover(mouseX, mouseY, canAfford, towerType)
    local gridX, gridY = Grid.screenToGrid(mouseX, mouseY)
    if not Grid.isValidCell(gridX, gridY) then return end

    local screenX = state.offsetX + (gridX - 1) * state.cellSize
    local screenY = state.offsetY + (gridY - 1) * state.cellSize
    local canPlace = Grid.canPlaceTower(gridX, gridY) and canAfford

    if canPlace then
        love.graphics.setColor(1, 1, 1, 0.3)
    else
        love.graphics.setColor(1, 0.3, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", screenX + 1, screenY + 1, state.cellSize - 2, state.cellSize - 2)

    -- Draw range preview for valid placements (non-wall towers) - transparent white
    if canPlace and towerType then
        local towerStats = Config.TOWERS[towerType]
        local range = towerStats and towerStats.range or 0
        if range > 0 then
            local centerX, centerY = Grid.gridToScreen(gridX, gridY)
            local previewConfig = Config.UI.rangePreview

            -- Fill circle (white)
            love.graphics.setColor(1, 1, 1, previewConfig.fillAlpha)
            love.graphics.circle("fill", centerX, centerY, range)

            -- Stroke circle (white)
            love.graphics.setColor(1, 1, 1, previewConfig.strokeAlpha)
            love.graphics.setLineWidth(previewConfig.strokeWidth)
            love.graphics.circle("line", centerX, centerY, range)
        end
    end
end

-- Expose state for pathfinding
function Grid.getCells() return state.cells end
function Grid.getCols() return state.cols end
function Grid.getRows() return state.rows end
function Grid.getBaseRow() return state.rows end

-- Get void bounds (void is positioned above the grid)
function Grid.getVoidBounds()
    return state.voidX, state.voidY, state.voidWidth, state.voidHeight
end

-- Alias for backwards compatibility
function Grid.getSpawnZoneBounds()
    return Grid.getVoidBounds()
end

-- Get the center position for the portal
function Grid.getPortalCenter()
    local Config = require("src.config")
    local x = state.voidX + state.voidWidth / 2
    -- Center portal vertically in void area with slight top padding
    local topPadding = Config.VOID_PORTAL.topPadding or 0
    local y = state.voidY + topPadding + (state.voidHeight - topPadding) / 2
    return x, y
end

-- Get the Y coordinate of the grid bottom (for collision detection)
function Grid.getGridBottom()
    return state.offsetY + state.rows * state.cellSize
end

-- Get the center position for the exit portal (below the grid)
function Grid.getExitPortalCenter()
    -- Center horizontally in the grid
    local x = state.offsetX + (state.cols * state.cellSize) / 2
    -- Position below the grid, with bottom padding from screen edge
    local gridBottom = Grid.getGridBottom()
    local screenHeight = Config.SCREEN_HEIGHT
    local bottomPadding = Config.EXIT_PORTAL.bottomPadding or 30
    -- Center between grid bottom and (screen bottom - padding)
    local availableSpace = screenHeight - gridBottom - bottomPadding
    local y = gridBottom + availableSpace / 2
    return x, y
end

-- Get a spawn position for creeps
-- If void reference provided, spawn from within the portal
-- Otherwise falls back to column-based spawning
function Grid.getSpawnPosition(col, void)
    -- If void reference provided, spawn from its position
    if void then
        -- Random position within portal radius
        local angle = math.random() * math.pi * 2
        local dist = math.random() * void.size * 0.5  -- Within inner half
        local x = void.x + math.cos(angle) * dist
        local y = void.y + math.sin(angle) * dist
        return x, y
    end
    -- Fallback to old column-based spawning
    col = col or math.random(1, state.cols)
    local x = state.voidX + (col - 0.5) * state.cellSize
    local y = state.voidY + state.voidHeight - state.cellSize * 0.3
    return x, y
end

return Grid
