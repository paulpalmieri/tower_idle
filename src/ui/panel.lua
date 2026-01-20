-- src/ui/panel.lua
-- Right-side UI panel with minimalist 8-bit aesthetic
-- Compact layout: unified stats/void, tower cards, collapsible upgrades

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Fonts = require("src.rendering.fonts")
local PixelFrames = require("src.ui.pixel_frames")
local PixelArt = require("src.rendering.pixel_art")
local TurretConcepts = require("src.rendering.turret_concepts")

local Panel = {}

local state = {
    x = 0,
    width = 0,
    height = 0,
    selectedTower = nil,
    towerButtons = {},
    upgradeButtons = {},
    hoverButton = nil,
    upgradeLevels = {
        autoClicker = 0,
    },
    upgradesExpanded = false,  -- Collapsible upgrades state
    upgradesHeaderBounds = nil, -- Click area for expand/collapse
    -- Dynamic layout positions
    layout = {
        statsY = 0,
        statsHeight = 0,
        towersY = 0,
        towersHeight = 0,
        upgradesY = 0,
        upgradesHeight = 0,
    },
    -- Cached values from events
    cache = {
        gold = 0,
        income = 0,
        incomeProgress = 0,
        lives = 0,
        waveNumber = 0,
    },
}

-- Tower types in order
local TOWER_ORDER = {"void_orb", "void_ring", "void_bolt", "void_eye", "void_star"}
local TOWER_KEYS = {"1", "2", "3", "4", "5"}

-- Upgrade types in order
local UPGRADE_ORDER = {"autoClicker"}
local UPGRADE_KEYS = {"Q"}

-- Calculate dynamic layout based on content
local function _calculateLayout(height)
    local padding = Config.UI.padding
    local buttonHeight = Config.UI.buttonHeight
    local buttonSpacing = Config.UI.buttonSpacing
    local sectionSpacing = Config.UI.LAYOUT.sectionSpacing

    -- Stats section (combined stats + void bar)
    local statsHeight = Config.UI.LAYOUT.statsHeight

    -- Tower cards
    local towerCount = #TOWER_ORDER
    local towersHeight = towerCount * buttonHeight + (towerCount - 1) * buttonSpacing

    -- Upgrades section (collapsible)
    local upgradesHeaderHeight = 28
    local upgradeCount = #UPGRADE_ORDER
    local upgradesContentHeight = upgradeCount * buttonHeight + (upgradeCount - 1) * buttonSpacing
    local upgradesHeight = state.upgradesExpanded and (upgradesHeaderHeight + upgradesContentHeight + buttonSpacing) or upgradesHeaderHeight

    -- Position sections from top
    local y = padding

    state.layout.statsY = y
    state.layout.statsHeight = statsHeight
    y = y + statsHeight + sectionSpacing

    state.layout.towersY = y
    state.layout.towersHeight = towersHeight
    y = y + towersHeight + sectionSpacing

    state.layout.upgradesY = y
    state.layout.upgradesHeight = upgradesHeight
end

