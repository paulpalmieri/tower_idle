-- src/entities/lobbed_projectile.lua
-- Lobbed bomb projectile entity (for Void Star tower)
-- Parabolic arc trajectory with explosion burst on impact

local Object = require("lib.classic")
local Config = require("src.config")
local EventBus = require("src.core.event_bus")

-- Lazy-load to avoid circular requires
local BurningGround

local function loadEntityClasses()
    if not BurningGround then
        BurningGround = require("src.entities.burning_ground")
    end
end

local LobbedProjectile = Object:extend()

function LobbedProjectile:new(startX, startY, targetX, targetY, damage, sourceTower)
    self.startX = startX
    self.startY = startY
    self.targetX = targetX
    self.targetY = targetY
    self.x = startX
    self.y = startY
    self.damage = damage
    self.sourceTower = sourceTower
    self.towerType = "void_star"

    local cfg = Config.TOWER_ATTACKS.void_star

    -- Calculate distance for arc height
    local dx = targetX - startX
    local dy = targetY - startY
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Arc height scales with distance
    self.arcHeight = math.min(
        cfg.maxArcHeight,
        cfg.arcHeightBase + distance * cfg.arcHeightPerDistance
    )

    -- Flight time based on slower lob speed
    self.flightTime = distance / cfg.lobSpeed
    self.flightTime = math.max(0.3, self.flightTime)  -- Minimum flight time
    self.elapsed = 0

    -- Animation
    self.rotation = 0

    -- State
    self.dead = false
end

function LobbedProjectile:update(dt, creeps, groundEffects, explosionBursts)
    if self.dead then return end

    local cfg = Config.TOWER_ATTACKS.void_star
    self.elapsed = self.elapsed + dt
    local t = self.elapsed / self.flightTime

    -- Spin animation
    self.rotation = self.rotation + cfg.spinSpeed * dt

    if t >= 1 then
        -- Impact!
        self.x = self.targetX
        self.y = self.targetY
        self:onImpact(creeps, groundEffects, explosionBursts)
        self.dead = true
        return
    end

    -- Linear interpolation for X
    self.x = self.startX + (self.targetX - self.startX) * t

    -- Y with parabolic arc
    local baseY = self.startY + (self.targetY - self.startY) * t
    self.y = baseY - math.sin(t * math.pi) * self.arcHeight
end

function LobbedProjectile:onImpact(creeps, groundEffects, explosionBursts)
    loadEntityClasses()

    local cfg = Config.TOWER_ATTACKS.void_star
    local splashRadius = cfg.fireRadius

    -- Apply splash damage
    for _, creep in ipairs(creeps) do
        if not creep.dead and not creep.dying then
            local dx = creep.x - self.x
            local dy = creep.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist <= splashRadius then
                local falloff = 1 - (dist / splashRadius)
                local splashDamage = self.damage * falloff
                creep:takeDamage(splashDamage, nil)

                if self.sourceTower then
                    creep.killedBy = self.sourceTower
                end

                EventBus.emit("creep_hit", {
                    creep = creep,
                    damage = splashDamage,
                    position = { x = creep.x, y = creep.y },
                    angle = nil,
                })
            end
        end
    end

    -- Spawn explosion burst particles
    if explosionBursts then
        local colors = Config.GROUND_EFFECTS.burning_ground.colors
        local particles = {}
        for i = 1, cfg.explosionParticles do
            local angle = (i / cfg.explosionParticles) * math.pi * 2 + math.random() * 0.3
            local speed = cfg.explosionSpeed * (0.6 + math.random() * 0.4)
            table.insert(particles, {
                x = self.x,
                y = self.y,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed * 0.7 - 30,
                life = cfg.explosionDuration,
                maxLife = cfg.explosionDuration,
                size = 3,
                r = colors.edge[1],
                g = colors.edge[2],
                b = colors.edge[3],
            })
        end
        table.insert(explosionBursts, {
            x = self.x,
            y = self.y,
            time = 0,
            duration = cfg.explosionDuration,
            particles = particles,
        })
    end

    -- Spawn burning ground
    if groundEffects then
        local fire = BurningGround(self.x, self.y)
        table.insert(groundEffects, fire)
    end
end

function LobbedProjectile:draw()
    local ps = 4  -- Pixel size
    local colors = Config.GROUND_EFFECTS.burning_ground.colors

    -- Draw shadow on ground
    local t = self.elapsed / self.flightTime
    local shadowX = self.startX + (self.targetX - self.startX) * t
    local shadowAlpha = 0.25 * (1 - math.abs(0.5 - t) * 2)
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.rectangle("fill", shadowX - ps, self.targetY - ps/2, ps * 2, ps)

    -- Draw simple rotating pixel bomb
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)

    -- Core (orange/red)
    love.graphics.setColor(colors.mid[1], colors.mid[2], colors.mid[3])
    love.graphics.rectangle("fill", -ps, -ps, ps * 2, ps * 2)

    -- Bright center
    love.graphics.setColor(colors.edge[1], colors.edge[2], colors.edge[3])
    love.graphics.rectangle("fill", -ps/2, -ps/2, ps, ps)

    love.graphics.pop()
end

-- Get glow parameters for the bloom system
function LobbedProjectile:getGlowParams()
    local colors = Config.GROUND_EFFECTS.burning_ground.colors
    return {
        x = self.x,
        y = self.y,
        radius = 40,
        color = { colors.edge[1], colors.edge[2], colors.edge[3] },
        intensity = 0.8,
    }
end

-- Alias for backward compatibility
LobbedProjectile.getLightParams = LobbedProjectile.getGlowParams

return LobbedProjectile
