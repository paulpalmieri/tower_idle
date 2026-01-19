-- main.lua
-- Tower Idle - Entry Point
--
-- This file is intentionally minimal.
-- All game logic lives in src/

local Game = require("src.init")

function love.load()
    Game.load()
end

function love.update(dt)
    Game.update(dt)
end

function love.draw()
    Game.draw()
end

function love.mousepressed(x, y, button)
    Game.mousepressed(x, y, button)
end

function love.keypressed(key)
    Game.keypressed(key)
end

function love.quit()
    Game.quit()
end
