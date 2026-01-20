-- src/systems/profiler.lua
-- Simple profiler for identifying performance bottlenecks
-- Outputs timing data to console every N seconds

local Profiler = {}

-- State
local state = {
    enabled = true,
    timers = {},           -- Current frame timings
    accumulated = {},      -- Accumulated timings over report interval
    counts = {},           -- Call counts over report interval
    reportInterval = 2.0,  -- Seconds between console reports
    timeSinceReport = 0,
    frameCount = 0,
}

-- High-resolution timer
local getTime = love.timer.getTime

function Profiler.init()
    state.timers = {}
    state.accumulated = {}
    state.counts = {}
    state.timeSinceReport = 0
    state.frameCount = 0
end

-- Start timing a section
function Profiler.start(name)
    if not state.enabled then return end
    state.timers[name] = getTime()
end

-- Stop timing a section and accumulate
function Profiler.stop(name)
    if not state.enabled then return end
    local startTime = state.timers[name]
    if not startTime then return end

    local elapsed = (getTime() - startTime) * 1000  -- Convert to ms
    state.accumulated[name] = (state.accumulated[name] or 0) + elapsed
    state.counts[name] = (state.counts[name] or 0) + 1
    state.timers[name] = nil
end

-- Call at end of each frame
function Profiler.endFrame(dt)
    if not state.enabled then return end

    state.frameCount = state.frameCount + 1
    state.timeSinceReport = state.timeSinceReport + dt

    if state.timeSinceReport >= state.reportInterval then
        Profiler.report()
        -- Reset accumulators
        state.accumulated = {}
        state.counts = {}
        state.timeSinceReport = 0
        state.frameCount = 0
    end
end

-- Print report to console
function Profiler.report()
    if state.frameCount == 0 then return end

    local fps = love.timer.getFPS()
    local frameTime = 1000 / math.max(1, fps)

    print("\n=== PROFILER REPORT ===")
    print(string.format("FPS: %d | Frame Time: %.2fms | Frames: %d", fps, frameTime, state.frameCount))
    print("-----------------------")

    -- Sort by total time
    local sorted = {}
    for name, total in pairs(state.accumulated) do
        local count = state.counts[name] or 1
        local avg = total / count
        local perFrame = total / state.frameCount
        table.insert(sorted, {
            name = name,
            total = total,
            avg = avg,
            perFrame = perFrame,
            count = count,
        })
    end
    table.sort(sorted, function(a, b) return a.perFrame > b.perFrame end)

    -- Print top entries
    print(string.format("%-25s %8s %8s %8s", "Section", "Per Frame", "Total", "Calls"))
    print(string.format("%-25s %8s %8s %8s", "-------", "---------", "-----", "-----"))
    for i, entry in ipairs(sorted) do
        if i <= 20 then  -- Top 20
            local pct = (entry.perFrame / frameTime) * 100
            print(string.format("%-25s %7.2fms %7.0fms %7d  (%.1f%%)",
                entry.name, entry.perFrame, entry.total, entry.count, pct))
        end
    end
    print("=======================\n")
end

-- Toggle profiler on/off
function Profiler.toggle()
    state.enabled = not state.enabled
    print("Profiler: " .. (state.enabled and "ENABLED" or "DISABLED"))
    return state.enabled
end

function Profiler.isEnabled()
    return state.enabled
end

return Profiler