function Panel.init(playAreaWidth, panelWidth, height)
    state.x = playAreaWidth
    state.width = panelWidth
    state.height = height

    -- Calculate dynamic layout
    _calculateLayout(height)

    local padding = Config.UI.padding
    local buttonHeight = Config.UI.buttonHeight
    local buttonSpacing = Config.UI.buttonSpacing
    local buttonWidth = panelWidth - padding * 2

    -- Build tower button layouts
    local towerStartY = state.layout.towersY

    state.towerButtons = {}
    for i, towerType in ipairs(TOWER_ORDER) do
        state.towerButtons[i] = {
            type = towerType,
            x = state.x + padding,
            y = towerStartY + (i - 1) * (buttonHeight + buttonSpacing),
            width = buttonWidth,
            height = buttonHeight,
            hotkey = TOWER_KEYS[i],
        }
    end

    -- Upgrades header bounds (for expand/collapse click)
    state.upgradesHeaderBounds = {
        x = state.x + padding,
        y = state.layout.upgradesY,
        width = buttonWidth,
        height = 28,
    }

    -- Build upgrade button layouts (below header when expanded)
    local upgradeStartY = state.layout.upgradesY + 28 + buttonSpacing

    state.upgradeButtons = {}
    for i, upgradeType in ipairs(UPGRADE_ORDER) do
        state.upgradeButtons[i] = {
            type = upgradeType,
            x = state.x + padding,
            y = upgradeStartY + (i - 1) * (buttonHeight + buttonSpacing),
            width = buttonWidth,
            height = buttonHeight,
            hotkey = UPGRADE_KEYS[i],
        }
    end

    -- Reset upgrade levels
    state.upgradeLevels = { autoClicker = 0 }

    -- Initialize cache with starting values
    state.cache = {
        gold = Config.STARTING_GOLD,
        income = Config.BASE_INCOME,
        incomeProgress = 0,
        lives = Config.STARTING_LIVES,
        waveNumber = 0,
    }

    -- Subscribe to events for cache updates
    EventBus.on("gold_changed", function(data)
        state.cache.gold = data.total
    end)

    EventBus.on("income_tick", function(data)
        state.cache.gold = data.total
    end)

    EventBus.on("creep_sent", function(data)
        state.cache.income = data.income
    end)

    EventBus.on("life_lost", function(data)
        state.cache.lives = data.remaining
    end)

    EventBus.on("wave_started", function(data)
        state.cache.waveNumber = data.waveNumber
    end)
end

function Panel.update(mouseX, mouseY)
    state.hoverButton = nil

    -- Check tower buttons
    for _, btn in ipairs(state.towerButtons) do
        if mouseX >= btn.x and mouseX <= btn.x + btn.width and
           mouseY >= btn.y and mouseY <= btn.y + btn.height then
            state.hoverButton = btn
            return
        end
    end

    -- Check upgrade buttons (only if expanded)
    if state.upgradesExpanded then
        for _, btn in ipairs(state.upgradeButtons) do
            if mouseX >= btn.x and mouseX <= btn.x + btn.width and
               mouseY >= btn.y and mouseY <= btn.y + btn.height then
                state.hoverButton = btn
                return
            end
        end
    end

    -- Check upgrades header for hover
    local hdr = state.upgradesHeaderBounds
    if hdr and mouseX >= hdr.x and mouseX <= hdr.x + hdr.width and
       mouseY >= hdr.y and mouseY <= hdr.y + hdr.height then
        state.hoverButton = { type = "upgradesHeader" }
    end
end

function Panel.handleClick(x, y, economy)
    -- Check upgrades header (expand/collapse)
    local hdr = state.upgradesHeaderBounds
    if hdr and x >= hdr.x and x <= hdr.x + hdr.width and
       y >= hdr.y and y <= hdr.y + hdr.height then
        state.upgradesExpanded = not state.upgradesExpanded
        _calculateLayout(state.height)
        return nil
    end

    -- Check tower buttons
    for _, btn in ipairs(state.towerButtons) do
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            state.selectedTower = btn.type
            return nil
        end
    end

    -- Check upgrade buttons (only if expanded)
    if state.upgradesExpanded then
        for _, btn in ipairs(state.upgradeButtons) do
            if x >= btn.x and x <= btn.x + btn.width and
               y >= btn.y and y <= btn.y + btn.height then
                local cost = Panel.getUpgradeCost(btn.type)
                local upgradeConfig = Config.UPGRADES.panel[btn.type]
                local currentLevel = state.upgradeLevels[btn.type] or 0

                if currentLevel < upgradeConfig.maxLevel and economy.canAfford(cost) then
                    return {action = "buy_upgrade", type = btn.type, cost = cost}
                end
                return nil
            end
        end
    end

    return nil
end

-- Get cost for an upgrade at current level
function Panel.getUpgradeCost(upgradeType)
    local upgradeConfig = Config.UPGRADES.panel[upgradeType]
    if not upgradeConfig then return 0 end

    local currentLevel = state.upgradeLevels[upgradeType] or 0
    if currentLevel >= upgradeConfig.maxLevel then
        return 0
    end

    return math.floor(upgradeConfig.baseCost * (upgradeConfig.costMultiplier ^ currentLevel))
end

