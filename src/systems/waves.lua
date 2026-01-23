-- src/systems/waves.lua
-- Wave spawning and composition

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local SpawnCoordinator = require("src.systems.spawn_coordinator")

local Waves = {}

local state = {
    waveNumber = 0,
    waveTimer = 0,
    spawning = false,
    spawnQueue = {},
    spawnTimer = 0,
    currentTier = 0, -- Current tier from Anger (0-4), only affects enemy stats (HP/speed)
    gameWon = false, -- True when all waves completed
    activePortals = {1}, -- Which portals are active (1-4)
    currentPortalIndex = 1, -- For round-robin spawning
}

function Waves.init()
    state.waveNumber = 0
    state.waveTimer = 0
    state.spawning = false
    state.spawnQueue = {}
    state.spawnTimer = 0
    state.currentTier = 0
    state.gameWon = false
    state.activePortals = {1}  -- Start with only portal 1 active
    state.currentPortalIndex = 1
end

-- Check and activate portals based on wave number
local function _checkPortalActivation(waveNumber)
    local activationWaves = Config.SPAWN_PORTALS.activationWaves
    local portalsToActivate = {}

    for i, activationWave in ipairs(activationWaves) do
        if waveNumber >= activationWave then
            -- Check if portal is not already active
            local alreadyActive = false
            for _, activeIndex in ipairs(state.activePortals) do
                if activeIndex == i then
                    alreadyActive = true
                    break
                end
            end

            if not alreadyActive then
                table.insert(portalsToActivate, i)
            end
        end
    end

    -- Activate new portals
    for _, portalIndex in ipairs(portalsToActivate) do
        table.insert(state.activePortals, portalIndex)
        EventBus.emit("activate_portal", { index = portalIndex })
    end
end

-- Get next portal for spawning (round-robin)
local function _getNextPortal()
    local portalIndex = state.activePortals[state.currentPortalIndex]
    state.currentPortalIndex = state.currentPortalIndex + 1
    if state.currentPortalIndex > #state.activePortals then
        state.currentPortalIndex = 1
    end
    return portalIndex
end

-- Set the current tier (called when Void tier changes)
-- Tier only affects enemy stats (HP/speed), not wave composition
function Waves.setTier(tier)
    state.currentTier = tier or 0
end

-- Check if a wave number is a boss wave
local function _isBossWave(waveNum)
    for _, bw in ipairs(Config.WAVE_PROGRESSION.bossWaves) do
        if waveNum == bw then return true end
    end
    return false
end

-- Build the spawn queue based on wave number (anger only affects stats, not composition)
local function _buildQueue()
    local queue = {}

    -- Boss waves only spawn the boss
    if _isBossWave(state.waveNumber) then
        table.insert(queue, "voidBoss")
        return queue
    end

    -- Calculate total enemy count based on wave number
    local totalEnemies = Config.WAVE_BASE_ENEMIES + math.floor(state.waveNumber * Config.WAVE_SCALING)

    -- Distribute enemies between types (mix of voidSpawn and voidSpider)
    -- Later waves have more spiders (harder enemy)
    local spiderRatio = math.min(0.5, 0.2 + (state.waveNumber * 0.015))  -- 20% at wave 1, up to 50%
    local spiderCount = math.floor(totalEnemies * spiderRatio)
    local spawnCount = totalEnemies - spiderCount

    for _ = 1, spawnCount do
        table.insert(queue, "voidSpawn")
    end
    for _ = 1, spiderCount do
        table.insert(queue, "voidSpider")
    end

    -- Shuffle the queue for variety
    for i = #queue, 2, -1 do
        local j = math.random(i)
        queue[i], queue[j] = queue[j], queue[i]
    end

    return queue
end

-- Start a new wave
local function _startWave()
    -- Don't start new waves if we've already completed all waves
    if state.waveNumber >= Config.WAVE_PROGRESSION.totalWaves then
        return
    end

    state.waveNumber = state.waveNumber + 1
    state.waveTimer = 0
    state.spawning = true
    state.spawnQueue = _buildQueue()
    state.spawnTimer = 0
    state.currentPortalIndex = 1  -- Reset portal round-robin

    -- Check for portal activations
    _checkPortalActivation(state.waveNumber)

    EventBus.emit("wave_started", {
        waveNumber = state.waveNumber,
        enemyCount = #state.spawnQueue,
        tier = state.currentTier,
        activePortals = #state.activePortals,
    })
end

