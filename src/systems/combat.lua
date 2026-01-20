-- src/systems/combat.lua
-- Damage calculation and targeting

local SpatialHash = require("src.systems.spatial_hash")

local Combat = {}

-- Spatial hash for efficient range queries
local creepSpatialHash = nil

function Combat.init()
    -- Initialize spatial hash with cell size ~= largest tower range
    creepSpatialHash = SpatialHash.new(200)
end

-- Rebuild the spatial hash from current creep list
-- Should be called once per frame before tower updates
function Combat.rebuildSpatialHash(creeps)
    if not creepSpatialHash then
        creepSpatialHash = SpatialHash.new(200)
    end

    creepSpatialHash:clear()
    for _, creep in ipairs(creeps) do
        if not creep.dead then
            creepSpatialHash:insert(creep)
        end
    end
end

-- Get the spatial hash (for projectile collision, etc.)
function Combat.getSpatialHash()
    return creepSpatialHash
end

function Combat.calculateDamage(baseDamage, multipliers)
    local damage = baseDamage
    if multipliers then
        for _, mult in ipairs(multipliers) do
            damage = damage * mult
        end
    end
    return math.floor(damage)
end

-- Find closest target in range using spatial hash (or fallback to O(n) scan)
function Combat.findTarget(tower, creeps)
    -- Use spatial hash if available (much faster for large creep counts)
    if creepSpatialHash then
        return creepSpatialHash:queryClosest(tower.x, tower.y, tower.range)
    end

    -- Fallback: O(n) scan using squared distances (avoids sqrt)
    local closest = nil
    local closestDistSq = math.huge
    local rangeSq = tower.range * tower.range

    for _, creep in ipairs(creeps) do
        if not creep.dead then
            local dx = creep.x - tower.x
            local dy = creep.y - tower.y
            local distSq = dx * dx + dy * dy

            if distSq <= rangeSq and distSq < closestDistSq then
                closest = creep
                closestDistSq = distSq
            end
        end
    end

    return closest
end

-- Find all creeps within range (uses spatial hash if available)
function Combat.findAllInRange(x, y, radius, creeps)
    if creepSpatialHash then
        return creepSpatialHash:queryRadius(x, y, radius)
    end

    -- Fallback: O(n) scan
    local results = {}
    local radiusSq = radius * radius

    for _, creep in ipairs(creeps) do
        if not creep.dead then
            local dx = creep.x - x
            local dy = creep.y - y
            local distSq = dx * dx + dy * dy
            if distSq <= radiusSq then
                table.insert(results, creep)
            end
        end
    end

    return results
end

-- Check if position is in range (uses squared distance)
function Combat.isInRange(x, y, targetX, targetY, range)
    local dx = targetX - x
    local dy = targetY - y
    return (dx * dx + dy * dy) <= (range * range)
end

-- Get squared distance (for when you need the value but don't need sqrt)
function Combat.distanceSquared(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

return Combat
