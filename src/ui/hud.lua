-- src/ui/hud.lua
-- Minimalistic HUD with compact bottom bar (Diablo/LoL style) and top-right void info
-- No background bar - just floating elements centered at the bottom

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Fonts = require("src.rendering.fonts")
local TurretConcepts = require("src.rendering.turret_concepts")
local Upgrades = require("src.systems.upgrades")

local HUD = {}

-- UI Style definitions (fantasy frames)
local UI_STYLES = {
    { name = "stone", label = "Stone" },
    { name = "wood", label = "Wood" },
    { name = "void", label = "Void" },
}

local state = {
    -- Screen dimensions (updated on init/resize)
    screenWidth = 0,
    screenHeight = 0,

    -- Calculated sizes (based on screen height)
    orbSize = 0,           -- Health/mana orb diameter
    iconSize = 0,          -- Tower icon size
    angerCircleSize = 0,   -- Top-right anger circle diameter

    -- Layout positions
    centerY = 0,           -- Y position for bottom HUD elements
    goldRowY = 0,          -- Y position for gold display

    -- Tower selection
    selectedTower = nil,
    towerButtons = {},
    upgradeButton = nil,   -- Auto-clicker button
    hoverButton = nil,

    -- Cached values
    cache = {
        gold = 0,
        lives = 0,
        maxLives = 0,
        waveNumber = 0,
        voidShards = 0,
        manaFill = 0,      -- Placeholder mana (0-1)
    },

    -- Animation state
    time = 0,

    -- UI Style system
    currentStyle = 1,        -- Index into UI_STYLES
    styleLabelTimer = 0,     -- Timer for showing style label (fades out)
    styleLabelDuration = 2,  -- How long to show style label
}

-- Tower types and hotkeys (from centralized config)
local TOWER_ORDER = Config.TOWER_UI_ORDER
local TOWER_KEYS = Config.TOWER_HOTKEYS

-- Calculate dynamic sizes based on screen dimensions
local function _calculateSizes()
    local height = state.screenHeight

    -- Smaller UI: reduced from 10% to 7% for orbs
    state.orbSize = math.floor(height * 0.07)

    -- Tower icon size: 5% of height
    state.iconSize = math.floor(height * 0.05)

    -- Anger circle: same as orb
    state.angerCircleSize = math.floor(height * 0.07)

    -- Bottom padding from screen edge
    local bottomPadding = 12

    -- Center Y for the main row (orbs + towers)
    state.centerY = state.screenHeight - bottomPadding - state.orbSize / 2

    -- Gold row above the main row
    state.goldRowY = state.centerY - state.orbSize / 2 - 20
end

