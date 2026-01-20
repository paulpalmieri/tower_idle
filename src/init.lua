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
local Audio = require("src.systems.audio")

-- Rendering
local Fonts = require("src.rendering.fonts")
local Background = require("src.rendering.background")
local Atmosphere = require("src.rendering.atmosphere")
local Lighting = require("src.rendering.lighting")
local FloatingNumbers = require("src.rendering.floating_numbers")

-- Entities
local Tower = require("src.entities.tower")
local Void = require("src.entities.void")
local Creep = require("src.entities.creep")
local ExitPortal = require("src.entities.exit_portal")

-- UI
local Panel = require("src.ui.panel")
local Tooltip = require("src.ui.tooltip")
local Cursor = require("src.ui.cursor")
local Settings = require("src.ui.settings")
local Shortcuts = require("src.ui.shortcuts")

local Game = {}

-- Game state (private)
local state = {
    towers = {},
    creeps = {},
    projectiles = {},
    cadavers = {},         -- Dead creep remains on the floor
    groundEffects = {},    -- Poison clouds, burning ground, etc.
    chainLightnings = {},  -- Chain lightning visual effects
    flowField = nil,
    gameSpeedIndex = 1,
    selectedTower = nil,   -- Reference to selected placed tower
    isDragging = false,    -- Drag-to-place active
    lastPlacedCell = nil,  -- {gridX, gridY} to avoid double-placing
    void = nil,            -- The Void entity
    exitPortal = nil,      -- The Exit Portal entity (at base)
    autoClickTimer = 0,    -- Timer for auto-clicker
}

