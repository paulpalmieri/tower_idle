-- src/systems/waves.lua
-- Wave spawning and composition

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Grid = require("src.world.grid")
local Creep = require("src.entities.creep")

local Waves = {}

local state = {
    waveNumber = 0,
    waveTimer = 0,
    spawning = false,
    spawnQueue = {},
    spawnTimer = 0,
    angerLevel = 0,  -- Current anger level from Void (legacy)
    currentTier = 0, -- Current tier from Void click system (0-4)
    gameWon = false, -- True when all waves completed
}

function Waves.init()
    state.waveNumber = 0
    state.waveTimer = 0
    state.spawning = false
    state.spawnQueue = {}
    state.spawnTimer = 0
    state.angerLevel = 0
    state.currentTier = 0
    state.gameWon = false
end

-- Set the anger level (called when Void is clicked) - legacy
function Waves.setAngerLevel(anger)
    state.angerLevel = anger or 0
end

-- Set the current tier (called when Void tier changes)
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

-- Build the spawn queue based on anger level
local function _buildQueue()
    local queue = {}

    -- Boss waves only spawn the boss
    if _isBossWave(state.waveNumber) then
        table.insert(queue, "voidBoss")
        return queue
    end

    -- Get composition for current anger level (cap at max defined level)
    local maxAnger = 0
    for level, _ in pairs(Config.WAVE_ANGER_COMPOSITION) do
        if level > maxAnger then maxAnger = level end
    end
    local effectiveAnger = math.min(state.angerLevel, maxAnger)
    local composition = Config.WAVE_ANGER_COMPOSITION[effectiveAnger] or Config.WAVE_ANGER_COMPOSITION[0]

    -- Add base enemies that scale with wave number
    local waveScaling = math.floor(state.waveNumber * Config.WAVE_SCALING)

    -- Add enemies from composition
    for creepType, count in pairs(composition) do
        -- Scale count slightly with wave number
        local scaledCount = count + math.floor(waveScaling * (count / 3))
        for _ = 1, scaledCount do
            table.insert(queue, creepType)
        end
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

    EventBus.emit("wave_started", {
        waveNumber = state.waveNumber,
        enemyCount = #state.spawnQueue,
        angerLevel = state.angerLevel,
    })
end

-- Spawn the next creep from the queue
local function _spawnNext()
    if #state.spawnQueue == 0 then
        -- Don't set spawning = false here, let the wave clear check handle it
        return
    end

    -- Pop from queue
    local creepType = table.remove(state.spawnQueue, 1)

    -- Calculate multipliers based on wave number and tier
    local waveHealthMult = 1.0 + ((state.waveNumber - 1) * Config.WAVE_HEALTH_SCALING)
    local tierHpBonus = state.currentTier * Config.VOID.tierHpBonus
    local tierSpeedBonus = state.currentTier * Config.VOID.tierSpeedBonus
    local healthMultiplier = waveHealthMult * (1.0 + tierHpBonus)
    local speedMultiplier = 1.0 + tierSpeedBonus

    -- Random spawn column from the void area
    local cols = Grid.getCols()
    local spawnCol = math.random(1, cols)

    local x, y = Grid.getSpawnPosition(spawnCol)
    local creep = Creep(x, y, creepType, healthMultiplier, speedMultiplier)

    EventBus.emit("spawn_creep", { creep = creep })
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

        -- Check if wave is clear (no more queue and no creeps alive)
        if #state.spawnQueue == 0 and #creeps == 0 then
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

-- Spawn red bosses (called from void at tier 4)
function Waves.spawnRedBosses(count)
    count = count or 2

    -- Calculate tier 4 bonuses (max tier)
    local tierHpBonus = 4 * Config.VOID.tierHpBonus
    local tierSpeedBonus = 4 * Config.VOID.tierSpeedBonus
    local healthMultiplier = 1.0 + tierHpBonus
    local speedMultiplier = 1.0 + tierSpeedBonus

    local cols = Grid.getCols()

    for i = 1, count do
        -- Spread bosses across spawn columns
        local spawnCol = math.floor(cols * (i / (count + 1)))
        spawnCol = math.max(1, math.min(cols, spawnCol))

        local x, y = Grid.getSpawnPosition(spawnCol)
        local creep = Creep(x, y, "redBoss", healthMultiplier, speedMultiplier)

        EventBus.emit("spawn_creep", { creep = creep })
    end
end

return Waves