-- Build button layouts for towers
local function _buildTowerButtons()
    local centerX = state.screenWidth / 2
    local iconSize = state.iconSize
    local iconSpacing = math.floor(iconSize * 0.15)  -- Tighter spacing

    -- Total width of tower row (5 towers + 1 upgrade button)
    local towerCount = #TOWER_ORDER
    local totalTowerWidth = towerCount * iconSize + (towerCount - 1) * iconSpacing

    -- Start position for towers (centered)
    local towerStartX = centerX - totalTowerWidth / 2

    -- Tower icon Y position (vertically centered with orbs)
    local iconY = state.centerY - iconSize / 2

    state.towerButtons = {}
    for i, towerType in ipairs(TOWER_ORDER) do
        local x = towerStartX + (i - 1) * (iconSize + iconSpacing)
        state.towerButtons[i] = {
            type = towerType,
            x = x,
            y = iconY,
            size = iconSize,
            hotkey = TOWER_KEYS[i],
        }
    end

    -- Auto-clicker button (after towers with small gap)
    local lastTower = state.towerButtons[#state.towerButtons]
    state.upgradeButton = {
        type = "autoClicker",
        x = lastTower.x + lastTower.size + iconSpacing * 2,
        y = iconY,
        size = iconSize,
        hotkey = "Q",
    }

    -- Calculate orb positions (adjacent to tower row)
    local firstTower = state.towerButtons[1]
    local orbGap = 10  -- Gap between orb and tower row

    state.healthOrbX = firstTower.x - orbGap - state.orbSize / 2
    state.manaOrbX = state.upgradeButton.x + state.upgradeButton.size + orbGap + state.orbSize / 2
end

function HUD.init(screenWidth, screenHeight)
    state.screenWidth = screenWidth
    state.screenHeight = screenHeight

    _calculateSizes()
    _buildTowerButtons()

    -- Initialize cache
    state.cache = {
        gold = Config.STARTING_GOLD,
        lives = Config.STARTING_LIVES,
        maxLives = Config.STARTING_LIVES,
        waveNumber = 0,
        voidShards = 0,
        manaFill = 0,
    }

    -- Reset upgrade levels
    state.upgradeLevels = { autoClicker = 0 }

    -- Subscribe to events
    EventBus.on("gold_changed", function(data)
        state.cache.gold = data.total
    end)

    EventBus.on("life_lost", function(data)
        state.cache.lives = data.remaining
    end)

    EventBus.on("wave_started", function(data)
        state.cache.waveNumber = data.waveNumber
    end)

    EventBus.on("void_shards_changed", function(data)
        state.cache.voidShards = data.total
    end)
end

function HUD.update(mouseX, mouseY)
    -- Update animation time
    local dt = love.timer.getDelta()
    state.time = state.time + dt

    -- Update style label timer (fade out)
    if state.styleLabelTimer > 0 then
        state.styleLabelTimer = state.styleLabelTimer - dt
    end

    -- Slowly fill mana as placeholder effect
    state.cache.manaFill = math.min(1, state.cache.manaFill + love.timer.getDelta() * 0.01)

    -- Check hover state
    state.hoverButton = nil

    -- Check tower buttons
    for _, btn in ipairs(state.towerButtons) do
        local halfSize = btn.size / 2
        local dx = mouseX - (btn.x + halfSize)
        local dy = mouseY - (btn.y + halfSize)
        if math.abs(dx) <= halfSize and math.abs(dy) <= halfSize then
            state.hoverButton = btn
            return
        end
    end

    -- Check upgrade button
    if state.upgradeButton then
        local btn = state.upgradeButton
        local halfSize = btn.size / 2
        local dx = mouseX - (btn.x + halfSize)
        local dy = mouseY - (btn.y + halfSize)
        if math.abs(dx) <= halfSize and math.abs(dy) <= halfSize then
            state.hoverButton = btn
        end
    end
end

function HUD.handleClick(x, y, economy)
    -- Check tower buttons
    for _, btn in ipairs(state.towerButtons) do
        local halfSize = btn.size / 2
        local dx = x - (btn.x + halfSize)
        local dy = y - (btn.y + halfSize)
        if math.abs(dx) <= halfSize and math.abs(dy) <= halfSize then
            state.selectedTower = btn.type
            return nil
        end
    end

    -- Check upgrade button
    if state.upgradeButton then
        local btn = state.upgradeButton
        local halfSize = btn.size / 2
        local dx = x - (btn.x + halfSize)
        local dy = y - (btn.y + halfSize)
        if math.abs(dx) <= halfSize and math.abs(dy) <= halfSize then
            local cost = HUD.getUpgradeCost("autoClicker")
            local upgradeConfig = Config.UPGRADES.panel.autoClicker
            local currentLevel = state.upgradeLevels.autoClicker or 0

            if currentLevel < upgradeConfig.maxLevel and economy.canAfford(cost) then
                return {action = "buy_upgrade", type = "autoClicker", cost = cost}
            end
            return nil
        end
    end

    return nil
end

-- =============================================================================
-- FANTASY FRAME SYSTEM
-- =============================================================================

-- Pixel size for UI (chunky pixel art)
local PIXEL = 2

-- Frame thickness for different elements
local FRAME = {
    thin = PIXEL * 2,
    medium = PIXEL * 3,
    thick = PIXEL * 4,
}

-- Color palettes for each style
local PALETTES = {
    stone = {
        dark = {0.18, 0.16, 0.14, 1},
        mid = {0.32, 0.30, 0.28, 1},
        light = {0.45, 0.42, 0.38, 1},
        highlight = {0.55, 0.52, 0.48, 0.8},
        bg = {0.10, 0.09, 0.08, 0.9},
        border = {0.40, 0.38, 0.35, 1},
    },
    wood = {
        dark = {0.25, 0.15, 0.08, 1},
        mid = {0.45, 0.28, 0.15, 1},
        light = {0.60, 0.40, 0.22, 1},
        highlight = {0.70, 0.50, 0.30, 0.8},
        bg = {0.15, 0.10, 0.06, 0.9},
        border = {0.50, 0.32, 0.18, 1},
    },
    void = {
        dark = {0.08, 0.04, 0.12, 1},
        mid = {0.20, 0.12, 0.30, 1},
        light = {0.35, 0.22, 0.50, 1},
        highlight = {0.55, 0.40, 0.80, 0.8},
        bg = {0.04, 0.02, 0.08, 0.9},
        border = {0.45, 0.30, 0.65, 1},
    },
}

-- Get current style
local function _getStyle()
    return UI_STYLES[state.currentStyle].name
end

-- Get current palette
local function _getPalette()
    return PALETTES[_getStyle()]
end

-- =============================================================================
-- DRAWING PRIMITIVES
-- =============================================================================

-- Draw a pixel rectangle (snapped to grid)
local function _rect(x, y, w, h, color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), w, h)
end

