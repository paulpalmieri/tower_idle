-- src/ui/skill_tree.lua
-- Skill tree full scene with infinite canvas (pan/zoom)
-- Accessible only from recap screen after death/victory
-- Features: 5 towers in star pattern, skill nodes branching outward

local Config = require("src.config")
local Fonts = require("src.rendering.fonts")
local PixelFrames = require("src.ui.pixel_frames")
local SkillTreeData = require("src.systems.skill_tree_data")
local Economy = require("src.systems.economy")
local TurretConcepts = require("src.rendering.turret_concepts")
local SkillTreeBackground = require("src.rendering.skill_tree_background")
local Creep = require("src.entities.creep")
local Settings = require("src.ui.settings")

local SkillTree = {}

-- Camera/viewport state (pan only, no zoom)
local camera = {
    x = 0,          -- World position (center of view)
    y = 0,
    -- Panning state
    isPanning = false,
    panStartX = 0,
    panStartY = 0,
    panStartCamX = 0,
    panStartCamY = 0,
}

-- Node style (fixed to Stone Well)
local styleIndex = 3

-- Node sprite Y squash (fixed to 1.0 - no squash)
local nodeSquashValue = 1.0

-- Color scheme cycling
local colorSchemeIndex = 6  -- Default to Stone Glow
local COLOR_SCHEMES = {
    -- Scheme 1: Gold/Bronze progression (yellowish)
    {
        name = "Gold Progress",
        locked = {0.15, 0.12, 0.10, 0.5},      -- Dark stone, dim
        available = {0.4, 0.35, 0.25, 0.7},    -- Warm stone, ready
        allocated = {0.85, 0.70, 0.25, 0.9},   -- Bright gold
        hoverGlow = {1.0, 0.9, 0.5, 0.3},      -- Yellow glow
        hoverRim = {1.0, 0.85, 0.4, 0.8},      -- Gold rim
        keystoneMult = 1.2,                     -- Brighter keystones
    },
    -- Scheme 2: Purple void energy
    {
        name = "Void Purple",
        locked = {0.12, 0.10, 0.15, 0.5},
        available = {0.35, 0.25, 0.45, 0.7},
        allocated = {0.7, 0.4, 0.9, 0.9},
        hoverGlow = {0.8, 0.5, 1.0, 0.3},
        hoverRim = {0.9, 0.6, 1.0, 0.8},
        keystoneMult = 1.2,
    },
    -- Scheme 3: Emerald/Green growth
    {
        name = "Emerald Growth",
        locked = {0.10, 0.12, 0.10, 0.5},
        available = {0.25, 0.4, 0.30, 0.7},
        allocated = {0.3, 0.85, 0.45, 0.9},
        hoverGlow = {0.4, 1.0, 0.6, 0.3},
        hoverRim = {0.5, 0.95, 0.55, 0.8},
        keystoneMult = 1.2,
    },
    -- Scheme 4: Blue arcane
    {
        name = "Arcane Blue",
        locked = {0.10, 0.12, 0.15, 0.5},
        available = {0.25, 0.35, 0.5, 0.7},
        allocated = {0.4, 0.7, 1.0, 0.9},
        hoverGlow = {0.5, 0.8, 1.0, 0.3},
        hoverRim = {0.6, 0.85, 1.0, 0.8},
        keystoneMult = 1.2,
    },
    -- Scheme 5: Fire/Orange
    {
        name = "Fire Orange",
        locked = {0.15, 0.10, 0.08, 0.5},
        available = {0.5, 0.35, 0.2, 0.7},
        allocated = {1.0, 0.6, 0.2, 0.9},
        hoverGlow = {1.0, 0.7, 0.3, 0.3},
        hoverRim = {1.0, 0.75, 0.35, 0.8},
        keystoneMult = 1.2,
    },
    -- Scheme 6: Monochrome with glow
    {
        name = "Stone Glow",
        locked = {0.18, 0.17, 0.16, 0.4},
        available = {0.35, 0.33, 0.30, 0.6},
        allocated = {0.6, 0.58, 0.55, 0.85},
        hoverGlow = {0.9, 0.85, 0.7, 0.25},
        hoverRim = {0.8, 0.75, 0.65, 0.7},
        keystoneMult = 1.1,
        allocatedGlow = {0.9, 0.8, 0.5, 0.2},  -- Extra glow for allocated
    },
}

-- Private state
local state = {
    active = false,
    time = 0,
    hoveredNode = nil,
    backButtonHovered = false,
    -- Pre-computed node positions (world coordinates)
    nodePositions = {},
    -- Pre-computed tower positions (world coordinates)
    towerPositions = {},
    -- Pre-computed pathway segments for carved paths
    pathways = {},
    -- Void spawn in center (clickable to start run)
    voidSpawn = nil,
    voidSpawnHovered = false,
    voidSpawnScale = 1.0,
    -- Gravity particles (same as ExitPortal)
    gravityParticles = {},
}

-- =============================================================================
-- CAMERA HELPERS
-- =============================================================================

-- Get perspective Y ratio for tilted ground effect (camera)
local function _getPerspectiveYRatio()
    return Config.SKILL_TREE.background.perspectiveYRatio or 0.9
end

-- Get node sprite Y squash ratio (fixed)
local function _getNodeSquash()
    return nodeSquashValue
end

-- Get current color scheme
local function _getColorScheme()
    return COLOR_SCHEMES[colorSchemeIndex]
end

-- Convert screen coordinates to world coordinates (accounting for perspective)
local function _screenToWorld(screenX, screenY)
    local gameW, gameH = Settings.getGameDimensions()
    local centerX = gameW / 2
    local centerY = gameH / 2
    local perspectiveY = _getPerspectiveYRatio()
    local worldX = (screenX - centerX) + camera.x
    -- Reverse perspective: divide by ratio to get true world Y
    local worldY = ((screenY - centerY) + camera.y) / perspectiveY
    return worldX, worldY
end

-- Convert world coordinates to screen coordinates (accounting for perspective)
local function _worldToScreen(worldX, worldY)
    local gameW, gameH = Settings.getGameDimensions()
    local centerX = gameW / 2
    local centerY = gameH / 2
    local perspectiveY = _getPerspectiveYRatio()
    local screenX = (worldX - camera.x) + centerX
    -- Apply perspective: multiply Y by ratio for squashed look
    local screenY = (worldY * perspectiveY - camera.y) + centerY
    return screenX, screenY
