-- src/world/grid.lua
-- Grid state and queries (data only, no rendering)
-- Reworked for 40x40 grid with 4 spawn portals at center, creeps escape at edges

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
    worldWidth = 0,
    worldHeight = 0,
    -- Portal grid positions (cached from config)
    portalPositions = {},
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

    -- Use fixed grid dimensions from config (40x40)
    state.cols = Config.GRID_COLS or 40
    state.rows = Config.GRID_ROWS or 40

    -- Calculate grid dimensions
    local gridWidth = state.cols * state.cellSize   -- 40 * 32 = 1280
    local gridHeight = state.rows * state.cellSize  -- 40 * 32 = 1280

    -- CENTER GRID ON WORLD
    -- World center: (2800/2, 1800/2) = (1400, 900)
    -- Grid offset = world center - grid half size
    local worldCenterX = worldWidth / 2
    local worldCenterY = worldHeight / 2

    state.offsetX = math.floor(worldCenterX - gridWidth / 2)
    state.offsetY = math.floor(worldCenterY - gridHeight / 2)

    -- Cache portal positions from config
    state.portalPositions = Config.SPAWN_PORTALS.positions or {{20, 20}}

    -- Initialize cells: 0=empty (buildable), 1=tower, 4=portal (walkable, not buildable)
    state.cells = {}
    for y = 1, state.rows do
        state.cells[y] = {}
        for x = 1, state.cols do
            state.cells[y][x] = 0  -- All cells start empty
        end
    end

    -- Mark 3x3 area around each portal as type 4 (unbuildable but walkable)
    for _, pos in ipairs(state.portalPositions) do
        local px, py = pos[1], pos[2]
        for dy = -1, 1 do
            for dx = -1, 1 do
                local cx, cy = px + dx, py + dy
                if Grid.isValidCell(cx, cy) then
                    state.cells[cy][cx] = 4
                end
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
    return state.cells[y][x] == 0  -- Only empty cells are buildable
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

-- =============================================================================
-- EDGE DETECTION (creeps escape at any edge)
-- =============================================================================

-- Check if a cell is on the grid edge
function Grid.isEdgeCell(gridX, gridY)
    if not Grid.isValidCell(gridX, gridY) then return false end
    return gridX == 1 or gridX == state.cols or gridY == 1 or gridY == state.rows
end

-- Get all edge cells (perimeter of grid)
function Grid.getEdgeCells()
    local edges = {}
    -- Top and bottom rows
    for x = 1, state.cols do
        table.insert(edges, {x = x, y = 1})
        table.insert(edges, {x = x, y = state.rows})
    end
    -- Left and right columns (excluding corners already added)
    for y = 2, state.rows - 1 do
        table.insert(edges, {x = 1, y = y})
        table.insert(edges, {x = state.cols, y = y})
    end
    return edges
end

-- Get the nearest edge cell from a given position
function Grid.getNearestEdge(gridX, gridY)
    local distToLeft = gridX - 1
    local distToRight = state.cols - gridX
    local distToTop = gridY - 1
    local distToBottom = state.rows - gridY

    local minDist = math.min(distToLeft, distToRight, distToTop, distToBottom)

    if minDist == distToLeft then
        return 1, gridY
    elseif minDist == distToRight then
        return state.cols, gridY
    elseif minDist == distToTop then
        return gridX, 1
    else
        return gridX, state.rows
    end
end

-- =============================================================================
-- PORTAL FUNCTIONS (4 spawn portals in 2x2 pattern)
-- =============================================================================

-- Get portal grid positions from config
function Grid.getPortalGridPositions()
    return state.portalPositions
end

-- Get world position for a portal by index (1-4)
function Grid.getPortalWorldPosition(index)
    local pos = state.portalPositions[index]
    if not pos then return nil, nil end
    return Grid.gridToScreen(pos[1], pos[2])
end

-- Get spawn position from a portal (random cell within 3x3 area around portal)
function Grid.getSpawnPosition(portalIndex)
    portalIndex = portalIndex or math.random(1, #state.portalPositions)
    portalIndex = math.max(1, math.min(#state.portalPositions, portalIndex))

    local pos = state.portalPositions[portalIndex]
    if not pos then
        return state.worldWidth / 2, state.worldHeight / 2
    end

    -- Pick random cell within 3x3 area around portal
    local dx = math.random(-1, 1)
    local dy = math.random(-1, 1)
    local spawnGridX = pos[1] + dx
    local spawnGridY = pos[2] + dy

    -- Clamp to valid grid bounds
    spawnGridX = math.max(1, math.min(state.cols, spawnGridX))
    spawnGridY = math.max(1, math.min(state.rows, spawnGridY))

    return Grid.gridToScreen(spawnGridX, spawnGridY)
end

-- =============================================================================
-- EXPOSE STATE FOR PATHFINDING
-- =============================================================================

function Grid.getCells() return state.cells end
function Grid.getCols() return state.cols end
function Grid.getRows() return state.rows end
function Grid.getCellSize() return state.cellSize end
function Grid.getOffset() return state.offsetX, state.offsetY end

-- Get grid bounds in world coordinates
function Grid.getGridBounds()
    local gridWidth = state.cols * state.cellSize
    local gridHeight = state.rows * state.cellSize
    return state.offsetX, state.offsetY, gridWidth, gridHeight
end

return Grid