-- Draw horizontal line
local function _hline(x, y, w, color)
    _rect(x, y, w, PIXEL, color)
end

-- Draw vertical line
local function _vline(x, y, h, color)
    _rect(x, y, PIXEL, h, color)
end

-- Draw simple pixel border
local function _drawBorder(x, y, w, h, color)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    _hline(x, y, w, color)                    -- Top
    _hline(x, y + h - PIXEL, w, color)        -- Bottom
    _vline(x, y, h, color)                    -- Left
    _vline(x + w - PIXEL, y, h, color)        -- Right
end

-- =============================================================================
-- STONE FRAME - Heavy carved stone with beveled edges
-- =============================================================================

local function _drawStoneFrame(x, y, w, h)
    local p = PALETTES.stone
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)

    -- Outer dark edge
    _hline(x, y, w, p.dark)
    _hline(x, y + h - PIXEL, w, p.light)
    _vline(x, y, h, p.dark)
    _vline(x + w - PIXEL, y, h, p.light)

    -- Middle layer
    _hline(x + PIXEL, y + PIXEL, w - PIXEL * 2, p.mid)
    _hline(x + PIXEL, y + h - PIXEL * 2, w - PIXEL * 2, p.mid)
    _vline(x + PIXEL, y + PIXEL, h - PIXEL * 2, p.mid)
    _vline(x + w - PIXEL * 2, y + PIXEL, h - PIXEL * 2, p.mid)

    -- Inner bevel (light top-left, dark bottom-right for carved-in look)
    _hline(x + PIXEL * 2, y + PIXEL * 2, w - PIXEL * 4, p.dark)
    _vline(x + PIXEL * 2, y + PIXEL * 2, h - PIXEL * 4, p.dark)
    _hline(x + PIXEL * 2, y + h - PIXEL * 3, w - PIXEL * 4, p.highlight)
    _vline(x + w - PIXEL * 3, y + PIXEL * 2, h - PIXEL * 4, p.highlight)

    -- Background
    _rect(x + PIXEL * 3, y + PIXEL * 3, w - PIXEL * 6, h - PIXEL * 6, p.bg)
end

-- Stone orb socket - circular stone holder
local function _drawStoneOrbFrame(cx, cy, radius)
    local p = PALETTES.stone
    local r = radius + FRAME.thick

    -- Draw chunky square socket around orb
    local x, y = cx - r, cy - r
    local size = r * 2

    -- Outer stone block
    _rect(x, y, size, FRAME.medium, p.dark)  -- Top
    _rect(x, y + size - FRAME.medium, size, FRAME.medium, p.light)  -- Bottom
    _rect(x, y, FRAME.medium, size, p.dark)  -- Left
    _rect(x + size - FRAME.medium, y, FRAME.medium, size, p.light)  -- Right

    -- Corner blocks (thicker)
    _rect(x, y, FRAME.thick, FRAME.thick, p.mid)
    _rect(x + size - FRAME.thick, y, FRAME.thick, FRAME.thick, p.mid)
    _rect(x, y + size - FRAME.thick, FRAME.thick, FRAME.thick, p.mid)
    _rect(x + size - FRAME.thick, y + size - FRAME.thick, FRAME.thick, FRAME.thick, p.mid)

    -- Inner carved edge
    local inner = FRAME.medium
    _hline(x + inner, y + inner, size - inner * 2, p.highlight)
    _vline(x + inner, y + inner, size - inner * 2, p.highlight)
end

-- =============================================================================
-- WOOD FRAME - Planks with visible grain and nails
-- =============================================================================

