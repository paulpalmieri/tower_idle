-- src/systems/combat.lua
-- Damage calculation and targeting

local Combat = {}

function Combat.init()
    -- Nothing to init yet
end

function Combat.calculateDamage(baseDamage, multipliers)
    local damage = baseDamage
    if multipliers then
        for _, mult in ipairs(multipliers) do
            damage = damage * mult
        end
    end
    return math.floor(damage)
end

function Combat.findTarget(tower, creeps)
    local closest = nil
    local closestDist = tower.range + 1

    for _, creep in ipairs(creeps) do
        if not creep.dead then
            local dx = creep.x - tower.x
            local dy = creep.y - tower.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= tower.range and dist < closestDist then
                closest = creep
                closestDist = dist
            end
        end
    end

    return closest
end

return Combat
