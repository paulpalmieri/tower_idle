-- src/systems/audio.lua
-- Procedural audio + ambient soundscape
--
-- Design philosophy: minimal, non-fatiguing sounds that play well
-- even when triggered hundreds of times per session.

local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local Audio = {}

-- Private state
local pools = {}
local initialized = false

-- Ambient state
local ambient = {
    sources = {},      -- Loaded ambient sound sources
    timer = 0,         -- Time until next ambient sound
    lastIndex = 0,     -- Avoid repeating same sound
}

-- =============================================================================
-- CORE HELPERS
-- =============================================================================

local function clamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end

-- Create SoundData from generator function
local function createSound(duration, generator)
    local rate = Config.AUDIO.sampleRate
    local samples = math.floor(duration * rate)
    local data = love.sound.newSoundData(samples, rate, Config.AUDIO.bitDepth, Config.AUDIO.channels)

    for i = 0, samples - 1 do
        local t = i / rate
        local s = generator(t, duration)
        data:setSample(i, clamp(s, -1, 1))
    end

    return data
end

-- Create source pool for a sound
local function createPool(soundData, size, volume)
    local pool = { sources = {}, index = 1 }
    local vol = volume * Config.AUDIO.masterVolume

    for i = 1, size do
        local src = love.audio.newSource(soundData, "static")
        src:setVolume(vol)
        pool.sources[i] = src
    end

    return pool
end

-- Play from pool (round-robin)
local function playPool(pool)
    if not pool then return end
    local src = pool.sources[pool.index]
    src:stop()
    src:play()
    pool.index = pool.index % #pool.sources + 1
end

-- =============================================================================
-- SOUND GENERATORS
-- =============================================================================

-- Void fire: ethereal whoosh with void resonance
local function genVoidFire()
    local cfg = Config.AUDIO.sounds.void_fire
    local freq, decay = cfg.freq, cfg.decay

    return createSound(cfg.duration, function(t, dur)
        local env = math.exp(-t * decay)
        -- Mix of sine harmonics for ethereal tone
        local s1 = math.sin(2 * math.pi * freq * t)
        local s2 = math.sin(2 * math.pi * freq * 1.5 * t) * 0.3  -- Dissonant harmonic
        local s3 = math.sin(2 * math.pi * freq * 2 * t) * 0.2
        -- Slight noise for texture
        local noise = (math.random() - 0.5) * 0.15
        return (s1 + s2 + s3 + noise) * env * 0.8
    end)
end

-- Creep spawn: rift crack - sharp attack with quick decay
local function genCreepSpawn()
    local cfg = Config.AUDIO.sounds.creep_spawn

    return createSound(cfg.duration, function(t, dur)
        local env = math.exp(-t * cfg.decay)
        -- Mix of noise (crack) and tone (body), noise fades faster
        local noiseEnv = math.exp(-t * cfg.decay * 3)
        local noise = (math.random() - 0.5) * noiseEnv
        local tone = math.sin(2 * math.pi * cfg.freq * t) * env
        return (noise * 0.5 + tone * 0.7)
    end)
end

-- Creep hit: tiny tap
local function genCreepHit()
    local cfg = Config.AUDIO.sounds.creep_hit
    local freq, decay = cfg.freq, cfg.decay

    return createSound(cfg.duration, function(t, dur)
        local env = math.exp(-t * decay)
        return math.sin(2 * math.pi * freq * t) * env
    end)
end

-- Creep death: descending pop
local function genCreepDeath()
    local cfg = Config.AUDIO.sounds.creep_death
    local f0, f1, decay = cfg.freqStart, cfg.freqEnd, cfg.decay

    return createSound(cfg.duration, function(t, dur)
        local p = t / dur
        local freq = f0 + (f1 - f0) * p * p
        local env = math.exp(-t * decay)
        local noise = (math.random() - 0.5) * 0.15
        return (math.sin(2 * math.pi * freq * t) + noise) * env
    end)
end

-- =============================================================================
-- AMBIENT SYSTEM
-- =============================================================================

