-- src/entities/tower.lua
-- Tower entity

local Object = require("lib.classic")
local Config = require("src.config")
local MathUtils = require("src.core.math_utils")
local Projectile = require("src.entities.projectile")
local Combat = require("src.systems.combat")
local PixelArt = require("src.rendering.pixel_art")
local TurretConcepts = require("src.rendering.turret_concepts")
local EventBus = require("src.core.event_bus")
local StatusEffects = require("src.systems.status_effects")
local GroundEffects = require("src.rendering.ground_effects")
local Dither = require("src.rendering.dither")
local SkillTreeData = require("src.systems.skill_tree_data")

-- Lazy-load new entity classes to avoid circular requires
local LobbedProjectile, Blackhole, LightningProjectile, PoisonCloud

local function loadNewEntityClasses()
    if not LobbedProjectile then
        LobbedProjectile = require("src.entities.lobbed_projectile")
        Blackhole = require("src.entities.blackhole")
        LightningProjectile = require("src.entities.lightning_projectile")
        PoisonCloud = require("src.entities.poison_cloud")
    end
end

local Tower = Object:extend()

-- Attack states
Tower.STATE_IDLE = "idle"
Tower.STATE_TARGETING = "targeting"
Tower.STATE_CHARGING = "charging"
Tower.STATE_FIRING = "firing"
Tower.STATE_COOLDOWN = "cooldown"
Tower.STATE_BUILDING = "building"
-- New states for drip attack (void_orb)
Tower.STATE_GLOWING = "glowing"
Tower.STATE_DRIPPING = "dripping"
-- New states for piercing bolt (void_ring)
Tower.STATE_WINDUP = "windup"

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

    -- Upgrade tracking (unified level system)
    self.level = 1
    self.goldInvested = stats.cost  -- Track total gold invested for sell refund
    self:recalculateStats()

    -- Kill tracking
    self.kills = 0

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

    -- Build state (towers start building)
    self.buildTimer = Config.TOWER_BUILD.duration
    self.buildProgress = 0
    self.buildParticles = {}  -- Particles for build animation

    -- Attack state machine (starts in building state)
    self.attackState = Tower.STATE_BUILDING
    self.chargeTimer = 0
    self.beamTimer = 0
    self.beamTarget = nil  -- Stores target for beam attack

    -- Get attack type from config
    local attackCfg = Config.TOWER_ATTACKS[towerType]
    self.attackType = attackCfg and attackCfg.type or "projectile"

    -- Drip attack state (void_orb)
    self.glowTimer = 0
    self.dripTimer = 0
    self.dripTarget = nil
    self.dripTargetPos = nil  -- Last known position if target dies
    self.glowIntensity = 0

    -- Piercing bolt attack state (void_ring)
    self.windupTimer = 0
    self.windupSpinSpeed = 0
    self.baseSpinSpeed = 0.5  -- Idle spin speed

    -- Blackhole attack state (void_eye)
    self.blackholeTarget = nil
end

function Tower:recalculateStats()
    local bonuses = Config.UPGRADES.bonusPerLevel
    local levelBonus = self.level - 1  -- Level 1 = no bonus, level 5 = +4 levels of bonus

    -- Calculate base stats with level bonuses
    local baseDamage = self.baseDamage * (1 + levelBonus * bonuses.damage)
    local baseRange = self.baseRange * (1 + levelBonus * bonuses.range)
    local baseFireRate = self.baseFireRate * (1 + levelBonus * bonuses.fireRate)

    -- Apply skill tree bonuses
    self.damage = SkillTreeData.applyStatBonus(self.towerType, "damage", baseDamage)
    self.range = SkillTreeData.applyStatBonus(self.towerType, "range", baseRange)
    self.fireRate = SkillTreeData.applyStatBonus(self.towerType, "fireRate", baseFireRate)
end

function Tower:getUpgradeCost()
    if self.level >= Config.UPGRADES.maxLevel then
        return nil  -- Maxed out
    end
    local baseCost = Config.UPGRADES.baseCost
    -- Cost for upgrading from current level to next level
    return math.floor(baseCost * (Config.UPGRADES.costMultiplier ^ (self.level - 1)))
end

function Tower:canUpgrade()
    return self.level < Config.UPGRADES.maxLevel
end

