-- src/systems/pathfinding.lua
-- A* pathfinding and flow field computation for tower defense
--
-- Ported from tower_refined prototype with adaptations for Tower Idle grid.

local Config = require("src.config")

local Pathfinding = {}

-- Priority queue implementation (min-heap)
local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

function PriorityQueue:new()
    return setmetatable({heap = {}, size = 0}, PriorityQueue)
end

function PriorityQueue:push(item, priority)
    self.size = self.size + 1
    self.heap[self.size] = {item = item, priority = priority}
    self:bubbleUp(self.size)
end

function PriorityQueue:pop()
    if self.size == 0 then return nil end

    local root = self.heap[1].item
    self.heap[1] = self.heap[self.size]
    self.heap[self.size] = nil
    self.size = self.size - 1

    if self.size > 0 then
        self:bubbleDown(1)
    end

    return root
end

function PriorityQueue:isEmpty()
    return self.size == 0
end

function PriorityQueue:bubbleUp(index)
    while index > 1 do
        local parent = math.floor(index / 2)
        if self.heap[index].priority < self.heap[parent].priority then
            self.heap[index], self.heap[parent] = self.heap[parent], self.heap[index]
            index = parent
        else
            break
        end
    end
end

function PriorityQueue:bubbleDown(index)
    while true do
        local smallest = index
        local left = index * 2
        local right = index * 2 + 1

        if left <= self.size and self.heap[left].priority < self.heap[smallest].priority then
            smallest = left
        end
        if right <= self.size and self.heap[right].priority < self.heap[smallest].priority then
            smallest = right
        end

        if smallest ~= index then
            self.heap[index], self.heap[smallest] = self.heap[smallest], self.heap[index]
            index = smallest
        else
            break
        end
    end
end

