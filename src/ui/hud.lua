-- src/ui/hud.lua
-- Minimalistic HUD with compact bottom bar (Diablo/LoL style) and top-right void info
-- No background bar - just floating elements centered at the bottom

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Fonts = require("src.rendering.fonts")
local TurretConcepts = require("src.rendering.turret_concepts")

local HUD = {}

-- UI Style definitions (ancient stone variants)
local UI_STYLES = {
    { name = "weathered", label = "Weathered Stone" },
    { name = "obsidian", label = "Obsidian" },
    { name = "rusted", label = "Rusted Iron" },
    { name = "bone", label = "Carved Bone" },
    { name = "frozen", label = "Frozen Stone" },
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

    -- Upgrade levels
    upgradeLevels = {
        autoClicker = 0,
    },

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

-- Tower types and hotkeys
local TOWER_ORDER = {"void_orb", "void_ring", "void_bolt", "void_eye", "void_star"}
local TOWER_KEYS = {"1", "2", "3", "4", "5"}

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
-- PIXEL-ART UI STYLE SYSTEM
-- =============================================================================

-- Pixel size for UI elements (intentionally chunky)
local PIXEL = 2

-- Creative ancient stone variant palettes
local STYLE_PALETTES = {
    weathered = {
        -- Classic gray stone with moss hints
        bg = {0.14, 0.13, 0.12, 0.9},
        bgLight = {0.20, 0.19, 0.17, 0.85},
        border = {0.35, 0.32, 0.28, 1.0},
        borderLight = {0.50, 0.47, 0.40, 0.9},
        highlight = {0.60, 0.58, 0.50, 0.7},
        shadow = {0.08, 0.07, 0.06, 0.9},
        crack = {0.18, 0.16, 0.14, 0.8},
        detail = {0.25, 0.30, 0.22, 0.5},  -- Moss green hint
    },
    obsidian = {
        -- Black volcanic glass, sharp and reflective
        bg = {0.05, 0.05, 0.08, 0.95},
        bgLight = {0.10, 0.10, 0.14, 0.9},
        border = {0.20, 0.20, 0.28, 1.0},
        borderLight = {0.35, 0.35, 0.50, 0.9},
        highlight = {0.70, 0.70, 0.85, 0.6},  -- Glass reflection
        shadow = {0.02, 0.02, 0.04, 1.0},
        crack = {0.30, 0.30, 0.45, 0.7},  -- Purple-tinted cracks
        detail = {0.50, 0.50, 0.70, 0.4},  -- Glint
    },
    rusted = {
        -- Corroded iron with orange patina
        bg = {0.12, 0.08, 0.06, 0.9},
        bgLight = {0.18, 0.12, 0.08, 0.85},
        border = {0.45, 0.28, 0.18, 1.0},
        borderLight = {0.60, 0.40, 0.25, 0.9},
        highlight = {0.70, 0.55, 0.40, 0.7},
        shadow = {0.06, 0.04, 0.03, 0.9},
        crack = {0.55, 0.30, 0.15, 0.8},  -- Rust orange
        detail = {0.30, 0.25, 0.20, 0.6},  -- Dark iron
    },
    bone = {
        -- Carved ivory/bone, warm and organic
        bg = {0.20, 0.18, 0.15, 0.9},
        bgLight = {0.28, 0.25, 0.20, 0.85},
        border = {0.55, 0.50, 0.42, 1.0},
        borderLight = {0.70, 0.65, 0.55, 0.9},
        highlight = {0.85, 0.80, 0.70, 0.7},
        shadow = {0.12, 0.10, 0.08, 0.9},
        crack = {0.35, 0.30, 0.25, 0.7},  -- Aged bone
        detail = {0.45, 0.38, 0.30, 0.5},  -- Etching
    },
    frozen = {
        -- Icy stone with frost crystals
        bg = {0.12, 0.15, 0.20, 0.9},
        bgLight = {0.18, 0.22, 0.28, 0.85},
        border = {0.40, 0.50, 0.60, 1.0},
        borderLight = {0.55, 0.65, 0.75, 0.9},
        highlight = {0.80, 0.90, 1.00, 0.7},  -- Ice glint
        shadow = {0.06, 0.08, 0.12, 0.9},
        crack = {0.50, 0.60, 0.75, 0.8},  -- Frost blue
        detail = {0.70, 0.80, 0.95, 0.5},  -- Crystal
    },
}

-- Get current style name
local function _getStyleName()
    return UI_STYLES[state.currentStyle].name
end

-- Get current palette
local function _getPalette()
    return STYLE_PALETTES[_getStyleName()]
end

-- Simple hash for deterministic randomness (Lua 5.1 compatible)
local function _hash(x, y)
    local h = (x * 374761393 + y * 668265263) % 2147483647
    h = ((h * 1274126177) % 2147483647)
    return (h % 256) / 255
end

-- =============================================================================
-- PIXEL DRAWING PRIMITIVES (simple, fast)
-- =============================================================================

-- Draw pixel-perfect border
local function _drawBorder(x, y, w, h, color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", x, y, w, PIXEL)           -- Top
    love.graphics.rectangle("fill", x, y + h - PIXEL, w, PIXEL)  -- Bottom
    love.graphics.rectangle("fill", x, y, PIXEL, h)           -- Left
    love.graphics.rectangle("fill", x + w - PIXEL, y, PIXEL, h)  -- Right
end

-- Draw L-bracket corners
local function _drawCorners(x, y, w, h, color, size)
    size = size or PIXEL * 3
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    -- TL
    love.graphics.rectangle("fill", x, y, size, PIXEL)
    love.graphics.rectangle("fill", x, y, PIXEL, size)
    -- TR
    love.graphics.rectangle("fill", x + w - size, y, size, PIXEL)
    love.graphics.rectangle("fill", x + w - PIXEL, y, PIXEL, size)
    -- BL
    love.graphics.rectangle("fill", x, y + h - PIXEL, size, PIXEL)
    love.graphics.rectangle("fill", x, y + h - size, PIXEL, size)
    -- BR
    love.graphics.rectangle("fill", x + w - size, y + h - PIXEL, size, PIXEL)
    love.graphics.rectangle("fill", x + w - PIXEL, y + h - size, PIXEL, size)
end

-- Draw inner shadow (top-left dark, bottom-right light)
local function _drawInnerBevel(x, y, w, h, shadowColor, highlightColor)
    -- Shadow on top and left (inside)
    love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowColor[4] or 1)
    love.graphics.rectangle("fill", x + PIXEL, y + PIXEL, w - PIXEL * 2, PIXEL)
    love.graphics.rectangle("fill", x + PIXEL, y + PIXEL, PIXEL, h - PIXEL * 2)
    -- Highlight on bottom and right (inside)
    love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], highlightColor[4] or 1)
    love.graphics.rectangle("fill", x + PIXEL, y + h - PIXEL * 2, w - PIXEL * 2, PIXEL)
    love.graphics.rectangle("fill", x + w - PIXEL * 2, y + PIXEL, PIXEL, h - PIXEL * 2)