end

-- Apply camera transform for drawing (with perspective)
local function _applyCameraTransform()
    local gameW, gameH = Settings.getGameDimensions()
    local centerX = gameW / 2
    local centerY = gameH / 2
    local perspectiveY = _getPerspectiveYRatio()
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(1, perspectiveY)
    love.graphics.translate(-camera.x, -camera.y / perspectiveY)
end

local function _resetCameraTransform()
    love.graphics.pop()
end

-- =============================================================================
-- HELPERS
-- =============================================================================

local function _pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function _pointInCircle(px, py, cx, cy, r)
    local dx = px - cx
    local dy = py - cy
    return dx * dx + dy * dy <= r * r
end

-- Calculate world position for a node (star pattern with branching tiers)
-- New structure per branch: tier1(1) -> tier2(3) -> tier3(3) -> tier4(1) -> tier5(keystone)
local function _getNodePosition(node)
    local cfg = Config.SKILL_TREE

    -- Cross-branch nodes: positioned between two branches
    if node.branch == "cross" or node.isCrossBranch then
        local crossCfg = cfg.crossBranch
        local radius = crossCfg.radius

        -- Get the two branches this node connects
        local branches = node.position and node.position.connectsBranches
        if branches and #branches == 2 then
            local angle1 = cfg.branchAngles[branches[1]] or 0
            local angle2 = cfg.branchAngles[branches[2]] or 0

            -- Handle angle wrapping (e.g., void_star to void_bolt crosses the -π boundary)
            local angleDiff = angle2 - angle1
            if angleDiff > math.pi then
                angleDiff = angleDiff - math.pi * 2
            elseif angleDiff < -math.pi then
                angleDiff = angleDiff + math.pi * 2
            end

            -- Position at the midpoint between the two branch angles
            local midAngle = angle1 + angleDiff / 2

            return math.cos(midAngle) * radius, math.sin(midAngle) * radius
        end

        -- Fallback for cross nodes without proper position data
        return 0, 0
    end

    local radius = cfg.tierRadius[node.tier] or 100
    local branchAngle = cfg.branchAngles[node.branch] or 0

    -- Each branch spans 72° (2π/5 radians)
    local branchSpan = math.pi * 2 / 5

    -- Tier 1: Single node, centered on branch
    if node.tier == 1 then
        return math.cos(branchAngle) * radius, math.sin(branchAngle) * radius
    end

    -- Tier 2 & 3: 3 nodes spread across the branch (left, center, right)
    if node.tier == 2 or node.tier == 3 then
        local sideOffset = 0
        if node.position and node.position.side == "left" then
            sideOffset = -branchSpan * 0.18
        elseif node.position and node.position.side == "right" then
            sideOffset = branchSpan * 0.18
        end
        -- center stays at 0
        local angle = branchAngle + sideOffset
        return math.cos(angle) * radius, math.sin(angle) * radius
    end

    -- Tier 4: Single important node, centered on branch
    if node.tier == 4 then
        return math.cos(branchAngle) * radius, math.sin(branchAngle) * radius
    end

    -- Tier 5 (Keystone): centered on branch
    if node.tier == 5 or node.isKeystone then
        return math.cos(branchAngle) * radius, math.sin(branchAngle) * radius
    end

    -- Fallback
    return math.cos(branchAngle) * radius, math.sin(branchAngle) * radius
end

-- Pre-compute all node positions (world coordinates, centered at 0,0)
local function _computeNodePositions()
    state.nodePositions = {}
    local nodes = SkillTreeData.getAllNodes()
    for _, node in ipairs(nodes) do
        local x, y = _getNodePosition(node)
        state.nodePositions[node.id] = { x = x, y = y }
    end
end

-- Pre-compute tower positions (5 towers in circle at center, world coords)
local function _computeTowerPositions()
    local cfg = Config.SKILL_TREE
    local towerRadius = cfg.towerCircleRadius

    state.towerPositions = {}

    local towerTypes = {"void_bolt", "void_orb", "void_ring", "void_eye", "void_star"}
    for _, towerType in ipairs(towerTypes) do
        local angle = cfg.branchAngles[towerType]
        local x = math.cos(angle) * towerRadius
        local y = math.sin(angle) * towerRadius
        state.towerPositions[towerType] = {
            x = x,
            y = y,
            angle = angle,
            variantIndex = cfg.towerVariants[towerType],
        }
    end
end

-- Pre-compute all pathway segments for carved path rendering
local function _computePathways()
    state.pathways = {}
    local nodes = SkillTreeData.getAllNodes()
    local cfg = Config.SKILL_TREE

    -- Node-to-node connections
    for _, node in ipairs(nodes) do
        local pos = state.nodePositions[node.id]
        if pos and node.requires then
            for _, reqId in ipairs(node.requires) do
                local reqPos = state.nodePositions[reqId]
                if reqPos then
                    table.insert(state.pathways, {
                        fromX = pos.x,
                        fromY = pos.y,
                        toX = reqPos.x,
                        toY = reqPos.y,
                        fromId = node.id,
                        toId = reqId,
                        isTowerConnection = false,
                    })
                end
            end
        end
    end

    -- Tower-to-tier1 connections
    for _, node in ipairs(nodes) do
        if node.tier == 1 and node.branch ~= "cross" then
            local nodePos = state.nodePositions[node.id]
            local towerPos = state.towerPositions[node.branch]

            if nodePos and towerPos then
                table.insert(state.pathways, {
                    fromX = towerPos.x,
                    fromY = towerPos.y,
                    toX = nodePos.x,
                    toY = nodePos.y,
                    fromId = node.branch,  -- tower type as ID
                    toId = node.id,
                    isTowerConnection = true,
                })
            end
        end
    end
end

local function _calculateLayout()
    _computeNodePositions()
    _computeTowerPositions()
    _computePathways()
end

