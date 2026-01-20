-- src/systems/spatial_hash.lua
-- Spatial hash grid for efficient range queries
-- Reduces O(n) full-list scans to O(1) average for spatial lookups

local SpatialHash = {}
SpatialHash.__index = SpatialHash

-- Default cell size: should be >= largest tower range for best performance
local DEFAULT_CELL_SIZE = 200

-- Create a new spatial hash grid
function SpatialHash.new(cellSize)
    local self = setmetatable({}, SpatialHash)
    self.cellSize = cellSize or DEFAULT_CELL_SIZE
    self.cells = {}
    self.entityToCell = {}  -- Maps entity -> {cellKey, index in cell}
    return self
end

-- Convert world position to cell key
function SpatialHash:_getCellKey(x, y)
    local cx = math.floor(x / self.cellSize)
    local cy = math.floor(y / self.cellSize)
    return cx .. "," .. cy
end

-- Get cell coordinates from position
function SpatialHash:_getCellCoords(x, y)
    return math.floor(x / self.cellSize), math.floor(y / self.cellSize)
end

-- Clear all entities from the grid
function SpatialHash:clear()
    self.cells = {}
    self.entityToCell = {}
end

-- Insert an entity into the grid
function SpatialHash:insert(entity)
    if not entity or entity.dead then return end

    local key = self:_getCellKey(entity.x, entity.y)

    -- Create cell if needed
    if not self.cells[key] then
        self.cells[key] = {}
    end

    -- Add to cell
    table.insert(self.cells[key], entity)

    -- Track entity's cell for efficient updates
    self.entityToCell[entity] = {
        key = key,
        index = #self.cells[key]
    }
end

-- Remove an entity from the grid
function SpatialHash:remove(entity)
    local cellInfo = self.entityToCell[entity]
    if not cellInfo then return end

    local cell = self.cells[cellInfo.key]
    if cell then
        -- Swap with last element and remove (O(1) removal)
        local lastIdx = #cell
        if cellInfo.index ~= lastIdx then
            cell[cellInfo.index] = cell[lastIdx]
            -- Update swapped entity's index
            local swappedEntity = cell[cellInfo.index]
            if self.entityToCell[swappedEntity] then
                self.entityToCell[swappedEntity].index = cellInfo.index
            end
        end
        cell[lastIdx] = nil

        -- Clean up empty cells
        if #cell == 0 then
            self.cells[cellInfo.key] = nil
        end
    end

    self.entityToCell[entity] = nil
end

-- Update entity position in the grid (call when entity moves)
function SpatialHash:update(entity)
    if not entity then return end

    local newKey = self:_getCellKey(entity.x, entity.y)
    local cellInfo = self.entityToCell[entity]

    -- If entity not in grid, insert it
    if not cellInfo then
        self:insert(entity)
        return
    end

    -- If cell hasn't changed, nothing to do
    if cellInfo.key == newKey then return end

    -- Remove from old cell and add to new cell
    self:remove(entity)
    self:insert(entity)
end

-- Query all entities within a radius of a point
-- Returns an iterator function for memory efficiency
function SpatialHash:queryRadius(x, y, radius)
    local results = {}
    local radiusSq = radius * radius

    -- Calculate cell range to check
    local minCx, minCy = self:_getCellCoords(x - radius, y - radius)
    local maxCx, maxCy = self:_getCellCoords(x + radius, y + radius)

    -- Check all cells in range
    for cy = minCy, maxCy do
        for cx = minCx, maxCx do
            local key = cx .. "," .. cy
            local cell = self.cells[key]
            if cell then
                for _, entity in ipairs(cell) do
                    if not entity.dead then
                        local dx = entity.x - x
                        local dy = entity.y - y
                        local distSq = dx * dx + dy * dy
                        if distSq <= radiusSq then
                            table.insert(results, entity)
                        end
                    end
                end
            end
        end
    end

    return results
end

-- Query all entities within a radius, returning the closest one
function SpatialHash:queryClosest(x, y, radius)
    local closest = nil
    local closestDistSq = radius * radius

    -- Calculate cell range to check
    local minCx, minCy = self:_getCellCoords(x - radius, y - radius)
    local maxCx, maxCy = self:_getCellCoords(x + radius, y + radius)

    -- Check all cells in range
    for cy = minCy, maxCy do
        for cx = minCx, maxCx do
            local key = cx .. "," .. cy
            local cell = self.cells[key]
            if cell then
                for _, entity in ipairs(cell) do
                    if not entity.dead then
                        local dx = entity.x - x
                        local dy = entity.y - y
                        local distSq = dx * dx + dy * dy
                        if distSq <= closestDistSq then
                            closest = entity
                            closestDistSq = distSq
                        end
                    end
                end
            end
        end
    end

    return closest, closestDistSq
end

-- Get entity count (for debugging)
function SpatialHash:getEntityCount()
    local count = 0
    for _, cell in pairs(self.cells) do
        count = count + #cell
    end
    return count
end

-- Get cell count (for debugging)
function SpatialHash:getCellCount()
    local count = 0
    for _ in pairs(self.cells) do
        count = count + 1
    end
    return count
end

return SpatialHash
