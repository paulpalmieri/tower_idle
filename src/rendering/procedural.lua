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

-- Voronoi/cellular noise for tectonic plates, flagstones, etc.
-- Returns { f1, f2, cellId, edgeDistance }
-- f1 = distance to closest cell center (cell fill)
-- f2 = distance to second closest (for edges)
-- edgeDistance = f2 - f1 (thin = on fissure/edge)
-- yRatio applies vertical compression for top-down perspective
function Procedural.voronoi(x, y, seed, cellSize, yRatio)
    yRatio = yRatio or 0.9
    cellSize = cellSize or 1

    -- Convert to cell-space coordinates
    -- Divide Y by yRatio to compress vertically (cells appear wider/flatter)
    local cx = x / cellSize
    local cy = (y / cellSize) / yRatio

    local ix = math.floor(cx)
    local iy = math.floor(cy)

    local f1 = 999
    local f2 = 999
    local closestId = 0

    -- Check 3x3 cell neighborhood
    for dx = -1, 1 do
        for dy = -1, 1 do
            local nx = ix + dx
            local ny = iy + dy

            -- Random point within cell (using hash for deterministic positions)
            local px = nx + Procedural.hash(nx, ny, seed)
            local py = ny + Procedural.hash(nx, ny, seed + 100)

            -- Distance to this cell's point
            local distX = cx - px
            local distY = cy - py
            local dist = math.sqrt(distX * distX + distY * distY)

            if dist < f1 then
                f2 = f1
                f1 = dist
                closestId = Procedural.hash(nx, ny, seed + 200)
            elseif dist < f2 then
                f2 = dist
            end
        end
    end

    return {
        f1 = f1,
        f2 = f2,
        cellId = closestId,
        edgeDistance = f2 - f1,
    }
end

return Procedural