-- Purchase an upgrade (increment level)
function Panel.purchaseUpgrade(upgradeType)
    local upgradeConfig = Config.UPGRADES.panel[upgradeType]
    if not upgradeConfig then return false end

    local currentLevel = state.upgradeLevels[upgradeType] or 0
    if currentLevel >= upgradeConfig.maxLevel then
        return false
    end

    state.upgradeLevels[upgradeType] = currentLevel + 1
    return true
end

-- Get current level of an upgrade
function Panel.getUpgradeLevel(upgradeType)
    return state.upgradeLevels[upgradeType] or 0
end

-- Get auto-clicker interval (returns nil if not purchased)
function Panel.getAutoClickInterval()
    local level = state.upgradeLevels.autoClicker or 0
    if level == 0 then return nil end

    local config = Config.UPGRADES.panel.autoClicker
    return config.baseInterval - ((level - 1) * config.intervalReduction)
end

-- Draw tower sprite thumbnail (compact scale)
local function _drawTowerThumbnail(towerType, x, y, canAfford)
    local towerConfig = Config.TOWERS[towerType]
    local artConfig = Config.PIXEL_ART.TOWERS[towerType]
    local thumbScale = Config.UI.panel.iconScale

    -- Check if tower has a voidVariant (use TurretConcepts)
    if towerConfig and towerConfig.voidVariant then
        if not canAfford then
            love.graphics.setColor(0.4, 0.4, 0.4)
        else
            love.graphics.setColor(1, 1, 1)
        end
        TurretConcepts.drawThumbnail(towerConfig.voidVariant, x, y, 1.5)
    elseif artConfig and artConfig.base then
        -- Use pixel art for towers with sprites
        if not canAfford then
            love.graphics.setColor(0.4, 0.4, 0.4)
        else
            love.graphics.setColor(1, 1, 1)
        end
        PixelArt.drawTower(towerType, x, y, 0, 0, thumbScale)
    else
        -- Fallback to simple circle
        if canAfford then
            love.graphics.setColor(towerConfig.color)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.circle("fill", x, y, 10)
    end
end

-- Draw clean border between play area and panel
local function _drawPanelBorder()
    local x = state.x
    local dark = Config.COLORS.frameDark
    local mid = Config.COLORS.frameMid
    local accent = Config.COLORS.frameAccent

    -- Main border line (2px)
    love.graphics.setColor(dark)
    love.graphics.rectangle("fill", x, 0, 2, state.height)

    -- Subtle highlight
    love.graphics.setColor(mid[1], mid[2], mid[3], 0.5)
    love.graphics.rectangle("fill", x + 2, 0, 1, state.height)

    -- Sparse accent dots for texture
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.4)
    for py = 20, state.height - 20, 32 do
        love.graphics.rectangle("fill", x, py, 2, 2)
    end
end

