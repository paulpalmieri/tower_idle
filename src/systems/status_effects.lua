-- src/systems/status_effects.lua
-- Status effect management (DOT, slow, etc.)

local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local StatusEffects = {}

-- Effect types
StatusEffects.POISON = "poison"
StatusEffects.BURN = "burn"
StatusEffects.SLOW = "slow"

-- Apply a status effect to a creep
-- @param creep The creep to apply the effect to
-- @param effectType The type of effect (POISON, BURN, SLOW)
-- @param params Effect parameters (damagePerTick, tickInterval, duration, multiplier)
function StatusEffects.apply(creep, effectType, params)
    if creep.dead or creep.dying then return end

    -- Initialize status effects table if needed
    if not creep.statusEffects then
        creep.statusEffects = {}
    end

    local cfg = Config.STATUS_EFFECTS[effectType]
    if not cfg then return end

    local effect = creep.statusEffects[effectType]

    if effectType == StatusEffects.SLOW then
        -- Slow effect: just refresh duration, don't stack
        if not effect then
            creep.statusEffects[effectType] = {
                active = true,
                multiplier = params.multiplier or cfg.multiplier,
                remaining = params.duration or cfg.duration,
            }
        else
            -- Refresh duration if stronger or equal slow
            if params.multiplier and params.multiplier <= effect.multiplier then
                effect.multiplier = params.multiplier
            end
            effect.remaining = math.max(effect.remaining, params.duration or cfg.duration)
        end
    else
        -- DOT effects (poison, burn): refresh duration
        if not effect then
            creep.statusEffects[effectType] = {
                active = true,
                damagePerTick = params.damagePerTick or cfg.damagePerTick,
                tickInterval = params.tickInterval or cfg.tickInterval,
                remaining = params.duration or cfg.duration,
                tickTimer = 0,
            }
        else
            -- Refresh duration, use stronger damage
            effect.remaining = math.max(effect.remaining, params.duration or cfg.duration)
            if params.damagePerTick and params.damagePerTick > effect.damagePerTick then
                effect.damagePerTick = params.damagePerTick
            end
        end
    end
end

-- Remove a status effect from a creep
function StatusEffects.remove(creep, effectType)
    if creep.statusEffects then
        creep.statusEffects[effectType] = nil
    end
end

-- Update all status effects on a creep (call in creep:update)
-- Returns total DOT damage dealt this frame
function StatusEffects.update(creep, dt)
    if not creep.statusEffects then return 0 end
    if creep.dead or creep.dying then return 0 end

    local totalDamage = 0

    for effectType, effect in pairs(creep.statusEffects) do
        if effect.active then
            effect.remaining = effect.remaining - dt

            if effect.remaining <= 0 then
                -- Effect expired
                creep.statusEffects[effectType] = nil
            else
                -- Handle DOT ticks
                if effect.tickTimer ~= nil then
                    effect.tickTimer = effect.tickTimer + dt
                    if effect.tickTimer >= effect.tickInterval then
                        effect.tickTimer = effect.tickTimer - effect.tickInterval
                        -- Apply DOT damage
                        totalDamage = totalDamage + effect.damagePerTick
                        EventBus.emit("status_effect_tick", {
                            creep = creep,
                            effectType = effectType,
                            damage = effect.damagePerTick,
                        })
                    end
                end
            end
        end
    end

    return totalDamage
end

-- Get the current speed multiplier from slow effects
function StatusEffects.getSpeedMultiplier(creep)
    if not creep.statusEffects then return 1.0 end

    local slowEffect = creep.statusEffects[StatusEffects.SLOW]
    if slowEffect and slowEffect.active then
        return slowEffect.multiplier
    end

    return 1.0
end

-- Check if creep has a specific effect
function StatusEffects.hasEffect(creep, effectType)
    if not creep.statusEffects then return false end
    local effect = creep.statusEffects[effectType]
    return effect and effect.active
end

-- Get effect data for visual rendering
function StatusEffects.getEffectData(creep, effectType)
    if not creep.statusEffects then return nil end
    return creep.statusEffects[effectType]
end

return StatusEffects
