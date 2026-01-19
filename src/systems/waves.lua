-- src/systems/waves.lua
-- Wave spawning and composition

local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local Waves = {}

local state = {
    waveNumber = 0,
    waveTimer = 0,
    spawning = false,
    spawnQueue = {},
    spawnTimer = 0,
}

local SPAWN_INTERVAL = 0.5  -- Time between spawning each creep

function Waves.init()
    state.waveNumber = 0
    state.waveTimer = 0
    state.spawning = false
    state.spawnQueue = {}
    state.spawnTimer = 0
end

-- Build the spawn queue based on sent enemies
local function buildQueue(sentCounts)
    local queue = {}

    -- Base triangles for the wave (scales with wave number)
    local baseCount = Config.WAVE_BASE_ENEMIES + (state.waveNumber * Config.WAVE_SCALING)
    for _ = 1, baseCount do
        table.insert(queue, "triangle")
    end

    -- Add extras based on sent ratios
    for creepType, ratio in pairs(Config.WAVE_SEND_RATIOS) do
        local sentCount = sentCounts[creepType] or 0
        local extras = math.floor(sentCount / ratio)
        for _ = 1, extras do
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
local function startWave(sentCounts)
    state.waveNumber = state.waveNumber + 1
    state.waveTimer = 0
    state.spawning = true
    state.spawnQueue = buildQueue(sentCounts)
    state.spawnTimer = 0

    EventBus.emit("wave_started", {
        waveNumber = state.waveNumber,
        enemyCount = #state.spawnQueue,
    })
end

-- Spawn the next creep from the queue
local function spawnNext(Grid, Game)
    if #state.spawnQueue == 0 then
        state.spawning = false
        return
    end

    local Creep = require("src.entities.creep")

    -- Pop from queue
    local creepType = table.remove(state.spawnQueue, 1)

    -- Random spawn column in spawn zone
    local cols = Grid.getCols()
    local spawnCol = math.random(1, cols)
    local spawnRow = 1  -- Top row

    local x, y = Grid.gridToScreen(spawnCol, spawnRow)
    local creep = Creep(x, y, creepType)

    Game.addCreep(creep)
end

function Waves.update(dt, creeps)
    local Grid = require("src.world.grid")
    local Game = require("src.init")
    local Economy = require("src.systems.economy")

    if state.spawning then
        -- During spawning: spawn from queue at intervals
        state.spawnTimer = state.spawnTimer + dt
        if state.spawnTimer >= SPAWN_INTERVAL then
            state.spawnTimer = state.spawnTimer - SPAWN_INTERVAL
            spawnNext(Grid, Game)
        end

        -- Check if wave is clear (no more queue and no creeps alive)
        if #state.spawnQueue == 0 and #creeps == 0 then
            state.spawning = false
            EventBus.emit("wave_cleared", { waveNumber = state.waveNumber })
        end
    else
        -- Between waves: increment timer
        state.waveTimer = state.waveTimer + dt

        -- Start wave when timer expires
        if state.waveTimer >= Config.WAVE_DURATION then
            startWave(Economy.getSent())
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

return Waves