function Tower:upgrade()
    if not self:canUpgrade() then
        return false
    end
    local cost = self:getUpgradeCost()
    self.level = self.level + 1
    self.goldInvested = self.goldInvested + cost
    self:recalculateStats()
    return true
end

function Tower:getLevel()
    return self.level
end

function Tower:recordKill()
    self.kills = self.kills + 1
end

function Tower:getSellValue()
    return math.floor(self.goldInvested * Config.TOWER_SELL_REFUND)
end

function Tower:update(dt, creeps, projectiles, groundEffects, chainLightnings)
    -- Update void animation time (all towers)
    self.voidTime = self.voidTime + dt

    -- Handle building phase
    if self.attackState == Tower.STATE_BUILDING then
        self.buildTimer = self.buildTimer - dt
        self.buildProgress = 1 - (self.buildTimer / Config.TOWER_BUILD.duration)
        self.buildProgress = math.max(0, math.min(1, self.buildProgress))

        -- Update build particles
        for i = #self.buildParticles, 1, -1 do
            local p = self.buildParticles[i]
            p.life = p.life - dt
            if p.life <= 0 then
                table.remove(self.buildParticles, i)
            else
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                -- Apply gravity toward target if set
                if p.targetX and p.targetY then
                    local dx = p.targetX - p.x
                    local dy = p.targetY - p.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist > 1 then
                        local pull = p.gravity or 150
                        p.vx = p.vx + (dx / dist) * pull * dt
                        p.vy = p.vy + (dy / dist) * pull * dt
                    end
                end
            end
        end

        if self.buildTimer <= 0 then
            self.attackState = Tower.STATE_IDLE
            self.buildProgress = 1
            self.buildParticles = {}  -- Clear particles when done
        end
        return  -- Skip combat logic while building
    end

    -- Non-attacking towers skip combat logic
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
    elseif self.attackType == "drip" then
        self:updateDripAttack(dt, creeps, groundEffects)
    elseif self.attackType == "piercing_bolt" then
        self:updatePiercingBoltAttack(dt, creeps)
    elseif self.attackType == "blackhole" then
        self:updateBlackholeAttack(dt, creeps)
    elseif self.attackType == "lobbed" then
        self:updateLobbedAttack(dt, creeps, projectiles)
    else
        self:updateProjectileAttack(dt, creeps, projectiles)
    end
end

-- Aura attack: constant slow to all creeps in range (void_ring)
function Tower:updateAuraAttack(dt, creeps)
    local attackCfg = Config.TOWER_ATTACKS.void_ring
    local rangeSq = self.range * self.range

    -- Find all creeps in range and apply slow (using squared distance)
    for _, creep in ipairs(creeps) do
        if not creep.dead and not creep.dying then
            local dx = creep.x - self.x
            local dy = creep.y - self.y
            local distSq = dx * dx + dy * dy

            if distSq <= rangeSq then
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
        self.rotation = MathUtils.lerpAngle(self.rotation, targetRotation, self.rotationSpeed * 0.5, dt)
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
        self.rotation = MathUtils.lerpAngle(self.rotation, targetRotation, self.rotationSpeed, dt)
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

        -- Check if target moved out of range (using squared distance)
        if self.beamTarget then
            local dx = self.beamTarget.x - self.x
            local dy = self.beamTarget.y - self.y
            local distSq = dx * dx + dy * dy
            local graceRangeSq = (self.range * 1.2) * (self.range * 1.2)
            if distSq > graceRangeSq then  -- Small grace range
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
                -- Mark the creep with the source tower for kill attribution
                self.beamTarget.killedBy = self
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

-- Projectile attack: standard firing behavior (void_bolt - chain lightning)
function Tower:updateProjectileAttack(dt, creeps, projectiles)
    -- Find closest non-dead creep within range
    self.target = Combat.findTarget(self, creeps)

    -- Rotate barrel toward target
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local targetRotation = math.atan2(dy, dx)
        self.rotation = MathUtils.lerpAngle(self.rotation, targetRotation, self.rotationSpeed, dt)
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
            self.towerType,
            self  -- Pass source tower for kill attribution
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

