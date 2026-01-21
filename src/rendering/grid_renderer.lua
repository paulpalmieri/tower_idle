-- src/rendering/grid_renderer.lua
-- Grid rendering (extracted from Grid.lua)

local Config = require("src.config")
local Grid = require("src.world.grid")

local GridRenderer = {}

function GridRenderer.draw(showGridOverlay)
    if not showGridOverlay then return end

    local cols = Grid.getCols()
    local rows = Grid.getRows()
    local cells = Grid.getCells()
    local cellSize = Config.CELL_SIZE
    local spawnRows = Config.SPAWN_ROWS or 0
    local buildableRows = rows - Config.BASE_ROWS
    local dotRadius = math.max(3, cellSize / 10)

    love.graphics.setColor(Config.COLORS.grid)

    -- Start after spawn rows, end before base rows
    for y = spawnRows + 1, buildableRows do
        for x = 1, cols do
            -- Only show dots for empty (buildable) cells
            if cells[y][x] == 0 then
                local centerX, centerY = Grid.gridToScreen(x, y)
                love.graphics.circle("fill", centerX, centerY, dotRadius)
            end
        end
    end
end

function GridRenderer.drawHover(mouseX, mouseY, canAfford, towerType)
    local gridX, gridY = Grid.screenToGrid(mouseX, mouseY)
    if not Grid.isValidCell(gridX, gridY) then return end

    local canPlace = Grid.canPlaceTower(gridX, gridY) and canAfford
    local centerX, centerY = Grid.gridToScreen(gridX, gridY)

    -- Draw highlighted dot at hovered cell (white if can place, red if cannot)
    local dotRadius = math.max(4, Config.CELL_SIZE / 8)
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
            local cellValue = cells[y][x]

            -- Color based on cell state
            if cellValue == 1 then
                love.graphics.setColor(1, 0.2, 0.2, 0.3)  -- Tower: red
            elseif cellValue == 2 then
                love.graphics.setColor(0.6, 0.3, 0.8, 0.3)  -- Spawn zone: purple
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
    for x = 1, cols do
        local screenX, screenY = Grid.gridToScreen(x, 0)
        screenX = screenX - cellSize / 2
        screenY = screenY - cellSize / 2
        love.graphics.rectangle("line", screenX, screenY, cellSize, cellSize)
    end

    -- Draw continuous ghost paths from each spawn column following the flow field
    if flowField then
        love.graphics.setLineWidth(2)

        for startX = 1, cols do
            -- Check if this column has a valid flow at row 0 or row 1
            local hasPath = (flowField[0] and flowField[0][startX]) or (flowField[1] and flowField[1][startX])
            if hasPath then
                -- Trace path from row 0 to base
                local points = {}
                local x, y = startX, 0
                local maxSteps = rows * cols  -- Prevent infinite loops

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
                    if y >= rows then
                        break
                    end
                end

                -- Draw the path line with color based on column
                if #points >= 4 then
                    -- Cycle through colors for each column
                    local hue = (startX - 1) / cols
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
        for y = 0, rows do
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