function Game.load()
    -- Set up graphics
    love.graphics.setBackgroundColor(Config.COLORS.background)
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Initialize core systems
    EventBus.init()

    -- Initialize fonts (must be before UI)
    Fonts.init()

    -- Initialize game systems
    Grid.init(Config.SCREEN_WIDTH, Config.SCREEN_HEIGHT)
    Economy.init()
    Waves.init()
    Combat.init()

    -- Generate procedural background (full play area height)
    Background.generate(Grid.getPlayAreaWidth(), Config.SCREEN_HEIGHT)

    -- Compute initial pathfinding
    state.flowField = Pathfinding.computeFlowField(Grid)

    -- Create Void entity (positioned at center of spawn area)
    local voidX, voidY = Grid.getPortalCenter()
    state.void = Void(voidX, voidY)

    -- Create Exit Portal entity (positioned at center of base zone)
    local exitX, exitY = Grid.getExitPortalCenter()
    state.exitPortal = ExitPortal(exitX, exitY)

    -- Initialize UI (panel now contains all UI elements)
    Panel.init(Grid.getPlayAreaWidth(), Grid.getPanelWidth(), Config.SCREEN_HEIGHT)

    -- Initialize custom cursor
    Cursor.init()

    -- Initialize atmosphere effects
    Atmosphere.init()

    -- Initialize lighting system
    Lighting.init()

    -- Initialize audio system
    Audio.init()

    -- Initialize settings menu
    Settings.init()

    -- Initialize shortcuts overlay
    Shortcuts.init()

    -- Initialize floating numbers system
    FloatingNumbers.init()

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
        -- Register spawn with void for tear effect rendering
        if state.void then
            state.void:registerSpawn(data.creep)
        end
    end)

    EventBus.on("void_clicked", function(data)
        -- Give gold for clicking
        Economy.voidClicked(data.income)

        -- Spawn one enemy immediately
        Game.spawnImmediateEnemy()

        -- Update waves system with current anger level
        Waves.setAngerLevel(data.angerLevel)
    end)

    EventBus.on("window_resized", function(data)
        -- Recreate canvases for background and lighting at the base resolution
        -- (they are drawn at base res, then scaled by the transform)
        Background.regenerate(Grid.getPlayAreaWidth(), Config.SCREEN_HEIGHT)
        Lighting.resize()
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
    -- All enemies are now Void Spawns
    local creepType = "voidSpawn"

    -- Spawn from the portal
    local x, y = Grid.getSpawnPosition(nil, state.void)
    local creep = Creep(x, y, creepType)
    table.insert(state.creeps, creep)

    -- Register spawn with void for tear effect rendering
    if state.void then
        state.void:registerSpawn(creep)
    end
end

-- Procedural noise for cadaver rendering (simplified from creep)
local Procedural = require("src.rendering.procedural")

-- Draw a single cadaver (collapsed void remains)
local function _drawCadaver(cadaver)
    local cfg = Config.VOID_SPAWN
    local colors = cfg.colors
    local ps = cadaver.pixelSize
    local t = cadaver.time  -- Frozen animation time

    -- Calculate fade progress (0 = fresh, 1 = fully faded)
    local fadeProgress = cadaver.fadeTimer / Config.CADAVER_FADE_DURATION
    local fadeAlpha = 1.0 - fadeProgress

    -- Skip drawing if nearly invisible
    if fadeAlpha < 0.01 then return end

    -- Cadaver settings
    local alpha = 0.35 * fadeAlpha  -- Base opacity multiplied by fade
    local squashY = 0.75           -- Flatten vertically (collapsed look)
    local squashX = 1.0           -- Keep horizontal size natural

    -- Draw flattened shadow first
    love.graphics.setColor(0, 0, 0, alpha * 0.3)
    local shadowWidth = cadaver.size * 2.0 * squashX
    local shadowHeight = cadaver.size * 0.5
    love.graphics.ellipse("fill", cadaver.x, cadaver.y, shadowWidth, shadowHeight)

    -- Draw each pixel with static void texture (no animation)
    local radius = cadaver.size
    for _, p in ipairs(cadaver.pixels) do
        -- Use frozen boundary calculation
        local wobbleNoise = Procedural.fbm(
            p.angle * cfg.wobbleFrequency + t * cfg.wobbleSpeed,
            t * cfg.wobbleSpeed * 0.3,
            cadaver.seed + 500,
            2
        )
        local animatedEdgeRadius = radius * (0.7 + p.baseEdgeNoise * 0.5 + wobbleNoise * cfg.wobbleAmount * 0.3)

        -- Skip pixels outside the frozen boundary
        if p.dist >= animatedEdgeRadius then
            goto continue
        end

        -- Apply squash transform (flatten vertically, spread horizontally)
        local screenX = cadaver.x + p.relX * squashX - ps * squashX / 2
        local screenY = cadaver.y + p.relY * squashY - ps * squashY / 2
        local pixelW = ps * squashX
        local pixelH = ps * squashY

        -- Simplified color: darker, desaturated void remains
        local isEdge = p.dist > animatedEdgeRadius - ps * 1.5

        local r, g, b
        if isEdge then
            -- Faded edge glow
            r = colors.edgeGlow[1] * 0.5
            g = colors.edgeGlow[2] * 0.5
            b = colors.edgeGlow[3] * 0.5
        else
            -- Dark interior with subtle variation
            local blend = p.distNorm * 0.5 + p.rnd * 0.2
            r = colors.core[1] + (colors.mid[1] - colors.core[1]) * blend
            g = colors.core[2] + (colors.mid[2] - colors.core[2]) * blend
            b = colors.core[3] + (colors.mid[3] - colors.core[3]) * blend
        end

        love.graphics.setColor(r, g, b, alpha)
        love.graphics.rectangle("fill", screenX, screenY, pixelW, pixelH)

        ::continue::
    end
end

-- Find tower at screen position (used for hover detection and click handling)
local function _findTowerAt(screenX, screenY)
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

function Game.update(dt)
    -- Get mouse position in screen and game coordinates
    local screenMx, screenMy = love.mouse.getPosition()
    local mx, my = Settings.screenToGame(screenMx, screenMy)

    -- Update settings menu (uses screen coordinates)
    Settings.update(screenMx, screenMy)

    -- If settings menu or shortcuts overlay is open, pause game and show pointer cursor
    if Settings.isVisible() or Shortcuts.isVisible() then
        Cursor.setCursor(Cursor.POINTER)
        return
    end

    -- Cap delta time
    dt = math.min(dt, Config.MAX_DELTA_TIME)

    -- Apply time scale
    dt = dt * Game.getTimeScale()

    -- Update Void
    if state.void then
        state.void:update(dt)
    end

    -- Update Exit Portal
    if state.exitPortal then
        state.exitPortal:update(dt)
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
        tower:update(dt, state.creeps, state.projectiles, state.groundEffects, state.chainLightnings)
    end

    for i = #state.projectiles, 1, -1 do
        local proj = state.projectiles[i]
        proj:update(dt, state.creeps, state.groundEffects, state.chainLightnings)
        if proj.dead then
            table.remove(state.projectiles, i)
        end
    end

    -- Update ground effects (poison clouds, burning ground)
    for i = #state.groundEffects, 1, -1 do
        local effect = state.groundEffects[i]
        effect:update(dt, state.creeps)
        if effect.dead then
            table.remove(state.groundEffects, i)
        end
    end

    -- Update chain lightnings
    for i = #state.chainLightnings, 1, -1 do
        local chain = state.chainLightnings[i]
        chain:update(dt)
        if chain.dead then
            table.remove(state.chainLightnings, i)
        end
    end

    for i = #state.creeps, 1, -1 do
        local creep = state.creeps[i]
        creep:update(dt, Grid, state.flowField)

        -- Check if creep crossed the exit line (horizontal line through exit portal center)
        if not creep.dead and not creep:isExiting() and not creep:isSpawning() then
            if state.exitPortal and creep.y >= state.exitPortal.y then
                -- Start exit animation
                creep:startExitAnimation(state.exitPortal.x, state.exitPortal.y)
                state.exitPortal:registerExit(creep)
            end
        end

        -- Emit events when creep first starts dying (not after animation)
        if (creep.dying or creep.reachedBase) and not creep.deathEventSent then
            creep.deathEventSent = true
            if creep.reachedBase then
                EventBus.emit("creep_reached_base", { creep = creep })
            else
                EventBus.emit("creep_killed", {
                    creep = creep,
                    reward = creep.reward,
                    position = { x = creep.x, y = creep.y },
                })
            end
        end
        -- Create cadaver immediately when death animation completes
        if creep.dead and not creep.cadaverCreated and not creep.reachedBase then
            creep.cadaverCreated = true
            table.insert(state.cadavers, {
                x = creep.x,
                y = creep.y,
                size = creep.size,
                seed = creep.seed,
                time = creep.time,
                pixelSize = creep.pixelSize,
                pixels = creep.pixels,
                fadeTimer = 0,
            })
        end
        -- Remove creep when particles are done
        if creep:canRemove() then
            table.remove(state.creeps, i)
        end
    end

    -- Update cadavers (fade out and remove expired ones)
    local realDt = math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME)
    for i = #state.cadavers, 1, -1 do
        local cadaver = state.cadavers[i]
        cadaver.fadeTimer = cadaver.fadeTimer + realDt
        if cadaver.fadeTimer >= Config.CADAVER_FADE_DURATION then
            table.remove(state.cadavers, i)
        end
    end

    -- Update background animation (uses real dt for smooth effects regardless of game speed)
    Background.update(math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME))

    -- Update atmosphere (uses real dt for smooth particles regardless of game speed)
    Atmosphere.update(math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME))

    -- Update lighting (uses real dt for smooth animations)
    Lighting.update(math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME))

    -- Update audio (uses real dt for ambient timing)
    Audio.update(math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME))

    -- Update floating numbers (uses real dt for smooth animations)
    FloatingNumbers.update(math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME))

    -- Update UI
    Panel.update(mx, my)

    -- Update cursor based on hover state
    local isClickable = false

    -- Check if hovering over a panel button
    if Panel.isHoveringButton() then
        isClickable = true
    -- Check if hovering over tooltip button
    elseif Tooltip.isHoveringButton(mx, my) then
        isClickable = true
    -- Check if hovering over void
    elseif state.void and state.void:isPointInside(mx, my) then
        isClickable = true
    -- Check if hovering over a placed tower
    elseif _findTowerAt(mx, my) then
        isClickable = true
    end

    if isClickable then
        Cursor.setCursor(Cursor.POINTER)
    else
        Cursor.setCursor(Cursor.ARROW)
    end
