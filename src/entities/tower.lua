-- src/entities/tower.lua
-- Tower entity

local Object = require("lib.classic")
local Config = require("src.config")
local Projectile = require("src.entities.projectile")
local Combat = require("src.systems.combat")
local PixelArt = require("src.rendering.pixel_art")
local TurretConcepts = require("src.rendering.turret_concepts")
local EventBus = require("src.core.event_bus")
local StatusEffects = require("src.systems.status_effects")
local GroundEffects = require("src.rendering.ground_effects")

local Tower = Object:extend()

-- Attack states
Tower.STATE_IDLE = "idle"
Tower.STATE_TARGETING = "targeting"
Tower.STATE_CHARGING = "charging"
Tower.STATE_FIRING = "firing"
Tower.STATE_COOLDOWN = "cooldown"

function Tower:new(x, y, towerType, gridX, gridY)
    self.x = x
    self.y = y
    self.gridX = gridX
    self.gridY = gridY
    self.towerType = towerType

    local stats = Config.TOWERS[towerType]
    self.baseDamage = stats.damage
    self.baseRange = stats.range
    self.baseFireRate = stats.fireRate
    self.color = stats.color
    self.projectileSpeed = stats.projectileSpeed
    self.splashRadius = stats.splashRadius
    self.rotationSpeed = stats.rotationSpeed or 10

    -- Upgrade tracking
    self.upgrades = { range = 0, fireRate = 0, damage = 0 }
    self:recalculateStats()

    self.cooldown = 0
    self.target = nil
    self.rotation = 0
    self.dead = false

    -- Recoil animation state
    self.recoilTimer = 0
    self.muzzleFlashTimer = 0

    -- Get recoil config for this tower type
    local artConfig = Config.PIXEL_ART.TOWERS[towerType]
    if artConfig and artConfig.recoil then
        self.recoilDuration = artConfig.recoil.duration
        self.recoilDistance = artConfig.recoil.distance
    else
        self.recoilDuration = 0.1
        self.recoilDistance = 3
    end

    -- Void tower animation state
    self.voidTime = 0
    self.voidSeed = gridX * 1000 + gridY * 37 + math.random(1000)

    -- Attack state machine
    self.attackState = Tower.STATE_IDLE
    self.chargeTimer = 0
    self.beamTimer = 0
    self.beamTarget = nil  -- Stores target for beam attack

    -- Get attack type from config
    local attackCfg = Config.TOWER_ATTACKS[towerType]
    self.attackType = attackCfg and attackCfg.type or "projectile"
end

function Tower:recalculateStats()
    local bonuses = Config.UPGRADES.bonusPerLevel
    self.damage = self.baseDamage * (1 + self.upgrades.damage * bonuses.damage)
    self.range = self.baseRange * (1 + self.upgrades.range * bonuses.range)
    self.fireRate = self.baseFireRate * (1 + self.upgrades.fireRate * bonuses.fireRate)
end

function Tower:getUpgradeCost(stat)
    local level = self.upgrades[stat]
    if level >= Config.UPGRADES.maxLevel then
        return nil  -- Maxed out
    end
    local baseCost = Config.UPGRADES.baseCost[stat]
    return math.floor(baseCost * (Config.UPGRADES.costMultiplier ^ level))
end

function Tower:canUpgrade(stat)
    return self.upgrades[stat] < Config.UPGRADES.maxLevel
end

function Tower:upgrade(stat)
    if not self:canUpgrade(stat) then
        return false
    end
    self.upgrades[stat] = self.upgrades[stat] + 1
    self:recalculateStats()
    return true
end

function Tower:getTotalUpgradeLevel()
    return self.upgrades.damage + self.upgrades.range + self.upgrades.fireRate
end

function Tower:update(dt, creeps, projectiles, groundEffects, chainLightnings)
    -- Update void animation time (all towers)
    self.voidTime = self.voidTime + dt

    -- Non-attacking towers (walls) skip combat logic
    if not self.fireRate or self.fireRate == 0 then
        return
    end

    -- Update recoil animation
    if self.recoilTimer > 0 then
        self.recoilTimer = self.recoilTimer - dt
        if self.recoilTimer < 0 then
            self.recoilTimer = 0
        end
    end

    -- Update muzzle flash
    if self.muzzleFlashTimer > 0 then
        self.muzzleFlashTimer = self.muzzleFlashTimer - dt
        if self.muzzleFlashTimer < 0 then
            self.muzzleFlashTimer = 0
        end
    end

    -- Update beam timer
    if self.beamTimer > 0 then
        self.beamTimer = self.beamTimer - dt
        if self.beamTimer < 0 then
            self.beamTimer = 0
        end
    end

    -- Decrement cooldown
    if self.cooldown > 0 then
        self.cooldown = self.cooldown - dt
    end

    -- Handle attack based on type
    if self.attackType == "aura" then
        self:updateAuraAttack(dt, creeps)
    elseif self.attackType == "beam" then
        self:updateBeamAttack(dt, creeps)
    else
        self:updateProjectileAttack(dt, creeps, projectiles)
    end