-- Get node color based on state
local function _getNodeColor(node)
    local cfg = Config.SKILL_TREE.colors

    if SkillTreeData.isAllocated(node.id) then
        if node.isKeystone then
            return cfg.keystoneAllocated
        end
        return cfg.allocated
    elseif SkillTreeData.isAvailable(node.id) then
        if node.isKeystone then
            return cfg.keystone
        end
        return cfg.available
    else
        return cfg.locked
    end
end

-- Get node size
local function _getNodeSize(node)
    local cfg = Config.SKILL_TREE
    if node.isKeystone then
        return cfg.keystoneSize
    elseif node.isCrossBranch or node.branch == "cross" then
        return cfg.crossBranch.nodeSize
    end
    return cfg.nodeSize
end

-- =============================================================================
-- GRAVITY PARTICLE SYSTEM (Same as ExitPortal)
-- =============================================================================

-- Void spawn size for particle calculations (matches 1.8x scaled void spawn)
local VOID_SPAWN_SIZE = 25 * 1.8  -- Base creep size * skill tree scale

-- Spawn a single gravity particle
local function _spawnGravityParticle()
    local cfg = Config.VOID_CORE
    local pcfg = cfg.particles
    local angle = math.random() * math.pi * 2
    local dist = VOID_SPAWN_SIZE * (pcfg.spawnRadius * (0.8 + math.random() * 0.4))

    return {
        angle = angle,
        dist = dist,
        speed = pcfg.pullSpeed * (0.7 + math.random() * 0.6),
        brightness = 0.3 + math.random() * 0.5,
    }
end

-- Initialize all gravity particles
local function _initGravityParticles()
    local cfg = Config.VOID_CORE.particles
    state.gravityParticles = {}
    for _ = 1, cfg.count do
        table.insert(state.gravityParticles, _spawnGravityParticle())
    end
end

-- Update gravity particles (pull inward)
local function _updateGravityParticles(dt)
    local cfg = Config.VOID_CORE

    for i = #state.gravityParticles, 1, -1 do
        local p = state.gravityParticles[i]
        p.dist = p.dist - p.speed * dt

        -- Respawn when reaching core
        if p.dist < cfg.coreSize then
            table.remove(state.gravityParticles, i)
            table.insert(state.gravityParticles, _spawnGravityParticle())
        end
    end
end

-- Draw gravity particles
local function _drawGravityParticles()
    local cfg = Config.VOID_CORE
    local pcfg = cfg.particles
    local ps = pcfg.size

    for _, p in ipairs(state.gravityParticles) do
        local x = math.cos(p.angle) * p.dist
        local y = math.sin(p.angle) * p.dist
        local distNorm = p.dist / (VOID_SPAWN_SIZE * pcfg.spawnRadius)
        -- Stronger alpha for more visible trails, brighter when far, still visible when close
        local alpha = p.brightness * (0.3 + distNorm * 0.7)

        -- Brighter color with slight additive feel
        love.graphics.setColor(pcfg.color[1], pcfg.color[2], pcfg.color[3], alpha)
        love.graphics.rectangle("fill", x - ps/2, y - ps/2, ps, ps)

        -- Add a subtle glow/trail behind each particle
        if distNorm > 0.3 then
            local glowAlpha = alpha * 0.3
            love.graphics.setColor(pcfg.color[1], pcfg.color[2], pcfg.color[3], glowAlpha)
            love.graphics.rectangle("fill", x - ps, y - ps, ps * 2, ps * 2)
        end
    end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function SkillTree.init()
    _calculateLayout()
end

function SkillTree.activate()
    state.active = true
    state.time = 0
    state.hoveredNode = nil
    state.backButtonHovered = false
    state.voidSpawnHovered = false
    state.voidSpawnScale = 1.0
    -- Reset camera to center
    camera.x = 0
    camera.y = 0
    camera.isPanning = false
    _calculateLayout()

    -- Create void spawn at center for start run button
    state.voidSpawn = Creep(0, 0, "voidSpawn")
    state.voidSpawn.spawnPhase = "active"  -- Skip spawn animation

    -- Initialize gravity particle system (same as ExitPortal)
    _initGravityParticles()

    -- Generate background (regenerate to ensure correct size)
    SkillTreeBackground.generate()
end

function SkillTree.deactivate()
    state.active = false
    camera.isPanning = false
end

function SkillTree.show()
    SkillTree.activate()
end

function SkillTree.hide()
    SkillTree.deactivate()
end

function SkillTree.toggle()
    if state.active then
        SkillTree.deactivate()
    else
        SkillTree.activate()
    end
end

function SkillTree.isVisible()
    return state.active
end

function SkillTree.isActive()
    return state.active
end

function SkillTree.update(mouseX, mouseY)
    if not state.active then return end

    local dt = love.timer.getDelta()
    state.time = state.time + dt
    state.hoveredNode = nil

    -- Update void spawn animation time
    if state.voidSpawn then
        state.voidSpawn.time = state.voidSpawn.time + dt
    end

    -- Update gravity particles
    _updateGravityParticles(dt)

    -- Handle panning (with left mouse drag)
    if camera.isPanning then
        local dx = mouseX - camera.panStartX
        local dy = mouseY - camera.panStartY
        camera.x = camera.panStartCamX - dx
        camera.y = camera.panStartCamY - dy

        -- Clamp camera to bounds
        local bounds = Config.SKILL_TREE.cameraBounds
        if bounds then
            camera.x = math.max(-bounds.maxPanX, math.min(bounds.maxPanX, camera.x))
            camera.y = math.max(-bounds.maxPanY, math.min(bounds.maxPanY, camera.y))
        end
    end

    -- Convert mouse to world coords for node hover detection
    local worldX, worldY = _screenToWorld(mouseX, mouseY)

    -- Check for void spawn hover (center of tree)
    state.voidSpawnHovered = false
    if not camera.isPanning and state.voidSpawn then
        local voidSpawnRadius = 45  -- Hitbox radius for void spawn (scaled 1.8x)
        if _pointInCircle(worldX, worldY, 0, 0, voidSpawnRadius) then
            state.voidSpawnHovered = true
        end
    end

    -- Smoothly interpolate void spawn scale for hover effect
    local targetScale = state.voidSpawnHovered and 1.15 or 1.0
    state.voidSpawnScale = state.voidSpawnScale + (targetScale - state.voidSpawnScale) * dt * 10

    -- Check for hovered node (only if not panning and not hovering void spawn)
    if not camera.isPanning and not state.voidSpawnHovered then
        local nodes = SkillTreeData.getAllNodes()
        for _, node in ipairs(nodes) do
            local pos = state.nodePositions[node.id]
            if pos then
                local size = _getNodeSize(node)
                if _pointInCircle(worldX, worldY, pos.x, pos.y, size / 2 + 4) then
                    state.hoveredNode = node
                    break
                end
            end
        end
    end

    -- Check for UI button hovers (screen space)
    local backBtnW, backBtnH = 100, 36
    local backBtnX, backBtnY = 20, 20
    state.backButtonHovered = _pointInRect(mouseX, mouseY, backBtnX, backBtnY, backBtnW, backBtnH)
