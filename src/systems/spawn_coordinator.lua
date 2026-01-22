-- src/systems/spawn_coordinator.lua
-- Coordinates entity spawning via events
-- Manages sequential portal charging (only ONE portal charges at a time)

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local EntityManager = require("src.core.entity_manager")
local Grid = require("src.world.grid")

-- Lazy-loaded entity classes to avoid circular dependencies
local LobbedProjectile, Blackhole, LightningProjectile, Creep

local SpawnCoordinator = {}

-- Spawn portals reference for spawn registration (set by Game)
local spawnPortalsRef = {}

-- Global spawn queue for sequential portal charging
local spawnQueue = {}
local currentlyCharging = false  -- Is any portal currently charging?

local function loadEntityClasses()
    if not LobbedProjectile then
        LobbedProjectile = require("src.entities.lobbed_projectile")
        Blackhole = require("src.entities.blackhole")
        LightningProjectile = require("src.entities.lightning_projectile")
    end
end

local function loadCreepClass()
    if not Creep then
        Creep = require("src.entities.creep")
    end
end

-- Start the next portal charging if queue has items and nothing is charging
local function _startNextCharge()
    if currentlyCharging or #spawnQueue == 0 then
        return
    end

    -- Get next spawn from queue (don't remove yet - remove on completion)
    local spawnData = spawnQueue[1]
    local portal = spawnPortalsRef[spawnData.portalIndex]

    if portal and portal.isActive then
        currentlyCharging = true
        portal:startCharging(spawnData.creepType, spawnData.healthMultiplier, spawnData.speedMultiplier)
    else
        -- Portal not active, skip this spawn
        table.remove(spawnQueue, 1)
        _startNextCharge()
    end
end

function SpawnCoordinator.init()
    -- Reset state
    spawnQueue = {}
    currentlyCharging = false

    -- Subscribe to spawn events

    -- Queue a spawn (goes into global queue, portals charge sequentially)
    EventBus.on("queue_spawn", function(data)
        table.insert(spawnQueue, {
            portalIndex = data.portalIndex or 1,
            creepType = data.creepType,
            healthMultiplier = data.healthMultiplier,
            speedMultiplier = data.speedMultiplier,
        })

        -- Try to start charging if nothing is currently charging
        _startNextCharge()
    end)

    -- Portal finished charging - create the actual creep and start next portal
    EventBus.on("portal_spawn_ready", function(data)
        loadCreepClass()
        local portalIndex = data.portalIndex or 1
        local x, y = Grid.getSpawnPosition(portalIndex)

        local creep = Creep(x, y, data.creepType, data.healthMultiplier, data.speedMultiplier)

        -- Add to entity manager
        EntityManager.addCreep(creep)

        -- Register spawn with portal for tear effect
        local portal = spawnPortalsRef[portalIndex]
        if portal then
            portal:registerSpawn(creep)
        end

        -- Remove the completed spawn from queue
        if #spawnQueue > 0 and spawnQueue[1].portalIndex == portalIndex then
            table.remove(spawnQueue, 1)
        end

        -- Portal is done charging
        currentlyCharging = false

        -- Start next portal charging (if queue has more)
        _startNextCharge()
    end)

    -- Legacy direct spawn (for compatibility)
    EventBus.on("spawn_creep", function(data)
        EntityManager.addCreep(data.creep)
        -- Register spawn with appropriate portal for tear effect rendering
        local portalIndex = data.portalIndex or 1
        local portal = spawnPortalsRef[portalIndex]
        if portal then
            portal:registerSpawn(data.creep)
        end
    end)

    EventBus.on("spawn_lobbed_projectile", function(data)
        loadEntityClasses()
        local proj = LobbedProjectile(
            data.startX, data.startY,
            data.targetX, data.targetY,
            data.damage, data.sourceTower
        )
        EntityManager.addLobbedProjectile(proj)
    end)

    EventBus.on("spawn_blackhole", function(data)
        loadEntityClasses()
        local hole = Blackhole(data.x, data.y, data.sourceTower)
        EntityManager.addBlackhole(hole)
    end)

    EventBus.on("spawn_lightning_bolt", function(data)
        loadEntityClasses()
        local bolt = LightningProjectile(
            data.x, data.y, data.angle,
            data.damage, data.sourceTower, data.canPierce
        )
        EntityManager.addLightningProjectile(bolt)
    end)
end

-- Set the spawn portals reference for spawn registration
function SpawnCoordinator.setSpawnPortals(portals)
    spawnPortalsRef = portals or {}
end

-- Get count of pending spawns in queue
function SpawnCoordinator.getPendingSpawnCount()
    return #spawnQueue
end

-- Check if any portal is currently charging
function SpawnCoordinator.isCharging()
    return currentlyCharging
end

return SpawnCoordinator
