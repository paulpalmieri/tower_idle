-- src/core/state_machine.lua
-- Game state management
--
-- States: "menu", "playing", "paused", "prestige", "gameover"

local StateMachine = {}

-- Private state
local states = {}
local currentState = nil
local currentStateName = nil

-- Register a state
-- state = { enter = fn, update = fn, draw = fn, exit = fn }
function StateMachine.register(name, state)
    states[name] = state
end

-- Transition to a new state
function StateMachine.transition(name, data)
    -- Exit current state
    if currentState and currentState.exit then
        currentState.exit()
    end

    -- Enter new state
    currentStateName = name
    currentState = states[name]

    if currentState and currentState.enter then
        currentState.enter(data)
    end
end

-- Get current state name
function StateMachine.getCurrentState()
    return currentStateName
end

-- Forward update to current state
function StateMachine.update(dt)
    if currentState and currentState.update then
        currentState.update(dt)
    end
end

-- Forward draw to current state
function StateMachine.draw()
    if currentState and currentState.draw then
        currentState.draw()
    end
end

-- Forward input to current state
function StateMachine.keypressed(key)
    if currentState and currentState.keypressed then
        currentState.keypressed(key)
    end
end

function StateMachine.mousepressed(x, y, button)
    if currentState and currentState.mousepressed then
        currentState.mousepressed(x, y, button)
    end
end

return StateMachine