local function _drawWoodFrame(x, y, w, h)
    local p = PALETTES.wood
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)

    -- Background
    _rect(x, y, w, h, p.bg)

    -- Horizontal planks (top and bottom)
    _rect(x, y, w, FRAME.medium, p.mid)
    _rect(x, y + h - FRAME.medium, w, FRAME.medium, p.mid)

    -- Wood grain on planks (horizontal lines)
    _hline(x + PIXEL * 2, y + PIXEL, w - PIXEL * 4, p.dark)
    _hline(x + PIXEL * 2, y + h - PIXEL * 2, w - PIXEL * 4, p.dark)

    -- Vertical posts (left and right)
    _rect(x, y, FRAME.medium, h, p.mid)
    _rect(x + w - FRAME.medium, y, FRAME.medium, h, p.mid)

    -- Wood grain on posts (vertical lines)
    _vline(x + PIXEL, y + PIXEL * 2, h - PIXEL * 4, p.dark)
    _vline(x + w - PIXEL * 2, y + PIXEL * 2, h - PIXEL * 4, p.dark)

    -- Nail heads at corners
    _rect(x + PIXEL, y + PIXEL, PIXEL, PIXEL, p.light)
    _rect(x + w - PIXEL * 2, y + PIXEL, PIXEL, PIXEL, p.light)
    _rect(x + PIXEL, y + h - PIXEL * 2, PIXEL, PIXEL, p.light)
    _rect(x + w - PIXEL * 2, y + h - PIXEL * 2, PIXEL, PIXEL, p.light)

    -- Highlight on top edges
    _hline(x, y, w, p.light)
    _vline(x, y, h, p.light)
end

-- Wood orb bracket - wooden holder with visible supports
local function _drawWoodOrbFrame(cx, cy, radius)
    local p = PALETTES.wood
    local r = radius + PIXEL * 2

    -- Four wooden brackets around the orb
    local bw = FRAME.medium  -- bracket width
    local bl = FRAME.thick + PIXEL * 2  -- bracket length

    -- Top bracket
    _rect(cx - bw/2, cy - r - bl, bw, bl, p.mid)
    _hline(cx - bw/2, cy - r - bl, bw, p.light)
    _vline(cx - bw/2, cy - r - bl, bl, p.light)

    -- Bottom bracket
    _rect(cx - bw/2, cy + r, bw, bl, p.mid)
    _hline(cx - bw/2, cy + r + bl - PIXEL, bw, p.dark)

    -- Left bracket
    _rect(cx - r - bl, cy - bw/2, bl, bw, p.mid)
    _vline(cx - r - bl, cy - bw/2, bw, p.light)

    -- Right bracket
    _rect(cx + r, cy - bw/2, bl, bw, p.mid)
    _vline(cx + r + bl - PIXEL, cy - bw/2, bw, p.dark)

    -- Wood grain details
    _vline(cx - PIXEL, cy - r - bl + PIXEL, bl - PIXEL * 2, p.dark)
    _vline(cx - PIXEL, cy + r + PIXEL, bl - PIXEL * 2, p.dark)
end

-- =============================================================================
-- VOID FRAME - Ethereal with floating particles
-- =============================================================================

local function _drawVoidFrame(x, y, w, h)
    local p = PALETTES.void
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    local time = state.time

    -- Background (darker)
    _rect(x, y, w, h, p.bg)

    -- Outer glow/edge (pulsing)
    local pulse = 0.7 + math.sin(time * 2) * 0.3
    local glowColor = {p.light[1], p.light[2], p.light[3], pulse * 0.6}

    _hline(x, y, w, glowColor)
    _hline(x, y + h - PIXEL, w, glowColor)
    _vline(x, y, h, glowColor)
    _vline(x + w - PIXEL, y, h, glowColor)

    -- Inner border
    _hline(x + PIXEL, y + PIXEL, w - PIXEL * 2, p.mid)
    _hline(x + PIXEL, y + h - PIXEL * 2, w - PIXEL * 2, p.mid)
    _vline(x + PIXEL, y + PIXEL, h - PIXEL * 2, p.mid)
    _vline(x + w - PIXEL * 2, y + PIXEL, h - PIXEL * 2, p.mid)

    -- Floating particles (4 corners, animated)
    local particleColor = {p.highlight[1], p.highlight[2], p.highlight[3], pulse}
    local offset = math.sin(time * 3) * PIXEL

    _rect(x + PIXEL * 2 + offset, y + PIXEL * 2, PIXEL, PIXEL, particleColor)
    _rect(x + w - PIXEL * 3 - offset, y + PIXEL * 2, PIXEL, PIXEL, particleColor)
    _rect(x + PIXEL * 2 - offset, y + h - PIXEL * 3, PIXEL, PIXEL, particleColor)
    _rect(x + w - PIXEL * 3 + offset, y + h - PIXEL * 3, PIXEL, PIXEL, particleColor)
end