end

function SkillTree.handleClick(x, y, button)
    if not state.active then return false end

    -- Check for Back button (screen space)
    local backBtnW, backBtnH = 100, 36
    local backBtnX, backBtnY = 20, 20
    if _pointInRect(x, y, backBtnX, backBtnY, backBtnW, backBtnH) then
        return { action = "back" }
    end

    -- Check for void spawn click (world space - starts the run)
    if state.voidSpawnHovered and button == 1 then
        return { action = "start_run" }
    end

    -- Check for node click (world space)
    if state.hoveredNode then
        if button == 1 then
            -- Left click: allocate
            if SkillTreeData.canAllocate(state.hoveredNode.id) then
                SkillTreeData.allocate(state.hoveredNode.id)
            end
        elseif button == 2 then
            -- Right click: unallocate
            if SkillTreeData.canUnallocate(state.hoveredNode.id) then
                SkillTreeData.unallocate(state.hoveredNode.id)
            end
        end
        return true
    end

    -- Left click on empty space starts panning
    if button == 1 then
        camera.isPanning = true
        camera.panStartX = x
        camera.panStartY = y
        camera.panStartCamX = camera.x
        camera.panStartCamY = camera.y
        return true
    end

    return true  -- Consume all clicks
end

function SkillTree.handleMouseReleased(x, y, button)
    if button == 1 then
        camera.isPanning = false
    end
end

function SkillTree.handleWheel(wheelX, wheelY)
    -- No zoom
end