end

function Game.draw()
    -- Get scaling info
    local scale = Settings.getScale()
    local offsetX, offsetY = Settings.getOffset()
    local windowW, windowH = Settings.getWindowDimensions()

    -- Fill letterbox areas with background color (if aspect ratio differs)
    if offsetX > 0 or offsetY > 0 then
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("fill", 0, 0, windowW, windowH)
    end

    -- Apply scaling transform for game content
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    -- Draw procedural background first
    Background.draw()

    -- Draw atmospheric fog/dust particles (behind game elements)
    Atmosphere.drawParticles()

    -- Get mouse position in game coordinates
    local screenMx, screenMy = love.mouse.getPosition()
    local mx, my = Settings.screenToGame(screenMx, screenMy)

    -- Determine if we should show grid overlay (only when a tower is selected for placement)
    local towerSelectedForPlacement = Panel.getSelectedTower() ~= nil
    local showGridOverlay = towerSelectedForPlacement and mx < Grid.getPlayAreaWidth()

    -- Draw game world (grid overlay only when placing towers)
    Grid.draw(showGridOverlay)

    -- Draw Void (behind towers and creeps)
    if state.void then
        state.void:draw()
        state.void:drawTears()  -- Draw spawn tears on top of void base
        state.void:drawSpawnParticles()  -- Draw spark particles
    end

    -- Draw Exit Portal (behind towers and creeps, at base zone)
    if state.exitPortal then
        state.exitPortal:draw()
    end

    -- Draw cadavers (dead creep remains on floor, behind everything else)
    for _, cadaver in ipairs(state.cadavers) do
        _drawCadaver(cadaver)
    end

    -- Draw ground effects (poison clouds, burning ground) behind towers and creeps
    for _, effect in ipairs(state.groundEffects) do
        effect:draw()
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

        -- Draw range circle for selected tower (transparent white)
        if t.range and t.range > 0 then
            love.graphics.setColor(1, 1, 1, Config.UI.rangePreview.fillAlpha)
            love.graphics.circle("fill", t.x, t.y, t.range)
            love.graphics.setColor(1, 1, 1, Config.UI.rangePreview.strokeAlpha)
            love.graphics.setLineWidth(Config.UI.rangePreview.strokeWidth)
            love.graphics.circle("line", t.x, t.y, t.range)
        end
    end

    for _, creep in ipairs(state.creeps) do
        creep:draw()
    end

    -- Draw Exit Portal particles and breach effects (on top of creeps)
    if state.exitPortal then
        state.exitPortal:drawExitParticles()
        state.exitPortal:drawBreachEffects()
    end

    for _, proj in ipairs(state.projectiles) do
        proj:draw()
    end

    -- Draw chain lightning effects on top
    for _, chain in ipairs(state.chainLightnings) do
        chain:draw()
    end

    -- Draw floating damage/gold numbers
    FloatingNumbers.draw()

    -- Draw tower placement preview (only if tower selected for placement and no placed tower selected)
    if towerSelectedForPlacement and mx < Grid.getPlayAreaWidth() and not state.selectedTower then
        local canAfford = Economy.canAfford(Panel.getSelectedTowerCost())
        local towerType = Panel.getSelectedTower()
        Grid.drawHover(mx, my, canAfford, towerType)
    end

    -- Pre-lighting glow pass: soft halos that survive the multiply pass
    if Settings.isLightingEnabled() then
        love.graphics.setBlendMode("add")

        -- Void glow halo
        if state.void then
            local voidColor = Config.LIGHTING.colors.void[state.void:getAngerLevel()] or Config.LIGHTING.colors.void[0]
            local pulse = math.sin(love.timer.getTime() * 2) * 0.1 + 0.9
            -- Outer soft halo
            love.graphics.setColor(voidColor[1] * 0.15, voidColor[2] * 0.1, voidColor[3] * 0.2, 0.25 * pulse)
            love.graphics.circle("fill", state.void.x, state.void.y, state.void.size * 2.5)
            -- Inner brighter halo
            love.graphics.setColor(voidColor[1] * 0.25, voidColor[2] * 0.15, voidColor[3] * 0.3, 0.3 * pulse)
            love.graphics.circle("fill", state.void.x, state.void.y, state.void.size * 1.5)
        end

        -- Creep glow halos
        local creepColor = Config.LIGHTING.colors.creep
        for _, creep in ipairs(state.creeps) do
            if not creep.dead and not creep:isSpawning() then
                local creepPulse = math.sin(love.timer.getTime() * 3.5 + creep.seed * 0.1) * 0.1 + 0.9
                -- Soft purple glow behind each creep
                love.graphics.setColor(creepColor[1] * 0.2, creepColor[2] * 0.1, creepColor[3] * 0.25, 0.35 * creepPulse)
                love.graphics.circle("fill", creep.x, creep.y, creep.size * 2.2)
            end
        end

        love.graphics.setBlendMode("alpha")
    end

    -- Apply lighting overlay (before vignette, after all game elements)
    Lighting.render(state.towers, state.creeps, state.projectiles, state.void, state.groundEffects, state.chainLightnings)
    Lighting.apply()

    -- Draw vignette overlay (atmospheric darkening at edges)
    Atmosphere.drawVignette()

    -- Draw lighting toggle indicator
    Lighting.drawIndicator()

    -- Draw UI (panel now contains all stats, void info, towers, upgrades)
    Panel.draw(Economy, state.void, Waves, Game.getSpeedLabel())
    -- HUD is no longer needed - stats are in panel

    -- Draw tooltip on top
    Tooltip.draw(Economy)

    -- Pop the scaling transform before drawing settings and cursor
    love.graphics.pop()

    -- Draw settings menu (modal, in screen space on top of everything except cursor)
    Settings.draw()

    -- Draw shortcuts overlay (modal, in game space)
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)
    Shortcuts.draw()
    love.graphics.pop()

    -- Draw custom cursor (always on top, in screen space)
    Cursor.draw()