-- Void orb portal - ethereal ring with particles
local function _drawVoidOrbFrame(cx, cy, radius)
    local p = PALETTES.void
    local time = state.time
    local r = radius + PIXEL * 3

    -- Pulsing outer ring (drawn as 8 segments)
    local pulse = 0.6 + math.sin(time * 2) * 0.4
    local segments = 8
    for i = 0, segments - 1 do
        local angle = (i / segments) * math.pi * 2 + time * 0.5
        local px = cx + math.cos(angle) * r
        local py = cy + math.sin(angle) * r
        local alpha = pulse * (0.5 + math.sin(time * 3 + i) * 0.5)
        _rect(px - PIXEL/2, py - PIXEL/2, PIXEL, PIXEL, {p.light[1], p.light[2], p.light[3], alpha})
    end

    -- Inner ring (static)
    local innerR = radius + PIXEL
    for i = 0, segments - 1 do
        local angle = (i / segments) * math.pi * 2
        local px = cx + math.cos(angle) * innerR
        local py = cy + math.sin(angle) * innerR
        _rect(px - PIXEL/2, py - PIXEL/2, PIXEL, PIXEL, p.mid)
    end

    -- Floating particles around orb
    for i = 1, 3 do
        local angle = time * (0.5 + i * 0.3) + i * 2
        local dist = r + PIXEL * 2 + math.sin(time * 2 + i) * PIXEL
        local px = cx + math.cos(angle) * dist
        local py = cy + math.sin(angle) * dist
        _rect(px - PIXEL/2, py - PIXEL/2, PIXEL, PIXEL, {p.highlight[1], p.highlight[2], p.highlight[3], 0.7})
    end
end

-- =============================================================================
-- UNIFIED DRAWING FUNCTIONS
-- =============================================================================

-- Draw panel frame (simplified - no decorations)
local function _drawStyledPanel(x, y, w, h, isSelected, isHovered)
    -- Selection highlight only
    if isSelected then
        local gold = Config.COLORS.gold
        love.graphics.setColor(gold)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, y, w, h)
    end
end

-- Draw orb frame (simplified - no decorations)
local function _drawOrbFrame(cx, cy, radius)
    -- No frame decorations
end

-- =============================================================================
-- ORB AND ELEMENT DRAWING
-- =============================================================================

-- Draw a filled circle (liquid effect) from bottom up
local function _drawFilledOrb(cx, cy, radius, fillPercent, liquidColor, glowColor)
    local time = state.time

    -- Simple dark background
    love.graphics.setColor(0.06, 0.05, 0.08, 0.85)
    love.graphics.circle("fill", cx, cy, radius)

    -- Calculate fill level (from bottom)
    local fillHeight = radius * 2 * fillPercent
    local fillTop = cy + radius - fillHeight

    -- Draw liquid fill using stencil
    love.graphics.stencil(function()
        love.graphics.circle("fill", cx, cy, radius - 2)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    -- Liquid fill
    if fillPercent > 0 then
        love.graphics.setColor(liquidColor[1], liquidColor[2], liquidColor[3], 0.8)

        -- Wobble the top surface
        local wobbleAmplitude = 2
        local segments = 16
        local vertices = {}

        for i = 0, segments do
            local wobble = math.sin(time * 3 + i * 0.5) * wobbleAmplitude * (1 - math.abs(i / segments - 0.5) * 2)
            local px = cx - radius + (i / segments) * radius * 2
            local py = fillTop + wobble
            table.insert(vertices, px)
            table.insert(vertices, py)
        end

        -- Add bottom corners
        table.insert(vertices, cx + radius)
        table.insert(vertices, cy + radius)
        table.insert(vertices, cx - radius)
        table.insert(vertices, cy + radius)

        if #vertices >= 6 then
            love.graphics.polygon("fill", vertices)
        end

        -- Surface highlight
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.4)
        love.graphics.setLineWidth(2)
        local surfaceVertices = {}
        for i = 0, segments do
            local wobble = math.sin(time * 3 + i * 0.5) * wobbleAmplitude * (1 - math.abs(i / segments - 0.5) * 2)
            local px = cx - radius + 4 + (i / segments) * (radius * 2 - 8)
            local py = fillTop + wobble
            table.insert(surfaceVertices, px)
            table.insert(surfaceVertices, py)
        end
        if #surfaceVertices >= 4 then
            love.graphics.line(surfaceVertices)
        end
    end

    love.graphics.setStencilTest()
end

