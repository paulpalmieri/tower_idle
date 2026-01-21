-- src/init.lua
-- Game initialization and main loop coordination

local Config = require("src.config")
local ConfigValidator = require("src.core.config_validator")
local EventBus = require("src.core.event_bus")
local StateMachine = require("src.core.state_machine")
local Camera = require("src.core.camera")

-- Systems
local Grid = require("src.world.grid")
local Economy = require("src.systems.economy")
local Waves = require("src.systems.waves")
local Combat = require("src.systems.combat")
local Pathfinding = require("src.systems.pathfinding")
local Audio = require("src.systems.audio")
local Profiler = require("src.systems.profiler")

-- Rendering
local Fonts = require("src.rendering.fonts")
local Background = require("src.rendering.background")
local Atmosphere = require("src.rendering.atmosphere")
local PostProcessing = require("src.rendering.post_processing")
local Bloom = require("src.rendering.bloom")
local FloatingNumbers = require("src.rendering.floating_numbers")
local TurretConcepts = require("src.rendering.turret_concepts")
local SkillTreeBackground = require("src.rendering.skill_tree_background")

-- Entities
local Tower = require("src.entities.tower")
local Void = require("src.entities.void")
local Creep = require("src.entities.creep")
local ExitPortal = require("src.entities.exit_portal")

-- New projectile/effect entities
local LobbedProjectile = require("src.entities.lobbed_projectile")
local Blackhole = require("src.entities.blackhole")
local LightningProjectile = require("src.entities.lightning_projectile")

-- UI
local HUD = require("src.ui.hud")
local Tooltip = require("src.ui.tooltip")
local Cursor = require("src.ui.cursor")
local Settings = require("src.ui.settings")
local Shortcuts = require("src.ui.shortcuts")
local SkillTree = require("src.ui.skill_tree")
local VictoryScreen = require("src.ui.victory_screen")
local PauseMenu = require("src.ui.pause_menu")

-- Systems (skill tree)
local SkillTreeData = require("src.systems.skill_tree_data")

local Game = {}