-- Draw unified stats section (gold, lives, wave, speed, void bar)
local function _drawStatsSection(economy, voidEntity, waves, speedLabel)
    local padding = Config.UI.padding
    local sectionX = state.x + padding
    local sectionY = state.layout.statsY
    local sectionWidth = state.width - padding * 2
    local sectionHeight = state.layout.statsHeight

    -- Clean frame
    PixelFrames.draw8BitFrame(sectionX, sectionY, sectionWidth, sectionHeight, "hud")

    local contentX = sectionX + 10
    local y = sectionY + 10

    -- Row 1: Gold (large) | +income/tick
    Fonts.setFont("medium")
    love.graphics.setColor(Config.COLORS.gold)
    love.graphics.print(tostring(economy.getGold()) .. "g", contentX, y)

    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.income)
    love.graphics.printf("+" .. economy.getIncome() .. "/tick", sectionX, y + 4, sectionWidth - 12, "right")

    y = y + 22

    -- Row 2: Lives | Wave | Speed
    -- Lives with heart indicator
    love.graphics.setColor(Config.COLORS.lives)
    Fonts.setFont("small")
    love.graphics.print("HP", contentX, y + 2)
    Fonts.setFont("medium")
    love.graphics.print(tostring(economy.getLives()), contentX + 22, y)

    -- Wave number
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    love.graphics.print("WAVE", contentX + 60, y + 2)
    Fonts.setFont("medium")
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print(tostring(waves.getWaveNumber()), contentX + 95, y)

    -- Speed indicator (right-aligned)
    local speedText = speedLabel or "x1"
    Fonts.setFont("small")
    if speedLabel == "||" then
        love.graphics.setColor(Config.COLORS.ruby)
    elseif speedLabel == "x5" then
        love.graphics.setColor(Config.COLORS.emerald)
    else
        love.graphics.setColor(Config.COLORS.textSecondary)
    end
    love.graphics.printf(speedText, sectionX, y + 2, sectionWidth - 12, "right")

    y = y + 24

    -- Row 3: VOID bar with anger level
    if voidEntity then
        Fonts.setFont("small")
        love.graphics.setColor(Config.COLORS.amethyst)
        love.graphics.print("VOID", contentX, y + 1)

        -- Health bar (8 segments)
        local barX = contentX + 40
        local barWidth = sectionWidth - 95
        local barHeight = 12
        local healthPercent = voidEntity:getHealthPercent()

        PixelFrames.drawSegmentedBar(barX, y, barWidth, barHeight, healthPercent, 8, Config.COLORS.amethyst, {0.12, 0.06, 0.14})

        -- Anger level indicator
        love.graphics.setColor(Config.COLORS.gold)
        love.graphics.printf("Lv" .. voidEntity.currentAnger, sectionX, y + 1, sectionWidth - 12, "right")
    end
end

-- Draw tower card with icon and stats
local function _drawTowerCard(btn, economy)
    local towerConfig = Config.TOWERS[btn.type]
    local canAfford = economy.canAfford(towerConfig.cost)
    local isSelected = state.selectedTower == btn.type
    local isHovered = state.hoverButton == btn

    -- Card frame style
    local styleName = "standard"
    if not canAfford then
        styleName = "disabled"
    elseif isSelected then
        styleName = "selected"
    elseif isHovered then
        styleName = "highlight"
    end

    -- Selection glow
    if isSelected then
        love.graphics.setColor(Config.COLORS.gold[1], Config.COLORS.gold[2], Config.COLORS.gold[3], 0.12)
        love.graphics.rectangle("fill", btn.x - 2, btn.y - 2, btn.width + 4, btn.height + 4)
    end

    PixelFrames.draw8BitCard(btn.x, btn.y, btn.width, btn.height, styleName)

    -- Icon (centered vertically, left side)
    local iconScale = Config.UI.panel.iconScale
    local iconSize = 16 * iconScale  -- 32px at 2.0 scale
    local iconX = btn.x + 6 + iconSize / 2
    local iconY = btn.y + btn.height / 2
    _drawTowerThumbnail(btn.type, iconX, iconY, canAfford)

    -- Text area starts after icon
    local textX = btn.x + 6 + iconSize + 8

    -- Row 1: Name
    Fonts.setFont("medium")
    if isSelected then
        love.graphics.setColor(Config.COLORS.gold)
    elseif canAfford then
        love.graphics.setColor(Config.COLORS.textPrimary)
    else
        love.graphics.setColor(Config.COLORS.textDisabled)
    end
    love.graphics.print(towerConfig.name, textX, btn.y + 8)

    -- Cost (right-aligned, same row as name)
    Fonts.setFont("small")
    if canAfford then
        love.graphics.setColor(Config.COLORS.gold)
    else
        love.graphics.setColor(Config.COLORS.textDisabled)
    end
    love.graphics.printf(towerConfig.cost .. "g", btn.x, btn.y + 10, btn.width - 22, "right")

    -- Hotkey (top-right corner, subtle)
    love.graphics.setColor(Config.COLORS.textSecondary[1], Config.COLORS.textSecondary[2], Config.COLORS.textSecondary[3], 0.5)
    love.graphics.print(btn.hotkey, btn.x + btn.width - 12, btn.y + 4)

    -- Row 2: Stats
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    local statsText
    if towerConfig.fireRate == 0 then
        statsText = "BLOCKS PATH"
    else
        statsText = "DMG:" .. towerConfig.damage .. "  RNG:" .. towerConfig.range
    end
    love.graphics.print(statsText, textX, btn.y + 30)
