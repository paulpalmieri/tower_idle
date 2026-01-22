-- src/systems/anger.lua
-- Shared anger system for spawn portals
-- Clicking any portal increases shared anger, which affects creep stats

local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local Anger = {}

-- Private state
local state = {
    level = 0,
    maxLevel = 100,
    tier = 0,  -- Current tier (0-3)
}

-- Tier thresholds (anger levels that trigger tier changes)
local TIER_THRESHOLDS = {25, 50, 75, 100}

function Anger.init()
    state.level = 0
    state.tier = 0
end

-- Increase anger by amount
function Anger.increase(amount)
    amount = amount or 1
    local oldTier = state.tier

    state.level = math.min(state.maxLevel, state.level + amount)

    -- Recalculate tier
    state.tier = 0
    for i, threshold in ipairs(TIER_THRESHOLDS) do
        if state.level >= threshold then
            state.tier = i
        end
    end

    -- Emit event if tier changed
    if state.tier > oldTier then
        EventBus.emit("anger_tier_changed", {
            oldTier = oldTier,
            newTier = state.tier,
            level = state.level,
        })
    end

    EventBus.emit("anger_changed", {
        level = state.level,
        tier = state.tier,
        maxLevel = state.maxLevel,
    })
end

-- Get current anger level (0 to maxLevel)
function Anger.getLevel()
    return state.level
end

-- Get max anger level
function Anger.getMaxLevel()
    return state.maxLevel
end

-- Get anger as percentage (0 to 1)
function Anger.getPercent()
    return state.level / state.maxLevel
end

-- Get current tier (0-3)
function Anger.getTier()
    return state.tier
end

-- Get HP bonus multiplier based on tier
function Anger.getHpMultiplier()
    local tierBonus = Config.VOID and Config.VOID.tierHpBonus or 0.15
    return 1.0 + (state.tier * tierBonus)
end

-- Get speed bonus multiplier based on tier
function Anger.getSpeedMultiplier()
    local tierBonus = Config.VOID and Config.VOID.tierSpeedBonus or 0.05
    return 1.0 + (state.tier * tierBonus)
end

-- Reset anger (e.g., on prestige)
function Anger.reset()
    local oldLevel = state.level
    state.level = 0
    state.tier = 0

    if oldLevel > 0 then
        EventBus.emit("anger_reset", {
            previousLevel = oldLevel,
        })
    end
end

return Anger
