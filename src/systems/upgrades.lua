-- src/systems/upgrades.lua
-- Manages upgrade state and logic (extracted from HUD)

local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local Upgrades = {}

-- Private state
local state = {
    levels = {
        autoClicker = 0,
    },
}

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function Upgrades.init()
    -- Reset upgrade levels
    state.levels = {
        autoClicker = 0,
    }
end

-- Get current level for an upgrade
function Upgrades.getLevel(upgradeType)
    return state.levels[upgradeType] or 0
end

-- Get cost for an upgrade at current level
function Upgrades.getCost(upgradeType)
    local upgradeConfig = Config.UPGRADES.panel[upgradeType]
    if not upgradeConfig then return 0 end

    local currentLevel = state.levels[upgradeType] or 0
    if currentLevel >= upgradeConfig.maxLevel then
        return 0
    end

    return math.floor(upgradeConfig.baseCost * (upgradeConfig.costMultiplier ^ currentLevel))
end

-- Check if an upgrade can be purchased (not maxed out)
function Upgrades.canPurchase(upgradeType)
    local upgradeConfig = Config.UPGRADES.panel[upgradeType]
    if not upgradeConfig then return false end

    local currentLevel = state.levels[upgradeType] or 0
    return currentLevel < upgradeConfig.maxLevel
end

-- Get max level for an upgrade
function Upgrades.getMaxLevel(upgradeType)
    local upgradeConfig = Config.UPGRADES.panel[upgradeType]
    if not upgradeConfig then return 0 end
    return upgradeConfig.maxLevel
end

-- Purchase an upgrade (does not check gold - caller must verify affordability)
function Upgrades.purchase(upgradeType)
    local upgradeConfig = Config.UPGRADES.panel[upgradeType]
    if not upgradeConfig then return false end

    local currentLevel = state.levels[upgradeType] or 0
    if currentLevel >= upgradeConfig.maxLevel then
        return false
    end

    local cost = Upgrades.getCost(upgradeType)
    state.levels[upgradeType] = currentLevel + 1

    EventBus.emit("upgrade_purchased", {
        type = upgradeType,
        level = state.levels[upgradeType],
        cost = cost,
    })

    return true
end

-- Get auto-clicker interval based on current level (nil if not purchased)
function Upgrades.getAutoClickInterval()
    local level = state.levels.autoClicker or 0
    if level == 0 then return nil end

    local config = Config.UPGRADES.panel.autoClicker
    return config.baseInterval - ((level - 1) * config.intervalReduction)
end

-- Reset all upgrades (for game restart/prestige)
function Upgrades.reset()
    state.levels = {
        autoClicker = 0,
    }
end

return Upgrades
