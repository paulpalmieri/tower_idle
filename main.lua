-- main.lua
-- Tower Idle - Entry Point
--
-- This file is intentionally minimal.
-- All game logic lives in src/

local Game = require("src.init")

function love.load()
    -- Pixel-perfect rendering (no blur/smoothing)
    love.graphics.setDefaultFilter("nearest", "nearest")
    Game.load()
end

function love.update(dt)
    Game.update(dt)
end

function love.draw()
    Game.draw()
end

function love.mousepressed(x, y, button)
    if Game.mousepressed then
        Game.mousepressed(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    if Game.mousemoved then
        Game.mousemoved(x, y, dx, dy)
    end
end

function love.mousereleased(x, y, button)
    if Game.mousereleased then
        Game.mousereleased(x, y, button)
    end
end

function love.keypressed(key)
    if Game.keypressed then
        Game.keypressed(key)
    end
end

function love.wheelmoved(x, y)
    if Game.wheelmoved then
        Game.wheelmoved(x, y)
    end
end

function love.quit()
    if Game.quit then
        Game.quit()
    end
end