end

-- Draw crack detail pixels
local function _drawCracks(x, y, w, h, color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    -- Diagonal crack from top-left
    love.graphics.rectangle("fill", x + PIXEL * 3, y + PIXEL * 2, PIXEL, PIXEL)
    love.graphics.rectangle("fill", x + PIXEL * 4, y + PIXEL * 3, PIXEL, PIXEL)
    -- Crack from bottom-right
    love.graphics.rectangle("fill", x + w - PIXEL * 4, y + h - PIXEL * 3, PIXEL, PIXEL)
    love.graphics.rectangle("fill", x + w - PIXEL * 5, y + h - PIXEL * 4, PIXEL, PIXEL)
end

-- Draw rivet dots (for rusted iron)
local function _drawRivets(x, y, w, h, color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    local spacing = math.max(PIXEL * 4, math.floor(w / 5))
    for px = x + PIXEL * 2, x + w - PIXEL * 3, spacing do
        love.graphics.rectangle("fill", px, y + PIXEL, PIXEL, PIXEL)
        love.graphics.rectangle("fill", px, y + h - PIXEL * 2, PIXEL, PIXEL)
    end
end

-- Draw frost crystals (for frozen)
local function _drawFrost(x, y, w, h, color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    -- Small crystal patterns at corners
    love.graphics.rectangle("fill", x + PIXEL * 2, y + PIXEL, PIXEL, PIXEL)
    love.graphics.rectangle("fill", x + PIXEL, y + PIXEL * 2, PIXEL, PIXEL)
    love.graphics.rectangle("fill", x + w - PIXEL * 3, y + PIXEL, PIXEL, PIXEL)
    love.graphics.rectangle("fill", x + w - PIXEL * 2, y + PIXEL * 2, PIXEL, PIXEL)
    love.graphics.rectangle("fill", x + PIXEL * 2, y + h - PIXEL * 2, PIXEL, PIXEL)
    love.graphics.rectangle("fill", x + w - PIXEL * 3, y + h - PIXEL * 2, PIXEL, PIXEL)
end

-- Draw etched lines (for bone)
local function _drawEtching(x, y, w, h, color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    -- Horizontal etched lines
    if h > PIXEL * 6 then
        love.graphics.rectangle("fill", x + PIXEL * 2, y + PIXEL * 2, w - PIXEL * 4, PIXEL)
        love.graphics.rectangle("fill", x + PIXEL * 2, y + h - PIXEL * 3, w - PIXEL * 4, PIXEL)
    end
end

-- =============================================================================
-- MAIN STYLED PANEL DRAWING
-- =============================================================================

-- Draw styled panel (background + layered border + details)
local function _drawStyledPanel(x, y, w, h, isSelected, isHovered)
    local styleName = _getStyleName()
    local pal = _getPalette()

    -- Snap to pixel grid
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)

    -- Base background
    love.graphics.setColor(pal.bg[1], pal.bg[2], pal.bg[3], pal.bg[4])
    love.graphics.rectangle("fill", x, y, w, h)

    -- Border color (selection state)
    local borderColor = pal.border
    if isSelected then
        borderColor = {Config.COLORS.gold[1], Config.COLORS.gold[2], Config.COLORS.gold[3], 1}
    elseif isHovered then
        borderColor = pal.borderLight
    end

    -- Style-specific layering
    if styleName == "weathered" then
        -- Layered stone: outer border, inner shadow, cracks
        _drawBorder(x, y, w, h, borderColor)
        _drawInnerBevel(x, y, w, h, pal.shadow, pal.highlight)
        _drawCracks(x, y, w, h, pal.crack)
        -- Moss hint pixel
        love.graphics.setColor(pal.detail[1], pal.detail[2], pal.detail[3], pal.detail[4])
        love.graphics.rectangle("fill", x + PIXEL, y + h - PIXEL * 2, PIXEL, PIXEL)

    elseif styleName == "obsidian" then
        -- Sharp glass: double border, bright highlight corner
        _drawBorder(x, y, w, h, pal.shadow)
        _drawBorder(x + PIXEL, y + PIXEL, w - PIXEL * 2, h - PIXEL * 2, borderColor)
        _drawCorners(x, y, w, h, pal.highlight, PIXEL * 2)
        -- Glass reflection
        love.graphics.setColor(pal.detail[1], pal.detail[2], pal.detail[3], pal.detail[4])
        love.graphics.rectangle("fill", x + PIXEL * 2, y + PIXEL * 2, PIXEL * 2, PIXEL)

    elseif styleName == "rusted" then
        -- Metal: border, rivets, rust patches
        _drawBorder(x, y, w, h, borderColor)
        _drawInnerBevel(x, y, w, h, pal.shadow, pal.highlight)
        _drawRivets(x, y, w, h, pal.detail)
        -- Rust spot
        love.graphics.setColor(pal.crack[1], pal.crack[2], pal.crack[3], pal.crack[4])
        love.graphics.rectangle("fill", x + w - PIXEL * 3, y + PIXEL * 3, PIXEL, PIXEL)
        love.graphics.rectangle("fill", x + PIXEL * 2, y + h - PIXEL * 4, PIXEL * 2, PIXEL)

    elseif styleName == "bone" then
        -- Carved bone: rounded feel, etched details
        _drawBorder(x, y, w, h, borderColor)
        _drawInnerBevel(x, y, w, h, pal.shadow, pal.highlight)
        _drawEtching(x, y, w, h, pal.detail)
        _drawCorners(x, y, w, h, pal.borderLight, PIXEL * 2)

    elseif styleName == "frozen" then
        -- Icy stone: cold colors, frost crystals
        _drawBorder(x, y, w, h, borderColor)
        _drawInnerBevel(x, y, w, h, pal.shadow, pal.highlight)
        _drawFrost(x, y, w, h, pal.detail)
        _drawCracks(x, y, w, h, pal.crack)
    end
end

-- =============================================================================
-- ORB AND ELEMENT DRAWING
-- =============================================================================

-- Draw circular decorations around an orb
local function _drawOrbDecorations(cx, cy, radius)
    local pal = _getPalette()
    local outerRadius = radius + 4

    -- Outer pixel ring (weathered stone border)
    love.graphics.setColor(pal.border[1], pal.border[2], pal.border[3], 0.9)
    local segments = 24
    for i = 0, segments - 1 do
        local angle = (i / segments) * math.pi * 2
        local px = cx + math.cos(angle) * outerRadius
        local py = cy + math.sin(angle) * outerRadius
        -- Skip some pixels for weathered look
        if _hash(i, math.floor(cx)) > 0.2 then
            love.graphics.rectangle("fill", math.floor(px) - 1, math.floor(py) - 1, PIXEL, PIXEL)
        end
    end

    -- Corner bracket decorations (at 4 cardinal positions)
    local bracketRadius = outerRadius + 3
    local bracketPositions = {
        {angle = -math.pi/2},  -- Top
        {angle = math.pi/2},   -- Bottom
        {angle = 0},           -- Right
        {angle = math.pi},     -- Left
    }

    love.graphics.setColor(pal.borderLight[1], pal.borderLight[2], pal.borderLight[3], 0.7)
    for _, pos in ipairs(bracketPositions) do
        local bx = cx + math.cos(pos.angle) * bracketRadius
        local by = cy + math.sin(pos.angle) * bracketRadius
        -- Draw small pixel
        love.graphics.rectangle("fill", math.floor(bx) - 1, math.floor(by) - 1, PIXEL, PIXEL)
        -- Extend perpendicular
        local perpAngle = pos.angle + math.pi/2
        local ex1 = bx + math.cos(perpAngle) * 3
        local ey1 = by + math.sin(perpAngle) * 3
        love.graphics.rectangle("fill", math.floor(ex1) - 1, math.floor(ey1) - 1, PIXEL, PIXEL)
    end

    -- Crack details radiating from orb
    local crack = pal.crack or {0.2, 0.15, 0.15, 0.6}
    love.graphics.setColor(crack[1], crack[2], crack[3], crack[4] or 0.6)
    -- Top-left crack
    love.graphics.rectangle("fill", math.floor(cx - radius * 0.7) - 1, math.floor(cy - radius - 6), PIXEL, PIXEL * 2)
    -- Bottom-right crack
    love.graphics.rectangle("fill", math.floor(cx + radius * 0.6), math.floor(cy + radius + 4), PIXEL, PIXEL * 2)
end

-- Draw a filled circle (liquid effect) from bottom up
local function _drawFilledOrb(cx, cy, radius, fillPercent, liquidColor, glowColor)
    local time = state.time

    -- Outer ring (dark border)
    love.graphics.setColor(0.08, 0.06, 0.10, 0.95)
    love.graphics.circle("fill", cx, cy, radius + 3)

    -- Inner background (dark)
    love.graphics.setColor(0.04, 0.03, 0.06, 0.9)
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

    -- Rim highlight
    love.graphics.setColor(0.3, 0.25, 0.35, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.arc("line", "open", cx, cy, radius - 1, -math.pi * 0.8, -math.pi * 0.2)

    -- Circular decorations around orb (ancient stone style)
    _drawOrbDecorations(cx, cy, radius)
end

-- Draw the anger circle (top right)
local function _drawAngerCircle(voidEntity)
    if not voidEntity then return end

    local padding = 20
    local radius = state.angerCircleSize / 2
    local cx = state.screenWidth - padding - radius
    local cy = padding + radius

    local clickCount = voidEntity:getClickCount()
    local maxClicks = voidEntity:getMaxClicks()
    local fillPercent = clickCount / maxClicks
    local tier = voidEntity:getTier()

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
    love.graphics.printf(clickCount .. "/" .. maxClicks, cx - radius, cy + radius + 22, radius * 2, "center")
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

    -- Draw styled panel (background + border + decorations)
    _drawStyledPanel(btn.x, btn.y, btn.size, btn.size, isSelected, isHovered)

    -- Dim overlay if can't afford
    if not canAfford then
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", btn.x + PIXEL, btn.y + PIXEL, btn.size - PIXEL * 2, btn.size - PIXEL * 2)
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

    -- Draw styled panel (background + border + decorations)
    _drawStyledPanel(btn.x, btn.y, btn.size, btn.size, isMaxLevel, isHovered)

    -- Dim overlay if can't afford
    if not canAfford and not isMaxLevel then
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", btn.x + PIXEL, btn.y + PIXEL, btn.size - PIXEL * 2, btn.size - PIXEL * 2)
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

    -- Calculate text width for panel sizing
    local panelWidth = 80
    local panelHeight = 24
    local panelX = centerX - panelWidth / 2
    local panelY = state.goldRowY - 4

    -- Draw styled background for gold
    _drawStyledPanel(panelX, panelY, panelWidth, panelHeight, false, false)

    Fonts.setFont("medium")
    love.graphics.setColor(Config.COLORS.gold)
    love.graphics.printf(goldText, panelX, panelY + 4, panelWidth, "center")
end

-- Draw container frame for tower icons (groups them visually)
local function _drawTowerContainer()
    if #state.towerButtons == 0 then return end

    local firstBtn = state.towerButtons[1]
    local lastBtn = state.upgradeButton or state.towerButtons[#state.towerButtons]

    -- Calculate container bounds with padding
    local padding = 6
    local containerX = firstBtn.x - padding
    local containerY = firstBtn.y - padding
    local containerW = (lastBtn.x + lastBtn.size) - firstBtn.x + padding * 2
    local containerH = firstBtn.size + padding * 2

    local pal = _getPalette()

    -- Draw subtle background
    love.graphics.setColor(pal.bg[1] * 0.7, pal.bg[2] * 0.7, pal.bg[3] * 0.7, 0.5)
    love.graphics.rectangle("fill", containerX, containerY, containerW, containerH)

    -- Draw weathered border (ancient stone style)
    love.graphics.setColor(pal.border[1], pal.border[2], pal.border[3], 0.6)

    -- Top border with gaps
    for px = 0, containerW - PIXEL, PIXEL do
        if _hash(px, containerY) > 0.15 then
            love.graphics.rectangle("fill", containerX + px, containerY, PIXEL, PIXEL)
        end
    end
    -- Bottom border with gaps
    for px = 0, containerW - PIXEL, PIXEL do
        if _hash(px, containerY + containerH) > 0.15 then
            love.graphics.rectangle("fill", containerX + px, containerY + containerH - PIXEL, PIXEL, PIXEL)
        end
    end
    -- Left border with gaps
    for py = 0, containerH - PIXEL, PIXEL do
        if _hash(containerX, py) > 0.2 then
            love.graphics.rectangle("fill", containerX, containerY + py, PIXEL, PIXEL)
        end
    end
    -- Right border with gaps
    for py = 0, containerH - PIXEL, PIXEL do
        if _hash(containerX + containerW, py) > 0.2 then
            love.graphics.rectangle("fill", containerX + containerW - PIXEL, containerY + py, PIXEL, PIXEL)
        end
    end

    -- Corner accents (solid L-brackets)
    love.graphics.setColor(pal.borderLight[1], pal.borderLight[2], pal.borderLight[3], 0.8)
    local cornerSize = PIXEL * 4

    -- Top-left corner
    love.graphics.rectangle("fill", containerX, containerY, cornerSize, PIXEL)
    love.graphics.rectangle("fill", containerX, containerY, PIXEL, cornerSize)

    -- Top-right corner
    love.graphics.rectangle("fill", containerX + containerW - cornerSize, containerY, cornerSize, PIXEL)
    love.graphics.rectangle("fill", containerX + containerW - PIXEL, containerY, PIXEL, cornerSize)

    -- Bottom-left corner
    love.graphics.rectangle("fill", containerX, containerY + containerH - PIXEL, cornerSize, PIXEL)
    love.graphics.rectangle("fill", containerX, containerY + containerH - cornerSize, PIXEL, cornerSize)

    -- Bottom-right corner
    love.graphics.rectangle("fill", containerX + containerW - cornerSize, containerY + containerH - PIXEL, cornerSize, PIXEL)
    love.graphics.rectangle("fill", containerX + containerW - PIXEL, containerY + containerH - cornerSize, PIXEL, cornerSize)

    -- Crack details
    love.graphics.setColor(pal.crack[1] or 0.2, pal.crack[2] or 0.15, pal.crack[3] or 0.15, 0.5)
    -- Crack from top-left
    love.graphics.rectangle("fill", containerX + cornerSize + 2, containerY + PIXEL, PIXEL, PIXEL * 2)
    -- Crack from bottom-right
    love.graphics.rectangle("fill", containerX + containerW - cornerSize - 4, containerY + containerH - PIXEL * 3, PIXEL, PIXEL * 2)
end

function HUD.draw(economy, voidEntity, waves, speedLabel)
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
    _drawAngerCircle(voidEntity)

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
        local panelHeight = 22
        _drawStyledPanel(cx - radius - 10, baseY - 4, panelWidth, panelHeight, false, false)

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

    -- Style label (shows briefly when cycling styles)
    if state.styleLabelTimer > 0 then
        local alpha = math.min(1, state.styleLabelTimer / 0.5)  -- Fade out in last 0.5s
        local styleLabel = UI_STYLES[state.currentStyle].label

        -- Draw centered at top of screen
        local labelY = 60
        local labelWidth = 200
        local labelHeight = 30
        local labelX = state.screenWidth / 2 - labelWidth / 2

        -- Draw styled background with alpha
        local pal = _getPalette()
        love.graphics.setColor(pal.bg[1], pal.bg[2], pal.bg[3], pal.bg[4] * alpha)
        love.graphics.rectangle("fill", labelX, labelY - 5, labelWidth, labelHeight)

        -- Pixel border with alpha
        _drawBorder(labelX, labelY - 5, labelWidth, labelHeight,
            {pal.border[1], pal.border[2], pal.border[3], alpha})

        -- Text
        Fonts.setFont("medium")
        love.graphics.setColor(Config.COLORS.textPrimary[1], Config.COLORS.textPrimary[2], Config.COLORS.textPrimary[3], alpha)
        love.graphics.printf("UI: " .. styleLabel, labelX, labelY, labelWidth, "center")
    end
end

-- Get cost for an upgrade at current level
function HUD.getUpgradeCost(upgradeType)
    local upgradeConfig = Config.UPGRADES.panel[upgradeType]
    if not upgradeConfig then return 0 end

    local currentLevel = state.upgradeLevels[upgradeType] or 0
    if currentLevel >= upgradeConfig.maxLevel then
        return 0
    end

    return math.floor(upgradeConfig.baseCost * (upgradeConfig.costMultiplier ^ currentLevel))
end

-- Purchase an upgrade
function HUD.purchaseUpgrade(upgradeType)
    local upgradeConfig = Config.UPGRADES.panel[upgradeType]
    if not upgradeConfig then return false end

    local currentLevel = state.upgradeLevels[upgradeType] or 0
    if currentLevel >= upgradeConfig.maxLevel then
        return false
    end

    state.upgradeLevels[upgradeType] = currentLevel + 1
    return true
end

function HUD.getUpgradeLevel(upgradeType)
    return state.upgradeLevels[upgradeType] or 0
end

function HUD.getAutoClickInterval()
    local level = state.upgradeLevels.autoClicker or 0
    if level == 0 then return nil end

    local config = Config.UPGRADES.panel.autoClicker
    return config.baseInterval - ((level - 1) * config.intervalReduction)
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
