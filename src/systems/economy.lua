-- src/systems/economy.lua
-- Gold, income, and spending management

local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local Economy = {}

-- Private state
local state = {
    gold = 0,
    income = 0,
    lives = 0,
    incomeTimer = 0,
    sent = {
        triangle = 0,
        square = 0,
        pentagon = 0,
        hexagon = 0,
    },
}

function Economy.init()
    state.gold = Config.STARTING_GOLD
    state.income = Config.BASE_INCOME
    state.lives = Config.STARTING_LIVES
    state.incomeTimer = 0
    state.sent = { triangle = 0, square = 0, pentagon = 0, hexagon = 0 }
end

function Economy.update(dt)
    state.incomeTimer = state.incomeTimer + dt

    if state.incomeTimer >= Config.INCOME_TICK_SECONDS then
        state.incomeTimer = state.incomeTimer - Config.INCOME_TICK_SECONDS
        state.gold = state.gold + state.income
        EventBus.emit("income_tick", { amount = state.income, total = state.gold })
    end
end

function Economy.getGold()
    return state.gold
end

function Economy.getIncome()
    return state.income
end

function Economy.getLives()
    return state.lives
end

function Economy.getSent()
    return state.sent
end

function Economy.getIncomeProgress()
    return state.incomeTimer / Config.INCOME_TICK_SECONDS
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
    state.income = state.income + creepConfig.income
    state.sent[creepType] = state.sent[creepType] + 1

    EventBus.emit("creep_sent", {
        type = creepType,
        income = state.income,
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

return Economy
