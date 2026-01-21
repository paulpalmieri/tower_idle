-- src/systems/economy.lua
-- Gold and spending management

local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local Economy = {}

-- Private state
local state = {
    gold = 0,
    lives = 0,
    voidShards = 0,
    voidCrystals = 0,
    sent = {
        voidSpawn = 0,
    },
    -- Run stats for recap screen
    stats = {
        kills = 0,
        goldEarned = 0,
        damageDealt = 0,
        towersBuilt = 0,
        timePlayed = 0,
        waveReached = 0,
    },
}

function Economy.init()
    state.gold = Config.STARTING_GOLD
    state.lives = Config.STARTING_LIVES
    state.voidShards = Config.STARTING_VOID_SHARDS
    state.voidCrystals = Config.STARTING_VOID_CRYSTALS
    state.sent = { voidSpawn = 0, voidSpider = 0 }
    -- Reset run stats
    state.stats = {
        kills = 0,
        goldEarned = 0,
        damageDealt = 0,
        towersBuilt = 0,
        timePlayed = 0,
        waveReached = 0,
    }
end

function Economy.getGold()
    return state.gold
end

function Economy.getLives()
    return state.lives
end

function Economy.getSent()
    return state.sent
end

function Economy.canAfford(amount)
    return state.gold >= amount
end

function Economy.addGold(amount)
    state.gold = state.gold + amount
    EventBus.emit("gold_changed", { amount = amount, total = state.gold })
end

function Economy.spendGold(amount)
    if not Economy.canAfford(amount) then
        return false
    end
    state.gold = state.gold - amount
    EventBus.emit("gold_changed", { amount = -amount, total = state.gold })
    return true
end

function Economy.sendCreep(creepType)
    local creepConfig = Config.CREEPS[creepType]
    if not creepConfig then return false end

    if not Economy.canAfford(creepConfig.sendCost) then
        return false
    end

    Economy.spendGold(creepConfig.sendCost)

    -- Initialize send counter if not present
    state.sent[creepType] = (state.sent[creepType] or 0) + 1

    EventBus.emit("creep_sent", {
        type = creepType,
        totalSent = state.sent[creepType],
    })

    return true
end

function Economy.loseLife()
    state.lives = state.lives - 1
    EventBus.emit("life_lost", { remaining = state.lives })

    if state.lives <= 0 then
        EventBus.emit("game_over", { reason = "no_lives" })
        return true -- Game over
    end
    return false
end

-- Add gold from clicking the Void
function Economy.voidClicked(amount)
    state.gold = state.gold + amount
    EventBus.emit("gold_changed", { amount = amount, total = state.gold })
end

-- Void Shards (meta-currency for skill tree)
function Economy.getVoidShards()
    return state.voidShards
end

function Economy.addVoidShards(amount)
    state.voidShards = state.voidShards + amount
    EventBus.emit("void_shards_changed", { amount = amount, total = state.voidShards })
end

function Economy.canAffordShards(amount)
    return state.voidShards >= amount
end

function Economy.spendVoidShards(amount)
    if not Economy.canAffordShards(amount) then
        return false
    end
    state.voidShards = state.voidShards - amount
    EventBus.emit("void_shards_changed", { amount = -amount, total = state.voidShards })
    return true
end

-- Void Crystals (rare currency for keystones, from boss kills)
function Economy.getVoidCrystals()
    return state.voidCrystals
end

function Economy.addVoidCrystals(amount)
    state.voidCrystals = state.voidCrystals + amount
    EventBus.emit("void_crystals_changed", { amount = amount, total = state.voidCrystals })
end

function Economy.canAffordCrystals(amount)
    return state.voidCrystals >= amount
end

function Economy.spendVoidCrystals(amount)
    if not Economy.canAffordCrystals(amount) then
        return false
    end
    state.voidCrystals = state.voidCrystals - amount
    EventBus.emit("void_crystals_changed", { amount = -amount, total = state.voidCrystals })
    return true
end

-- =============================================================================
-- RUN STATS (for recap screen)
-- =============================================================================

function Economy.getStats()
    return state.stats
end

function Economy.recordKill()
    state.stats.kills = state.stats.kills + 1
end

function Economy.recordGoldEarned(amount)
    state.stats.goldEarned = state.stats.goldEarned + amount
end

function Economy.recordDamage(amount)
    state.stats.damageDealt = state.stats.damageDealt + amount
end

function Economy.recordTowerBuilt()
    state.stats.towersBuilt = state.stats.towersBuilt + 1
end

function Economy.updateTimePlayed(dt)
    state.stats.timePlayed = state.stats.timePlayed + dt
end

function Economy.setWaveReached(wave)
    if wave > state.stats.waveReached then
        state.stats.waveReached = wave
    end
end

return Economy
