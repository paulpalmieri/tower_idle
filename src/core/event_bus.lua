-- src/core/event_bus.lua
-- Pub/sub event system for decoupled communication
--
-- Usage:
--   EventBus.on("enemy_killed", function(data) ... end)
--   EventBus.emit("enemy_killed", { enemy = e, reward = 10 })

local EventBus = {}

-- Private state
local listeners = {}

function EventBus.init()
    listeners = {}
end

-- Subscribe to an event
-- Returns a handle that can be used to unsubscribe
function EventBus.on(event, callback)
    if not listeners[event] then
        listeners[event] = {}
    end

    local handle = {
        event = event,
        callback = callback,
    }

    table.insert(listeners[event], handle)
    return handle
end

-- Unsubscribe from an event
function EventBus.off(handle)
    if not handle or not handle.event then return end

    local eventListeners = listeners[handle.event]
    if not eventListeners then return end

    for i = #eventListeners, 1, -1 do
        if eventListeners[i] == handle then
            table.remove(eventListeners, i)
            return
        end
    end
end

-- Emit an event to all listeners
function EventBus.emit(event, data)
    local eventListeners = listeners[event]
    if not eventListeners then return end

    for _, handle in ipairs(eventListeners) do
        handle.callback(data)
    end
end

-- Clear all listeners for an event (or all events if none specified)
function EventBus.clear(event)
    if event then
        listeners[event] = nil
    else
        listeners = {}
    end
end

-- Get listener count (for debugging)
function EventBus.getListenerCount(event)
    if event then
        return listeners[event] and #listeners[event] or 0
    end

    local total = 0
    for _, eventListeners in pairs(listeners) do
        total = total + #eventListeners
    end
    return total
end

return EventBus