-- Game state (private)
local state = {
    towers = {},
    creeps = {},
    projectiles = {},
    cadavers = {},         -- Dead creep remains on the floor
    groundEffects = {},    -- Poison clouds, burning ground, etc.
    chainLightnings = {},  -- Chain lightning visual effects
    -- New collections for redesigned towers
    lobbedProjectiles = {},    -- Parabolic arc bombs (void_star)
    blackholes = {},           -- Pull-effect fields (void_eye)
    lightningProjectiles = {}, -- Piercing bolts (void_ring)
    explosionBursts = {},      -- Explosion burst particles
    flowField = nil,
    gameSpeedIndex = 1,
    selectedTower = nil,   -- Reference to selected placed tower
    hoveredTower = nil,    -- Reference to tower under mouse cursor
    isDragging = false,    -- Drag-to-place active
    lastPlacedCell = nil,  -- {gridX, gridY} to avoid double-placing
    void = nil,            -- The Void entity
    exitPortal = nil,      -- The Exit Portal entity (at base)
    autoClickTimer = 0,    -- Timer for auto-clicker
    -- Tower Y-sorting cache (optimization: towers don't move)
    towersSortedByY = {},  -- Cached sorted tower list
    towersSortDirty = true,  -- Flag to rebuild cache when towers change
    -- Debug display
    showDebug = false,  -- Toggle with D key
    debugPath = nil,    -- Cached path for debug visualization
}

function Game.load()
    -- Validate config before anything else
    ConfigValidator.validateOrDie(Config)

    -- Set up graphics
    love.graphics.setBackgroundColor(Config.COLORS.background)
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Initialize core systems
    EventBus.init()

    -- Initialize fonts (must be before UI)
    Fonts.init()

    -- Initialize settings early (calculates dynamic screen dimensions)
    Settings.init()

    -- Get fixed game dimensions (1280x720 canvas)
    local gameWidth, gameHeight = Settings.getGameDimensions()

    -- Initialize game systems with fixed dimensions
    Grid.init(gameWidth, gameHeight)
    Economy.init()
    Waves.init()
    Combat.init()

    -- Initialize camera with world dimensions and full canvas viewport
    local worldW, worldH = Grid.getWorldDimensions()
    Camera.init(worldW, worldH, gameWidth, gameHeight)

    -- Generate procedural background (uses world dimensions internally)
    Background.generate(gameWidth, gameHeight)

    -- Compute initial pathfinding
    state.flowField = Pathfinding.computeFlowField(Grid)
    -- Debug path is computed lazily when debug mode is enabled

    -- Create Void entity (positioned at center of spawn area)
    local voidX, voidY = Grid.getPortalCenter()
    state.void = Void(voidX, voidY)

    -- Center camera on the void portal at game start
    Camera.centerOn(voidX, voidY)

    -- Create Exit Portal entity (positioned at center of base zone)
    local exitX, exitY = Grid.getExitPortalCenter()
    state.exitPortal = ExitPortal(exitX, exitY)

    -- Initialize UI (minimalistic HUD with bottom bar and top-right info)
    HUD.init(gameWidth, gameHeight)

    -- Initialize custom cursor
    Cursor.init()

    -- Initialize atmosphere effects
    Atmosphere.init()

    -- Initialize post-processing and bloom
    PostProcessing.init()

    -- Initialize audio system
    Audio.init()

    -- Initialize shortcuts overlay
    Shortcuts.init()

    -- Initialize pause menu
    PauseMenu.init()

    -- Initialize skill tree
    SkillTreeData.init()
    SkillTree.init()

    -- Initialize victory screen
    VictoryScreen.init()

    -- Initialize floating numbers system
    FloatingNumbers.init()

    -- Initialize profiler
    Profiler.init()

    -- Set up event listeners
    Game.setupEvents()

    -- Start game
    StateMachine.transition("playing")
end

-- Recompute debug path when flow field changes (only if debug mode is enabled)
local function _recomputeDebugPath()
    if state.showDebug then
        local centerCol = math.ceil(Grid.getCols() / 2)
        state.debugPath = Pathfinding.findPathToBase(Grid, centerCol, 1)
    end
end

-- Spawn test towers for debugging: one row per tower type, levels 1-5
function Game.spawnTestTowers()
    local towerTypes = {"void_orb", "void_ring", "void_bolt", "void_eye", "void_star"}

    for row, towerType in ipairs(towerTypes) do
        for level = 1, 5 do
            local gridX = level  -- Columns 1-5
            local gridY = row    -- Rows 1-6

            -- Check if cell is valid and can place
            if Grid.isValidCell(gridX, gridY) and Pathfinding.canPlaceTowerAt(Grid, gridX, gridY) then
                local screenX, screenY = Grid.gridToScreen(gridX, gridY)
                local tower = Tower(screenX, screenY, towerType, gridX, gridY)

                -- Skip build animation for test towers
                tower.attackState = Tower.STATE_IDLE
                tower.buildProgress = 1
                tower.buildTimer = 0

                -- Upgrade tower to target level
                for _ = 2, level do
                    tower:upgrade()
                end

                -- Place in grid and add to towers list
                if Grid.placeTower(gridX, gridY, tower) then
                    table.insert(state.towers, tower)
                    state.towersSortDirty = true
                end
            end
        end
    end

    -- Recompute pathfinding after placing all towers
    state.flowField = Pathfinding.computeFlowField(Grid)
    _recomputeDebugPath()
end

function Game.setupEvents()
    EventBus.on("tower_placed", function(data)
        -- Recompute pathfinding when towers change
        state.flowField = Pathfinding.computeFlowField(Grid)
        _recomputeDebugPath()
        -- Track stats for recap screen
        Economy.recordTowerBuilt()
    end)

    EventBus.on("creep_killed", function(data)
        Economy.addGold(data.reward)
        -- Track stats for recap screen
        Economy.recordKill()
        Economy.recordGoldEarned(data.reward)
        -- Track kill to the tower that dealt the final blow
        local creep = data.creep
        if creep and creep.killedBy and not creep.killedBy.dead then
            creep.killedBy:recordKill()
        end
        -- Award bonus shards for boss kills
        if creep and creep.isBoss then
            Economy.addVoidShards(Config.VOID_SHARDS.bossBonus)

            -- Award void crystals for boss kills based on current wave
            local currentWave = Waves.getWaveNumber()
            local crystalReward = Config.VOID_CRYSTALS.bossRewards[currentWave]
            if crystalReward and crystalReward > 0 then
                Economy.addVoidCrystals(crystalReward)
                EventBus.emit("void_crystal_dropped", {
                    amount = crystalReward,
                    position = data.position,
                })
            end
        end
        -- 10% chance to drop a void shard on any kill
        if math.random() < Config.VOID_SHARDS.dropChance then
            local shardAmount = Config.VOID_SHARDS.dropAmount
            Economy.addVoidShards(shardAmount)
            EventBus.emit("void_shard_dropped", {
                amount = shardAmount,
                position = data.position,
            })
        end
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
        -- Track stats for recap screen
        Economy.recordGoldEarned(data.income)

        -- Spawn one enemy immediately
        Game.spawnImmediateEnemy()

        -- Update waves system with current tier
        Waves.setTier(data.tier)
    end)

    EventBus.on("spawn_red_bosses", function(data)
        Waves.spawnRedBosses(data.count)
    end)

    EventBus.on("window_resized", function(data)
        -- Reinitialize Grid with fixed canvas dimensions
        Grid.init(data.gameWidth, data.gameHeight)

        -- Preserve camera position during resize
        local camX, camY = Camera.getPosition()
        local worldW, worldH = Grid.getWorldDimensions()
        Camera.init(worldW, worldH, data.gameWidth, data.gameHeight)
        Camera.centerOn(camX, camY)  -- Restore position (will be clamped to valid bounds)

        -- Reinitialize UI HUD
        HUD.init(data.gameWidth, data.gameHeight)

        -- Recreate canvases for background and post-processing
        Background.regenerate(data.gameWidth, data.gameHeight)
        PostProcessing.resize()

        -- Clear turret base canvas cache (canvas contents can be invalidated on window mode change)
        TurretConcepts.clearCache()

        -- Regenerate skill tree background if visible
        if SkillTree.isVisible() then
            SkillTreeBackground.generate()
        end
    end)

    -- New tower attack spawn events
    EventBus.on("spawn_lobbed_projectile", function(data)
        local proj = LobbedProjectile(
            data.startX, data.startY,
            data.targetX, data.targetY,
            data.damage, data.sourceTower
        )
        table.insert(state.lobbedProjectiles, proj)
    end)

    EventBus.on("spawn_blackhole", function(data)
        local hole = Blackhole(data.x, data.y, data.sourceTower)
        table.insert(state.blackholes, hole)
    end)

    EventBus.on("spawn_lightning_bolt", function(data)
        local bolt = LightningProjectile(
            data.x, data.y, data.angle,
            data.damage, data.sourceTower
        )
        table.insert(state.lightningProjectiles, bolt)
    end)

    EventBus.on("spawn_test_towers", function(data)
        Game.spawnTestTowers()
    end)

    EventBus.on("game_won", function(data)
        -- Award level completion shards
        Economy.addVoidShards(data.shardReward)
        -- Show victory recap screen
        VictoryScreen.show()
    end)

    EventBus.on("game_over", function(data)
        -- Show defeat recap screen
        VictoryScreen.showDefeat()
    end)

    EventBus.on("skill_tree_changed", function(data)
        -- Recalculate stats for all towers when skill tree changes
        for _, tower in ipairs(state.towers) do
            tower:recalculateStats()
        end
    end)

    EventBus.on("wave_started", function(data)
        -- Track wave reached for recap screen
        Economy.setWaveReached(data.waveNumber)
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

    -- Spawn from random column on spawn row (same as wave spawns)
    local cols = Grid.getCols()
    local spawnCol = math.random(1, cols)
    local x, y = Grid.getSpawnPosition(spawnCol)
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
-- Pre-compute cadaver visible pixels when created (OPTIMIZATION)
-- Called once when cadaver is created, stores only visible pixels with pre-computed colors
local function _prepareCadaverPixels(cadaver)
    local cfg = Config.VOID_SPAWN
    local colors = cfg.colors
    local ps = cadaver.pixelSize
    local t = cadaver.time
    local radius = cadaver.size

    cadaver.visiblePixels = {}

    for _, p in ipairs(cadaver.pixels) do
        -- Use pre-computed wobblePhase if available, otherwise calculate once
        local wobbleNoise
        if p.wobblePhase then
            wobbleNoise = math.sin(t * cfg.wobbleSpeed + p.wobblePhase) * 0.5 + 0.5
        else
            wobbleNoise = math.sin(p.angle * cfg.wobbleFrequency + t * cfg.wobbleSpeed) * 0.5 + 0.5
        end
        local animatedEdgeRadius = radius * (0.7 + p.baseEdgeNoise * 0.5 + wobbleNoise * cfg.wobbleAmount * 0.3)

        -- Skip pixels outside the frozen boundary
        if p.dist >= animatedEdgeRadius then
            goto continue
        end

        -- Pre-compute color
        local isEdge = p.dist > animatedEdgeRadius - ps * 1.5
        local r, g, b
        if isEdge then
            r = colors.edgeGlow[1] * 0.5
            g = colors.edgeGlow[2] * 0.5
            b = colors.edgeGlow[3] * 0.5
        else
            local blend = p.distNorm * 0.5 + p.rnd * 0.2
            r = colors.core[1] + (colors.mid[1] - colors.core[1]) * blend
            g = colors.core[2] + (colors.mid[2] - colors.core[2]) * blend
            b = colors.core[3] + (colors.mid[3] - colors.core[3]) * blend
        end

        table.insert(cadaver.visiblePixels, {
            relX = p.relX,
            relY = p.relY,
            r = r, g = g, b = b,
        })

        ::continue::
    end

    -- Clear original pixels to save memory
    cadaver.pixels = nil
end

local function _drawCadaver(cadaver)
    local ps = cadaver.pixelSize

    -- Calculate fade progress (0 = fresh, 1 = fully faded)
    local fadeProgress = cadaver.fadeTimer / Config.CADAVER_FADE_DURATION
    local fadeAlpha = 1.0 - fadeProgress

    -- Skip drawing if nearly invisible
    if fadeAlpha < 0.01 then return end

    -- Pre-compute visible pixels on first draw
    if not cadaver.visiblePixels then
        _prepareCadaverPixels(cadaver)
    end

    -- Cadaver settings
    local alpha = 0.35 * fadeAlpha
    local squashY = 0.75
    local squashX = 1.0

    -- Draw flattened shadow first
    love.graphics.setColor(0, 0, 0, alpha * 0.3)
    local shadowWidth = cadaver.size * 2.0 * squashX
    local shadowHeight = cadaver.size * 0.5
    love.graphics.ellipse("fill", cadaver.x, cadaver.y, shadowWidth, shadowHeight)

    -- Draw pre-computed visible pixels (no per-pixel calculations)
    local pixelW = ps * squashX
    local pixelH = ps * squashY
    for _, vp in ipairs(cadaver.visiblePixels) do
        local screenX = cadaver.x + vp.relX * squashX - ps * squashX / 2
        local screenY = cadaver.y + vp.relY * squashY - ps * squashY / 2
        love.graphics.setColor(vp.r, vp.g, vp.b, alpha)
        love.graphics.rectangle("fill", screenX, screenY, pixelW, pixelH)
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
    -- Get mouse position in screen coordinates and game coordinates (scaled for window)
    local screenMx, screenMy = love.mouse.getPosition()
    local gameMx, gameMy = Settings.screenToGame(screenMx, screenMy)

    -- Convert game coordinates to world coordinates through camera
    -- mx, my are world coordinates (where entities live)
    local mx, my = Camera.screenToWorld(gameMx, gameMy)

    -- Update settings menu (uses screen coordinates)
    Settings.update(screenMx, screenMy)

    -- If settings menu, shortcuts overlay, skill tree, victory screen, or pause menu is open, pause game and show pointer cursor
    if Settings.isVisible() or Shortcuts.isVisible() or SkillTree.isVisible() or VictoryScreen.isVisible() or PauseMenu.isVisible() then
        -- Update skill tree hover state
        if SkillTree.isVisible() then
            SkillTree.update(gameMx, gameMy)
        end
        -- Update victory screen hover state
        if VictoryScreen.isVisible() then
            VictoryScreen.update(gameMx, gameMy)
        end
        -- Update pause menu hover state
        if PauseMenu.isVisible() then
            PauseMenu.update(gameMx, gameMy)
        end
        Cursor.setCursor(Cursor.POINTER)
        return
    end

    -- Update camera (zoom interpolation)
    local realDtForCamera = math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME)
    Camera.update(realDtForCamera)

    -- Cap delta time
    dt = math.min(dt, Config.MAX_DELTA_TIME)

    -- Track time played (using real dt, not scaled)
    Economy.updateTimePlayed(dt)

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
    local autoClickInterval = HUD.getAutoClickInterval()
    if autoClickInterval then
        state.autoClickTimer = state.autoClickTimer + dt
        if state.autoClickTimer >= autoClickInterval then
            state.autoClickTimer = state.autoClickTimer - autoClickInterval
            Game.clickVoid()
        end
    end

    -- Update systems
    Profiler.start("waves_update")
    Waves.update(dt, state.creeps)
    Profiler.stop("waves_update")

    -- Rebuild spatial hash once per frame for efficient range queries
    Profiler.start("spatial_hash_rebuild")
    Combat.rebuildSpatialHash(state.creeps)
    Profiler.stop("spatial_hash_rebuild")

    -- Update entities
    Profiler.start("towers_update")
    for _, tower in ipairs(state.towers) do
        tower:update(dt, state.creeps, state.projectiles, state.groundEffects, state.chainLightnings)
    end
    Profiler.stop("towers_update")

    Profiler.start("projectiles_update")
    for i = #state.projectiles, 1, -1 do
        local proj = state.projectiles[i]
        proj:update(dt, state.creeps, state.groundEffects, state.chainLightnings)
        if proj.dead then
            table.remove(state.projectiles, i)
        end
    end
    Profiler.stop("projectiles_update")

    -- Update ground effects (poison clouds, burning ground)
    Profiler.start("ground_effects_update")
    for i = #state.groundEffects, 1, -1 do
        local effect = state.groundEffects[i]
        effect:update(dt, state.creeps)
        if effect.dead then
            table.remove(state.groundEffects, i)
        end
    end
    Profiler.stop("ground_effects_update")

    -- Update chain lightnings
    for i = #state.chainLightnings, 1, -1 do
        local chain = state.chainLightnings[i]
        chain:update(dt)
        if chain.dead then
            table.remove(state.chainLightnings, i)
        end
    end

    -- Update blackholes (before creeps - affects their movement)
    for i = #state.blackholes, 1, -1 do
        local hole = state.blackholes[i]
        hole:update(dt, state.creeps)
        if hole.dead then
            table.remove(state.blackholes, i)
        end
    end

    -- Update lobbed projectiles
    for i = #state.lobbedProjectiles, 1, -1 do
        local proj = state.lobbedProjectiles[i]
        proj:update(dt, state.creeps, state.groundEffects, state.explosionBursts)
        if proj.dead then
            table.remove(state.lobbedProjectiles, i)
        end
    end

    -- Update lightning projectiles
    for i = #state.lightningProjectiles, 1, -1 do
        local proj = state.lightningProjectiles[i]
        proj:update(dt, state.creeps)
        if proj.dead then
            table.remove(state.lightningProjectiles, i)
        end
    end

    -- Update explosion bursts
    for i = #state.explosionBursts, 1, -1 do
        local burst = state.explosionBursts[i]
        burst.time = burst.time + dt

        -- Update particles
        for _, p in ipairs(burst.particles) do
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.life = p.life - dt
            -- Gravity
            p.vy = p.vy + 200 * dt
        end

        if burst.time >= burst.duration then
            table.remove(state.explosionBursts, i)
        end
    end

    Profiler.start("creeps_update")
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
            -- Spiders use bodyPixels, standard creeps use pixels
            local pixelData = creep.pixels or creep.bodyPixels
            table.insert(state.cadavers, {
                x = creep.x,
                y = creep.y,
                size = creep.size,
                seed = creep.seed,
                time = creep.time,
                pixelSize = creep.pixelSize,
                pixels = pixelData,
                fadeTimer = 0,
            })
        end
        -- Remove creep when particles are done
        if creep:canRemove() then
            table.remove(state.creeps, i)
        end
    end
    Profiler.stop("creeps_update")

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

    -- Update post-processing (uses real dt for smooth animations)
    PostProcessing.update(math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME))

    -- Update audio (uses real dt for ambient timing)
    Audio.update(math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME))

    -- Update floating numbers (uses real dt for smooth animations)
    FloatingNumbers.update(math.min(love.timer.getDelta(), Config.MAX_DELTA_TIME))

    -- Update UI (HUD uses game/screen coordinates, not world)
    HUD.update(gameMx, gameMy)

    -- Track hovered tower (only when not placing a tower)
    -- Tower positions are in world coordinates, so use mx, my
    local towerSelectedForPlacement = HUD.getSelectedTower() ~= nil

    -- Clear previous hover state
    if state.hoveredTower then
        state.hoveredTower.isHovered = false
    end

    -- Check if mouse is in play area (not over HUD elements)
    local isOverHUD = HUD.isPointInHUD(gameMx, gameMy)
    if not towerSelectedForPlacement and not isOverHUD then
        state.hoveredTower = _findTowerAt(mx, my)
    else
        state.hoveredTower = nil
    end

    -- Set new hover state
    if state.hoveredTower then
        state.hoveredTower.isHovered = true
    end

    -- Update cursor based on hover state
    local isClickable = false

    -- Check if hovering over a HUD button
    if HUD.isHoveringButton() then
        isClickable = true
    -- Check if hovering over tooltip button (uses game coords for tooltip position)
    elseif Tooltip.isHoveringButton(gameMx, gameMy) then
        isClickable = true
    -- Check if hovering over void (world coords)
    elseif state.void and state.void:isPointInside(mx, my) then
        isClickable = true
        state.void:setHovered(true)
    -- Check if hovering over a placed tower
    elseif state.hoveredTower then
        isClickable = true
    end

    -- Clear void hover state when not hovering
    if state.void and not state.void:isPointInside(mx, my) then
        state.void:setHovered(false)
    end

    -- Update cursor based on state
    if Camera.isDragging() then
        -- Actively dragging the camera
        Cursor.setCursor(Cursor.GRABBING)
    elseif isClickable then
        -- Hovering over clickable element
        Cursor.setCursor(Cursor.POINTER)
    elseif not isOverHUD and not towerSelectedForPlacement then
        -- In play area with no tower selected - ready to drag
        Cursor.setCursor(Cursor.GRAB)
    else
        -- Default cursor
        Cursor.setCursor(Cursor.ARROW)
    end

    -- End frame for profiler (report timing data)
    Profiler.endFrame(love.timer.getDelta())