end

-- Draw collapsible upgrades section
local function _drawUpgradesSection(economy)
    local hdr = state.upgradesHeaderBounds
    local isHovered = state.hoverButton and state.hoverButton.type == "upgradesHeader"

    -- Header row with expand/collapse arrow
    local arrowChar = state.upgradesExpanded and "v" or ">"
    local headerStyle = isHovered and "highlight" or "standard"

    PixelFrames.draw8BitCard(hdr.x, hdr.y, hdr.width, hdr.height, headerStyle)

    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.amethyst)
    love.graphics.print(arrowChar .. " UPGRADES", hdr.x + 10, hdr.y + 7)

    -- Badge showing count of upgrades
    local upgradeCount = #UPGRADE_ORDER
    love.graphics.setColor(Config.COLORS.textSecondary)
    love.graphics.printf("(" .. upgradeCount .. ")", hdr.x, hdr.y + 7, hdr.width - 12, "right")

    -- Draw upgrade buttons (only if expanded)
    if state.upgradesExpanded then
        for _, btn in ipairs(state.upgradeButtons) do
            local upgradeConfig = Config.UPGRADES.panel[btn.type]
            local currentLevel = state.upgradeLevels[btn.type] or 0
            local cost = Panel.getUpgradeCost(btn.type)
            local isMaxLevel = currentLevel >= upgradeConfig.maxLevel
            local canAfford = not isMaxLevel and economy.canAfford(cost)
            local isHover = state.hoverButton == btn

            -- Card frame
            local styleName = "standard"
            if isMaxLevel then
                styleName = "selected"
            elseif not canAfford then
                styleName = "disabled"
            elseif isHover then
                styleName = "highlight"
            end

            PixelFrames.draw8BitCard(btn.x, btn.y, btn.width, btn.height, styleName)

            -- Upgrade name
            local textX = btn.x + 12
            Fonts.setFont("medium")
            if canAfford or isMaxLevel then
                love.graphics.setColor(Config.COLORS.textPrimary)
            else
                love.graphics.setColor(Config.COLORS.textDisabled)
            end
            love.graphics.print(upgradeConfig.name, textX, btn.y + 8)

            -- Cost or MAX (right-aligned)
            Fonts.setFont("small")
            if isMaxLevel then
                love.graphics.setColor(Config.COLORS.gold)
                love.graphics.printf("MAX", btn.x, btn.y + 10, btn.width - 12, "right")
            else
                if canAfford then
                    love.graphics.setColor(Config.COLORS.gold)
                else
                    love.graphics.setColor(Config.COLORS.textDisabled)
                end
                love.graphics.printf(cost .. "g", btn.x, btn.y + 10, btn.width - 12, "right")
            end

            -- Level indicator
            love.graphics.setColor(Config.COLORS.textSecondary)
            love.graphics.print("Lv" .. currentLevel .. "/" .. upgradeConfig.maxLevel, textX, btn.y + 30)
        end
    end
end

function Panel.draw(economy, voidEntity, waves, speedLabel)
    -- Panel background
    love.graphics.setColor(Config.COLORS.panel)
    love.graphics.rectangle("fill", state.x, 0, state.width, state.height)

    -- Stylized border
    _drawPanelBorder()

    -- Unified stats section (gold, lives, wave, speed, void bar)
    if economy and waves then
        _drawStatsSection(economy, voidEntity, waves, speedLabel)
    end

    -- Tower cards (compact 2-row)
    for _, btn in ipairs(state.towerButtons) do
        _drawTowerCard(btn, economy)
    end

    -- Collapsible upgrades section
    _drawUpgradesSection(economy)
end

function Panel.getSelectedTower()
    return state.selectedTower
end

function Panel.getSelectedTowerCost()
    if not state.selectedTower then return 0 end
    return Config.TOWERS[state.selectedTower].cost
end

function Panel.selectTower(towerType)
    state.selectedTower = towerType
end

function Panel.isHoveringButton()
    return state.hoverButton ~= nil
end

return Panel
