-- src/rendering/procedural.lua
-- Shared procedural noise functions for void effects

local Procedural = {}

-- Fast hash - no bit ops needed
function Procedural.hash(x, y, seed)
    local n = math.sin(x * 12.9898 + y * 78.233 + seed) * 43758.5453
    return n - math.floor(n)
end

-- Raw noise at integer coords
function Procedural.noise2d(x, y, seed)
    return Procedural.hash(x, y, seed)
end

-- Smooth interpolated noise
function Procedural.smoothNoise(x, y, seed)
    local ix, iy = math.floor(x), math.floor(y)
    local fx, fy = x - ix, y - iy

    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)

    local a = Procedural.noise2d(ix, iy, seed)
    local b = Procedural.noise2d(ix + 1, iy, seed)
    local c = Procedural.noise2d(ix, iy + 1, seed)
    local d = Procedural.noise2d(ix + 1, iy + 1, seed)

    return a + fx * (b - a) + fy * (c - a) + fx * fy * (a - b - c + d)
end

-- Layered fractal noise
function Procedural.fbm(x, y, seed, octaves)
    local val = 0
    local amp = 0.5
    local freq = 1
    for _ = 1, octaves do
        val = val + Procedural.smoothNoise(x * freq, y * freq, seed) * amp
        amp = amp * 0.5
        freq = freq * 2
    end
    return val
end

return Procedural