end

function Game.draw()
    -- Get scaling info
    local scale = Settings.getScale()
    local offsetX, offsetY = Settings.getOffset()
    local windowW, windowH = Settings.getWindowDimensions()

    -- Fill letterbox/pillarbox areas with BLACK (for non-16:9 screens)
    if offsetX > 0 or offsetY > 0 then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, windowW, windowH)
    end

    -- Begin post-processing pipeline (render to scene canvas at base resolution)
    -- This must happen BEFORE applying transform so scene renders at 1:1
    PostProcessing.beginFrame()

    -- Apply camera transform for world rendering
    -- Everything drawn from here until we pop is in world coordinates
    Camera.push()

    -- Draw procedural background first (in world space)
    Profiler.start("background_draw")
    Background.draw()
    Profiler.stop("background_draw")

    -- Draw atmospheric fog/dust particles (behind game elements, in world space)
    Profiler.start("atmosphere_draw")
    Atmosphere.drawParticles()
    Profiler.stop("atmosphere_draw")

    -- Get mouse position in game and world coordinates
    local screenMx, screenMy = love.mouse.getPosition()
    local gameMx, gameMy = Settings.screenToGame(screenMx, screenMy)
    local mx, my = Camera.screenToWorld(gameMx, gameMy)

    -- Determine if we should show grid overlay (only when a tower is selected for placement)
    local towerSelectedForPlacement = HUD.getSelectedTower() ~= nil
    local isOverHUDDraw = HUD.isPointInHUD(gameMx, gameMy)
    local showGridOverlay = towerSelectedForPlacement and not isOverHUDDraw

    -- Draw game world (grid overlay only when placing towers)
    Grid.draw(showGridOverlay)

    -- Draw Void (behind towers and creeps)
    Profiler.start("void_draw")
    if state.void then
        state.void:drawSpewParticles()  -- Draw outward spewing particles (behind portal)
        state.void:draw()
        state.void:drawTears()  -- Draw spawn tears on top of void base
        state.void:drawSpawnParticles()  -- Draw spark particles
    end
    Profiler.stop("void_draw")

    -- Draw Exit Portal (behind towers and creeps, at base zone)
    if state.exitPortal then
        state.exitPortal:draw()
    end

    -- Draw cadavers (dead creep remains on floor, behind everything else)
    Profiler.start("cadavers_draw")
    for _, cadaver in ipairs(state.cadavers) do
        _drawCadaver(cadaver)
    end
    Profiler.stop("cadavers_draw")

    -- Draw range ellipse for selected tower FIRST (behind everything)
    if state.selectedTower then
        local t = state.selectedTower
        if t.range and t.range > 0 then
            love.graphics.setColor(1, 1, 1, 0.05)
            love.graphics.ellipse("fill", t.x, t.y, t.range, t.range * 0.9)
        end
    end

    -- Draw all game entities sorted by Y for proper depth layering
    -- Entities with lower Y (further back) are drawn first, higher Y (closer) drawn on top
    -- Includes: ground effects, blackholes, towers, and creeps
    Profiler.start("entities_draw")

    -- Update tower Y-sort cache if needed (towers don't move, so cache is stable)
    if state.towersSortDirty then
        state.towersSortedByY = {}
        for _, tower in ipairs(state.towers) do
            table.insert(state.towersSortedByY, tower)
        end
        table.sort(state.towersSortedByY, function(a, b) return a.y < b.y end)
        state.towersSortDirty = false
    end

    -- Draw all tower shadows first (behind everything)
    for _, tower in ipairs(state.towersSortedByY) do
        tower:drawShadow()
    end

    -- Draw ground effects (poison clouds, burning ground) - flat on ground, always under entities
    for _, effect in ipairs(state.groundEffects) do
        effect:draw()
    end

    local sortedEntities = {}

    -- Add blackholes
    for _, hole in ipairs(state.blackholes) do
        table.insert(sortedEntities, { entity = hole, y = hole.y, type = "blackhole" })
    end

    -- Add pre-sorted towers
    for _, tower in ipairs(state.towersSortedByY) do
        table.insert(sortedEntities, { entity = tower, y = tower.y, type = "tower" })
    end

    -- Add creeps
    for _, creep in ipairs(state.creeps) do
        table.insert(sortedEntities, { entity = creep, y = creep.y, type = "creep" })
    end

    table.sort(sortedEntities, function(a, b) return a.y < b.y end)

    for _, item in ipairs(sortedEntities) do
        item.entity:draw()
    end
    Profiler.stop("entities_draw")

    -- Draw Exit Portal particles and breach effects (on top of creeps)
    if state.exitPortal then
        state.exitPortal:drawExitParticles()
        state.exitPortal:drawBreachEffects()
    end

    for _, proj in ipairs(state.projectiles) do
        proj:draw()
    end

    -- Draw lobbed projectiles (arc high above)
    for _, proj in ipairs(state.lobbedProjectiles) do
        proj:draw()
    end

    -- Draw lightning projectiles
    for _, proj in ipairs(state.lightningProjectiles) do
        proj:draw()
    end

    -- Draw explosion bursts
    for _, burst in ipairs(state.explosionBursts) do
        local colors = Config.GROUND_EFFECTS.burning_ground.colors
        for _, p in ipairs(burst.particles) do
            if p.life > 0 then
                local alpha = p.life / p.maxLife
                -- Glow
                love.graphics.setColor(colors.edge[1], colors.edge[2] * 0.7, colors.edge[3] * 0.3, alpha * 0.5)
                love.graphics.circle("fill", p.x, p.y, p.size * 2)
                -- Core
                love.graphics.setColor(p.r, p.g, p.b, alpha)
                love.graphics.rectangle("fill", p.x - p.size/2, p.y - p.size/2, p.size, p.size)
            end
        end
    end

    -- Draw chain lightning effects on top
    for _, chain in ipairs(state.chainLightnings) do
        chain:draw()
    end

    -- Draw floating damage/gold numbers
    FloatingNumbers.draw()

    -- Draw tower placement preview (only if tower selected for placement and no placed tower selected)
    -- Check if mouse is not over HUD, but use mx (world coords) for actual positioning
    if towerSelectedForPlacement and not isOverHUDDraw and not state.selectedTower then
        local canAfford = Economy.canAfford(HUD.getSelectedTowerCost())
        local towerType = HUD.getSelectedTower()
        Grid.drawHover(mx, my, canAfford, towerType)
    end

    -- Draw pathfinding debug overlay (in world space)
    if state.showDebug then
        Grid.drawDebug(state.flowField)
        Grid.drawGhostPath(state.debugPath)
    end

    -- Pop camera transform before ending scene rendering
    Camera.pop()

    -- End scene rendering (stop drawing to scene canvas)
    PostProcessing.endFrame()

    -- Render bloom effect (extract glow sources and blur)
    Profiler.start("bloom_render")
    PostProcessing.renderBloom(
        state.void,
        state.creeps,
        state.towers,
        state.projectiles,
        state.groundEffects,
        state.lobbedProjectiles,
        state.lightningProjectiles,
        state.blackholes
    )
    Profiler.stop("bloom_render")

    -- Apply scaling transform for drawing to screen
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)

    -- Draw final composited result (scene + bloom)
    PostProcessing.drawResult()

    -- Draw vignette overlay (atmospheric darkening at edges)
    Atmosphere.drawVignette()

    -- Draw UI (minimalistic HUD with bottom bar and top-right info)
    Profiler.start("hud_draw")
    HUD.draw(Economy, state.void, Waves, Game.getSpeedLabel())
    Profiler.stop("hud_draw")

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

    -- Draw skill tree overlay (modal, in game space)
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)
    SkillTree.draw()
    love.graphics.pop()

    -- Draw victory screen overlay (modal, in game space)
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)
    VictoryScreen.draw()
    love.graphics.pop()

    -- Draw pause menu overlay (modal, in game space)
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)
    PauseMenu.draw()
    love.graphics.pop()

    -- Draw debug overlay (top left, screen space)
    if state.showDebug then
        local fps = love.timer.getFPS()
        local stats = love.graphics.getStats()
        local memKB = collectgarbage("count")

        -- Count entities
        local creepCount = #state.creeps
        local towerCount = #state.towers
        local projCount = #state.projectiles + #state.lobbedProjectiles + #state.lightningProjectiles
        local effectCount = #state.groundEffects + #state.blackholes + #state.chainLightnings + #state.explosionBursts
        local cadaverCount = #state.cadavers

        -- Build stats text
        local lines = {
            string.format("FPS: %d", fps),
            string.format("Draw: %d", stats.drawcalls),
            string.format("Mem: %.1fMB", memKB / 1024),
            string.format("Creeps: %d", creepCount),
            string.format("Towers: %d", towerCount),
            string.format("Proj: %d", projCount),
            string.format("Effects: %d", effectCount),
            string.format("Cadavers: %d", cadaverCount),
        }

        love.graphics.setFont(Fonts.get("small"))
        local lineHeight = 12
        local panelWidth = 76
        local panelHeight = #lines * lineHeight + 8

        -- Background
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 4, 4, panelWidth, panelHeight)

        -- Text
        love.graphics.setColor(1, 1, 1, 0.9)
        for i, line in ipairs(lines) do
            love.graphics.print(line, 8, 4 + (i - 1) * lineHeight + 2)
        end

        -- Draw bloom debug minimap next to stats
        Bloom.drawDebug(panelWidth + 12, 4)
    end

    -- Draw custom cursor (always on top, in screen space)
    Cursor.draw()
