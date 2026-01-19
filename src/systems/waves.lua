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
    angerLevel = 0,  -- Current anger level from Void
}

function Waves.init()
    state.waveNumber = 0
    state.waveTimer = 0
    state.spawning = false
    state.spawnQueue = {}
    state.spawnTimer = 0
    state.angerLevel = 0
end

-- Set the anger level (called when Void is clicked)
function Waves.setAngerLevel(anger)
    state.angerLevel = anger or 0
end

-- Build the spawn queue based on anger level
local function buildQueue()
    local queue = {}

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
local function startWave()
    state.waveNumber = state.waveNumber + 1
    state.waveTimer = 0
    state.spawning = true
    state.spawnQueue = buildQueue()
    state.spawnTimer = 0

    EventBus.emit("wave_started", {
        waveNumber = state.waveNumber,
        enemyCount = #state.spawnQueue,
        angerLevel = state.angerLevel,
    })
end

-- Spawn the next creep from the queue
local function spawnNext()
    if #state.spawnQueue == 0 then
        state.spawning = false
        return
    end

    -- Pop from queue
    local creepType = table.remove(state.spawnQueue, 1)

    -- Random spawn column in spawn zone
    local cols = Grid.getCols()
    local spawnCol = math.random(1, cols)
    local spawnRow = 1  -- Top row

    local x, y = Grid.gridToScreen(spawnCol, spawnRow)
    local creep = Creep(x, y, creepType)

    EventBus.emit("spawn_creep", { creep = creep })
end

function Waves.update(dt, creeps)
    if state.spawning then
        -- During spawning: spawn from queue at intervals
        state.spawnTimer = state.spawnTimer + dt
        if state.spawnTimer >= Config.WAVE_SPAWN_INTERVAL then
            state.spawnTimer = state.spawnTimer - Config.WAVE_SPAWN_INTERVAL
            spawnNext()
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
            startWave()
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