function SkillTree.handleKeyPressed(key)
    if not state.active then return false end

    if key == "n" then
        colorSchemeIndex = (colorSchemeIndex % #COLOR_SCHEMES) + 1
        return true
    end
    return false
end

function SkillTree.getStyleIndex()
    return styleIndex
end

function SkillTree.draw()
    if not state.active then return end

    -- Draw dark background fallback (will be mostly covered by Voronoi texture)
    local gameW, gameH = Settings.getGameDimensions()
    love.graphics.setColor(0.03, 0.02, 0.05)
    love.graphics.rectangle("fill", 0, 0, gameW, gameH)

    -- Apply camera transform for world elements
    _applyCameraTransform()

    -- 1. Background texture (Voronoi stone ground)
    SkillTreeBackground.draw()

    -- 2. Carved paths (pixelated void channels)
    SkillTree.drawCarvedPaths()

    -- 3. Nodes (subtle, transparent, blends with ground)
    SkillTree.drawNodes()

    -- 4. Gravity particles (same as ExitPortal - pulled toward center)
    _drawGravityParticles()

    -- 5. Void spawn at center (clickable start run)
    SkillTree.drawVoidSpawn()

    _resetCameraTransform()

    -- 6. Towers (screen space, upright - not affected by perspective transform)
    -- We manually convert world coords to screen coords
    SkillTree.drawTowers()

    -- 7. UI elements (screen space, not affected by camera)
    SkillTree.drawUI()

    -- 8. Tooltip for hovered node (screen space)
    if state.hoveredNode then
        SkillTree.drawTooltip(state.hoveredNode)
    end
end

function SkillTree.drawTowers()
    -- Draw towers sorted by Y for proper depth
    local sortedTowers = {}
    for towerType, pos in pairs(state.towerPositions) do
        -- Convert world position to screen position
        local screenX, screenY = _worldToScreen(pos.x, pos.y)
        table.insert(sortedTowers, { type = towerType, pos = pos, screenX = screenX, screenY = screenY })
    end
    table.sort(sortedTowers, function(a, b) return a.screenY < b.screenY end)

    -- Draw towers at screen coordinates (scaled 1.5x, level 1 base)
    local towerScale = 1.5
    for _, tower in ipairs(sortedTowers) do
        love.graphics.push()
        love.graphics.translate(tower.screenX, tower.screenY)
        love.graphics.scale(towerScale, towerScale)
        TurretConcepts.drawVariant(
            tower.pos.variantIndex,
            0,  -- Draw at origin since we translated
            0,
            tower.pos.angle,
            0,
            state.time,
            tower.pos.variantIndex,
            1.0,
            nil,
            1  -- Level 1 base
        )
        love.graphics.pop()
    end
end

-- Draw a pixelated ellipse (filled)
local function _drawPixelEllipse(cx, cy, radiusX, radiusY, pixelSize, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    for py = -radiusY, radiusY, pixelSize do
        for px = -radiusX, radiusX, pixelSize do
            local nx = (px + pixelSize/2) / radiusX
            local ny = (py + pixelSize/2) / radiusY
            if nx*nx + ny*ny <= 1 then
                local drawX = math.floor((cx + px) / pixelSize) * pixelSize
                local drawY = math.floor((cy + py) / pixelSize) * pixelSize
                love.graphics.rectangle("fill", drawX, drawY, pixelSize, pixelSize)
            end
        end
    end
end

-- Draw a pixelated ellipse ring
local function _drawPixelRing(cx, cy, radiusX, radiusY, pixelSize, thickness, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    local innerRX = radiusX - thickness
    local innerRY = radiusY - thickness
    for py = -radiusY, radiusY, pixelSize do
        for px = -radiusX, radiusX, pixelSize do
            local nx = (px + pixelSize/2) / radiusX
            local ny = (py + pixelSize/2) / radiusY
            if nx*nx + ny*ny <= 1 then
                if innerRX <= 0 or innerRY <= 0 then
                    love.graphics.rectangle("fill", math.floor((cx + px) / pixelSize) * pixelSize, math.floor((cy + py) / pixelSize) * pixelSize, pixelSize, pixelSize)
                else
                    local nxi = (px + pixelSize/2) / innerRX
                    local nyi = (py + pixelSize/2) / innerRY
                    if nxi*nxi + nyi*nyi > 1 then
                        love.graphics.rectangle("fill", math.floor((cx + px) / pixelSize) * pixelSize, math.floor((cy + py) / pixelSize) * pixelSize, pixelSize, pixelSize)
                    end
                end
            end
        end
    end
end

-- Style 1: Thin ring - simple base style
local function _drawNodeThinRing(pos, color, size, isHovered, isAllocated, isKeystone, pixelSize)
    local r = size / 2
    local alpha = isAllocated and 0.85 or 0.4

    if isHovered then
        _drawPixelEllipse(pos.x, pos.y, r + 3, r + 3, pixelSize, color[1], color[2], color[3], 0.12)
    end

    -- Thin outer ring
    _drawPixelRing(pos.x, pos.y, r, r * 0.9, pixelSize, pixelSize, color[1], color[2], color[3], alpha)

    -- Center dot
    if isAllocated then
        _drawPixelEllipse(pos.x, pos.y, r * 0.35, r * 0.35, pixelSize, color[1], color[2], color[3], 0.8)
    else
        _drawPixelEllipse(pos.x, pos.y, pixelSize, pixelSize, pixelSize, color[1], color[2], color[3], alpha * 0.5)
    end

    if isKeystone then
        _drawPixelRing(pos.x, pos.y, r * 0.65, r * 0.6, pixelSize, pixelSize, color[1], color[2], color[3], alpha * 0.6)
    end
end

-- Style 2: Shallow cylinder - visible walls like turret base
local function _drawNodeShallowCylinder(pos, color, size, isHovered, isAllocated, isKeystone, pixelSize)
    local r = size / 2
    local baseHeight = pixelSize * 3
    local numLayers = 3
    local alpha = isAllocated and 0.85 or 0.4
    local ySquash = _getNodeSquash()

    if isHovered then
        _drawPixelEllipse(pos.x, pos.y + baseHeight/2, r + 3, (r + 3) * ySquash, pixelSize, color[1], color[2], color[3], 0.1)
    end

    -- Draw stacked ellipse layers (bottom to top) to show walls
    for layer = 0, numLayers - 1 do
        local layerProgress = layer / numLayers
        local layerY = pos.y + baseHeight/2 - layer * (baseHeight / numLayers)

        -- Slight taper toward top
        local taperFactor = 1.0 - layerProgress * 0.05
        local layerRX = r * taperFactor
        local layerRY = r * ySquash * taperFactor

        -- Darker at bottom, lighter at top
        local brightness = 0.3 + layerProgress * 0.5
        local lr = color[1] * brightness
        local lg = color[2] * brightness
        local lb = color[3] * brightness

        _drawPixelEllipse(pos.x, layerY, layerRX, layerRY, pixelSize, lr, lg, lb, alpha)
    end

    -- Top surface
    local topY = pos.y - baseHeight/2
    _drawPixelEllipse(pos.x, topY, r * 0.95, r * ySquash * 0.95, pixelSize, color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, alpha)

    -- Top rim highlight
    _drawPixelRing(pos.x, topY, r * 0.95, r * ySquash * 0.95, pixelSize, pixelSize, color[1], color[2], color[3], alpha)

    -- Inner darkness (the hole)
    _drawPixelEllipse(pos.x, topY + pixelSize/2, r * 0.6, r * ySquash * 0.55, pixelSize, 0.015, 0.01, 0.02, 0.9)

    if isAllocated then
        _drawPixelEllipse(pos.x, topY, r * 0.3, r * ySquash * 0.28, pixelSize, color[1], color[2], color[3], 0.85)
    end

    if isKeystone then
        _drawPixelRing(pos.x, topY, r * 0.5, r * ySquash * 0.45, pixelSize, pixelSize, color[1], color[2], color[3], alpha * 0.6)
    end
end

-- Style 3: Stone well - deeper cylinder with visible walls
local function _drawNodeStoneWell(pos, color, size, isHovered, isAllocated, isKeystone, pixelSize, nodeState)
    local r = size / 2
    local baseHeight = pixelSize * 5
    local numLayers = 5
    local ySquash = _getNodeSquash()
    local scheme = _getColorScheme()

    -- Get color from scheme based on state
    local schemeColor
    if isAllocated then
        schemeColor = scheme.allocated
    elseif nodeState == "available" then
        schemeColor = scheme.available
    else
        schemeColor = scheme.locked
    end

    -- Apply keystone multiplier
    if isKeystone and scheme.keystoneMult then
        schemeColor = {
            math.min(1, schemeColor[1] * scheme.keystoneMult),
            math.min(1, schemeColor[2] * scheme.keystoneMult),
            math.min(1, schemeColor[3] * scheme.keystoneMult),
            schemeColor[4]
        }
    end

    local baseAlpha = schemeColor[4] or 0.7

    -- Hover glow effect (outer glow)
    if isHovered then
        local glow = scheme.hoverGlow
        _drawPixelEllipse(pos.x, pos.y + baseHeight/2, r + 6, (r + 6) * ySquash, pixelSize, glow[1], glow[2], glow[3], glow[4])
        _drawPixelEllipse(pos.x, pos.y + baseHeight/2, r + 4, (r + 4) * ySquash, pixelSize, glow[1], glow[2], glow[3], glow[4] * 1.5)
    end

    -- Allocated glow effect (if scheme has it)
    if isAllocated and scheme.allocatedGlow then
        local ag = scheme.allocatedGlow
        _drawPixelEllipse(pos.x, pos.y, r + 4, (r + 4) * ySquash, pixelSize, ag[1], ag[2], ag[3], ag[4])
    end

    -- Draw stacked ellipse layers (bottom to top) to show walls
    for layer = 0, numLayers - 1 do
        local layerProgress = layer / numLayers
        local layerY = pos.y + baseHeight/2 - layer * (baseHeight / numLayers)

        -- Slight taper toward top
        local taperFactor = 1.0 - layerProgress * 0.06
        local layerRX = r * taperFactor
        local layerRY = r * ySquash * taperFactor

        -- Darker at bottom, lighter at top with rim lighting
        local brightness = 0.3 + layerProgress * 0.5
        local lr = schemeColor[1] * brightness
        local lg = schemeColor[2] * brightness
        local lb = schemeColor[3] * brightness

        _drawPixelEllipse(pos.x, layerY, layerRX, layerRY, pixelSize, lr, lg, lb, baseAlpha)
    end

    -- Top surface
    local topY = pos.y - baseHeight/2
    _drawPixelEllipse(pos.x, topY, r * 0.94, r * ySquash * 0.94, pixelSize, schemeColor[1] * 0.7, schemeColor[2] * 0.7, schemeColor[3] * 0.7, baseAlpha)

    -- Top rim highlight (thicker for worn stone feel)
    local rimAlpha = isHovered and 1.0 or baseAlpha
    if isHovered then
        local rim = scheme.hoverRim
        _drawPixelRing(pos.x, topY, r * 0.94, r * ySquash * 0.94, pixelSize, pixelSize * 2, rim[1], rim[2], rim[3], rim[4])
    else
        _drawPixelRing(pos.x, topY, r * 0.94, r * ySquash * 0.94, pixelSize, pixelSize * 2, schemeColor[1], schemeColor[2], schemeColor[3], baseAlpha)
    end

    -- Inner darkness (the deep hole)
    _drawPixelEllipse(pos.x, topY + pixelSize, r * 0.55, r * ySquash * 0.5, pixelSize, 0.01, 0.008, 0.015, 0.95)

    if isAllocated then
        -- Glowing energy in the well
        _drawPixelEllipse(pos.x, topY, r * 0.35, r * ySquash * 0.32, pixelSize, schemeColor[1], schemeColor[2], schemeColor[3], 0.9)
        -- Bright center
        _drawPixelEllipse(pos.x, topY, r * 0.15, r * ySquash * 0.14, pixelSize, 1, 1, 1, 0.4)
    end

    if isKeystone then
        -- Inner rim detail
        _drawPixelRing(pos.x, topY, r * 0.65, r * ySquash * 0.6, pixelSize, pixelSize, schemeColor[1], schemeColor[2], schemeColor[3], baseAlpha * 0.6)
    end
end

-- Style 4: Ruined pedestal - weathered stone with visible walls and broken section
local function _drawNodeRuinedPedestal(pos, color, size, isHovered, isAllocated, isKeystone, pixelSize)
    local r = size / 2
    local baseHeight = pixelSize * 4
    local numLayers = 4
    local alpha = isAllocated and 0.85 or 0.4
    local ySquash = _getNodeSquash()

    if isHovered then
        _drawPixelEllipse(pos.x, pos.y + baseHeight/2, r + 3, (r + 3) * ySquash, pixelSize, color[1], color[2], color[3], 0.1)
    end

    -- Draw stacked ellipse layers with a "broken" gap section
    for layer = 0, numLayers - 1 do
        local layerProgress = layer / numLayers
        local layerY = pos.y + baseHeight/2 - layer * (baseHeight / numLayers)

        local taperFactor = 1.0 - layerProgress * 0.05
        local layerRX = r * taperFactor
        local layerRY = r * ySquash * taperFactor

        local brightness = 0.28 + layerProgress * 0.5
        local lr = color[1] * brightness
        local lg = color[2] * brightness
        local lb = color[3] * brightness

        -- Draw ellipse with gap (broken section in upper-right)
        love.graphics.setColor(lr, lg, lb, alpha)
        for py = -layerRY, layerRY, pixelSize do
            for px = -layerRX, layerRX, pixelSize do
                local nx = (px + pixelSize/2) / layerRX
                local ny = (py + pixelSize/2) / layerRY
                if nx*nx + ny*ny <= 1 then
                    local angle = math.atan2(py, px)
                    -- Gap in upper right quadrant
                    local hasGap = angle > 0.6 and angle < 1.3 and layerProgress > 0.3
                    if not hasGap then
                        local drawX = math.floor((pos.x + px) / pixelSize) * pixelSize
                        local drawY = math.floor((layerY + py) / pixelSize) * pixelSize
                        love.graphics.rectangle("fill", drawX, drawY, pixelSize, pixelSize)
                    end
                end
            end
        end
    end

    -- Top surface (also with gap)
    local topY = pos.y - baseHeight/2
    love.graphics.setColor(color[1] * 0.65, color[2] * 0.65, color[3] * 0.65, alpha)
    local topRX = r * 0.94
    local topRY = r * ySquash * 0.94
    for py = -topRY, topRY, pixelSize do
        for px = -topRX, topRX, pixelSize do
            local nx = (px + pixelSize/2) / topRX
            local ny = (py + pixelSize/2) / topRY
            if nx*nx + ny*ny <= 1 then
                local angle = math.atan2(py, px)
                local hasGap = angle > 0.6 and angle < 1.3
                if not hasGap then
                    local drawX = math.floor((pos.x + px) / pixelSize) * pixelSize
                    local drawY = math.floor((topY + py) / pixelSize) * pixelSize
                    love.graphics.rectangle("fill", drawX, drawY, pixelSize, pixelSize)
                end
            end
        end
    end

    -- Top rim highlight (with gap)
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    local rimInnerRX = topRX - pixelSize * 2
    local rimInnerRY = topRY - pixelSize * 2
    for py = -topRY, topRY, pixelSize do
        for px = -topRX, topRX, pixelSize do
            local nx = (px + pixelSize/2) / topRX
            local ny = (py + pixelSize/2) / topRY
            local nxi = (px + pixelSize/2) / rimInnerRX
            local nyi = (py + pixelSize/2) / rimInnerRY
            local angle = math.atan2(py, px)
            local hasGap = angle > 0.6 and angle < 1.3
            if nx*nx + ny*ny <= 1 and (rimInnerRX <= 0 or nxi*nxi + nyi*nyi > 1) and not hasGap then
                local drawX = math.floor((pos.x + px) / pixelSize) * pixelSize
                local drawY = math.floor((topY + py) / pixelSize) * pixelSize
                love.graphics.rectangle("fill", drawX, drawY, pixelSize, pixelSize)
            end
        end
    end

    -- Inner darkness (the hole)
    _drawPixelEllipse(pos.x, topY + pixelSize, r * 0.5, r * ySquash * 0.45, pixelSize, 0.015, 0.01, 0.02, 0.9)

    if isAllocated then
        _drawPixelEllipse(pos.x, topY, r * 0.3, r * ySquash * 0.27, pixelSize, color[1], color[2], color[3], 0.8)
    end

    if isKeystone then
        _drawPixelRing(pos.x, topY, r * 0.6, r * ySquash * 0.55, pixelSize, pixelSize, color[1], color[2], color[3], alpha * 0.5)
    end
end

-- Style 5: Heavy stone socket - thick weighted cylinder with visible walls
local function _drawNodeHeavySocket(pos, color, size, isHovered, isAllocated, isKeystone, pixelSize)
    local r = size / 2
    local baseHeight = pixelSize * 6
    local numLayers = 6
    local alpha = isAllocated and 0.85 or 0.4
    local ySquash = _getNodeSquash()

    if isHovered then
        _drawPixelEllipse(pos.x, pos.y + baseHeight/2, r + 4, (r + 4) * ySquash, pixelSize, color[1], color[2], color[3], 0.1)
    end

    -- Draw stacked ellipse layers (bottom to top) to show thick walls
    for layer = 0, numLayers - 1 do
        local layerProgress = layer / numLayers
        local layerY = pos.y + baseHeight/2 - layer * (baseHeight / numLayers)

        -- Slight taper toward top
        local taperFactor = 1.0 - layerProgress * 0.04
        local layerRX = r * taperFactor
        local layerRY = r * ySquash * taperFactor

        -- Darker at bottom, lighter at top
        local brightness = 0.2 + layerProgress * 0.6
        local lr = color[1] * brightness
        local lg = color[2] * brightness
        local lb = color[3] * brightness

        _drawPixelEllipse(pos.x, layerY, layerRX, layerRY, pixelSize, lr, lg, lb, alpha)
    end

    -- Top surface
    local topY = pos.y - baseHeight/2
    _drawPixelEllipse(pos.x, topY, r * 0.96, r * ySquash * 0.96, pixelSize, color[1] * 0.55, color[2] * 0.55, color[3] * 0.55, alpha)

    -- Top rim highlight (thick)
    _drawPixelRing(pos.x, topY, r * 0.96, r * ySquash * 0.96, pixelSize, pixelSize * 2, color[1], color[2], color[3], alpha)

    -- Deep socket hole
    _drawPixelEllipse(pos.x, topY + pixelSize, r * 0.45, r * ySquash * 0.4, pixelSize, 0.01, 0.008, 0.015, 0.95)

    if isAllocated then
        -- Gem/energy in socket
        _drawPixelEllipse(pos.x, topY, r * 0.32, r * ySquash * 0.29, pixelSize, color[1], color[2], color[3], 0.9)
        -- Inner glow
        _drawPixelEllipse(pos.x, topY, r * 0.15, r * ySquash * 0.14, pixelSize, 1, 1, 1, 0.4)
    end

    if isKeystone then
        _drawPixelRing(pos.x, topY, r * 0.6, r * ySquash * 0.55, pixelSize, pixelSize, color[1], color[2], color[3], alpha * 0.5)
    end
end

function SkillTree.drawNodes()
    local cfg = Config.SKILL_TREE
    local nodes = SkillTreeData.getAllNodes()
    local pixelSize = 2

    for _, node in ipairs(nodes) do
        local pos = state.nodePositions[node.id]
        if pos then
            local color = _getNodeColor(node)
            local size = _getNodeSize(node) * 1.3  -- Bigger nodes
            local isHovered = state.hoveredNode and state.hoveredNode.id == node.id
            local isAllocated = SkillTreeData.isAllocated(node.id)

            -- Determine node state for color scheme
            local nodeState = "locked"
            if isAllocated then
                nodeState = "allocated"
            elseif SkillTreeData.isAvailable(node.id) then
                nodeState = "available"
            end

            if styleIndex == 1 then
                _drawNodeThinRing(pos, color, size, isHovered, isAllocated, node.isKeystone, pixelSize)
            elseif styleIndex == 2 then
                _drawNodeShallowCylinder(pos, color, size, isHovered, isAllocated, node.isKeystone, pixelSize)
            elseif styleIndex == 3 then
                _drawNodeStoneWell(pos, color, size, isHovered, isAllocated, node.isKeystone, pixelSize, nodeState)
            elseif styleIndex == 4 then
                _drawNodeRuinedPedestal(pos, color, size, isHovered, isAllocated, node.isKeystone, pixelSize)
            else
                _drawNodeHeavySocket(pos, color, size, isHovered, isAllocated, node.isKeystone, pixelSize)
            end
        end
    end
end

-- Draw void spawn at center (clickable to start run)
function SkillTree.drawVoidSpawn()
    if not state.voidSpawn then return end

    -- Draw at world origin (0, 0) with base scale of 1.8x plus hover effect
    local baseScale = 1.8
    local finalScale = baseScale * state.voidSpawnScale
    love.graphics.push()
    love.graphics.translate(0, 0)
    love.graphics.scale(finalScale, finalScale)
    state.voidSpawn:draw()
    love.graphics.pop()
end

-- Draw a pixelated line between two points
local function _drawPixelLine(x1, y1, x2, y2, pixelSize, r, g, b, a, glowR, glowG, glowB, glowA)
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end

    local steps = math.max(1, math.ceil(len / pixelSize))

    -- Track drawn pixels to avoid overdraw
    local drawn = {}

    for i = 0, steps do
        local t = i / steps
        local px = x1 + dx * t
        local py = y1 + dy * t

        -- Snap to pixel grid
        local gx = math.floor(px / pixelSize) * pixelSize
        local gy = math.floor(py / pixelSize) * pixelSize
        local key = gx .. "," .. gy

        if not drawn[key] then
            drawn[key] = true

            -- Draw glow if specified
            if glowA and glowA > 0 then
                love.graphics.setColor(glowR, glowG, glowB, glowA)
                love.graphics.rectangle("fill", gx - pixelSize, gy - pixelSize, pixelSize * 3, pixelSize * 3)
            end

            -- Draw core pixel
            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill", gx, gy, pixelSize, pixelSize)
        end
    end
end

-- Draw paths as pixelated lines
function SkillTree.drawCarvedPaths()
    local pixelSize = 4  -- Match background pixel size

    for _, path in ipairs(state.pathways) do
        -- Check if path is active
        local isActive = false
        if path.isTowerConnection then
            isActive = SkillTreeData.isAllocated(path.toId)
        else
            isActive = SkillTreeData.isAllocated(path.fromId) and SkillTreeData.isAllocated(path.toId)
        end

        if isActive then
            -- Active: warm stone glow (matches Stone Glow palette)
            _drawPixelLine(path.fromX, path.fromY, path.toX, path.toY, pixelSize,
                0.5, 0.45, 0.35, 0.6,
                nil, nil, nil, 0)
        else
            -- Inactive: dark subtle line
            _drawPixelLine(path.fromX, path.fromY, path.toX, path.toY, pixelSize,
                0.22, 0.20, 0.18, 0.35,
                nil, nil, nil, 0)
        end
    end
end

function SkillTree.drawUI()
    local gameW, gameH = Settings.getGameDimensions()
    local shards = Economy.getVoidShards()
    local crystals = Economy.getVoidCrystals()

    -- Currency display (top center)
    local currencyWidth = 200
    local currencyHeight = 50
    local currencyX = gameW / 2 - currencyWidth / 2
    local currencyY = 20

    PixelFrames.draw8BitFrame(currencyX, currencyY, currencyWidth, currencyHeight, "hud")

    Fonts.setFont("medium")
    love.graphics.setColor(Config.FLOATING_NUMBERS.shardColor)
    love.graphics.print("Shards: " .. shards, currencyX + 15, currencyY + 8)
    love.graphics.setColor(Config.FLOATING_NUMBERS.crystalColor)
    love.graphics.print("Crystals: " .. crystals, currencyX + 15, currencyY + 28)

    -- Back button (top left)
    local backBtnW, backBtnH = 100, 36
    local backBtnX, backBtnY = 20, 20
    local backStyle = state.backButtonHovered and "highlight" or "standard"
    PixelFrames.draw8BitCard(backBtnX, backBtnY, backBtnW, backBtnH, backStyle)

    Fonts.setFont("medium")
    local backText = "< BACK"
    local backTextW = Fonts.get("medium"):getWidth(backText)
    local backTextH = Fonts.get("medium"):getHeight()
    if state.backButtonHovered then
        love.graphics.setColor(Config.COLORS.gold)
    else
        love.graphics.setColor(Config.COLORS.textPrimary)
    end
    love.graphics.print(backText, backBtnX + (backBtnW - backTextW) / 2, backBtnY + (backBtnH - backTextH) / 2)

    -- Instructions (bottom)
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    local scheme = _getColorScheme()
    love.graphics.printf(
        "Click center to start | Click node: allocate | Right-click: refund | Drag: pan | N: " .. scheme.name,
        0, gameH - 28, gameW, "center"
    )
end

function SkillTree.drawTooltip(node)
    local worldPos = state.nodePositions[node.id]
    if not worldPos then return end

    -- Convert world pos to screen for tooltip positioning
    local screenX, screenY = _worldToScreen(worldPos.x, worldPos.y)

    local padding = 10
    local tooltipWidth = 200
    local lineHeight = 16

    local lines = {}
    table.insert(lines, { text = node.name, color = Config.COLORS.gold, font = "medium" })
    table.insert(lines, { text = "", color = nil })

    for line in node.description:gmatch("[^\n]+") do
        table.insert(lines, { text = line, color = Config.COLORS.textPrimary, font = "small" })
    end

    table.insert(lines, { text = "", color = nil })

    local cost = node.cost
    if cost.crystals then
        table.insert(lines, {
            text = "Cost: " .. cost.crystals .. " Crystal" .. (cost.crystals > 1 and "s" or ""),
            color = Config.FLOATING_NUMBERS.crystalColor,
            font = "small"
        })
    else
        local shardCost = cost.shards or Config.SKILL_TREE.nodeCosts[node.tier] or 10
        table.insert(lines, {
            text = "Cost: " .. shardCost .. " Shards",
            color = Config.FLOATING_NUMBERS.shardColor,
            font = "small"
        })
    end

    if SkillTreeData.isAllocated(node.id) then
        table.insert(lines, { text = "[ALLOCATED]", color = Config.COLORS.emerald, font = "small" })
    elseif SkillTreeData.canAllocate(node.id) then
        table.insert(lines, { text = "[Click to allocate]", color = Config.SKILL_TREE.colors.available, font = "small" })
    elseif SkillTreeData.isAvailable(node.id) then
        table.insert(lines, { text = "[Cannot afford]", color = Config.COLORS.ruby, font = "small" })
    else
        table.insert(lines, { text = "[Locked - requires previous]", color = Config.COLORS.textDisabled, font = "small" })
    end

    local tooltipHeight = #lines * lineHeight + padding * 2

    local tooltipX = screenX + 20
    local tooltipY = screenY - tooltipHeight / 2

    local gameW, gameH = Settings.getGameDimensions()
    if tooltipX + tooltipWidth > gameW - 10 then
        tooltipX = screenX - tooltipWidth - 20
    end
    if tooltipY < 50 then tooltipY = 50 end
    if tooltipY + tooltipHeight > gameH - 30 then
        tooltipY = gameH - 30 - tooltipHeight
    end

    love.graphics.setColor(0.08, 0.06, 0.1, 0.95)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipWidth, tooltipHeight)

    love.graphics.setColor(Config.COLORS.frameMid)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipWidth, tooltipHeight)

    local y = tooltipY + padding
    for _, line in ipairs(lines) do
        if line.color then
            if line.font then Fonts.setFont(line.font) end
            love.graphics.setColor(line.color)
            love.graphics.print(line.text, tooltipX + padding, y)
        end
        y = y + lineHeight
    end
end

return SkillTree
