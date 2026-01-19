-- src/systems/waves.lua
-- Wave spawning and composition

local Config = require("src.config")
local _EventBus = require("src.core.event_bus")  -- Will emit wave_started, wave_cleared

local Waves = {}

local state = {
    waveNumber = 0,
    waveTimer = 0,
    spawning = false,
    spawnQueue = {},
}

function Waves.init()
    state.waveNumber = 0
    state.waveTimer = 0
    state.spawning = false
    state.spawnQueue = {}
end

function Waves.update(dt, creeps)
    -- TODO: Implement wave logic
    -- See prototype wave_manager.lua for reference
end

function Waves.getWaveNumber()
    return state.waveNumber
end

function Waves.getTimeUntilWave()
    return math.max(0, Config.WAVE_DURATION - state.waveTimer)
end

return Waves