-- Draw the anger circle (top right)
local function _drawAngerCircle(angerSystem)
    if not angerSystem then return end

    local padding = 20
    local radius = state.angerCircleSize / 2
    local cx = state.screenWidth - padding - radius
    local cy = padding + radius

    local angerLevel = angerSystem.getLevel()
    local maxAnger = angerSystem.getMaxLevel()
    local fillPercent = angerLevel / maxAnger
    local tier = angerSystem.getTier()

    -- Color based on tier
    local liquidColor, glowColor
    if tier >= 4 then
        liquidColor = {1.0, 0.15, 0.15}
        glowColor = {1.0, 0.4, 0.3}
    elseif tier >= 3 then
        liquidColor = {0.9, 0.25, 0.35}
        glowColor = {1.0, 0.5, 0.5}
    elseif tier >= 2 then
        liquidColor = {0.75, 0.25, 0.55}
        glowColor = {0.9, 0.5, 0.7}
    else
        liquidColor = {0.55, 0.25, 0.70}
        glowColor = {0.75, 0.5, 0.9}
    end

    _drawFilledOrb(cx, cy, radius, fillPercent, liquidColor, glowColor)

    -- Threshold markers (dotted lines at 25%, 50%, 75%)
    local thresholds = {0.25, 0.50, 0.75}
    love.graphics.setColor(0.5, 0.4, 0.6, 0.6)
    for _, threshold in ipairs(thresholds) do
        local markerY = cy + radius - (threshold * radius * 2)
        local dy = math.abs(markerY - cy)
        if dy < radius then
            local halfWidth = math.sqrt(radius * radius - dy * dy) - 4
            local dotSpacing = 6
            local dotSize = 2
            for dx = -halfWidth, halfWidth, dotSpacing do
                love.graphics.rectangle("fill", cx + dx - dotSize/2, markerY - dotSize/2, dotSize, dotSize)
            end
        end
    end

    -- Labels
    Fonts.setFont("small")
    love.graphics.setColor(0.7, 0.5, 0.8, 0.9)
    love.graphics.printf("ANGER", cx - radius, cy + radius + 8, radius * 2, "center")

    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.printf(angerLevel .. "/" .. maxAnger, cx - radius, cy + radius + 22, radius * 2, "center")
end

-- Draw wave info (below anger circle)
local function _drawWaveInfo(waves)
    if not waves then return end

    local padding = 20
    local radius = state.angerCircleSize / 2
    local cx = state.screenWidth - padding - radius
    local baseY = padding + state.angerCircleSize + 50

    local currentWave = waves.getWaveNumber()
    local totalWaves = waves.getTotalWaves()

    -- Draw styled panel for wave info
    local panelWidth = radius * 2 + 20
    local panelHeight = 44
    _drawStyledPanel(cx - radius - 10, baseY - 6, panelWidth, panelHeight, false, false)

    Fonts.setFont("medium")
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.printf("WAVE " .. currentWave, cx - radius - 10, baseY, panelWidth, "center")

    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    love.graphics.printf("of " .. totalWaves, cx - radius - 10, baseY + 22, panelWidth, "center")
end

-- Draw health orb
local function _drawHealthOrb(economy)
    local cx = state.healthOrbX
    local cy = state.centerY
    local radius = state.orbSize / 2

    local lives = economy.getLives()
    local maxLives = Config.STARTING_LIVES
    local fillPercent = lives / maxLives

    local liquidColor = {0.75, 0.20, 0.25}
    local glowColor = {1.0, 0.4, 0.4}

    _drawFilledOrb(cx, cy, radius, fillPercent, liquidColor, glowColor)

    -- Health text
    Fonts.setFont("medium")
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.printf(tostring(lives), cx - radius, cy - 8, radius * 2, "center")

    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    love.graphics.printf("HP", cx - radius, cy + 10, radius * 2, "center")
end

-- Draw mana orb (placeholder)
local function _drawManaOrb()
    local cx = state.manaOrbX
    local cy = state.centerY
    local radius = state.orbSize / 2

    local liquidColor = {0.25, 0.45, 0.75}
    local glowColor = {0.5, 0.7, 1.0}

    _drawFilledOrb(cx, cy, radius, state.cache.manaFill, liquidColor, glowColor)

    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    love.graphics.printf("MANA", cx - radius, cy + 2, radius * 2, "center")
end

