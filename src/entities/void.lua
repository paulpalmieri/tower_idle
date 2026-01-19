-- src/entities/void.lua
-- The Void entity: procedurally generated pixel art portal

local Object = require("lib.classic")
local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local Void = Object:extend()

-- Fast hash - no bit ops needed
local function hash(x, y, seed)
    local n = math.sin(x * 12.9898 + y * 78.233 + seed) * 43758.5453
    return n - math.floor(n)
end

-- Raw noise at integer coords
local function noise2d(x, y, seed)
    return hash(x, y, seed)
end

-- Smooth interpolated noise
local function smoothNoise(x, y, seed)
    local ix, iy = math.floor(x), math.floor(y)
    local fx, fy = x - ix, y - iy

    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)

    local a = noise2d(ix, iy, seed)
    local b = noise2d(ix + 1, iy, seed)
    local c = noise2d(ix, iy + 1, seed)
    local d = noise2d(ix + 1, iy + 1, seed)

    return a + fx * (b - a) + fy * (c - a) + fx * fy * (a - b - c + d)
end

-- Layered fractal noise
local function fbm(x, y, seed, octaves)
    local val = 0
    local amp = 0.5
    local freq = 1
    for _ = 1, octaves do
        val = val + smoothNoise(x * freq, y * freq, seed) * amp
        amp = amp * 0.5
        freq = freq * 2
    end
    return val
end

function Void:new(x, y, width, height)
    -- Rectangle bounds (covering spawn zone)
    self.x = x
    self.y = y
    self.width = width
    self.height = height

    -- Health state
    self.maxHealth = Config.VOID.maxHealth
    self.health = self.maxHealth

    -- Anger state
    self.permanentAnger = 0
    self.currentAnger = 0

    -- Animation state
    self.clickFlash = 0
    self.time = 0

    -- Pixel art scale (size of each "pixel")
    self.pixelSize = 4

    -- Pre-generate rock border data for consistency
    self.rockSeed = math.random(1000)

    -- Generate rock border pixels
    self:generateRocks()
end

function Void:generateRocks()
    self.rocks = {}
    self.riftPixels = {}
    local ps = self.pixelSize
    local cols = math.floor(self.width / ps)
    local rows = math.floor(self.height / ps)
    local seed = self.rockSeed

    for py = 0, rows - 1 do
        for px = 0, cols - 1 do
            local screenX = self.x + px * ps
            local screenY = self.y + py * ps

            -- Distance from edges with jagged variation
            local edgeNoise1 = fbm(px * 0.4, py * 0.2, seed, 3)
            local edgeNoise2 = fbm(px * 0.15 + 50, py * 0.15, seed + 77, 2)
            local edgeNoise3 = hash(px * 0.7, py * 0.7, seed + 200)

            local distFromLeft = px + edgeNoise1 * 3
            local distFromRight = cols - 1 - px + edgeNoise2 * 3
            local distFromTop = py + fbm(px * 0.3, py * 0.1, seed + 33, 2) * 2
            local distFromBottom = rows - 1 - py + edgeNoise1 * 2
            local minDist = math.min(distFromLeft, distFromRight, distFromTop, distFromBottom)

            -- Jagged rocky border
            local baseThickness = 4 + fbm(px * 0.2, py * 0.2, seed + 10, 4) * 5
            local jagged = hash(px, py, seed + 999) * 2
            local borderThickness = baseThickness + jagged

            if minDist < borderThickness then
                -- Rock pixel with lots of variation
                local depth = 1 - (minDist / borderThickness)
                local n1 = fbm(px * 0.6, py * 0.6, seed + 100, 3)
                local n2 = hash(px * 1.5, py * 1.5, seed + 200)
                local n3 = fbm(px * 0.2, py * 0.8, seed + 300, 2)
                local crack = hash(px + py * 0.3, py, seed + 500) > 0.92

                table.insert(self.rocks, {
                    x = screenX, y = screenY,
                    depth = depth,
                    n1 = n1, n2 = n2, n3 = n3,
                    crack = crack,
                    edge = minDist < 0.8,
                    highlight = n2 > 0.75 and depth < 0.6,
                    moss = n1 > 0.6 and n3 > 0.4 and depth < 0.4,
                })
            else
                -- Rift interior pixel
                local cx, cy = cols / 2, rows / 2
                local dx, dy = (px - cx) / cx, (py - cy) / cy
                local distCenter = math.sqrt(dx * dx + dy * dy)

                table.insert(self.riftPixels, {
                    x = screenX, y = screenY,
                    px = px, py = py,
                    distCenter = distCenter,
                    angle = math.atan2(dy, dx),
                    rnd = hash(px, py, seed + 888),
                    rnd2 = hash(px * 2.1, py * 1.7, seed + 777),
                })
            end
        end
    end