-- Drip attack: glow + drip visual, spawns poison pool at enemy (void_orb)
function Tower:updateDripAttack(dt, creeps, groundEffects)
    loadNewEntityClasses()
    local attackCfg = Config.TOWER_ATTACKS.void_orb

    -- Find target
    self.target = Combat.findTarget(self, creeps)

    -- Rotate toward target
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local targetRotation = math.atan2(dy, dx)
        self.rotation = MathUtils.lerpAngle(self.rotation, targetRotation, self.rotationSpeed, dt)
    end

    -- State machine: IDLE -> GLOWING -> DRIPPING -> COOLDOWN
    if self.attackState == Tower.STATE_IDLE then
        self.glowIntensity = 0
        if self.target and self.cooldown <= 0 then
            self.attackState = Tower.STATE_GLOWING
            self.glowTimer = 0
            self.dripTarget = self.target
            self.dripTargetPos = { x = self.target.x, y = self.target.y }
        end

    elseif self.attackState == Tower.STATE_GLOWING then
        self.glowTimer = self.glowTimer + dt
        self.glowIntensity = self.glowTimer / attackCfg.glowDuration

        -- Update target position if still alive
        if self.dripTarget and not self.dripTarget.dead and not self.dripTarget.dying then
            self.dripTargetPos = { x = self.dripTarget.x, y = self.dripTarget.y }
        end

        if self.glowTimer >= attackCfg.glowDuration then
            -- Start dripping
            self.attackState = Tower.STATE_DRIPPING
            self.dripTimer = 0
            self.glowIntensity = 1
        end

    elseif self.attackState == Tower.STATE_DRIPPING then
        self.dripTimer = self.dripTimer + dt

        -- Keep updating target position while dripping
        if self.dripTarget and not self.dripTarget.dead and not self.dripTarget.dying then
            self.dripTargetPos = { x = self.dripTarget.x, y = self.dripTarget.y }
        end

        if self.dripTimer >= attackCfg.dripDuration then
            -- Drip complete - spawn poison cloud at target position
            if groundEffects and self.dripTargetPos then
                local cloud = PoisonCloud(self.dripTargetPos.x, self.dripTargetPos.y)
                table.insert(groundEffects, cloud)
            end

            -- Apply direct damage to target if still alive
            if self.dripTarget and not self.dripTarget.dead and not self.dripTarget.dying then
                self.dripTarget:takeDamage(self.damage, self.rotation)
                self.dripTarget.killedBy = self
                EventBus.emit("creep_hit", {
                    creep = self.dripTarget,
                    damage = self.damage,
                    position = { x = self.dripTarget.x, y = self.dripTarget.y },
                    angle = self.rotation,
                })
            end

            -- Trigger visual feedback
            self.recoilTimer = self.recoilDuration
            self.muzzleFlashTimer = 0.1
            EventBus.emit("tower_fired", { towerType = self.towerType })

            -- Go to cooldown
            self.attackState = Tower.STATE_COOLDOWN
            self.cooldown = 1 / self.fireRate
            self.dripTarget = nil
            self.glowIntensity = 0
        end

    elseif self.attackState == Tower.STATE_COOLDOWN then
        self.glowIntensity = math.max(0, self.glowIntensity - dt * 3)
        if self.cooldown <= 0 then
            self.attackState = Tower.STATE_IDLE
        end
    end
end

-- Piercing bolt attack: fast piercing projectile (void_bolt)
function Tower:updatePiercingBoltAttack(dt, creeps)
    loadNewEntityClasses()
    local attackCfg = Config.TOWER_ATTACKS.void_bolt

    -- Find target
    self.target = Combat.findTarget(self, creeps)

    -- Rotate toward target
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local targetRotation = math.atan2(dy, dx)
        self.rotation = MathUtils.lerpAngle(self.rotation, targetRotation, self.rotationSpeed, dt)
    end

    -- Fire if cooldown expired and target exists
    if self.cooldown <= 0 and self.target then
        -- Calculate angle to target
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local angle = math.atan2(dy, dx)

        -- Spawn piercing bolt
        EventBus.emit("spawn_lightning_bolt", {
            x = self.x,
            y = self.y,
            angle = angle,
            damage = self.damage,
            sourceTower = self,
        })

        self.cooldown = 1 / self.fireRate

        -- Trigger visual feedback
        self.recoilTimer = self.recoilDuration
        self.muzzleFlashTimer = 0.05
        EventBus.emit("tower_fired", { towerType = self.towerType })
    end
end

