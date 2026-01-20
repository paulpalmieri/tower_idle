-- src/entities/projectile.lua
-- Tower projectile entity

local Object = require("lib.classic")
local Config = require("src.config")
local PixelArt = require("src.rendering.pixel_art")
local EventBus = require("src.core.event_bus")

-- Lazy-load entity classes to avoid circular requires
local PoisonCloud, BurningGround, ChainLightning

local function loadEntityClasses()
    if not PoisonCloud then
        PoisonCloud = require("src.entities.poison_cloud")
        BurningGround = require("src.entities.burning_ground")
        ChainLightning = require("src.entities.chain_lightning")
    end
end

local Projectile = Object:extend()

function Projectile:new(x, y, angle, speed, damage, color, splashRadius, towerType)
    self.x = x
    self.y = y
    self.angle = angle
    self.speed = speed
    self.damage = damage
    self.color = color
    self.splashRadius = splashRadius
    self.towerType = towerType

    self.vx = math.cos(angle) * speed
    self.vy = math.sin(angle) * speed
    self.dead = false
end

function Projectile:update(dt, creeps, groundEffects, chainLightnings)
    -- Move projectile
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Bounds check - mark dead if off screen
    if self.x < -50 or self.x > Config.SCREEN_WIDTH + 50 or
       self.y < -50 or self.y > Config.SCREEN_HEIGHT + 50 then
        self.dead = true
        return
    end

    -- Collision detection with creeps
    for _, creep in ipairs(creeps) do
        if not creep.dead then
            local dx = creep.x - self.x
            local dy = creep.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local hitRadius = Config.PROJECTILE_SIZE + creep.size

            if dist < hitRadius then
                -- Hit! Apply damage with bullet angle for directional particles
                if self.splashRadius and self.splashRadius > 0 then
                    -- Splash damage: full damage at center, falloff with distance
                    for _, target in ipairs(creeps) do
                        if not target.dead then
                            local tx = target.x - self.x
                            local ty = target.y - self.y
                            local targetDist = math.sqrt(tx * tx + ty * ty)

                            if targetDist < self.splashRadius then
                                -- Linear falloff from center
                                local falloff = 1 - (targetDist / self.splashRadius)
                                local splashDamage = self.damage * falloff
                                target:takeDamage(splashDamage, self.angle)
                                EventBus.emit("creep_hit", { creep = target, damage = splashDamage, position = { x = target.x, y = target.y }, angle = self.angle })
                            end
                        end
                    end
                else
                    -- Single target damage with bullet direction
                    creep:takeDamage(self.damage, self.angle)
                    EventBus.emit("creep_hit", { creep = creep, damage = self.damage, position = { x = creep.x, y = creep.y }, angle = self.angle })
                end

                -- Spawn on-hit effects based on tower type
                self:spawnOnHitEffects(creep, creeps, groundEffects, chainLightnings)

                self.dead = true
                return
            end
        end
    end
end

-- Spawn on-hit effects based on tower type
function Projectile:spawnOnHitEffects(hitCreep, allCreeps, groundEffects, chainLightnings)
    loadEntityClasses()

    local attackCfg = Config.TOWER_ATTACKS[self.towerType]
    if not attackCfg then return end

    if attackCfg.type == "projectile_cloud" then
        -- Void Orb: spawn poison cloud at impact
        if groundEffects then
            local cloud = PoisonCloud(self.x, self.y)
            table.insert(groundEffects, cloud)
        end

    elseif attackCfg.type == "projectile_fire" then
        -- Void Star: spawn burning ground at impact
        if groundEffects then
            local fire = BurningGround(self.x, self.y)
            table.insert(groundEffects, fire)
        end

    elseif attackCfg.type == "projectile_chain" then
        -- Void Bolt: chain lightning to nearby enemies
        if chainLightnings then
            local targets = ChainLightning.findChainTargets(
                self.x, self.y,
                hitCreep,
                allCreeps,
                attackCfg.maxChains,
                attackCfg.chainRange
            )

            if #targets > 0 then
                local chain = ChainLightning(
                    self.x, self.y,
                    targets,
                    self.damage,
                    attackCfg.chainDamageMultiplier
                )
                table.insert(chainLightnings, chain)
            end
        end
    end
end

-- Check if tower type is a void turret
local function isVoidTurret(towerType)
    return towerType == "void_orb" or towerType == "void_ring" or
           towerType == "void_bolt" or towerType == "void_eye" or
           towerType == "void_star"