end

-- Select/deselect a tower
local function _selectTower(tower)
    -- Clear previous selection state
    if state.selectedTower then
        state.selectedTower.isSelected = false
    end

    if tower then
        state.selectedTower = tower
        tower.isSelected = true
        Tooltip.show(tower)
        EventBus.emit("tower_selected", { tower = tower })
    else
        state.selectedTower = nil
        Tooltip.hide()
        EventBus.emit("tower_selection_cleared", {})
    end
end

-- Sell a tower and refund gold
local function _sellTower(tower)
    if not tower then return end

    local refund = tower:getSellValue()

    -- Clear selection first
    _selectTower(nil)

    -- Clear hovered state if this was the hovered tower
    if state.hoveredTower == tower then
        state.hoveredTower = nil
    end

    -- Remove tower from grid
    Grid.clearCell(tower.gridX, tower.gridY)

    -- Remove tower from towers list
    for i = #state.towers, 1, -1 do
        if state.towers[i] == tower then
            table.remove(state.towers, i)
            state.towersSortDirty = true
            break
        end
    end

    -- Mark tower as dead
    tower.dead = true

    -- Refund gold
    Economy.addGold(refund)

    -- Recompute pathfinding
    state.flowField = Pathfinding.computeFlowField(Grid)
    _recomputeDebugPath()

    -- Emit event
    EventBus.emit("tower_sold", { tower = tower, refund = refund })
