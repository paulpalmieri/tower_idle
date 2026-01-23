-- src/rendering/grid_renderer.lua
-- Grid rendering (extracted from Grid.lua)

local Config = require("src.config")
local Grid = require("src.world.grid")
local Pathfinding = require("src.systems.pathfinding")

local GridRenderer = {}

-- Cache of which cells are valid for tower placement
-- Recomputed only when grid changes (tower placed/sold)
local placeableCache = {}
local cacheValid = false

-- Recompute the placeable cells cache
-- Call this after any grid change (tower placed, sold, or grid init)
function GridRenderer.invalidateCache()
    cacheValid = false
end

function GridRenderer.rebuildCache()
    local cols = Grid.getCols()
    local rows = Grid.getRows()

    placeableCache = {}
    for y = 1, rows do
        placeableCache[y] = {}
        for x = 1, cols do
            placeableCache[y][x] = Pathfinding.canPlaceTowerAt(Grid, x, y)
        end
    end
    cacheValid = true
end

function GridRenderer.draw(showGridOverlay)
    if not showGridOverlay then return end

    -- Rebuild cache if invalidated
    if not cacheValid then
        GridRenderer.rebuildCache()
    end

    local cols = Grid.getCols()
    local rows = Grid.getRows()
    local cellSize = Config.CELL_SIZE

    -- Draw grid cells only for cells where towers can actually be placed
    love.graphics.setColor(Config.COLORS.grid)
    love.graphics.setLineWidth(1)

    for y = 1, rows do
        for x = 1, cols do
            -- Use cached placement validity
            if placeableCache[y] and placeableCache[y][x] then
                local centerX, centerY = Grid.gridToScreen(x, y)
                local cellX = centerX - cellSize / 2
                local cellY = centerY - cellSize / 2
                love.graphics.rectangle("line", cellX, cellY, cellSize, cellSize)
            end
        end
    end
end

function GridRenderer.drawHover(mouseX, mouseY, canAfford, towerType)
    local gridX, gridY = Grid.screenToGrid(mouseX, mouseY)
    if not Grid.isValidCell(gridX, gridY) then return end

    -- Rebuild cache if invalidated (in case hover is called before draw)
    if not cacheValid then
        GridRenderer.rebuildCache()
    end

    -- Use cached placement validity instead of expensive pathfinding check
    local canPlaceAtCell = placeableCache[gridY] and placeableCache[gridY][gridX]
    local canPlace = canPlaceAtCell and canAfford
    local centerX, centerY = Grid.gridToScreen(gridX, gridY)
    local cellSize = Config.CELL_SIZE

    -- Calculate cell top-left corner
    local cellX = centerX - cellSize / 2
    local cellY = centerY - cellSize / 2

    -- Fill the hovered cell (green if can place, red if cannot)
    if canPlace then
        love.graphics.setColor(0.2, 0.8, 0.3, 0.4)  -- Green
    else
        love.graphics.setColor(0.8, 0.2, 0.2, 0.4)  -- Red
    end
    love.graphics.rectangle("fill", cellX, cellY, cellSize, cellSize)

    -- Draw cell border for emphasis
    if canPlace then
        love.graphics.setColor(0.3, 1.0, 0.4, 0.7)  -- Bright green border
    else
        love.graphics.setColor(1.0, 0.3, 0.3, 0.7)  -- Bright red border
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cellX, cellY, cellSize, cellSize)

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

-- Draw debug overlay for pathfinding visualization
function GridRenderer.drawDebug(flowField)
    local cellSize = Config.CELL_SIZE
    local cols = Grid.getCols()
    local rows = Grid.getRows()
    local cells = Grid.getCells()

    -- Draw grid cell boundaries
    love.graphics.setLineWidth(1)
    for y = 1, rows do
        for x = 1, cols do
            local screenX, screenY = Grid.gridToScreen(x, y)
            -- Adjust to cell corner instead of center
            screenX = screenX - cellSize / 2
            screenY = screenY - cellSize / 2
            local cellValue = cells[y] and cells[y][x] or 0

            -- Color based on cell state
            if cellValue == 1 then
                love.graphics.setColor(1, 0.2, 0.2, 0.3)  -- Tower: red
            elseif cellValue == 4 then
                love.graphics.setColor(0.6, 0.3, 0.8, 0.3)  -- Portal: purple
            elseif Grid.isEdgeCell(x, y) then
                love.graphics.setColor(0.2, 1, 0.2, 0.3)  -- Edge: green
            else
                love.graphics.setColor(0.5, 0.5, 0.5, 0.2)  -- Empty: gray
            end
            love.graphics.rectangle("line", screenX, screenY, cellSize, cellSize)
        end
    end

    -- Draw continuous ghost paths from spawn portals following the flow field
    if flowField then
        love.graphics.setLineWidth(2)

        -- Get portal positions and trace paths from each
        local portalPositions = Config.SPAWN_PORTALS and Config.SPAWN_PORTALS.positions or {}
        for i, pos in ipairs(portalPositions) do
            local startX, startY = pos[1], pos[2]
            local hasPath = flowField[startY] and flowField[startY][startX]
            if hasPath then
                -- Trace path from portal to edge
                local points = {}
                local x, y = startX, startY
                local maxSteps = rows * cols  -- Prevent infinite loops

                -- Start point
                local screenX, screenY = Grid.gridToScreen(x, y)
                table.insert(points, screenX)
                table.insert(points, screenY)

                -- Follow flow field
                for _ = 1, maxSteps do
                    local flow = flowField[y] and flowField[y][x]
                    if not flow or (flow.dx == 0 and flow.dy == 0) then
                        break  -- Reached edge or dead end
                    end

                    x = x + flow.dx
                    y = y + flow.dy

                    screenX, screenY = Grid.gridToScreen(x, y)
                    table.insert(points, screenX)
                    table.insert(points, screenY)

                    -- Stop if we've reached an edge
                    if Grid.isEdgeCell(x, y) then
                        break
                    end
                end

                -- Draw the path line with color based on portal index
                if #points >= 4 then
                    -- Cycle through colors for each portal
                    local hue = (i - 1) / 4
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

        for y = 1, rows do
            for x = 1, cols do
                local flow = flowField[y] and flowField[y][x]
                if flow and (flow.dx ~= 0 or flow.dy ~= 0) then
                    local centerX, centerY = Grid.gridToScreen(x, y)

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
function GridRenderer.drawGhostPath(path)
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

return GridRenderer
