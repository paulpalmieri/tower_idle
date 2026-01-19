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
local Void = require("src.entities.void")
local Creep = require("src.entities.creep")

-- UI
local HUD = require("src.ui.hud")
local Panel = require("src.ui.panel")
local Tooltip = require("src.ui.tooltip")

-- Screens (will be used in state machine)
local _GameScreen = require("src.ui.screens.game")

local Game = {}

-- Game state (private)
local state = {
    towers = {},
    creeps = {},
    projectiles = {},
    flowField = nil,
    gameSpeedIndex = 1,
    selectedTower = nil,   -- Reference to selected placed tower
    isDragging = false,    -- Drag-to-place active
    lastPlacedCell = nil,  -- {gridX, gridY} to avoid double-placing
    void = nil,            -- The Void entity
    autoClickTimer = 0,    -- Timer for auto-clicker
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

    -- Create Void entity covering spawn zone
    local voidX, voidY, voidW, voidH = Grid.getSpawnZoneBounds()
    state.void = Void(voidX, voidY, voidW, voidH)

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

    EventBus.on("void_clicked", function(data)
        -- Give gold for clicking
        Economy.voidClicked(data.income)

        -- Spawn one enemy immediately
        Game.spawnImmediateEnemy()

        -- Update waves system with current anger level
        Waves.setAngerLevel(data.angerLevel)
    end)
end

function Game.getTimeScale()
    return Config.GAME_SPEEDS[state.gameSpeedIndex]
end

function Game.getSpeedLabel()
    return Config.GAME_SPEED_LABELS[state.gameSpeedIndex]
end

-- Click the Void (used by both manual clicks and auto-clicker)
function Game.clickVoid()
    if state.void then
        state.void:click()
    end
end

-- Spawn a single enemy immediately (from Void click)
function Game.spawnImmediateEnemy()
    -- Pick enemy type based on current anger level
    local angerLevel = state.void and state.void:getAngerLevel() or 0

    -- At higher anger, chance of spawning stronger enemies
    local creepType = "triangle"
    if angerLevel >= 3 and math.random() < 0.2 then
        creepType = "hexagon"
    elseif angerLevel >= 2 and math.random() < 0.3 then
        creepType = "pentagon"
    elseif angerLevel >= 1 and math.random() < 0.4 then
        creepType = "square"
    end

    -- Spawn at random position in spawn zone
    local cols = Grid.getCols()
    local spawnCol = math.random(1, cols)
    local spawnRow = 1

    local x, y = Grid.gridToScreen(spawnCol, spawnRow)
    local creep = Creep(x, y, creepType)
    table.insert(state.creeps, creep)
end

function Game.update(dt)
    -- Cap delta time
    dt = math.min(dt, 1/30)

    -- Apply time scale
    dt = dt * Game.getTimeScale()

    -- Update Void
    if state.void then
        state.void:update(dt)
    end

    -- Handle auto-clicker
    local autoClickInterval = Panel.getAutoClickInterval()
    if autoClickInterval then
        state.autoClickTimer = state.autoClickTimer + dt
        if state.autoClickTimer >= autoClickInterval then
            state.autoClickTimer = state.autoClickTimer - autoClickInterval
            Game.clickVoid()
        end
    end

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

    -- Draw Void (behind towers and creeps)
    if state.void then
        state.void:draw()
    end

    -- Draw entities
    for _, tower in ipairs(state.towers) do
        tower:draw()
    end

    -- Draw selection highlight on selected tower
    if state.selectedTower then
        local t = state.selectedTower
        local selColor = Config.COLORS.upgrade.selected
        love.graphics.setColor(selColor[1], selColor[2], selColor[3], selColor[4])
        love.graphics.circle("fill", t.x, t.y, Config.TOWER_SIZE + 4)

        -- Draw range circle for selected tower
        if t.range and t.range > 0 then
            love.graphics.setColor(t.color[1], t.color[2], t.color[3], Config.UI.rangePreview.fillAlpha)
            love.graphics.circle("fill", t.x, t.y, t.range)
            love.graphics.setColor(t.color[1], t.color[2], t.color[3], Config.UI.rangePreview.strokeAlpha)
            love.graphics.setLineWidth(Config.UI.rangePreview.strokeWidth)
            love.graphics.circle("line", t.x, t.y, t.range)
        end
    end

    for _, creep in ipairs(state.creeps) do
        creep:draw()
    end

    for _, proj in ipairs(state.projectiles) do
        proj:draw()
    end

    -- Draw tower placement preview (only if no tower selected for upgrades)
    local mx, my = love.mouse.getPosition()
    if mx < Grid.getPlayAreaWidth() and not state.selectedTower then
        local canAfford = Economy.canAfford(Panel.getSelectedTowerCost())
        local towerType = Panel.getSelectedTower()
        Grid.drawHover(mx, my, canAfford, towerType)
    end

    -- Draw UI
    Panel.draw(Economy)
    HUD.draw(Economy, Waves, Game.getSpeedLabel())

    -- Draw tooltip on top
    Tooltip.draw(Economy)
end

-- Find tower at screen position
local function findTowerAt(screenX, screenY)
    for _, tower in ipairs(state.towers) do
        local dx = screenX - tower.x
        local dy = screenY - tower.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= Config.TOWER_SIZE then
            return tower
        end
    end
    return nil
end

-- Select/deselect a tower
local function selectTower(tower)
    if tower then
        state.selectedTower = tower
        Tooltip.show(tower)
        EventBus.emit("tower_selected", { tower = tower })
    else
        state.selectedTower = nil
        Tooltip.hide()
        EventBus.emit("tower_selection_cleared", {})
    end
end

-- Attempt to place a tower at grid position
local function tryPlaceTower(gridX, gridY)
    local towerType = Panel.getSelectedTower()
    local cost = Config.TOWERS[towerType].cost

    if Economy.canAfford(cost) and Pathfinding.canPlaceTowerAt(Grid, gridX, gridY) then
        local screenX, screenY = Grid.gridToScreen(gridX, gridY)
        local tower = Tower(screenX, screenY, towerType, gridX, gridY)

        if Grid.placeTower(gridX, gridY, tower) then
            table.insert(state.towers, tower)
            Economy.spendGold(cost)
            EventBus.emit("tower_placed", { tower = tower, gridX = gridX, gridY = gridY })
            return true
        end
    end
    return false
end

function Game.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Priority 1: Tooltip clicks (if visible)
    if Tooltip.isPointInside(x, y) then
        local result = Tooltip.handleClick(x, y, Economy)
        if result and result.action == "upgrade" then
            local tower = state.selectedTower
            if tower and Economy.spendGold(result.cost) then
                tower:upgrade(result.stat)
                EventBus.emit("tower_upgraded", {
                    tower = tower,
                    stat = result.stat,
                    newLevel = tower.upgrades[result.stat],
                    cost = result.cost,
                })
                -- Refresh tooltip position in case range changed
                Tooltip.show(tower)
            end
        end
        return
    end

    -- Priority 2: Panel clicks (deselect any selected tower)
    if x >= Grid.getPlayAreaWidth() then
        selectTower(nil)
        local result = Panel.handleClick(x, y, Economy)
        if result and result.action == "buy_upgrade" then
            if Economy.spendGold(result.cost) then
                Panel.purchaseUpgrade(result.type)
                EventBus.emit("upgrade_purchased", {
                    type = result.type,
                    level = Panel.getUpgradeLevel(result.type),
                    cost = result.cost,
                })
            end
        end
        return
    end

    -- Priority 3: Void clicks (before tower selection)
    if state.void and state.void:isPointInside(x, y) then
        selectTower(nil)
        Game.clickVoid()
        return
    end

    -- Priority 4: Click on placed tower (select/deselect)
    local clickedTower = findTowerAt(x, y)
    if clickedTower then
        -- Toggle selection
        if state.selectedTower == clickedTower then
            selectTower(nil)
        else
            selectTower(clickedTower)
        end
        return
    end

    -- Click on empty space deselects
    if state.selectedTower then
        selectTower(nil)
        return
    end

    -- Priority 5: Place tower and start drag
    local gridX, gridY = Grid.screenToGrid(x, y)
    if tryPlaceTower(gridX, gridY) then
        state.isDragging = true
        state.lastPlacedCell = { gridX = gridX, gridY = gridY }
    end
end

function Game.mousemoved(x, y, dx, dy)
    -- Drag-to-place: continue placing towers while dragging
    if state.isDragging and love.mouse.isDown(1) then
        -- Stop drag if moved to panel area
        if x >= Grid.getPlayAreaWidth() then
            state.isDragging = false
            state.lastPlacedCell = nil
            return
        end

        local gridX, gridY = Grid.screenToGrid(x, y)

        -- Skip if same cell as last placed
        if state.lastPlacedCell and
           state.lastPlacedCell.gridX == gridX and
           state.lastPlacedCell.gridY == gridY then
            return
        end

        -- Try to place at new cell
        if Grid.isValidCell(gridX, gridY) then
            if tryPlaceTower(gridX, gridY) then
                state.lastPlacedCell = { gridX = gridX, gridY = gridY }
            else
                -- Update last cell even if placement failed (to avoid retrying)
                state.lastPlacedCell = { gridX = gridX, gridY = gridY }
            end
        end
    end
end

function Game.mousereleased(x, y, button)
    if button == 1 then
        state.isDragging = false
        state.lastPlacedCell = nil
    end
end

function Game.keypressed(key)
    -- Tower selection
    local towerKeys = {
        ["1"] = "wall",
        ["2"] = "basic",
        ["3"] = "rapid",
        ["4"] = "sniper",
        ["5"] = "cannon",
    }
    if towerKeys[key] then
        Panel.selectTower(towerKeys[key])
        return
    end

    -- Upgrade hotkeys
    if key == "q" then
        local cost = Panel.getUpgradeCost("autoClicker")
        if cost > 0 and Economy.canAfford(cost) then
            if Economy.spendGold(cost) then
                Panel.purchaseUpgrade("autoClicker")
                EventBus.emit("upgrade_purchased", {
                    type = "autoClicker",
                    level = Panel.getUpgradeLevel("autoClicker"),
                    cost = cost,
                })
            end
        end
        return
    end

    -- Game speed toggle
    if key == "s" then
        state.gameSpeedIndex = state.gameSpeedIndex + 1
        if state.gameSpeedIndex > #Config.GAME_SPEEDS then
            state.gameSpeedIndex = 1
        end
        return
    end

    -- Escape: Deselect tower if selected, otherwise quit
    if key == "escape" then
        if state.selectedTower then
            selectTower(nil)
        else
            love.event.quit()
        end
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