local function initAmbient()
    local cfg = Config.AUDIO.ambient
    if not cfg or not cfg.enabled then return end

    -- Load all ambient sounds
    for i, path in ipairs(cfg.files) do
        local ok, src = pcall(love.audio.newSource, path, "stream")
        if ok and src then
            src:setVolume(cfg.volume * Config.AUDIO.masterVolume)
            ambient.sources[i] = src
        end
    end

    -- Set initial random delay
    ambient.timer = math.random() * (cfg.maxInterval - cfg.minInterval) + cfg.minInterval
end

local function pickNextAmbient()
    local count = #ambient.sources
    if count == 0 then return nil end
    if count == 1 then return 1 end

    -- Pick random, avoiding repeat
    local idx
    repeat
        idx = math.random(1, count)
    until idx ~= ambient.lastIndex

    ambient.lastIndex = idx
    return idx
end

local function updateAmbient(dt)
    local cfg = Config.AUDIO.ambient
    if not cfg or not cfg.enabled then return end
    if #ambient.sources == 0 then return end

    ambient.timer = ambient.timer - dt

    if ambient.timer <= 0 then
        -- Play a random ambient sound
        local idx = pickNextAmbient()
        if idx and ambient.sources[idx] then
            ambient.sources[idx]:stop()
            ambient.sources[idx]:play()
        end

        -- Schedule next
        ambient.timer = math.random() * (cfg.maxInterval - cfg.minInterval) + cfg.minInterval
    end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function Audio.init()
    if not Config.AUDIO.enabled then return end

    local s = Config.AUDIO.sounds

    pools.void_fire = createPool(genVoidFire(), s.void_fire.poolSize, s.void_fire.volume)
    pools.creep_spawn = createPool(genCreepSpawn(), s.creep_spawn.poolSize, s.creep_spawn.volume)
    pools.creep_hit = createPool(genCreepHit(), s.creep_hit.poolSize, s.creep_hit.volume)
    pools.creep_death = createPool(genCreepDeath(), s.creep_death.poolSize, s.creep_death.volume)

    -- Initialize ambient
    initAmbient()

    -- Event subscriptions
    EventBus.on("tower_fired", function(data)
        -- All void turrets use void_fire sound
        local towerType = data.towerType
        if towerType == "void_orb" or towerType == "void_ring" or
           towerType == "void_bolt" or towerType == "void_eye" or
           towerType == "void_star" then
            Audio.play("void_fire")
        end
    end)

    EventBus.on("spawn_creep", function()
        Audio.play("creep_spawn")
    end)

    EventBus.on("creep_hit", function()
        Audio.play("creep_hit")
    end)

    EventBus.on("creep_killed", function()
        Audio.play("creep_death")
    end)

    initialized = true
end

function Audio.update(dt)
    if not Config.AUDIO.enabled or not initialized then return end
    updateAmbient(dt)
end

function Audio.play(name)
    if not Config.AUDIO.enabled or not initialized then return end
    playPool(pools[name])
end

function Audio.setMasterVolume(vol)
    Config.AUDIO.masterVolume = clamp(vol, 0, 1)

    -- Update SFX pools
    for name, pool in pairs(pools) do
        local cfg = Config.AUDIO.sounds[name]
        if cfg then
            local v = cfg.volume * Config.AUDIO.masterVolume
            for _, src in ipairs(pool.sources) do
                src:setVolume(v)
            end
        end
    end

    -- Update ambient sources
    local ambCfg = Config.AUDIO.ambient
    if ambCfg then
        for _, src in ipairs(ambient.sources) do
            src:setVolume(ambCfg.volume * Config.AUDIO.masterVolume)
        end
    end
end

function Audio.setEnabled(enabled)
    Config.AUDIO.enabled = enabled
    if not enabled then
        for _, pool in pairs(pools) do
            for _, src in ipairs(pool.sources) do
                src:stop()
            end
        end
        for _, src in ipairs(ambient.sources) do
            src:stop()
        end
    end
end

function Audio.setAmbientEnabled(enabled)
    if Config.AUDIO.ambient then
        Config.AUDIO.ambient.enabled = enabled
        if not enabled then
            for _, src in ipairs(ambient.sources) do
                src:stop()
            end
        end
    end
end

return Audio