end

-- Aura attack: constant slow to all creeps in range (void_ring)
function Tower:updateAuraAttack(dt, creeps)
    local attackCfg = Config.TOWER_ATTACKS.void_ring

    -- Find all creeps in range and apply slow
    for _, creep in ipairs(creeps) do
        if not creep.dead and not creep.dying then
            local dx = creep.x - self.x
            local dy = creep.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= self.range then
                -- Apply slow effect
                StatusEffects.apply(creep, StatusEffects.SLOW, {
                    multiplier = attackCfg.slowMultiplier,
                    duration = attackCfg.slowDuration,
                })
            end
        end
    end

    -- No target tracking needed for visual, but we can still track closest for barrel rotation
    self.target = Combat.findTarget(self, creeps)

    -- Slow rotation toward target (or spin slowly when idle)
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local targetRotation = math.atan2(dy, dx)
        local rotDiff = targetRotation - self.rotation
        while rotDiff > math.pi do rotDiff = rotDiff - 2 * math.pi end
        while rotDiff < -math.pi do rotDiff = rotDiff + 2 * math.pi end
        self.rotation = self.rotation + rotDiff * math.min(1, dt * self.rotationSpeed * 0.5)
    else
        -- Slow idle spin
        self.rotation = self.rotation + dt * 0.5
    end
end

-- Beam attack: charge-up laser sight, then instant damage (void_eye)
function Tower:updateBeamAttack(dt, creeps)
    local attackCfg = Config.TOWER_ATTACKS.void_eye

    -- Find target
    self.target = Combat.findTarget(self, creeps)

    -- Rotate barrel toward target
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local targetRotation = math.atan2(dy, dx)
        local rotDiff = targetRotation - self.rotation
        while rotDiff > math.pi do rotDiff = rotDiff - 2 * math.pi end
        while rotDiff < -math.pi do rotDiff = rotDiff + 2 * math.pi end
        self.rotation = self.rotation + rotDiff * math.min(1, dt * self.rotationSpeed)
    end

    -- State machine for beam attack
    if self.attackState == Tower.STATE_IDLE then
        if self.target and self.cooldown <= 0 then
            -- Start charging
            self.attackState = Tower.STATE_CHARGING
            self.chargeTimer = 0
            self.beamTarget = self.target
        end

    elseif self.attackState == Tower.STATE_CHARGING then
        -- Track the same target while charging
        if self.beamTarget and (self.beamTarget.dead or self.beamTarget.dying) then
            -- Target died, restart
            self.attackState = Tower.STATE_IDLE
            self.beamTarget = nil
            return
        end

        -- Check if target moved out of range
        if self.beamTarget then
            local dx = self.beamTarget.x - self.x
            local dy = self.beamTarget.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > self.range * 1.2 then  -- Small grace range
                self.attackState = Tower.STATE_IDLE
                self.beamTarget = nil
                return
            end
        end

        self.chargeTimer = self.chargeTimer + dt

        if self.chargeTimer >= attackCfg.chargeTime then
            -- Fire beam!
            self.attackState = Tower.STATE_FIRING
            self.beamTimer = attackCfg.beamDuration

            -- Apply damage instantly
            if self.beamTarget and not self.beamTarget.dead then
                self.beamTarget:takeDamage(self.damage, self.rotation)
                EventBus.emit("creep_hit", {
                    creep = self.beamTarget,
                    damage = self.damage,
                    position = { x = self.beamTarget.x, y = self.beamTarget.y },
                    angle = self.rotation,
                })
            end

            -- Trigger recoil
            self.recoilTimer = self.recoilDuration
            self.muzzleFlashTimer = 0.1

            -- Emit tower fired event
            EventBus.emit("tower_fired", { towerType = self.towerType })
        end

    elseif self.attackState == Tower.STATE_FIRING then
        if self.beamTimer <= 0 then
            -- Beam finished, go to cooldown
            self.attackState = Tower.STATE_COOLDOWN
            self.cooldown = 1 / self.fireRate
            self.beamTarget = nil
        end

    elseif self.attackState == Tower.STATE_COOLDOWN then
        if self.cooldown <= 0 then
            self.attackState = Tower.STATE_IDLE
        end
    end
end

-- Projectile attack: standard firing behavior (void_orb, void_bolt, void_star)
function Tower:updateProjectileAttack(dt, creeps, projectiles)
    -- Find closest non-dead creep within range
    self.target = Combat.findTarget(self, creeps)

    -- Rotate barrel toward target
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local targetRotation = math.atan2(dy, dx)

        -- Smooth rotation using per-tower rotation speed
        local rotDiff = targetRotation - self.rotation
        while rotDiff > math.pi do rotDiff = rotDiff - 2 * math.pi end
        while rotDiff < -math.pi do rotDiff = rotDiff + 2 * math.pi end
        self.rotation = self.rotation + rotDiff * math.min(1, dt * self.rotationSpeed)
    end

    -- Fire if cooldown expired and target exists
    if self.cooldown <= 0 and self.target then
        local proj = Projectile(
            self.x,
            self.y,
            self.rotation,
            self.projectileSpeed,
            self.damage,
            self.color,
            self.splashRadius,
            self.towerType
        )
        table.insert(projectiles, proj)
        self.cooldown = 1 / self.fireRate

        -- Trigger recoil and muzzle flash
        self.recoilTimer = self.recoilDuration
        self.muzzleFlashTimer = 0.05

        -- Emit tower fired event for audio system
        EventBus.emit("tower_fired", { towerType = self.towerType })
    end