end

-- Attempt to place a tower at grid position
local function _tryPlaceTower(gridX, gridY)
    local towerType = HUD.getSelectedTower()
    local cost = Config.TOWERS[towerType].cost

    if Economy.canAfford(cost) and Pathfinding.canPlaceTowerAt(Grid, gridX, gridY) then
        local screenX, screenY = Grid.gridToScreen(gridX, gridY)
        local tower = Tower(screenX, screenY, towerType, gridX, gridY)

        if Grid.placeTower(gridX, gridY, tower) then
            table.insert(state.towers, tower)
            state.towersSortDirty = true
            Economy.spendGold(cost)
            EventBus.emit("tower_placed", { tower = tower, gridX = gridX, gridY = gridY })
            return true
        end
    end
    return false
end

function Game.mousepressed(screenX, screenY, button)
    -- Priority 0: Settings menu (if visible) - uses screen coordinates
    if Settings.isVisible() then
        if button == 1 then
            Settings.handleClick(screenX, screenY)
        end
        return
    end

    -- Convert to game coordinates (scaled for window) and world coordinates (with camera offset)
    local gameX, gameY = Settings.screenToGame(screenX, screenY)
    local worldX, worldY = Camera.screenToWorld(gameX, gameY)

    -- Priority 0.25: Pause menu (if visible) - uses game coordinates
    if PauseMenu.isVisible() then
        if button == 1 then
            local result = PauseMenu.handleClick(gameX, gameY)
            if result then
                if result.action == "resume" then
                    PauseMenu.hide()
                elseif result.action == "abandon" then
                    PauseMenu.hide()
                    VictoryScreen.showDefeat()
                end
            end
        end
        return
    end

    -- Priority 0.5: Victory screen (if visible) - uses game coordinates
    if VictoryScreen.isVisible() then
        if button == 1 then
            local result = VictoryScreen.handleClick(gameX, gameY)
            if result then
                if result.action == "restart" then
                    Game.restart()
                elseif result.action == "skill_tree" then
                    VictoryScreen.hide()
                    SkillTree.activate()
                end
            end
        end
        return
    end

    -- Priority 0.6: Skill tree scene (if active) - uses game coordinates
    if SkillTree.isActive() then
        local result = SkillTree.handleClick(gameX, gameY, button)
        if type(result) == "table" and result.action then
            if result.action == "start_run" then
                SkillTree.deactivate()
                Game.restart()
            elseif result.action == "back" then
                SkillTree.deactivate()
                VictoryScreen.show()  -- Return to recap screen
            end
        end
        return
    end

    -- Only left click for the rest
    if button ~= 1 then return end

    -- Priority 1: Tooltip clicks (if visible) - tooltip is in game/screen space
    if Tooltip.isPointInside(gameX, gameY) then
        local result = Tooltip.handleClick(gameX, gameY, Economy)
        if result then
            local tower = state.selectedTower
            if result.action == "upgrade" then
                if tower and Economy.spendGold(result.cost) then
                    tower:upgrade()
                    EventBus.emit("tower_upgraded", {
                        tower = tower,
                        newLevel = tower.level,
                        cost = result.cost,
                    })
                    -- Refresh tooltip position in case range changed
                    Tooltip.show(tower)
                end
            elseif result.action == "sell" then
                if tower then
                    -- Sell the tower
                    _sellTower(tower)
                end
            end
        end
        return
    end

    -- Priority 2: HUD clicks (deselect any selected tower) - HUD uses game coords
    if HUD.isPointInHUD(gameX, gameY) then
        _selectTower(nil)
        local result = HUD.handleClick(gameX, gameY, Economy)
        if result and result.action == "buy_upgrade" then
            if Economy.spendGold(result.cost) then
                HUD.purchaseUpgrade(result.type)
                EventBus.emit("upgrade_purchased", {
                    type = result.type,
                    level = HUD.getUpgradeLevel(result.type),
                    cost = result.cost,
                })
            end
        end
        return
    end

    -- Priority 3: Void clicks (before tower selection) - void is in world space
    if state.void and state.void:isPointInside(worldX, worldY) then
        _selectTower(nil)
        Game.clickVoid()
        return
    end

    -- Priority 4: Click on placed tower (select/deselect) - towers are in world space
    local clickedTower = _findTowerAt(worldX, worldY)
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
    -- Grid uses world coordinates
    local towerType = HUD.getSelectedTower()
    if towerType then
        local gridX, gridY = Grid.screenToGrid(worldX, worldY)
        if _tryPlaceTower(gridX, gridY) then
            state.isDragging = true
            state.lastPlacedCell = { gridX = gridX, gridY = gridY }
        end
    else
        -- No tower selected for placement - start camera drag on empty play area (not over HUD)
        if not HUD.isPointInHUD(gameX, gameY) then
            Camera.startDrag(gameX, gameY)
        end
    end