-- Draw tower icon with proper pixel scaling
local function _drawTowerIcon(btn, economy, isSelected, isHovered)
    local towerConfig = Config.TOWERS[btn.type]
    local canAfford = economy.canAfford(towerConfig.cost)

    local cx = btn.x + btn.size / 2
    local cy = btn.y + btn.size / 2

    -- Selection highlight only
    if isSelected then
        love.graphics.setColor(Config.COLORS.gold)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", btn.x, btn.y, btn.size, btn.size)
    end

    -- Tower sprite - use integer scale for pixel-perfect rendering
    if towerConfig.voidVariant then
        if not canAfford then
            love.graphics.setColor(0.5, 0.5, 0.5)
        else
            love.graphics.setColor(1, 1, 1)
        end
        -- Calculate scale and floor it to avoid pixel gaps
        local baseScale = btn.size / 40
        local pixelScale = math.max(1, math.floor(baseScale))
        TurretConcepts.drawThumbnail(towerConfig.voidVariant, math.floor(cx), math.floor(cy), pixelScale)
    end

    -- Hotkey label (pixel-aligned)
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary[1], Config.COLORS.textSecondary[2], Config.COLORS.textSecondary[3], 0.8)
    love.graphics.print(btn.hotkey, math.floor(btn.x + btn.size - 10), math.floor(btn.y + btn.size - 14))

    -- Cost on hover
    if isHovered then
        if canAfford then
            love.graphics.setColor(Config.COLORS.gold)
        else
            love.graphics.setColor(Config.COLORS.textDisabled)
        end
        love.graphics.printf(towerConfig.cost .. "g", btn.x - 10, btn.y - 18, btn.size + 20, "center")
    end
end

-- Draw upgrade button
local function _drawUpgradeButton(economy)
    local btn = state.upgradeButton
    if not btn then return end

    local upgradeConfig = Config.UPGRADES.panel.autoClicker
    local currentLevel = state.upgradeLevels.autoClicker or 0
    local cost = HUD.getUpgradeCost("autoClicker")
    local isMaxLevel = currentLevel >= upgradeConfig.maxLevel
    local canAfford = not isMaxLevel and economy.canAfford(cost)
    local isHovered = state.hoverButton == btn

    local cx = btn.x + btn.size / 2
    local cy = btn.y + btn.size / 2

    -- Max level highlight
    if isMaxLevel then
        love.graphics.setColor(Config.COLORS.emerald[1], Config.COLORS.emerald[2], Config.COLORS.emerald[3], 0.5)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", btn.x, btn.y, btn.size, btn.size)
    end

    -- Clock icon (pixel-style)
    local clockRadius = math.floor(btn.size * 0.25)
    love.graphics.setColor(Config.COLORS.amethyst)
    -- Draw pixelated circle outline
    for angle = 0, math.pi * 2, math.pi / 8 do
        local px = cx + math.cos(angle) * clockRadius
        local py = cy - 4 + math.sin(angle) * clockRadius
        love.graphics.rectangle("fill", math.floor(px) - 1, math.floor(py) - 1, PIXEL, PIXEL)
    end
    -- Clock hand
    local handAngle = -math.pi / 2 + state.time * 2
    local handLength = btn.size * 0.18
    local handX = cx + math.cos(handAngle) * handLength
    local handY = cy - 4 + math.sin(handAngle) * handLength
    love.graphics.rectangle("fill", math.floor(handX) - 1, math.floor(handY) - 1, PIXEL, PIXEL)
    love.graphics.rectangle("fill", math.floor(cx) - 1, math.floor(cy - 4) - 1, PIXEL, PIXEL)

    -- Level
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    love.graphics.printf("Lv" .. currentLevel, btn.x, btn.y + btn.size - 14, btn.size, "center")

    -- Hotkey
    love.graphics.setColor(Config.COLORS.textSecondary[1], Config.COLORS.textSecondary[2], Config.COLORS.textSecondary[3], 0.8)
    love.graphics.print(btn.hotkey, math.floor(btn.x + btn.size - 10), math.floor(btn.y + 2))

    -- Cost on hover
    if isHovered and not isMaxLevel then
        if canAfford then
            love.graphics.setColor(Config.COLORS.gold)
        else
            love.graphics.setColor(Config.COLORS.textDisabled)
        end
        love.graphics.printf(cost .. "g", btn.x - 10, btn.y - 18, btn.size + 20, "center")
    elseif isHovered and isMaxLevel then
        love.graphics.setColor(Config.COLORS.emerald)
        love.graphics.printf("MAX", btn.x - 10, btn.y - 18, btn.size + 20, "center")
    end
end

-- Draw gold display (centered above towers)
local function _drawGoldDisplay(economy)
    local centerX = state.screenWidth / 2
    local goldText = tostring(economy.getGold()) .. "g"

    Fonts.setFont("medium")
    love.graphics.setColor(Config.COLORS.gold)
    love.graphics.printf(goldText, centerX - 40, state.goldRowY, 80, "center")
end

-- Draw container frame for tower icons (simplified - no container)
local function _drawTowerContainer()
    -- No container drawn
