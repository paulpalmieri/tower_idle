-- src/systems/pathfinding.lua
-- A* pathfinding and flow field computation for tower defense
-- Reworked: Flow field points toward nearest edge (creeps escape at any edge)

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
-- Walkable: empty (0), portal (4)
-- Not walkable: tower (1)
local function _isWalkable(grid, x, y)
    local cols = grid.getCols()
    local rows = grid.getRows()

    -- Standard bounds check
    if x < 1 or x > cols or y < 1 or y > rows then
        return false
    end

    local cells = grid.getCells()
    local cell = cells[y][x]
    return cell ~= 1  -- Everything except towers is walkable
end

-- Check if a cell is on the edge (escape point)
local function _isEdgeCell(grid, x, y)
    local cols = grid.getCols()
    local rows = grid.getRows()
    return x == 1 or x == cols or y == 1 or y == rows
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
    -- Quick check: if start is not walkable, no path
    if not _isWalkable(grid, startX, startY) then
        return nil
    end

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

-- Find path from position to nearest edge
-- Returns the path or nil if no path exists
function Pathfinding.findPathToEdge(grid, startX, startY)
    local cols = grid.getCols()
    local rows = grid.getRows()

    -- Get nearest edge cell
    local edgeX, edgeY = grid.getNearestEdge(startX, startY)

    -- Try to reach the nearest edge first
    local path = Pathfinding.findPath(grid, startX, startY, edgeX, edgeY)
    if path then return path end

    -- If nearest edge is blocked, try any edge cell
    local edges = grid.getEdgeCells()
    for _, edge in ipairs(edges) do
        if edge.x ~= edgeX or edge.y ~= edgeY then
            path = Pathfinding.findPath(grid, startX, startY, edge.x, edge.y)
            if path then return path end
        end
    end

    return nil
end

-- Check if a position can reach any edge
-- Used to validate that a cell has a valid escape route
function Pathfinding.hasValidPath(grid, fromX, fromY)
    -- Simple BFS to check if we can reach any edge
    local cols = grid.getCols()
    local rows = grid.getRows()

    if not _isWalkable(grid, fromX, fromY) then
        return false
    end

    -- If already on edge, valid
    if _isEdgeCell(grid, fromX, fromY) then
        return true
    end

    local queue = {{x = fromX, y = fromY}}
    local visited = {}
    visited[fromY .. "," .. fromX] = true

    local directions = {
        {0, -1},  -- up
        {0, 1},   -- down
        {-1, 0},  -- left
        {1, 0},   -- right
    }

    local head = 1
    while head <= #queue do
        local current = queue[head]
        head = head + 1

        for _, dir in ipairs(directions) do
            local nx, ny = current.x + dir[1], current.y + dir[2]
            local key = ny .. "," .. nx

            if _isWalkable(grid, nx, ny) and not visited[key] then
                -- Found an edge - path exists
                if _isEdgeCell(grid, nx, ny) then
                    return true
                end

                visited[key] = true
                table.insert(queue, {x = nx, y = ny})
            end
        end
    end

    return false
end

-- Validate tower placement won't block all paths from ALL spawn portals
function Pathfinding.canPlaceTowerAt(grid, x, y)
    -- First check basic placement rules
    if not grid.canPlaceTower(x, y) then
        return false
    end

    -- Temporarily place tower
    local cells = grid.getCells()
    local oldValue = cells[y][x]
    cells[y][x] = 1

    -- Check if ALL spawn portals can still reach edges
    local portalPositions = grid.getPortalGridPositions()
    local allPortalsValid = true

    for _, pos in ipairs(portalPositions) do
        if not Pathfinding.hasValidPath(grid, pos[1], pos[2]) then
            allPortalsValid = false
            break
        end
    end

    -- Remove temporary tower
    cells[y][x] = oldValue

    return allPortalsValid
end

-- Get flow field for all cells pointing toward nearest edge
-- Returns a 2D table of {dx, dy} directions for each cell
-- Uses multi-sink BFS from ALL edge cells
function Pathfinding.computeFlowField(grid)
    local flowField = {}
    local cols = grid.getCols()
    local rows = grid.getRows()

    -- BFS from ALL edge cells (multi-source/multi-sink)
    local queue = {}
    local distance = {}

    -- Initialize with all edge cells as sources (distance = 0)
    for x = 1, cols do
        -- Top edge
        if _isWalkable(grid, x, 1) then
            table.insert(queue, {x = x, y = 1})
            distance["1," .. x] = 0
        end
        -- Bottom edge
        if _isWalkable(grid, x, rows) then
            table.insert(queue, {x = x, y = rows})
            distance[rows .. "," .. x] = 0
        end
    end
    for y = 2, rows - 1 do
        -- Left edge
        if _isWalkable(grid, 1, y) then
            table.insert(queue, {x = 1, y = y})
            distance[y .. ",1"] = 0
        end
        -- Right edge
        if _isWalkable(grid, cols, y) then
            table.insert(queue, {x = cols, y = y})
            distance[y .. "," .. cols] = 0
        end
    end

    local directions = {
        {0, -1},  -- up
        {0, 1},   -- down
        {-1, 0},  -- left
        {1, 0},   -- right
    }

    -- BFS to compute distances from nearest edge for each cell
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

    -- Compute flow directions for all cells
    -- Each cell points toward the neighbor with lowest distance (closest to edge)
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