end

function Game.mousemoved(screenX, screenY, dx, dy)
    -- Convert to game coordinates and world coordinates
    local gameX, gameY = Settings.screenToGame(screenX, screenY)
    local worldX, worldY = Camera.screenToWorld(gameX, gameY)

    -- Update camera drag-to-pan
    if Camera.isDragging() then
        Camera.updateDrag(gameX, gameY)
        return
    end

    -- Drag-to-place: continue placing towers while dragging
    if state.isDragging and love.mouse.isDown(1) then
        -- Stop drag if moved to HUD area (use game coords for UI check)
        if HUD.isPointInHUD(gameX, gameY) then
            state.isDragging = false
            state.lastPlacedCell = nil
            return
        end

        -- Grid uses world coordinates
        local gridX, gridY = Grid.screenToGrid(worldX, worldY)

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
    -- Handle skill tree panning release
    if SkillTree.isActive() then
        local x, y = Settings.screenToGame(screenX, screenY)
        SkillTree.handleMouseReleased(x, y, button)
    end

    if button == 1 then
        -- Handle settings slider release (uses screen coordinates)
        if Settings.isVisible() then
            Settings.handleRelease(screenX, screenY)
        end

        -- End camera drag-to-pan
        Camera.endDrag()

        state.isDragging = false
        state.lastPlacedCell = nil
    end
