-- src/world/grid.lua
-- Grid state and queries

local Config = require("src.config")
local Settings = require("src.ui.settings")

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
    local gameWidth, gameHeight = Settings.getGameDimensions()
    if gameWidth and gameWidth > 0 then
        state.playAreaWidth = Settings.getPlayAreaWidth()  -- Full canvas width
        state.panelWidth = Settings.getPanelWidth()
    else
        -- Fallback for initial load before Settings is ready
        state.playAreaWidth = Config.CANVAS_WIDTH or 1280
        state.panelWidth = Config.PANEL_WIDTH or 320
    end
    state.cellSize = Config.CELL_SIZE

    -- Use fixed grid dimensions from config (odd numbers for true center)
    state.cols = Config.GRID_COLS or 13
    state.rows = Config.GRID_ROWS or 19

    -- Calculate grid dimensions
    local gridWidth = state.cols * state.cellSize   -- 13 * 64 = 832
    local gridHeight = state.rows * state.cellSize  -- 19 * 64 = 1216

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

function Grid.draw(showGridOverlay)
    -- Draw small dots at center of each buildable cell when placing towers
    if showGridOverlay then
        local buildableRows = state.rows - Config.BASE_ROWS
        local dotRadius = math.max(3, Config.CELL_SIZE / 10)  -- Scale with cell size
        love.graphics.setColor(Config.COLORS.grid)

        for y = 1, buildableRows do
            for x = 1, state.cols do
                -- Only show dots for empty (buildable) cells
                if state.cells[y][x] == 0 then
                    local centerX = state.offsetX + (x - 0.5) * state.cellSize
                    local centerY = state.offsetY + (y - 0.5) * state.cellSize
                    love.graphics.circle("fill", centerX, centerY, dotRadius)
                end
            end
        end
    end

    -- Base zone no longer draws tiles - exit portal draws there instead
end

function Grid.drawHover(mouseX, mouseY, canAfford, towerType)
    local gridX, gridY = Grid.screenToGrid(mouseX, mouseY)
    if not Grid.isValidCell(gridX, gridY) then return end

    local canPlace = Grid.canPlaceTower(gridX, gridY) and canAfford
    local centerX, centerY = Grid.gridToScreen(gridX, gridY)

    -- Draw highlighted dot at hovered cell (white if can place, red if cannot)
    local dotRadius = math.max(4, Config.CELL_SIZE / 8)  -- Scale with cell size
    if canPlace then
        love.graphics.setColor(1, 1, 1, 0.9)
    else
        love.graphics.setColor(1, 0.3, 0.3, 0.7)
    end
    love.graphics.circle("fill", centerX, centerY, dotRadius)

    -- Draw range preview for valid placements - subtle fill only, no border
    -- Flattened ellipse for top-down perspective
    if canPlace and towerType then
        local towerStats = Config.TOWERS[towerType]
        local range = towerStats and towerStats.range or 0
        if range > 0 then
            -- Very subtle fill ellipse (squashed vertically for perspective)
            love.graphics.setColor(1, 1, 1, 0.05)
            love.graphics.ellipse("fill", centerX, centerY, range, range * 0.9)
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
    -- Position below the grid with a buffer
    local gridBottom = Grid.getGridBottom()
    local exitBuffer = state.cellSize  -- 1 cell buffer below grid
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

