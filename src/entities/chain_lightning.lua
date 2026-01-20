-- src/entities/chain_lightning.lua
-- Chain lightning visual effect entity (from void_bolt projectile impact)

local Object = require("lib.classic")
local Config = require("src.config")
local GroundEffects = require("src.rendering.ground_effects")
local EventBus = require("src.core.event_bus")

local ChainLightning = Object:extend()

-- Unique seed counter for each chain instance
local seedCounter = 0

function ChainLightning:new(startX, startY, targets, damage, damageMultiplier)
    -- targets is an array of {creep, x, y} for each chain target
    self.targets = targets or {}
    self.startX = startX
    self.startY = startY
    self.damage = damage
    self.damageMultiplier = damageMultiplier or Config.TOWER_ATTACKS.void_bolt.chainDamageMultiplier

    -- Visual timing
    local cfg = Config.GROUND_EFFECTS.chain_lightning
    self.duration = cfg.duration
    self.remaining = self.duration
    self.time = 0
    self.dead = false

    -- Unique seed for jagged path generation
    seedCounter = seedCounter + 1
    self.seed = seedCounter * 59 + math.random(1000)

    -- Chain delay tracking (slight delay between each chain jump)
    self.chainDelay = Config.TOWER_ATTACKS.void_bolt.chainDelay or 0.05
    self.chainTimer = 0
    self.currentChain = 0  -- Which chain we're currently showing
    self.appliedDamage = {}  -- Track which chains have applied damage

    -- Apply damage to first target immediately
    self:applyChainDamage(1)
end

function ChainLightning:applyChainDamage(chainIndex)
    if self.appliedDamage[chainIndex] then return end
    if chainIndex > #self.targets then return end

    local target = self.targets[chainIndex]
    if target and target.creep and not target.creep.dead then
        -- Calculate damage with falloff per chain
        local chainDamage = self.damage * (self.damageMultiplier ^ (chainIndex - 1))
        target.creep:takeDamage(chainDamage, nil)  -- No direction for chain damage

        -- Emit hit event
        EventBus.emit("creep_hit", {
            creep = target.creep,
            damage = chainDamage,
            position = { x = target.x, y = target.y },
            angle = nil,
        })
    end

    self.appliedDamage[chainIndex] = true
end

function ChainLightning:update(dt)
    -- Update animation time
    self.time = self.time + dt

    -- Update chain progression
    self.chainTimer = self.chainTimer + dt
    local newChain = math.floor(self.chainTimer / self.chainDelay) + 1
    if newChain > self.currentChain then
        self.currentChain = newChain
        -- Apply damage to this chain target
        self:applyChainDamage(self.currentChain)
    end

    -- Update remaining duration
    self.remaining = self.remaining - dt
    if self.remaining <= 0 then
        self.dead = true
    end
end

function ChainLightning:draw()
    -- Calculate fade progress
    local progress = self.remaining / self.duration

    -- Draw chain lightning from start to each target in sequence
    local prevX, prevY = self.startX, self.startY

    for i, target in ipairs(self.targets) do
        -- Only draw chains that have been activated
        if i <= self.currentChain then
            -- Calculate individual chain progress
            local chainAge = self.chainTimer - (i - 1) * self.chainDelay
            local chainProgress = math.max(0, math.min(1, 1 - (chainAge / self.duration)))

            if chainProgress > 0 then
                GroundEffects.drawChainLightning(
                    prevX, prevY,
                    target.x, target.y,
                    chainProgress,
                    self.seed + i * 100
                )
            end
        end

        prevX, prevY = target.x, target.y
    end
end

-- Get light parameters for the lighting system
function ChainLightning:getLightParams()
    local progress = self.remaining / self.duration
    local cfg = Config.GROUND_EFFECTS.chain_lightning

    -- Return light at the last active chain position
    local lightX, lightY = self.startX, self.startY
    if self.currentChain > 0 and self.targets[self.currentChain] then
        lightX = self.targets[self.currentChain].x
        lightY = self.targets[self.currentChain].y
    end

    return {
        x = lightX,
        y = lightY,
        radius = 60,
        color = cfg.color,
        intensity = 1.5 * progress,
        flicker = true,
    }
end

-- Static helper: Find chain targets from initial hit position
-- @param hitX, hitY: Position where projectile hit
-- @param initialCreep: The creep that was initially hit
-- @param allCreeps: All creeps in the game
-- @param maxChains: Maximum number of chain jumps
-- @param chainRange: Maximum range for chain jump
-- @return Array of {creep, x, y} targets
function ChainLightning.findChainTargets(hitX, hitY, initialCreep, allCreeps, maxChains, chainRange)
    local targets = {}
    local hitCreeps = { [initialCreep] = true }

    local prevX, prevY = hitX, hitY

    for i = 1, maxChains do
        local closest = nil
        local closestDist = chainRange + 1

        for _, creep in ipairs(allCreeps) do
            if not creep.dead and not creep.dying and not hitCreeps[creep] then
                local dx = creep.x - prevX
                local dy = creep.y - prevY
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist <= chainRange and dist < closestDist then
                    closest = creep
                    closestDist = dist
                end
            end
        end

        if closest then
            hitCreeps[closest] = true
            table.insert(targets, {
                creep = closest,
                x = closest.x,
                y = closest.y,
            })
            prevX, prevY = closest.x, closest.y
        else
            break  -- No more valid targets
        end
    end

    return targets
end

return ChainLightning