end

function HUD.draw(economy, angerSystem, waves, speedLabel)
    -- Gold display (above tower row)
    if economy then
        _drawGoldDisplay(economy)
    end

    -- Health orb (left of towers)
    if economy then
        _drawHealthOrb(economy)
    end

    -- Mana orb (right of towers)
    _drawManaOrb()

    -- Tower container (background frame for all tower icons)
    _drawTowerContainer()

    -- Tower icons (center)
    for _, btn in ipairs(state.towerButtons) do
        local isSelected = state.selectedTower == btn.type
        local isHovered = state.hoverButton == btn
        _drawTowerIcon(btn, economy, isSelected, isHovered)
    end

    -- Upgrade button
    if economy then
        _drawUpgradeButton(economy)
    end

    -- Top-right: Anger circle
    _drawAngerCircle(angerSystem)

    -- Top-right: Wave info
    _drawWaveInfo(waves)

    -- Speed indicator
    if speedLabel then
        local padding = 20
        local radius = state.angerCircleSize / 2
        local cx = state.screenWidth - padding - radius
        local baseY = padding + state.angerCircleSize + 100

        -- Draw styled panel for speed
        local panelWidth = radius * 2 + 20
        Fonts.setFont("small")
        if speedLabel == "||" then
            love.graphics.setColor(Config.COLORS.ruby)
        elseif speedLabel == "x5" or speedLabel == "x50" then
            love.graphics.setColor(Config.COLORS.emerald)
        else
            love.graphics.setColor(Config.COLORS.textSecondary)
        end
        love.graphics.printf(speedLabel, cx - radius - 10, baseY, panelWidth, "center")
    end
end

-- Get cost for an upgrade at current level (delegated to Upgrades system)
function HUD.getUpgradeCost(upgradeType)
    return Upgrades.getCost(upgradeType)
end

-- Purchase an upgrade (delegated to Upgrades system)
function HUD.purchaseUpgrade(upgradeType)
    return Upgrades.purchase(upgradeType)
end

function HUD.getUpgradeLevel(upgradeType)
    return Upgrades.getLevel(upgradeType)
end

function HUD.getAutoClickInterval()
    return Upgrades.getAutoClickInterval()
end

function HUD.getSelectedTower()
    return state.selectedTower
end

function HUD.getSelectedTowerCost()
    if not state.selectedTower then return 0 end
    return Config.TOWERS[state.selectedTower].cost
end

function HUD.selectTower(towerType)
    state.selectedTower = towerType
end

function HUD.isHoveringButton()
    return state.hoverButton ~= nil
end

-- Check if point is in HUD area (for click priority)
function HUD.isPointInHUD(x, y)
    -- Check tower buttons
    for _, btn in ipairs(state.towerButtons) do
        if x >= btn.x and x <= btn.x + btn.size and
           y >= btn.y and y <= btn.y + btn.size then
            return true
        end
    end

    -- Check upgrade button
    if state.upgradeButton then
        local btn = state.upgradeButton
        if x >= btn.x and x <= btn.x + btn.size and
           y >= btn.y and y <= btn.y + btn.size then
            return true
        end
    end

    -- Check health orb
    local healthDx = x - state.healthOrbX
    local healthDy = y - state.centerY
    local orbRadius = state.orbSize / 2 + 5
    if healthDx * healthDx + healthDy * healthDy <= orbRadius * orbRadius then
        return true
    end

    -- Check mana orb
    local manaDx = x - state.manaOrbX
    local manaDy = y - state.centerY
    if manaDx * manaDx + manaDy * manaDy <= orbRadius * orbRadius then
        return true
    end

    -- Top-right anger circle area
    local padding = 20
    local radius = state.angerCircleSize / 2
    local cx = state.screenWidth - padding - radius
    local cy = padding + radius
    local dx = x - cx
    local dy = y - cy
    if dx * dx + dy * dy <= (radius + 20) * (radius + 20) then
        return true
    end

    return false
end

function HUD.getBarY()
    return state.centerY - state.orbSize / 2
end

function HUD.getX()
    return state.screenWidth
end

-- Cycle to the next UI style
function HUD.cycleStyle()
    state.currentStyle = state.currentStyle + 1
    if state.currentStyle > #UI_STYLES then
        state.currentStyle = 1
    end
    state.styleLabelTimer = state.styleLabelDuration
    return UI_STYLES[state.currentStyle].name
end

-- Get current UI style name
function HUD.getCurrentStyle()
    return UI_STYLES[state.currentStyle].name
end

return HUD
