-- src/systems/spawn_coordinator.lua
-- Coordinates entity spawning via events

local EventBus = require("src.core.event_bus")
local EntityManager = require("src.core.entity_manager")

-- Lazy-loaded entity classes to avoid circular dependencies
local LobbedProjectile, Blackhole, LightningProjectile

local SpawnCoordinator = {}

-- Void reference for spawn registration (set by Game)
local voidRef = nil

local function loadEntityClasses()
    if not LobbedProjectile then
        LobbedProjectile = require("src.entities.lobbed_projectile")
        Blackhole = require("src.entities.blackhole")
        LightningProjectile = require("src.entities.lightning_projectile")
    end
end

function SpawnCoordinator.init()
    -- Subscribe to spawn events

    EventBus.on("spawn_creep", function(data)
        EntityManager.addCreep(data.creep)
        -- Register spawn with void for tear effect rendering
        if voidRef then
            voidRef:registerSpawn(data.creep)
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

-- Set the void reference for spawn registration
function SpawnCoordinator.setVoid(void)
    voidRef = void
end

return SpawnCoordinator