-- Draw debug overlay for pathfinding visualization
function Grid.drawDebug(flowField)
    local cellSize = state.cellSize
    local offsetX = state.offsetX
    local offsetY = state.offsetY

    -- Draw grid cell boundaries
    love.graphics.setLineWidth(1)
    for y = 1, state.rows do
        for x = 1, state.cols do
            local screenX = offsetX + (x - 1) * cellSize
            local screenY = offsetY + (y - 1) * cellSize
            local cellValue = state.cells[y][x]

            -- Color based on cell state
            if cellValue == 1 then
                love.graphics.setColor(1, 0.2, 0.2, 0.3)  -- Tower: red
            elseif cellValue == 3 then
                love.graphics.setColor(0.2, 1, 0.2, 0.3)  -- Base: green
            else
                love.graphics.setColor(0.5, 0.5, 0.5, 0.2)  -- Empty: gray
            end
            love.graphics.rectangle("line", screenX, screenY, cellSize, cellSize)
        end
    end

    -- Draw row 0 (spawn buffer) cell boundaries
    love.graphics.setColor(0.6, 0.3, 0.8, 0.3)  -- Purple for spawn buffer
    for x = 1, state.cols do
        local screenX = offsetX + (x - 1) * cellSize
        local screenY = offsetY - cellSize  -- Row 0 is above the grid
        love.graphics.rectangle("line", screenX, screenY, cellSize, cellSize)
    end

    -- Draw continuous ghost paths from each spawn column following the flow field
    if flowField then
        love.graphics.setLineWidth(2)

        for startX = 1, state.cols do
            -- Check if this column has a valid flow at row 0 or row 1
            local hasPath = (flowField[0] and flowField[0][startX]) or (flowField[1] and flowField[1][startX])
            if hasPath then
                -- Trace path from row 0 to base
                local points = {}
                local x, y = startX, 0
                local maxSteps = state.rows * state.cols  -- Prevent infinite loops

                -- Start point (row 0)
                local screenX, screenY = Grid.gridToScreen(x, y)
                table.insert(points, screenX)
                table.insert(points, screenY)

                -- Follow flow field
                for _ = 1, maxSteps do
                    local flow = flowField[y] and flowField[y][x]
                    if not flow or (flow.dx == 0 and flow.dy == 0) then
                        break  -- Reached base or dead end
                    end

                    x = x + flow.dx
                    y = y + flow.dy

                    screenX, screenY = Grid.gridToScreen(x, y)
                    table.insert(points, screenX)
                    table.insert(points, screenY)

                    -- Stop if we've reached or passed the base row
                    if y >= state.rows then
                        break
                    end
                end

                -- Draw the path line with color based on column
                if #points >= 4 then
                    -- Cycle through colors for each column
                    local hue = (startX - 1) / state.cols
                    local r = math.abs(math.sin(hue * math.pi * 2)) * 0.5 + 0.3
                    local g = math.abs(math.sin((hue + 0.33) * math.pi * 2)) * 0.5 + 0.3
                    local b = math.abs(math.sin((hue + 0.66) * math.pi * 2)) * 0.5 + 0.3
                    love.graphics.setColor(r, g, b, 0.4)
                    love.graphics.line(points)
                end
            end
        end
    end

    -- Draw flow field arrows
    if flowField then
        love.graphics.setColor(0.3, 0.8, 1, 0.6)  -- Cyan
        local arrowSize = cellSize * 0.3

        -- Include row 0 in arrow display
        for y = 0, state.rows do
            for x = 1, state.cols do
                local flow = flowField[y] and flowField[y][x]
                if flow and (flow.dx ~= 0 or flow.dy ~= 0) then
                    local centerX, centerY
                    if y == 0 then
                        -- Row 0 is above the grid
                        centerX = offsetX + (x - 0.5) * cellSize
                        centerY = offsetY - cellSize + cellSize * 0.5
                    else
                        centerX = offsetX + (x - 0.5) * cellSize
                        centerY = offsetY + (y - 0.5) * cellSize
                    end

                    -- Draw arrow line
                    local endX = centerX + flow.dx * arrowSize
                    local endY = centerY + flow.dy * arrowSize
                    love.graphics.line(centerX, centerY, endX, endY)

                    -- Draw arrowhead
                    local angle = math.atan2(flow.dy, flow.dx)
                    local headSize = arrowSize * 0.4
                    love.graphics.polygon("fill",
                        endX, endY,
                        endX - headSize * math.cos(angle - 0.5), endY - headSize * math.sin(angle - 0.5),
                        endX - headSize * math.cos(angle + 0.5), endY - headSize * math.sin(angle + 0.5)
                    )
                end
            end
        end
    end
end

-- Draw ghost path from spawn to base
function Grid.drawGhostPath(path)
    if not path or #path < 2 then return end

    love.graphics.setColor(1, 1, 0.5, 0.7)  -- Yellow
    love.graphics.setLineWidth(2)

    local points = {}
    for _, node in ipairs(path) do
        local screenX, screenY = Grid.gridToScreen(node.x, node.y)
        table.insert(points, screenX)
        table.insert(points, screenY)
    end

    if #points >= 4 then
        love.graphics.line(points)
    end

    -- Draw start and end markers
    love.graphics.setColor(0.5, 1, 0.5, 0.8)  -- Green for start
    local startX, startY = Grid.gridToScreen(path[1].x, path[1].y)
    love.graphics.circle("fill", startX, startY, 6)

    love.graphics.setColor(1, 0.5, 0.5, 0.8)  -- Red for end
    local endX, endY = Grid.gridToScreen(path[#path].x, path[#path].y)
    love.graphics.circle("fill", endX, endY, 6)
end

return Grid