end

function Tower:draw()
    -- Draw aura effect for void_ring (behind tower)
    if self.attackType == "aura" then
        GroundEffects.drawSlowAura(self.x, self.y, self.range, self.voidTime)
    end

    -- Calculate recoil offset (0-1 value for animation)
    local recoilOffset = PixelArt.calculateRecoil(self.recoilTimer, self.recoilDuration)

    -- Get tower config for voidVariant
    local towerConfig = Config.TOWERS[self.towerType]
    local voidVariant = towerConfig and towerConfig.voidVariant

    -- Draw void turret if tower has a voidVariant
    if voidVariant then
        local drew = TurretConcepts.drawVariant(
            voidVariant,
            self.x,
            self.y,
            self.rotation,
            recoilOffset,
            self.voidTime,
            self.voidSeed
        )

        if drew and self.muzzleFlashTimer > 0 then
            TurretConcepts.drawMuzzleFlashVariant(
                voidVariant,
                self.x,
                self.y,
                self.rotation,
                self.voidTime,
                self.voidSeed
            )
        end

        if drew then
            -- Draw beam effects on top of tower
            self:drawBeamEffects()
            return
        end
    end

    -- Fallback to pixel art (for wall and any tower without voidVariant)
    local drewPixelArt = PixelArt.drawTower(self.towerType, self.x, self.y, self.rotation, recoilOffset)

    -- Draw muzzle flash if active
    if drewPixelArt and self.muzzleFlashTimer > 0 then
        PixelArt.drawMuzzleFlash(self.towerType, self.x, self.y, self.rotation)
    end

    -- Final fallback to simple drawing if no pixel art defined
    if not drewPixelArt then
        -- Draw base circle (dark)
        love.graphics.setColor(Config.COLORS.towerBase)
        love.graphics.circle("fill", self.x, self.y, Config.TOWER_SIZE)

        -- Draw turret body (tower color)
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", self.x, self.y, Config.TOWER_SIZE * 0.7)

        -- Non-attacking towers (walls) don't have a barrel
        if self.fireRate and self.fireRate > 0 then
            -- Draw barrel toward rotation
            local barrelLength = Config.TOWER_SIZE * Config.TOWER_BARREL_LENGTH
            local barrelEndX = self.x + math.cos(self.rotation) * barrelLength
            local barrelEndY = self.y + math.sin(self.rotation) * barrelLength

            love.graphics.setLineWidth(4)
            love.graphics.setColor(self.color[1] * 0.8, self.color[2] * 0.8, self.color[3] * 0.8)
            love.graphics.line(self.x, self.y, barrelEndX, barrelEndY)
        end
    end

    -- Draw beam effects on top of fallback drawing too
    self:drawBeamEffects()
end

-- Draw beam charging/firing effects for void_eye
function Tower:drawBeamEffects()
    if self.attackType ~= "beam" then return end

    local attackCfg = Config.TOWER_ATTACKS.void_eye

    if self.attackState == Tower.STATE_CHARGING and self.beamTarget then
        -- Draw charging laser sight
        local chargeProgress = self.chargeTimer / attackCfg.chargeTime
        GroundEffects.drawBeam(self.x, self.y, self.beamTarget.x, self.beamTarget.y, true, chargeProgress)

    elseif self.attackState == Tower.STATE_FIRING and self.beamTarget then
        -- Draw firing beam
        local fireProgress = self.beamTimer / attackCfg.beamDuration
        GroundEffects.drawBeam(self.x, self.y, self.beamTarget.x, self.beamTarget.y, false, fireProgress)
    end
end

-- Get light parameters for the lighting system
function Tower:getLightParams()
    local lightingCfg = Config.LIGHTING
    local towerType = self.towerType

    -- Get base values from config
    local radius = lightingCfg.radii.tower[towerType] or 60
    local color = lightingCfg.colors.tower[towerType] or self.color
    local intensity = lightingCfg.intensities.tower[towerType] or 0.5

    -- Scale radius by tower range for attacking towers
    if self.range and self.range > 0 then
        radius = self.range * 0.5
    end

    return {
        x = self.x,
        y = self.y,
        radius = radius,
        color = color,
        intensity = intensity,
        flicker = true,  -- Towers can use flicker in ember mode
        flickerSeed = self.gridX * 100 + self.gridY,
    }
end

return Tower
