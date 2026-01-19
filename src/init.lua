-- src/init.lua
-- Game initialization and main loop coordination

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local StateMachine = require("src.core.state_machine")

-- Systems
local Grid = require("src.world.grid")
local Economy = require("src.systems.economy")
local Waves = require("src.systems.waves")
local Combat = require("src.systems.combat")
local Pathfinding = require("src.systems.pathfinding")

-- Entities
local Tower = require("src.entities.tower")

-- UI
local HUD = require("src.ui.hud")
local Panel = require("src.ui.panel")

-- Screens (will be used in state machine)
local _GameScreen = require("src.ui.screens.game")

local Game = {}

-- Game state (private)
local state = {
    towers = {},
    creeps = {},
    projectiles = {},
    flowField = nil,
}

function Game.load()
    -- Set up graphics
    love.graphics.setBackgroundColor(0.02, 0.02, 0.04)
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Initialize core systems
    EventBus.init()

    -- Initialize game systems
    Grid.init(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    Economy.init()
    Waves.init()
    Combat.init()

    -- Compute initial pathfinding
    state.flowField = Pathfinding.computeFlowField(Grid)

    -- Initialize UI
    HUD.init()
    Panel.init(Grid.getPlayAreaWidth(), Grid.getPanelWidth(), Config.SCREEN_HEIGHT)

    -- Set up event listeners
    Game.setupEvents()

    -- Start game
    StateMachine.transition("playing")
end

function Game.setupEvents()
    EventBus.on("tower_placed", function(data)
        -- Recompute pathfinding when towers change
        state.flowField = Pathfinding.computeFlowField(Grid)
    end)

    EventBus.on("creep_killed", function(data)
        Economy.addGold(data.reward)
    end)

    EventBus.on("creep_reached_base", function(data)
        Economy.loseLife()
    end)

    EventBus.on("spawn_creep", function(data)
        table.insert(state.creeps, data.creep)
    end)
end

function Game.update(dt)
    -- Cap delta time
    dt = math.min(dt, 1/30)

    -- Update systems
    Economy.update(dt)
    Waves.update(dt, state.creeps)

    -- Update entities
    for _, tower in ipairs(state.towers) do
        tower:update(dt, state.creeps, state.projectiles)
    end

    for i = #state.projectiles, 1, -1 do
        local proj = state.projectiles[i]
        proj:update(dt, state.creeps)
        if proj.dead then
            table.remove(state.projectiles, i)
        end
    end

    for i = #state.creeps, 1, -1 do
        local creep = state.creeps[i]
        creep:update(dt, Grid, state.flowField)
        if creep.dead then
            if creep.reachedBase then
                EventBus.emit("creep_reached_base", { creep = creep })
            else
                EventBus.emit("creep_killed", {
                    creep = creep,
                    reward = creep.reward,
                    position = { x = creep.x, y = creep.y },
                })
            end
            table.remove(state.creeps, i)
        end
    end

    -- Update UI
    local mx, my = love.mouse.getPosition()
    Panel.update(mx, my)
end

function Game.draw()
    -- Draw game world
    Grid.draw()

    -- Draw entities
    for _, tower in ipairs(state.towers) do
        tower:draw()
    end

    for _, creep in ipairs(state.creeps) do
        creep:draw()
    end

    for _, proj in ipairs(state.projectiles) do
        proj:draw()
    end

    -- Draw tower placement preview
    local mx, my = love.mouse.getPosition()
    if mx < Grid.getPlayAreaWidth() then
        local canAfford = Economy.canAfford(Panel.getSelectedTowerCost())
        Grid.drawHover(mx, my, canAfford)
    end

    -- Draw UI
    Panel.draw(Economy)
    HUD.draw(Economy, Waves)
end

function Game.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Check panel first
    if x >= Grid.getPlayAreaWidth() then
        local result = Panel.handleClick(x, y, Economy)
        if result and result.action == "send_enemy" then
            Economy.sendCreep(result.type)
        end
        return
    end

    -- Place tower
    local gridX, gridY = Grid.screenToGrid(x, y)
    local towerType = Panel.getSelectedTower()
    local cost = Config.TOWERS[towerType].cost

    if Economy.canAfford(cost) and Pathfinding.canPlaceTowerAt(Grid, gridX, gridY) then
        local screenX, screenY = Grid.gridToScreen(gridX, gridY)
        local tower = Tower(screenX, screenY, towerType, gridX, gridY)

        if Grid.placeTower(gridX, gridY, tower) then
            table.insert(state.towers, tower)
            Economy.spendGold(cost)
            EventBus.emit("tower_placed", { tower = tower, gridX = gridX, gridY = gridY })
        end
    end
end

function Game.keypressed(key)
    -- Tower selection
    local towerKeys = {
        ["1"] = "basic",
        ["2"] = "rapid",
        ["3"] = "sniper",
        ["4"] = "cannon",
    }
    if towerKeys[key] then
        Panel.selectTower(towerKeys[key])
        return
    end

    -- Enemy sending
    local sendKeys = {
        q = "triangle",
        w = "square",
        e = "pentagon",
        r = "hexagon",
    }
    if sendKeys[key] then
        Economy.sendCreep(sendKeys[key])
        return
    end

    -- Quit
    if key == "escape" then
        love.event.quit()
    end
end

function Game.quit()
    -- Save game state here when implemented
end

-- Expose state for systems that need it
function Game.getTowers()
    return state.towers
end

function Game.getCreeps()
    return state.creeps
end

return Game