-- Blackhole attack: charge + spawn blackhole that pulls enemies (void_eye)
function Tower:updateBlackholeAttack(dt, creeps)
    loadNewEntityClasses()
    local attackCfg = Config.TOWER_ATTACKS.void_eye

    -- Find target
    self.target = Combat.findTarget(self, creeps)

    -- Rotate toward target
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local targetRotation = math.atan2(dy, dx)
        self.rotation = MathUtils.lerpAngle(self.rotation, targetRotation, self.rotationSpeed, dt)
    end

    -- State machine: IDLE -> CHARGING -> FIRING -> COOLDOWN
    if self.attackState == Tower.STATE_IDLE then
        if self.target and self.cooldown <= 0 then
            self.attackState = Tower.STATE_CHARGING
            self.chargeTimer = 0
            self.blackholeTarget = self.target
        end

    elseif self.attackState == Tower.STATE_CHARGING then
        self.chargeTimer = self.chargeTimer + dt

        -- Track target position
        if self.blackholeTarget and (self.blackholeTarget.dead or self.blackholeTarget.dying) then
            -- Target died, find new one
            self.blackholeTarget = Combat.findTarget(self, creeps)
            if not self.blackholeTarget then
                self.attackState = Tower.STATE_IDLE
                return
            end
        end

        -- Check if target moved out of range (using squared distance)
        if self.blackholeTarget then
            local dx = self.blackholeTarget.x - self.x
            local dy = self.blackholeTarget.y - self.y
            local distSq = dx * dx + dy * dy
            local graceRangeSq = (self.range * 1.2) * (self.range * 1.2)
            if distSq > graceRangeSq then
                self.attackState = Tower.STATE_IDLE
                self.blackholeTarget = nil
                return
            end
        end

        if self.chargeTimer >= attackCfg.chargeTime and self.blackholeTarget then
            -- Spawn blackhole at target location!
            self.attackState = Tower.STATE_FIRING

            EventBus.emit("spawn_blackhole", {
                x = self.blackholeTarget.x,
                y = self.blackholeTarget.y,
                sourceTower = self,
            })

            -- No muzzle flash for blackhole - just audio event
            EventBus.emit("tower_fired", { towerType = self.towerType })

            -- Go to cooldown
            self.attackState = Tower.STATE_COOLDOWN
            self.cooldown = 1 / self.fireRate
            self.blackholeTarget = nil
        end

    elseif self.attackState == Tower.STATE_FIRING then
        self.attackState = Tower.STATE_COOLDOWN
        self.cooldown = 1 / self.fireRate

    elseif self.attackState == Tower.STATE_COOLDOWN then
        if self.cooldown <= 0 then
            self.attackState = Tower.STATE_IDLE
        end
    end
end

-- Lobbed attack: parabolic arc bomb + explosion burst (void_star)
function Tower:updateLobbedAttack(dt, creeps, projectiles)
    loadNewEntityClasses()

    -- Find target
    self.target = Combat.findTarget(self, creeps)

    -- Rotate toward target
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local targetRotation = math.atan2(dy, dx)
        self.rotation = MathUtils.lerpAngle(self.rotation, targetRotation, self.rotationSpeed, dt)
    end

    -- Fire if cooldown expired and target exists
    if self.cooldown <= 0 and self.target then
        -- Spawn lobbed projectile via event (handled by init.lua)
        EventBus.emit("spawn_lobbed_projectile", {
            startX = self.x,
            startY = self.y,
            targetX = self.target.x,
            targetY = self.target.y,
            damage = self.damage,
            sourceTower = self,
        })

        self.cooldown = 1 / self.fireRate

        -- Trigger recoil and muzzle flash
        self.recoilTimer = self.recoilDuration
        self.muzzleFlashTimer = 0.1

        -- Emit tower fired event
        EventBus.emit("tower_fired", { towerType = self.towerType })
    end
end