-- Heuristic: Manhattan distance
local function _heuristic(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

-- Check if a cell is walkable (for creeps)
-- Walkable: empty (0), spawn zone (2), base zone (3)
-- Not walkable: tower (1)
local function _isWalkable(grid, x, y)
    local cols = grid.getCols()
    local rows = grid.getRows()
    if x < 1 or x > cols or y < 1 or y > rows then
        return false
    end
    local cells = grid.getCells()
    local cell = cells[y][x]
    return cell ~= 1  -- Everything except towers is walkable
end

-- Get neighbors (4-directional)
local function _getNeighbors(grid, x, y)
    local neighbors = {}
    local directions = {
        {0, -1},  -- up
        {0, 1},   -- down
        {-1, 0},  -- left
        {1, 0},   -- right
    }

    for _, dir in ipairs(directions) do
        local nx, ny = x + dir[1], y + dir[2]
        if _isWalkable(grid, nx, ny) then
            table.insert(neighbors, {x = nx, y = ny})
        end
    end

    return neighbors
end

-- A* pathfinding
-- Returns a list of {x, y} grid coordinates from start to goal, or nil if no path
-- grid: the Grid module (with getCells, getCols, getRows functions)
function Pathfinding.findPath(grid, startX, startY, goalX, goalY)
    -- Quick check: if goal is not walkable, no path
    if not _isWalkable(grid, goalX, goalY) then
        return nil
    end

    local openSet = PriorityQueue:new()
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    local closedSet = {}

    local startKey = startY .. "," .. startX
    gScore[startKey] = 0
    fScore[startKey] = _heuristic(startX, startY, goalX, goalY)

    openSet:push({x = startX, y = startY}, fScore[startKey])

    while not openSet:isEmpty() do
        local current = openSet:pop()
        local currentKey = current.y .. "," .. current.x

        -- Goal reached
        if current.x == goalX and current.y == goalY then
            -- Reconstruct path
            local path = {}
            local node = current
            while node do
                table.insert(path, 1, {x = node.x, y = node.y})
                local nodeKey = node.y .. "," .. node.x
                node = cameFrom[nodeKey]
            end
            return path
        end

        closedSet[currentKey] = true

        local neighbors = _getNeighbors(grid, current.x, current.y)
        for _, neighbor in ipairs(neighbors) do
            local neighborKey = neighbor.y .. "," .. neighbor.x

            if not closedSet[neighborKey] then
                local tentativeG = (gScore[currentKey] or math.huge) + 1

                if tentativeG < (gScore[neighborKey] or math.huge) then
                    cameFrom[neighborKey] = current
                    gScore[neighborKey] = tentativeG
                    fScore[neighborKey] = tentativeG + _heuristic(neighbor.x, neighbor.y, goalX, goalY)

                    openSet:push(neighbor, fScore[neighborKey])
                end
            end
        end
    end

    -- No path found
    return nil
end

-- Find path from spawn point to base
-- Returns the path or nil if no path exists
-- Tries to reach ANY cell in the base row (not just center)
function Pathfinding.findPathToBase(grid, spawnX, spawnY)
    local cols = grid.getCols()
    local baseRow = grid.getBaseRow()

    -- Try to reach any cell in the base row (prefer center, but accept any)
    local baseX = math.floor((cols + 1) / 2)  -- Center column (4 for 7 cols)

    -- First try center
    local path = Pathfinding.findPath(grid, spawnX, spawnY, baseX, baseRow)
    if path then return path end

    -- Try other columns in the base row
    for x = 1, cols do
        if x ~= baseX then
            path = Pathfinding.findPath(grid, spawnX, spawnY, x, baseRow)
            if path then return path end
        end
    end

    return nil
end

-- Check if any path exists from grid entry (row 1) to base
-- Used to prevent blocking placements
-- Returns true if at least one column in row 1 can reach the base
function Pathfinding.hasValidPath(grid)
    local cols = grid.getCols()

    -- Check from every column in row 1 (where creeps enter from buffer)
    -- A valid path must exist from at least one entry point
    for x = 1, cols do
        local path = Pathfinding.findPathToBase(grid, x, 1)
        if path then
            return true  -- Found at least one valid path
        end
    end

    return false  -- No path from any column
end

-- Validate tower placement won't block all paths
function Pathfinding.canPlaceTowerAt(grid, x, y)
    -- First check basic placement rules
    if not grid.canPlaceTower(x, y) then
        return false
    end

    -- Temporarily place tower
    local cells = grid.getCells()
    local oldValue = cells[y][x]
    cells[y][x] = 1

    -- Check if path still exists
    local hasPath = Pathfinding.hasValidPath(grid)

    -- Remove temporary tower
    cells[y][x] = oldValue

    return hasPath
end

-- Get flow field for all cells pointing toward base
-- Returns a 2D table of {dx, dy} directions for each cell
function Pathfinding.computeFlowField(grid)
    local flowField = {}
    local cols = grid.getCols()
    local rows = grid.getRows()
    local baseRow = grid.getBaseRow()

    -- BFS from ALL base cells to all cells (multi-source BFS)
    local queue = {}
    local distance = {}

    -- Initialize with all base row cells as sources
    for x = 1, cols do
        table.insert(queue, {x = x, y = baseRow})
        distance[baseRow .. "," .. x] = 0
    end

    local directions = {
        {0, -1},  -- up
        {0, 1},   -- down
        {-1, 0},  -- left
        {1, 0},   -- right
    }

    -- BFS to compute distances
    local head = 1
    while head <= #queue do
        local current = queue[head]
        head = head + 1
        local currentKey = current.y .. "," .. current.x
        local currentDist = distance[currentKey]

        for _, dir in ipairs(directions) do
            local nx, ny = current.x + dir[1], current.y + dir[2]
            local neighborKey = ny .. "," .. nx

            if _isWalkable(grid, nx, ny) and not distance[neighborKey] then
                distance[neighborKey] = currentDist + 1
                table.insert(queue, {x = nx, y = ny})
            end
        end
    end

    -- Compute flow directions (each cell points toward lower distance)
    for y = 1, rows do
        flowField[y] = {}
        for x = 1, cols do
            local key = y .. "," .. x

            if distance[key] then
                local bestDir = {dx = 0, dy = 0}
                local bestDist = distance[key]

                for _, dir in ipairs(directions) do
                    local nx, ny = x + dir[1], y + dir[2]
                    local neighborKey = ny .. "," .. nx
                    local neighborDist = distance[neighborKey]

                    if neighborDist and neighborDist < bestDist then
                        bestDist = neighborDist
                        bestDir = {dx = dir[1], dy = dir[2]}
                    end
                end

                flowField[y][x] = bestDir
            else
                flowField[y][x] = nil  -- Unreachable
            end
        end
    end

    return flowField
end

return Pathfinding