-- Queue the next creep spawn on the appropriate portal
local function _spawnNext()
    if #state.spawnQueue == 0 then
        -- Don't set spawning = false here, let the wave clear check handle it
        return
    end

    -- Pop from queue
    local creepType = table.remove(state.spawnQueue, 1)

    -- Calculate multipliers based on wave number and tier
    local waveHealthMult = 1.0 + ((state.waveNumber - 1) * Config.WAVE_HEALTH_SCALING)
    local tierHpBonus = state.currentTier * (Config.VOID and Config.VOID.tierHpBonus or 0.15)
    local tierSpeedBonus = state.currentTier * (Config.VOID and Config.VOID.tierSpeedBonus or 0.05)
    local healthMultiplier = waveHealthMult * (1.0 + tierHpBonus)
    local speedMultiplier = 1.0 + tierSpeedBonus

    -- Get next portal for this spawn (round-robin across active portals)
    local portalIndex = _getNextPortal()

    -- Queue the spawn on the portal (portal will charge then spawn)
    EventBus.emit("queue_spawn", {
        portalIndex = portalIndex,
        creepType = creepType,
        healthMultiplier = healthMultiplier,
        speedMultiplier = speedMultiplier,
    })
end

function Waves.update(dt, creeps)
    -- Don't update if game is won
    if state.gameWon then return end

    if state.spawning then
        -- During spawning: spawn from queue at intervals
        state.spawnTimer = state.spawnTimer + dt
        if state.spawnTimer >= Config.WAVE_SPAWN_INTERVAL then
            state.spawnTimer = state.spawnTimer - Config.WAVE_SPAWN_INTERVAL
            _spawnNext()
        end

        -- Check if wave spawning is complete (queue empty AND portal done spawning)
        -- Note: Don't wait for all creeps to die - click-spawned enemies shouldn't block wave progression
        -- But DO wait for portals to finish charging/spawning all queued creeps
        if #state.spawnQueue == 0 and SpawnCoordinator.getPendingSpawnCount() == 0 and not SpawnCoordinator.isCharging() then
            state.spawning = false
            EventBus.emit("wave_cleared", { waveNumber = state.waveNumber })

            -- Check for win condition
            if state.waveNumber >= Config.WAVE_PROGRESSION.totalWaves then
                state.gameWon = true
                EventBus.emit("game_won", {
                    waveNumber = state.waveNumber,
                    shardReward = Config.VOID_SHARDS.levelReward,
                })
            end
        end
    else
        -- Check if final wave is complete (all creeps dead after last wave)
        if state.waveNumber >= Config.WAVE_PROGRESSION.totalWaves and #creeps == 0 then
            state.gameWon = true
            EventBus.emit("wave_cleared", { waveNumber = state.waveNumber })
            EventBus.emit("game_won", {
                waveNumber = state.waveNumber,
                shardReward = Config.VOID_SHARDS.levelReward,
            })
            return
        end

        -- Between waves: increment timer
        state.waveTimer = state.waveTimer + dt

        -- Start wave when timer expires (only if not won)
        if state.waveTimer >= Config.WAVE_DURATION then
            _startWave()
        end
    end
end

function Waves.getWaveNumber()
    return state.waveNumber
end

function Waves.getTimeUntilWave()
    if state.spawning then
        return 0
    end
    return math.max(0, Config.WAVE_DURATION - state.waveTimer)
end

function Waves.isSpawning()
    return state.spawning
end

function Waves.getTotalWaves()
    return Config.WAVE_PROGRESSION.totalWaves
end

function Waves.isBossWave(waveNum)
    waveNum = waveNum or state.waveNumber
    for _, bw in ipairs(Config.WAVE_PROGRESSION.bossWaves) do
        if waveNum == bw then return true end
    end
    return false
end

function Waves.getBossWaves()
    return Config.WAVE_PROGRESSION.bossWaves
end

function Waves.isGameWon()
    return state.gameWon
end

-- Spawn red bosses (called at max anger tier)
function Waves.spawnRedBosses(count)
    count = count or 2

    -- Calculate tier 4 bonuses (max tier)
    local tierHpBonus = 4 * (Config.VOID and Config.VOID.tierHpBonus or 0.15)
    local tierSpeedBonus = 4 * (Config.VOID and Config.VOID.tierSpeedBonus or 0.05)
    local healthMultiplier = 1.0 + tierHpBonus
    local speedMultiplier = 1.0 + tierSpeedBonus

    -- Spread bosses across active portals (queue spawns for pacing)
    for i = 1, count do
        local portalIndex = state.activePortals[((i - 1) % #state.activePortals) + 1]

        EventBus.emit("queue_spawn", {
            portalIndex = portalIndex,
            creepType = "redBoss",
            healthMultiplier = healthMultiplier,
            speedMultiplier = speedMultiplier,
        })
    end
end

-- Get count of active portals
function Waves.getActivePortalCount()
    return #state.activePortals
end

-- Get list of active portal indices
function Waves.getActivePortals()
    return state.activePortals
end

return Waves