end

function Void:update(dt)
    self.time = self.time + dt

    -- Decay click flash
    if self.clickFlash > 0 then
        self.clickFlash = self.clickFlash - dt / Config.VOID.clickFlashDuration
        if self.clickFlash < 0 then
            self.clickFlash = 0
        end
    end
end

-- Deal damage to the Void and return income earned
function Void:click(damage, income)
    damage = damage or Config.VOID.clickDamage
    income = income or Config.VOID.baseIncomePerClick

    self.health = self.health - damage

    -- Trigger click flash
    self.clickFlash = 1

    -- Calculate current anger from thresholds
    self:updateAnger()

    -- Check for reset
    if self.health <= 0 then
        self:reset()
    end

    -- Emit event
    EventBus.emit("void_clicked", {
        damage = damage,
        income = income,
        health = self.health,
        maxHealth = self.maxHealth,
        angerLevel = self:getAngerLevel(),
    })

    return income
end

-- Calculate anger from health thresholds
function Void:updateAnger()
    local thresholdAnger = 0
    for _, threshold in ipairs(Config.VOID.angerThresholds) do
        if self.health <= threshold then
            thresholdAnger = thresholdAnger + 1
        end
    end
    self.currentAnger = thresholdAnger
end

-- Get total anger level (threshold + permanent)
function Void:getAngerLevel()
    return math.min(self.currentAnger + self.permanentAnger, #Config.COLORS.void - 1)
end

-- Reset Void when health reaches 0
function Void:reset()
    self.permanentAnger = self.permanentAnger + 1
    self.health = self.maxHealth
    self.currentAnger = 0

    EventBus.emit("void_reset", {
        permanentAnger = self.permanentAnger,
        angerLevel = self:getAngerLevel(),
    })
end

-- Check if a point is inside the Void (for click detection)
function Void:isPointInside(px, py)
    return px >= self.x and px <= self.x + self.width and
           py >= self.y and py <= self.y + self.height
end

function Void:getHealth()
    return self.health
end

function Void:getMaxHealth()
    return self.maxHealth
end

function Void:getHealthPercent()
    return self.health / self.maxHealth
end

function Void:draw()
    local anger = self:getAngerLevel()
    local ps = self.pixelSize
    local t = self.time
    local seed = self.rockSeed

    -- Draw rift interior pixels
    for _, p in ipairs(self.riftPixels) do
        local px, py = p.px, p.py

        -- Multiple animated noise layers
        local n1 = fbm(px * 0.12 + t * 0.4, py * 0.12 + t * 0.1, seed, 4)
        local n2 = fbm(px * 0.08 - t * 0.2, py * 0.2 + t * 0.3, seed + 50, 3)
        local n3 = hash(px + math.floor(t * 3), py, seed + 111) -- flickering

        -- Swirling pattern
        local swirl = math.sin(p.angle * 4 + t * 1.5 + p.distCenter * 6) * 0.5 + 0.5

        -- Vertical tear streaks
        local tear = fbm(px * 0.05, py * 0.5 + t * 0.4, seed + 200, 2)
        local isTear = tear > 0.55 and p.rnd > 0.3

        -- Random sparkles
        local sparkle = hash(px + math.floor(t * 8), py + math.floor(t * 5), seed + 333)
        local isSpark = sparkle > 0.97

        -- Color calculation
        local r, g, b

        if isSpark then
            -- Bright sparkle
            r, g, b = 0.9, 0.7, 1.0
        elseif isTear then
            -- Bright purple tear
            local bright = (tear - 0.55) * 2 + n3 * 0.2
            r = 0.4 + bright * 0.5 + anger * 0.1
            g = 0.15 + bright * 0.3
            b = 0.7 + bright * 0.3
        else
            -- Dark void with texture
            local v = n1 * 0.5 + n2 * 0.3 + swirl * 0.2
            r = 0.03 + v * 0.15 + anger * 0.03 + p.rnd * 0.05
            g = 0.01 + v * 0.05 + p.rnd2 * 0.02
            b = 0.08 + v * 0.25 + p.rnd * 0.1

            -- Random darker spots
            if p.rnd > 0.85 then
                r, g, b = r * 0.5, g * 0.5, b * 0.7
            end

            -- Random purple tints
            if p.rnd2 > 0.8 then
                r = r + 0.1
                b = b + 0.15
            end
        end

        -- Pulsing glow based on anger
        local pulse = math.sin(t * 2.5 + p.distCenter * 3 + p.rnd * 6) * 0.08 * (anger + 1)
        r = math.max(0, math.min(1, r + pulse))
        b = math.max(0, math.min(1, b + pulse * 0.5))

        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", p.x, p.y, ps, ps)
    end

    -- Draw rock border pixels
    for _, rock in ipairs(self.rocks) do
        local d = rock.depth
        local n1, n2, n3 = rock.n1, rock.n2, rock.n3

        -- Base gray with lots of variation
        local base = 0.18 - d * 0.1
        local r = base + n1 * 0.12 + n2 * 0.08 - 0.02
        local g = base + n1 * 0.08 + n3 * 0.05 - 0.03
        local b = base + n1 * 0.05 + n2 * 0.03

        -- Cracks are dark
        if rock.crack then
            r, g, b = 0.02, 0.01, 0.03
        -- Edge outline
        elseif rock.edge then
            r, g, b = r * 0.3, g * 0.3, b * 0.3
        -- Highlights
        elseif rock.highlight then
            r, g, b = r + 0.12, g + 0.1, b + 0.08
        -- Moss/lichen spots
        elseif rock.moss then
            r = r - 0.03
            g = g + 0.06
            b = b + 0.02
        end

        -- Purple glow near void edge
        if d < 0.4 then
            local glow = (0.4 - d) / 0.4
            local pulse = math.sin(t * 2 + rock.x * 0.05 + rock.y * 0.05) * 0.3 + 0.7
            r = r + glow * 0.08 * pulse
            b = b + glow * 0.18 * pulse
        end

        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", rock.x, rock.y, ps, ps)
    end

    -- Click flash
    if self.clickFlash > 0 then
        love.graphics.setColor(0.8, 0.5, 1, self.clickFlash * 0.7)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    end

    self:drawUI()
end

function Void:drawUI()
    -- Health bar at bottom
    local barPadding = 8
    local barHeight = 6
    local barWidth = self.width - barPadding * 2
    local barX = self.x + barPadding
    local barY = self.y + self.height - barHeight - barPadding

    -- Background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth + 2, barHeight + 2)

    -- Health fill
    local healthPercent = self.health / self.maxHealth
    local r = 0.5 + (1 - healthPercent) * 0.5
    local g = 0.1
    local b = 0.6 + healthPercent * 0.2
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)

    -- Border
    love.graphics.setColor(0.4, 0.2, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)

    -- Health text
    love.graphics.setColor(1, 1, 1, 0.9)
    local healthText = self.health .. "/" .. self.maxHealth
    love.graphics.printf(healthText, barX, barY - 12, barWidth, "center")

    -- Anger pips
    local pipSize = 5
    local pipSpacing = 8
    local totalPips = #Config.VOID.angerThresholds
    local pipsWidth = totalPips * pipSpacing
    local pipStartX = self.x + self.width / 2 - pipsWidth / 2
    local pipY = barY - 26

    for i = 1, totalPips do
        local pipX = pipStartX + (i - 1) * pipSpacing
        local isFilled = i <= self.currentAnger

        if isFilled then
            love.graphics.setColor(1, 0.3, 0.1)
        else
            love.graphics.setColor(0.3, 0.15, 0.3)
        end
        love.graphics.rectangle("fill", pipX, pipY, pipSize, pipSize)
    end

    -- Permanent anger
    if self.permanentAnger > 0 then
        love.graphics.setColor(1, 0.3, 0.1)
        love.graphics.print("+" .. self.permanentAnger, pipStartX + pipsWidth + 3, pipY - 1)
    end
end

return Void
