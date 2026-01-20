-- src/core/math_utils.lua
-- Shared math utilities for angle normalization, interpolation, and seed generation

local MathUtils = {}

-- Normalize an angle to the range [-pi, pi]
function MathUtils.normalizeAngle(angle)
    while angle > math.pi do angle = angle - 2 * math.pi end
    while angle < -math.pi do angle = angle + 2 * math.pi end
    return angle
end

-- Smoothly interpolate from current angle to target angle
-- Returns the new angle after applying rotational interpolation
-- @param current: Current angle in radians
-- @param target: Target angle in radians
-- @param speed: Rotation speed multiplier
-- @param dt: Delta time
function MathUtils.lerpAngle(current, target, speed, dt)
    local diff = MathUtils.normalizeAngle(target - current)
    return current + diff * math.min(1, dt * speed)
end

-- Centralized seed generation (replaces module-level counters)
-- Each call returns a unique seed based on a global counter + random offset
local seedCounter = 0
function MathUtils.nextSeed(multiplier)
    seedCounter = seedCounter + 1
    return seedCounter * (multiplier or 17) + math.random(1000)
end

-- Get the raw seed counter value (for debugging/testing)
function MathUtils.getSeedCounter()
    return seedCounter
end

-- Reset the seed counter (for testing only)
function MathUtils.resetSeedCounter()
    seedCounter = 0
end

-- Clamp a value between min and max
function MathUtils.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- Linear interpolation
function MathUtils.lerp(a, b, t)
    return a + (b - a) * t
end

-- Distance between two points
function MathUtils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Distance squared (faster when you just need to compare distances)
function MathUtils.distanceSquared(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return dx * dx + dy * dy
end

return MathUtils