end

-- Select/deselect a tower
local function _selectTower(tower)
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
local function _tryPlaceTower(gridX, gridY)
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

function Game.mousepressed(screenX, screenY, button)
    if button ~= 1 then return end

    -- Priority 0: Settings menu (if visible) - uses screen coordinates
    if Settings.isVisible() then
        Settings.handleClick(screenX, screenY)
        return
    end

    -- Convert to game coordinates for all other interactions
    local x, y = Settings.screenToGame(screenX, screenY)

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
        _selectTower(nil)
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
        _selectTower(nil)
        Game.clickVoid()
        return
    end

    -- Priority 4: Click on placed tower (select/deselect)
    local clickedTower = _findTowerAt(x, y)
    if clickedTower then
        -- Toggle selection
        if state.selectedTower == clickedTower then
            _selectTower(nil)
        else
            _selectTower(clickedTower)
        end
        return
    end

    -- Click on empty space deselects
    if state.selectedTower then
        _selectTower(nil)
        return
    end

    -- Priority 5: Place tower (only if one is selected) and start drag
    local towerType = Panel.getSelectedTower()
    if towerType then
        local gridX, gridY = Grid.screenToGrid(x, y)
        if _tryPlaceTower(gridX, gridY) then
            state.isDragging = true
            state.lastPlacedCell = { gridX = gridX, gridY = gridY }
        end
    end
