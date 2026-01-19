-- conf.lua
-- LÖVE2D configuration

function love.conf(t)
    t.window.title = "Tower Idle"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = false
    t.window.vsync = 1

    t.version = "11.4"
    t.console = false

    -- Modules
    t.modules.audio = true
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
end
