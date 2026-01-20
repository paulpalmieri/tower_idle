-- main.lua
-- Tower Idle - Entry Point
--
-- This file is intentionally minimal.
-- All game logic lives in src/

-- Check for showcase mode via command line arguments
local showcaseMode = false
for _, arg in ipairs(arg or {}) do
    if arg == "--turret-concepts" then
        showcaseMode = true
        break
    end
end

-- Load appropriate module based on mode
local ActiveModule
if showcaseMode then
    ActiveModule = require("src.showcase.turret_showcase")
else
    ActiveModule = require("src.init")
end

function love.load()
    ActiveModule.load()
end

function love.update(dt)
    ActiveModule.update(dt)
end

function love.draw()
    ActiveModule.draw()
end

function love.mousepressed(x, y, button)
    if ActiveModule.mousepressed then
        ActiveModule.mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    if ActiveModule.mousemoved then
        ActiveModule.mousemoved(x, y, dx, dy)
    end
end

function love.mousereleased(x, y, button)
    if ActiveModule.mousereleased then
        ActiveModule.mousereleased(x, y, button)
    end
end

function love.keypressed(key)
    if ActiveModule.keypressed then
        ActiveModule.keypressed(key)
    end
end

function love.quit()
    if ActiveModule.quit then
        ActiveModule.quit()
    end
end