end

function Game.mousemoved(screenX, screenY, dx, dy)
    -- Convert to game coordinates
    local x, y = Settings.screenToGame(screenX, screenY)

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
            if _tryPlaceTower(gridX, gridY) then
                state.lastPlacedCell = { gridX = gridX, gridY = gridY }
            else
                -- Update last cell even if placement failed (to avoid retrying)
                state.lastPlacedCell = { gridX = gridX, gridY = gridY }
            end
        end
    end
end

function Game.mousereleased(screenX, screenY, button)
    if button == 1 then
        -- Handle settings slider release (uses screen coordinates)
        if Settings.isVisible() then
            Settings.handleRelease(screenX, screenY)
        end

        state.isDragging = false
        state.lastPlacedCell = nil
    end
end

function Game.keypressed(key)
    -- Toggle shortcuts overlay with ~ (backtick) key
    if key == "`" then
        Shortcuts.toggle()
        return
    end

    -- Handle keys when shortcuts overlay is visible
    if Shortcuts.isVisible() then
        if key == "escape" then
            Shortcuts.hide()
        end
        return
    end

    -- Toggle settings menu with P key
    if key == "p" then
        Settings.toggle()
        return
    end

    -- Handle keys when settings menu is visible
    if Settings.isVisible() then
        if key == "escape" then
            Settings.hide()
        end
        return
    end

    -- Tower selection
    local towerKeys = {
        ["1"] = "wall",
        ["2"] = "void_orb",
        ["3"] = "void_ring",
        ["4"] = "void_bolt",
        ["5"] = "void_eye",
        ["6"] = "void_star",
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

    -- Lighting toggle
    if key == "l" then
        Lighting.toggle()
        Lighting.showIndicator()
        return
    end

    -- Floating numbers style cycle
    if key == "g" then
        local newStyle = FloatingNumbers.cycleStyle()
        print("Floating numbers style: " .. newStyle)
        return
    end

    -- Escape: Cancel tower placement, deselect tower, or quit
    if key == "escape" then
        -- First, cancel tower placement selection
        if Panel.getSelectedTower() then
            Panel.selectTower(nil)
        -- Then, deselect placed tower
        elseif state.selectedTower then
            _selectTower(nil)
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