-- Draw tower shadow (call before drawing towers for proper layering)
function Tower:drawShadow()
    local shadowConfig = Config.TOWER_SHADOW
    local ditherConfig = Config.TOWER_DITHER

    -- Don't draw during early build phase
    if self.buildProgress < 0.3 then return end

    -- Fade in during build
    local buildFade = 1
    if self.buildProgress < 1 then
        buildFade = (self.buildProgress - 0.3) / 0.7
    end

    -- Draw dithering first (corruption stain underneath tower)
    if ditherConfig and ditherConfig.enabled then
        local ditherY = self.y + ditherConfig.offsetY
        local ditherAlpha = ditherConfig.alpha * buildFade
        -- Pass tower color for edge bleed effect
        local towerColor = self.color or {0.5, 0.5, 0.5}
        Dither.drawGroundingRing(
            self.x,
            ditherY,
            ditherConfig.radius,
            ditherConfig.radius * ditherConfig.yRatio,
            nil,  -- unused param
            towerColor,
            ditherAlpha
        )
    end

    -- Draw ellipse shadow
    if shadowConfig.enabled then
        local shadowAlpha = shadowConfig.alpha * buildFade
        local baseRadius = Config.CELL_SIZE * 0.4 * shadowConfig.radiusMultiplier
        local shadowRadiusX = baseRadius
        local shadowRadiusY = baseRadius * shadowConfig.yRatio
        local shadowY = self.y + shadowConfig.offsetY

        love.graphics.setColor(
            shadowConfig.color[1],
            shadowConfig.color[2],
            shadowConfig.color[3],
            shadowAlpha
        )
        love.graphics.ellipse("fill", self.x, shadowY, shadowRadiusX, shadowRadiusY)
    end
end

function Tower:draw()
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
            self.voidSeed,
            self.buildProgress,
            self.buildParticles,
            self.level
        )

        -- Hover/selected glow: redraw with additive blend to brighten the sprite
        if drew and (self.isHovered or self.isSelected) then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(0.3, 0.3, 0.3, 1)  -- Dim the additive pass
            TurretConcepts.drawVariant(
                voidVariant,
                self.x,
                self.y,
                self.rotation,
                recoilOffset,
                self.voidTime,
                self.voidSeed,
                self.buildProgress,
                self.buildParticles,
                self.level
            )
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(1, 1, 1, 1)  -- Reset color
        end

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

        -- Draw glow effect for drip attack (void_orb) - redraw only the void entity with additive blend
        if drew and self.attackType == "drip" and self.glowIntensity and self.glowIntensity > 0 then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(0.3 * self.glowIntensity, 0.5 * self.glowIntensity, 0.2 * self.glowIntensity, 1)
            TurretConcepts.drawVoidEntityOnly(
                voidVariant,
                self.x,
                self.y,
                self.rotation,
                self.voidTime,
                self.voidSeed,
                self.level
            )
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(1, 1, 1, 1)
        end

        if drew then
            -- Draw beam effects on top of tower
            self:drawBeamEffects()
            return
        end
    end

    -- Fallback to pixel art (for any tower without voidVariant)
    local drewPixelArt = PixelArt.drawTower(self.towerType, self.x, self.y, self.rotation, recoilOffset)

    -- Hover/selected glow for pixel art towers
    if drewPixelArt and (self.isHovered or self.isSelected) then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.3, 0.3, 0.3, 1)  -- Dim the additive pass
        PixelArt.drawTower(self.towerType, self.x, self.y, self.rotation, recoilOffset)
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1)  -- Reset color
    end

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

        -- Non-attacking towers don't have a barrel
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

-- Draw beam charging/firing effects for void_eye (now blackhole charging)
function Tower:drawBeamEffects()
    -- Blackhole has no charging line - just spawns blackhole
    if self.attackType == "blackhole" then
        return
    end

    -- Drip effect for void_orb
    if self.attackType == "drip" then
        local attackCfg = Config.TOWER_ATTACKS.void_orb

        if self.attackState == Tower.STATE_DRIPPING and self.dripTargetPos then
            local dripProgress = self.dripTimer / attackCfg.dripDuration
            GroundEffects.drawDripEffect(self.x, self.y, self.dripTargetPos.x, self.dripTargetPos.y, dripProgress)
        end
        return
    end

    -- Legacy beam attack (kept for compatibility)
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

-- Get glow parameters for the bloom system
function Tower:getGlowParams()
    local postCfg = Config.POST_PROCESSING
    local towerType = self.towerType

    -- Get base values from config
    local radius = postCfg.radii.tower or 80
    local color = postCfg.colors.tower[towerType] or self.color
    local intensity = 1.0

    return {
        x = self.x,
        y = self.y,
        radius = radius,
        color = color,
        intensity = intensity,
    }
end

-- Alias for backward compatibility
Tower.getLightParams = Tower.getGlowParams

return Tower
