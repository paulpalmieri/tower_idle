-- src/core/config_validator.lua
-- Validates Config values at startup to catch configuration errors early

local ConfigValidator = {}

-- Required fields for different config sections
local TOWER_REQUIRED = {"name", "cost", "damage", "fireRate", "range", "projectileSpeed", "color"}
local CREEP_REQUIRED = {"name", "hp", "speed", "reward", "sendCost", "size"}
local STATUS_EFFECT_REQUIRED = {"duration", "color"}

-- Validation errors are collected and returned
local errors = {}

local function addError(msg)
    table.insert(errors, msg)
end

local function validatePositive(value, name, section)
    if type(value) ~= "number" then
        addError(string.format("%s.%s: expected number, got %s", section, name, type(value)))
        return false
    end
    if value < 0 then
        addError(string.format("%s.%s: cannot be negative (got %s)", section, name, tostring(value)))
        return false
    end
    return true
end

local function validatePositiveNonZero(value, name, section)
    if not validatePositive(value, name, section) then
        return false
    end
    if value == 0 then
        addError(string.format("%s.%s: cannot be zero", section, name))
        return false
    end
    return true
end

local function validateColor(color, name, section)
    if type(color) ~= "table" then
        addError(string.format("%s.%s: expected color table, got %s", section, name, type(color)))
        return false
    end
    if #color < 3 then
        addError(string.format("%s.%s: color must have at least 3 components (RGB)", section, name))
        return false
    end
    return true
end

local function validateRequiredFields(tbl, required, section)
    for _, field in ipairs(required) do
        if tbl[field] == nil then
            addError(string.format("%s: missing required field '%s'", section, field))
        end
    end
end

local function validateTowers(Config)
    if not Config.TOWERS then
        addError("Config.TOWERS is missing")
        return
    end

    for towerType, tower in pairs(Config.TOWERS) do
        local section = "Config.TOWERS." .. towerType
        validateRequiredFields(tower, TOWER_REQUIRED, section)

        -- Validate numeric values
        if tower.cost then validatePositiveNonZero(tower.cost, "cost", section) end
        if tower.damage then validatePositive(tower.damage, "damage", section) end
        if tower.fireRate then validatePositiveNonZero(tower.fireRate, "fireRate", section) end
        if tower.range then validatePositiveNonZero(tower.range, "range", section) end
        if tower.projectileSpeed then validatePositive(tower.projectileSpeed, "projectileSpeed", section) end

        -- Validate color
        if tower.color then validateColor(tower.color, "color", section) end
    end
end

local function validateCreeps(Config)
    if not Config.CREEPS then
        addError("Config.CREEPS is missing")
        return
    end

    for creepType, creep in pairs(Config.CREEPS) do
        local section = "Config.CREEPS." .. creepType
        validateRequiredFields(creep, CREEP_REQUIRED, section)

        -- Validate numeric values
        if creep.hp then validatePositiveNonZero(creep.hp, "hp", section) end
        if creep.speed then validatePositive(creep.speed, "speed", section) end
        if creep.reward then validatePositive(creep.reward, "reward", section) end
        if creep.sendCost then validatePositive(creep.sendCost, "sendCost", section) end
        if creep.size then validatePositiveNonZero(creep.size, "size", section) end
    end
end

local function validateStatusEffects(Config)
    if not Config.STATUS_EFFECTS then
        addError("Config.STATUS_EFFECTS is missing")
        return
    end

    for effectType, effect in pairs(Config.STATUS_EFFECTS) do
        local section = "Config.STATUS_EFFECTS." .. effectType
        validateRequiredFields(effect, STATUS_EFFECT_REQUIRED, section)

        -- Validate duration
        if effect.duration then validatePositiveNonZero(effect.duration, "duration", section) end

        -- Validate color
        if effect.color then validateColor(effect.color, "color", section) end

        -- Effect-specific validations
        if effectType == "poison" or effectType == "burn" then
            if effect.damagePerTick then validatePositive(effect.damagePerTick, "damagePerTick", section) end
            if effect.tickInterval then validatePositiveNonZero(effect.tickInterval, "tickInterval", section) end
        end

        if effectType == "slow" then
            if effect.multiplier then
                if type(effect.multiplier) ~= "number" or effect.multiplier < 0 or effect.multiplier > 1 then
                    addError(string.format("%s.multiplier: must be between 0 and 1 (got %s)",
                        section, tostring(effect.multiplier)))
                end
            end
        end
    end
end

local function validateEconomy(Config)
    local section = "Config (Economy)"
    if Config.STARTING_GOLD then
        validatePositive(Config.STARTING_GOLD, "STARTING_GOLD", section)
    end
    if Config.STARTING_LIVES then
        validatePositiveNonZero(Config.STARTING_LIVES, "STARTING_LIVES", section)
    end
end

local function validateGrid(Config)
    local section = "Config (Grid)"
    if Config.CELL_SIZE then validatePositiveNonZero(Config.CELL_SIZE, "CELL_SIZE", section) end
    if Config.GRID_COLS then validatePositiveNonZero(Config.GRID_COLS, "GRID_COLS", section) end
    if Config.GRID_ROWS then validatePositiveNonZero(Config.GRID_ROWS, "GRID_ROWS", section) end
end

-- Main validation function
-- Returns true if valid, false and error list if invalid
function ConfigValidator.validate(Config)
    errors = {}

    validateTowers(Config)
    validateCreeps(Config)
    validateStatusEffects(Config)
    validateEconomy(Config)
    validateGrid(Config)

    if #errors > 0 then
        return false, errors
    end
    return true, nil
end

-- Convenience function that prints errors and optionally stops the game
function ConfigValidator.validateOrDie(Config)
    local valid, errorList = ConfigValidator.validate(Config)
    if not valid then
        print("=== CONFIG VALIDATION ERRORS ===")
        for _, err in ipairs(errorList) do
            print("  " .. err)
        end
        print("================================")
        error("Config validation failed. Please fix the above errors.")
    end
    return true
end

return ConfigValidator
