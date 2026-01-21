-- src/world/grid.lua
-- Grid state and queries (data only, no rendering)

local Config = require("src.config")
local Display = require("src.core.display")

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
    -- Use world dimensions if available (for scrollable camera)
    local worldWidth = Config.WORLD_WIDTH or screenWidth
    local worldHeight = Config.WORLD_HEIGHT or screenHeight

    -- Store world dimensions for external access
    state.worldWidth = worldWidth
    state.worldHeight = worldHeight

    -- Fixed canvas dimensions (1280x720 with panel overlay)
    -- Play area is full canvas width since panel overlays
    local gameWidth, gameHeight = Display.getGameDimensions()
    if gameWidth and gameWidth > 0 then
        state.playAreaWidth = Display.getPlayAreaWidth()  -- Full canvas width
        state.panelWidth = Display.getPanelWidth()
    else
        -- Fallback for initial load before Display is ready
        state.playAreaWidth = Config.CANVAS_WIDTH or 1280
        state.panelWidth = Config.PANEL_WIDTH or 320
    end
    state.cellSize = Config.CELL_SIZE

    -- Use fixed grid dimensions from config (odd numbers for true center)
    state.cols = Config.GRID_COLS or 11
    state.rows = Config.GRID_ROWS or 15

    -- Calculate grid dimensions
    local gridWidth = state.cols * state.cellSize   -- 11 * 64 = 704
    local gridHeight = state.rows * state.cellSize  -- 15 * 64 = 960

    -- CENTER GRID ON WORLD
    -- World center: (2800/2, 1800/2) = (1400, 900)
    -- Grid offset = world center - grid half size
    local worldCenterX = worldWidth / 2
    local worldCenterY = worldHeight / 2

    state.offsetX = math.floor(worldCenterX - gridWidth / 2)
    state.offsetY = math.floor(worldCenterY - gridHeight / 2)

    -- VOID ZONE (above grid)
    -- Void height in pixels + buffer
    local voidHeightPixels = Config.VOID_HEIGHT * state.cellSize  -- 2 * 64 = 128
    local bufferHeightPixels = Config.VOID_BUFFER * state.cellSize  -- 0.5 * 64 = 32

    -- Position void above the grid
    state.voidWidth = gridWidth
    state.voidHeight = voidHeightPixels
    state.voidX = state.offsetX
    state.voidY = state.offsetY - bufferHeightPixels - voidHeightPixels

    -- Initialize cells: 0=empty, 1=tower, 2=spawn zone (walkable only), 3=base
    -- Top SPAWN_ROWS are walkable but not buildable
    -- Bottom BASE_ROWS are the base zone
    local spawnRows = Config.SPAWN_ROWS or 0
    state.cells = {}
    for y = 1, state.rows do
        state.cells[y] = {}
        for x = 1, state.cols do
            if y <= spawnRows then
                state.cells[y][x] = 2  -- spawn zone (walkable, not buildable)
            elseif y > state.rows - Config.BASE_ROWS then
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

function Grid.getWorldDimensions()
    return state.worldWidth, state.worldHeight
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

function Grid.clearCell(gridX, gridY)
    if not Grid.isValidCell(gridX, gridY) then return false end
    -- Only clear if it's currently a tower (1)
    if state.cells[gridY][gridX] == 1 then
        state.cells[gridY][gridX] = 0
        return true
    end
    return false
end

-- Rendering functions moved to src/rendering/grid_renderer.lua

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

-- Get the center position for the portal (centered in void zone)
function Grid.getPortalCenter()
    -- Center horizontally on world (same as grid center X)
    local x = state.worldWidth / 2
    -- Center vertically in void zone
    local y = state.voidY + state.voidHeight / 2
    return x, y
end

-- Get the Y coordinate of the grid bottom (for collision detection)
function Grid.getGridBottom()
    return state.offsetY + state.rows * state.cellSize
end

-- Get the center position for the exit portal (below the grid)
function Grid.getExitPortalCenter()
    -- Center horizontally on world (same as grid center X)
    local x = state.worldWidth / 2
    -- Position below the grid with a buffer (symmetric with void buffer)
    local gridBottom = Grid.getGridBottom()
    local exitBuffer = (Config.EXIT_BUFFER or 1.0) * state.cellSize
    local y = gridBottom + exitBuffer
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
