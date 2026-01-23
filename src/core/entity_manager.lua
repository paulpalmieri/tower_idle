-- src/core/entity_manager.lua
-- Manages all entity collections and provides query interface

local EntityManager = {}

-- Private state
local state = {
    -- Entity collections
    towers = {},
    creeps = {},
    projectiles = {},
    groundEffects = {},
    chainLightnings = {},
    lobbedProjectiles = {},
    blackholes = {},
    lightningProjectiles = {},
    explosionBursts = {},

    -- Tower Y-sorting cache (optimization: towers don't move)
    towersSortedByY = {},
    towersSortDirty = true,
}

-- =============================================================================
-- LIFECYCLE
-- =============================================================================

function EntityManager.init()
    EntityManager.clear()
end

function EntityManager.clear()
    state.towers = {}
    state.creeps = {}
    state.projectiles = {}
    state.groundEffects = {}
    state.chainLightnings = {}
    state.lobbedProjectiles = {}
    state.blackholes = {}
    state.lightningProjectiles = {}
    state.explosionBursts = {}
    state.towersSortedByY = {}
    state.towersSortDirty = true
end

-- =============================================================================
-- COLLECTION ACCESSORS (return table references)
-- =============================================================================

function EntityManager.getTowers()
    return state.towers
end

function EntityManager.getCreeps()
    return state.creeps
end

function EntityManager.getProjectiles()
    return state.projectiles
end

function EntityManager.getGroundEffects()
    return state.groundEffects
end

function EntityManager.getChainLightnings()
    return state.chainLightnings
end

function EntityManager.getLobbedProjectiles()
    return state.lobbedProjectiles
end

function EntityManager.getBlackholes()
    return state.blackholes
end

function EntityManager.getLightningProjectiles()
    return state.lightningProjectiles
end

function EntityManager.getExplosionBursts()
    return state.explosionBursts
end

-- =============================================================================
-- ADD OPERATIONS
-- =============================================================================

function EntityManager.addTower(tower)
    table.insert(state.towers, tower)
    state.towersSortDirty = true
end

function EntityManager.addCreep(creep)
    table.insert(state.creeps, creep)
end

function EntityManager.addProjectile(projectile)
    table.insert(state.projectiles, projectile)
end

function EntityManager.addGroundEffect(effect)
    table.insert(state.groundEffects, effect)
end

function EntityManager.addChainLightning(lightning)
    table.insert(state.chainLightnings, lightning)
end

function EntityManager.addLobbedProjectile(projectile)
    table.insert(state.lobbedProjectiles, projectile)
end

function EntityManager.addBlackhole(blackhole)
    table.insert(state.blackholes, blackhole)
end

function EntityManager.addLightningProjectile(projectile)
    table.insert(state.lightningProjectiles, projectile)
end

function EntityManager.addExplosionBurst(burst)
    table.insert(state.explosionBursts, burst)
end

-- =============================================================================
-- REMOVE OPERATIONS
-- =============================================================================

function EntityManager.removeTower(tower)
    for i = #state.towers, 1, -1 do
        if state.towers[i] == tower then
            table.remove(state.towers, i)
            state.towersSortDirty = true
            return true
        end
    end
    return false
end

-- Remove all dead entities from a collection, returns removed entities
local function removeDeadFromCollection(collection)
    local removed = {}
    for i = #collection, 1, -1 do
        if collection[i].dead then
            table.insert(removed, table.remove(collection, i))
        end
    end
    return removed
end

function EntityManager.removeDeadCreeps()
    return removeDeadFromCollection(state.creeps)
end

function EntityManager.removeDeadProjectiles()
    return removeDeadFromCollection(state.projectiles)
end

function EntityManager.removeDeadGroundEffects()
    return removeDeadFromCollection(state.groundEffects)
end

function EntityManager.removeDeadChainLightnings()
    return removeDeadFromCollection(state.chainLightnings)
end

function EntityManager.removeDeadLobbedProjectiles()
    return removeDeadFromCollection(state.lobbedProjectiles)
end

function EntityManager.removeDeadBlackholes()
    return removeDeadFromCollection(state.blackholes)
end

function EntityManager.removeDeadLightningProjectiles()
    return removeDeadFromCollection(state.lightningProjectiles)
end

function EntityManager.removeDeadExplosionBursts()
    return removeDeadFromCollection(state.explosionBursts)
end

-- =============================================================================
-- QUERIES
-- =============================================================================

-- Find a tower at the given world position
function EntityManager.findTowerAt(x, y, towerSize)
    for _, tower in ipairs(state.towers) do
        local dx = x - tower.x
        local dy = y - tower.y
        if dx * dx + dy * dy <= towerSize * towerSize then
            return tower
        end
    end
    return nil
end

-- Get towers sorted by Y coordinate (cached)
function EntityManager.getTowersSortedByY()
    if state.towersSortDirty then
        -- Rebuild the sorted list
        state.towersSortedByY = {}
        for _, tower in ipairs(state.towers) do
            table.insert(state.towersSortedByY, tower)
        end
        table.sort(state.towersSortedByY, function(a, b)
            return a.y < b.y
        end)
        state.towersSortDirty = false
    end
    return state.towersSortedByY
end

-- Mark towers sort cache as dirty
function EntityManager.markTowersSortDirty()
    state.towersSortDirty = true
end

-- =============================================================================
-- COUNT QUERIES
-- =============================================================================

function EntityManager.getTowerCount()
    return #state.towers
end

function EntityManager.getCreepCount()
    return #state.creeps
end

function EntityManager.getProjectileCount()
    return #state.projectiles
end

return EntityManager