end

function Game.wheelmoved(x, y)
    -- Handle skill tree zoom
    if SkillTree.isActive() then
        SkillTree.handleWheel(x, y)
        return
    end

    -- Skip if any modal is open
    if Settings.isVisible() or Shortcuts.isVisible() or VictoryScreen.isVisible() or PauseMenu.isVisible() then
        return
    end

    -- Handle battlefield zoom (only when mouse is in play area, not over HUD)
    local screenMx, screenMy = love.mouse.getPosition()
    local gameMx, gameMy = Settings.screenToGame(screenMx, screenMy)

    if not HUD.isPointInHUD(gameMx, gameMy) then
        local zoomDelta = y * Config.CAMERA.zoomSpeed
        Camera.adjustZoom(zoomDelta)
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

    -- Handle keys when pause menu is visible
    if PauseMenu.isVisible() then
        if key == "escape" then
            PauseMenu.hide()
        end
        return
    end

    -- Handle keys when skill tree scene is active
    if SkillTree.isActive() then
        if SkillTree.handleKeyPressed(key) then
            return
        end
        -- ESC does nothing in skill tree scene - must click Start Run
        return
    end

    -- Handle keys when victory screen is visible
    if VictoryScreen.isVisible() then
        if key == "escape" then
            love.event.quit()
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
        ["1"] = "void_orb",
        ["2"] = "void_ring",
        ["3"] = "void_bolt",
        ["4"] = "void_eye",
        ["5"] = "void_star",
    }
    if towerKeys[key] then
        HUD.selectTower(towerKeys[key])
        return
    end

    -- Upgrade hotkeys
    if key == "q" then
        local cost = HUD.getUpgradeCost("autoClicker")
        if cost > 0 and Economy.canAfford(cost) then
            if Economy.spendGold(cost) then
                HUD.purchaseUpgrade("autoClicker")
                EventBus.emit("upgrade_purchased", {
                    type = "autoClicker",
                    level = HUD.getUpgradeLevel("autoClicker"),
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

    -- Bloom toggle
    if key == "l" then
        local enabled = Bloom.toggle()
        Settings.setBloomEnabled(enabled)
        return
    end

    -- Borderless toggle
    if key == "b" then
        Settings.toggleBorderless()
        return
    end

    -- Floating numbers style cycle
    if key == "g" then
        local newStyle = FloatingNumbers.cycleStyle()
        print("Floating numbers style: " .. newStyle)
        return
    end

    -- UI style cycle
    if key == "u" then
        local newStyle = HUD.cycleStyle()
        print("UI style: " .. newStyle)
        return
    end

    -- Debug overlay toggle
    if key == "d" then
        state.showDebug = not state.showDebug
        -- Compute debug path when enabling debug mode
        if state.showDebug then
            _recomputeDebugPath()
        end
        return
    end

    -- Zoom controls
    if key == "=" or key == "kp+" then
        Camera.adjustZoom(Config.CAMERA.zoomSpeed)
        return
    elseif key == "-" or key == "kp-" then
        Camera.adjustZoom(-Config.CAMERA.zoomSpeed)
        return
    elseif key == "0" or key == "kp0" then
        Camera.resetZoom()
        return
    end

    -- Escape: Cancel tower placement, deselect tower, or show pause menu
    if key == "escape" then
        -- First, cancel tower placement selection
        if HUD.getSelectedTower() then
            HUD.selectTower(nil)
        -- Then, deselect placed tower
        elseif state.selectedTower then
            _selectTower(nil)
        -- Finally, show pause menu
        else
            PauseMenu.show()
        end
    end
end

function Game.quit()
    -- Save game state here when implemented
end

function Game.restart()
    -- Hide skill tree scene and victory screen (if either is active)
    SkillTree.deactivate()
    VictoryScreen.hide()

    -- Clear all game entities
    state.towers = {}
    state.creeps = {}
    state.projectiles = {}
    state.cadavers = {}
    state.groundEffects = {}
    state.chainLightnings = {}
    state.lobbedProjectiles = {}
    state.blackholes = {}
    state.lightningProjectiles = {}
    state.explosionBursts = {}
    state.towersSortedByY = {}
    state.towersSortDirty = true
    state.selectedTower = nil
    state.hoveredTower = nil
    state.gameSpeedIndex = 1
    state.autoClickTimer = 0

    -- Get fixed game dimensions (1280x720 canvas)
    local gameWidth, gameHeight = Settings.getGameDimensions()

    -- Reset grid with fixed dimensions
    Grid.init(gameWidth, gameHeight)

    -- Reset camera with full canvas viewport
    local worldW, worldH = Grid.getWorldDimensions()
    Camera.init(worldW, worldH, gameWidth, gameHeight)

    -- Reset systems
    Economy.init()
    Waves.init()

    -- Recompute pathfinding
    state.flowField = Pathfinding.computeFlowField(Grid)
    _recomputeDebugPath()

    -- Reset Void entity
    local voidX, voidY = Grid.getPortalCenter()
    state.void = Void(voidX, voidY)

    -- Center camera on void portal
    Camera.centerOn(voidX, voidY)

    -- Reset Exit Portal
    local exitX, exitY = Grid.getExitPortalCenter()
    state.exitPortal = ExitPortal(exitX, exitY)

    -- Reset UI (minimalistic HUD)
    HUD.init(gameWidth, gameHeight)
    Tooltip.hide()
end

-- Expose state for systems that need it
function Game.getTowers()
    return state.towers
end

function Game.getCreeps()
    return state.creeps
end

return Game