end

-- Per-element projectile colors matching tower themes
local PROJECTILE_COLORS = {
    void_orb = {  -- Poison (green)
        trail = {0.4, 0.95, 0.3},
        glow = {0.5, 0.9, 0.35, 0.3},
        body = {0.5, 1.0, 0.4},
        bodyInner = {0.7, 1.0, 0.5},
    },
    void_ring = {  -- Ice (cyan)
        trail = {0.4, 0.85, 1.0},
        glow = {0.5, 0.85, 1.0, 0.3},
        body = {0.6, 0.95, 1.0},
        bodyInner = {0.8, 0.95, 1.0},
    },
    void_bolt = {  -- Electric (blue)
        trail = {0.3, 0.6, 1.0},
        glow = {0.4, 0.7, 1.0, 0.3},
        body = {0.5, 0.75, 1.0},
        bodyInner = {0.7, 0.85, 1.0},
    },
    void_eye = {  -- Shadow (purple)
        trail = {0.75, 0.45, 0.95},
        glow = {0.75, 0.50, 0.95, 0.3},
        body = {0.85, 0.6, 1.0},
        bodyInner = {0.90, 0.70, 1.0},
    },
    void_star = {  -- Fire (orange)
        trail = {1.0, 0.6, 0.2},
        glow = {1.0, 0.65, 0.25, 0.3},
        body = {1.0, 0.75, 0.3},
        bodyInner = {1.0, 0.85, 0.4},
    },
}

function Projectile:draw()
    -- Get element-specific colors for void turrets
    local projColors = PROJECTILE_COLORS[self.towerType]

    -- Draw trail effect (motion blur behind projectile)
    local trailLength = 3
    local trailAlphaStart = 0.25
    for i = trailLength, 1, -1 do
        local trailX = self.x - self.vx * 0.006 * i
        local trailY = self.y - self.vy * 0.006 * i
        local trailAlpha = trailAlphaStart * (1 - i / (trailLength + 1))

        if projColors then
            love.graphics.setColor(projColors.trail[1], projColors.trail[2], projColors.trail[3], trailAlpha)
        else
            love.graphics.setColor(0.85, 0.65, 0.25, trailAlpha)  -- Default gold
        end
        local trailSize = 4 - i
        love.graphics.circle("fill", trailX, trailY, trailSize)
    end

    -- Draw outer glow effect (behind projectile)
    local glowColor
    local glowSize

    if projColors then
        glowColor = projColors.glow
        glowSize = 10
    else
        glowColor = {0.95, 0.75, 0.35, 0.3}  -- Default brass/gold glow
        glowSize = 8
    end

    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowColor[4])
    love.graphics.circle("fill", self.x, self.y, glowSize)

    -- Inner brighter glow (hot core)
    love.graphics.setColor(glowColor[1] + 0.05, glowColor[2] + 0.15, glowColor[3] + 0.05, 0.5)
    love.graphics.circle("fill", self.x, self.y, glowSize * 0.5)

    -- Try to draw with pixel art sprite (only for non-void turrets)
    if self.towerType and not isVoidTurret(self.towerType) then
        local drew = PixelArt.drawProjectile(self.towerType, self.x, self.y, self.angle)
        if drew then
            return
        end
    end

    -- Fallback to simple circle (void energy orb or default)
    if projColors then
        -- Element-colored void energy orb
        love.graphics.setColor(projColors.body[1], projColors.body[2], projColors.body[3])
        love.graphics.circle("fill", self.x, self.y, Config.PROJECTILE_SIZE + 1)
        love.graphics.setColor(projColors.bodyInner[1], projColors.bodyInner[2], projColors.bodyInner[3])
        love.graphics.circle("fill", self.x, self.y, Config.PROJECTILE_SIZE * 0.6)
    else
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", self.x, self.y, Config.PROJECTILE_SIZE)
    end
end

-- Get light parameters for the lighting system
function Projectile:getLightParams()
    local lightingCfg = Config.LIGHTING

    -- Get color based on tower type
    local color
    if self.towerType and lightingCfg.colors.projectile[self.towerType] then
        color = lightingCfg.colors.projectile[self.towerType]
    else
        color = self.color or {0.8, 0.6, 0.4}
    end

    return {
        x = self.x,
        y = self.y,
        radius = lightingCfg.radii.projectile or 40,
        color = color,
        intensity = lightingCfg.intensities.projectile or 1.0,
        flicker = false,
    }
end

return Projectile
