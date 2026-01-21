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
    spawnAllButton = nil,  -- Spawn all test towers button
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
        progressY = 0,
        progressHeight = 0,
        towersY = 0,
        towersHeight = 0,
        upgradesY = 0,
        upgradesHeight = 0,
    },
    -- Cached values from events
    cache = {
        gold = 0,
        lives = 0,
        waveNumber = 0,
        voidShards = 0,
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

    -- Progress section (wave progress bar)
    local progressHeight = Config.UI.LAYOUT.progressHeight

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

    state.layout.progressY = y
    state.layout.progressHeight = progressHeight
    y = y + progressHeight + sectionSpacing

    state.layout.towersY = y
    state.layout.towersHeight = towersHeight
    y = y + towersHeight + sectionSpacing

    state.layout.upgradesY = y
    state.layout.upgradesHeight = upgradesHeight
end

function Panel.init(canvasWidth, panelWidth, height)
    -- Panel is now an overlay on the right side of the canvas
    state.x = canvasWidth - panelWidth
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

    -- Spawn all button (anchored at bottom)
    local spawnButtonHeight = 36
    state.spawnAllButton = {
        type = "spawnAll",
        x = state.x + padding,
        y = height - padding - spawnButtonHeight,
        width = buttonWidth,
        height = spawnButtonHeight,
    }

    -- Reset upgrade levels
    state.upgradeLevels = { autoClicker = 0 }

    -- Initialize cache with starting values
    state.cache = {
        gold = Config.STARTING_GOLD,
        lives = Config.STARTING_LIVES,
        waveNumber = 0,
        voidShards = 0,
    }

    -- Subscribe to events for cache updates
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
        return
    end

    -- Check spawn all button
    local btn = state.spawnAllButton
    if btn and mouseX >= btn.x and mouseX <= btn.x + btn.width and
       mouseY >= btn.y and mouseY <= btn.y + btn.height then
        state.hoverButton = btn
    end
end

function Panel.handleClick(x, y, economy)
    -- Check spawn all button
    local spawnBtn = state.spawnAllButton
    if spawnBtn and x >= spawnBtn.x and x <= spawnBtn.x + spawnBtn.width and
       y >= spawnBtn.y and y <= spawnBtn.y + spawnBtn.height then
        EventBus.emit("spawn_test_towers", {})
        return nil
    end

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

-- Draw unified stats section (gold, lives, wave, speed) - simplified, no void bar
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

    -- Row 1: Gold (large)
    Fonts.setFont("medium")
    love.graphics.setColor(Config.COLORS.gold)
    love.graphics.print(tostring(economy.getGold()) .. "g", contentX, y)

    y = y + 22

    -- Row 2: Lives | Wave | Speed (compact)
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
end

-- Draw wave progress section (progress bar with boss markers + anger meter)
local function _drawProgressSection(waves, voidEntity)
    local padding = Config.UI.padding
    local x = state.x + padding
    local y = state.layout.progressY
    local w = state.width - padding * 2
    local h = state.layout.progressHeight

    PixelFrames.draw8BitFrame(x, y, w, h, "hud")

    local contentX = x + 10
    local cy = y + 8

    -- Row 1: "WAVE 5/20" left, "10 SHARDS" right
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    love.graphics.print("WAVE", contentX, cy)

    Fonts.setFont("medium")
    local currentWave = waves.getWaveNumber()
    local totalWaves = waves.getTotalWaves()
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print(currentWave .. "/" .. totalWaves, contentX + 45, cy - 2)

    -- Void shards (right-aligned)
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.voidShard)
    love.graphics.printf(state.cache.voidShards .. " SHARDS", x, cy, w - 12, "right")

    cy = cy + 22

    -- Row 2: Wave Progress bar
    local barX = contentX
    local barWidth = w - 20
    local barHeight = 12
    local progress = currentWave / totalWaves

    -- Background
    love.graphics.setColor(Config.COLORS.progressBarBg)
    love.graphics.rectangle("fill", barX, cy, barWidth, barHeight)

    -- Fill
    love.graphics.setColor(Config.COLORS.progressBar)
    love.graphics.rectangle("fill", barX, cy, barWidth * progress, barHeight)

    -- Boss markers (triangles above bar)
    local bossWaves = waves.getBossWaves()
    for _, bossWave in ipairs(bossWaves) do
        local markerX = barX + (bossWave / totalWaves) * barWidth
        love.graphics.setColor(Config.COLORS.bossMarker)
        -- Triangle marker pointing down
        love.graphics.polygon("fill",
            markerX, cy - 2,
            markerX - 4, cy - 8,
            markerX + 4, cy - 8
        )
        -- Vertical line through bar
        love.graphics.setColor(Config.COLORS.bossMarker[1], Config.COLORS.bossMarker[2], Config.COLORS.bossMarker[3], 0.5)
        love.graphics.rectangle("fill", markerX - 1, cy, 2, barHeight)
    end

    -- Border
    love.graphics.setColor(Config.COLORS.frameMid)
    love.graphics.rectangle("line", barX, cy, barWidth, barHeight)

    cy = cy + barHeight + 10

    -- Row 3: Anger meter
    if voidEntity then
        local angerCfg = Config.UI.angerMeter
        local angerColors = angerCfg.colors
        local tier = voidEntity:getTier()
        local clickCount = voidEntity:getClickCount()
        local maxClicks = voidEntity:getMaxClicks()
        local clickPercent = clickCount / maxClicks

        -- Label + Tier indicator
        Fonts.setFont("small")
        love.graphics.setColor(Config.COLORS.amethyst)
        love.graphics.print("ANGER", contentX, cy + 1)

        -- Tier indicator (right-aligned on same row)
        local tierText = "Tier " .. tier
        if tier >= 4 then
            love.graphics.setColor(angerColors.fillTier4)
            tierText = "MAX"
        elseif tier >= 3 then
            love.graphics.setColor(angerColors.fillTier3)
        elseif tier >= 2 then
            love.graphics.setColor(angerColors.fillTier2)
        else
            love.graphics.setColor(angerColors.fill)
        end
        love.graphics.printf(tierText, x, cy + 1, w - 12, "right")

        cy = cy + 16

        -- Anger meter bar
        local angerBarHeight = angerCfg.height
        local thresholds = Config.VOID.angerThresholds

        -- Background
        love.graphics.setColor(angerColors.background)
        love.graphics.rectangle("fill", barX, cy, barWidth, angerBarHeight)

        -- Fill color based on tier
        local fillColor
        if tier >= 4 then
            fillColor = angerColors.fillTier4
        elseif tier >= 3 then
            fillColor = angerColors.fillTier3
        elseif tier >= 2 then
            fillColor = angerColors.fillTier2
        else
            fillColor = angerColors.fill
        end
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", barX, cy, barWidth * clickPercent, angerBarHeight)

        -- Threshold markers
        love.graphics.setColor(angerColors.thresholdMarker)
        for _, threshold in ipairs(thresholds) do
            local markerX = barX + (threshold / maxClicks) * barWidth
            love.graphics.rectangle("fill", markerX - angerCfg.thresholdMarkerWidth / 2, cy, angerCfg.thresholdMarkerWidth, angerBarHeight)
        end

        -- Border
        love.graphics.setColor(angerColors.border)
        love.graphics.rectangle("line", barX, cy, barWidth, angerBarHeight)

        -- Click count centered on bar
        Fonts.setFont("small")
        love.graphics.setColor(Config.COLORS.textPrimary)
        local countText = clickCount .. "/" .. maxClicks
        love.graphics.printf(countText, barX, cy + 1, barWidth, "center")
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

-- Draw spawn all button (anchored at bottom)
local function _drawSpawnAllButton()
    local btn = state.spawnAllButton
    if not btn then return end

    local isHovered = state.hoverButton == btn

    -- Card frame
    local styleName = isHovered and "highlight" or "standard"
    PixelFrames.draw8BitCard(btn.x, btn.y, btn.width, btn.height, styleName)

    -- Button text
    Fonts.setFont("medium")
    if isHovered then
        love.graphics.setColor(Config.COLORS.gold)
    else
        love.graphics.setColor(Config.COLORS.textPrimary)
    end

    -- Center text
    local text = "SPAWN ALL"
    local textWidth = Fonts.get("medium"):getWidth(text)
    local textX = btn.x + (btn.width - textWidth) / 2
    local textY = btn.y + (btn.height - Fonts.get("medium"):getHeight()) / 2
    love.graphics.print(text, textX, textY)
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
    -- Panel background (semi-transparent overlay)
    local panelColor = Config.COLORS.panel
    local panelAlpha = Config.PANEL_ALPHA or 0.92
    love.graphics.setColor(panelColor[1], panelColor[2], panelColor[3], panelAlpha)
    love.graphics.rectangle("fill", state.x, 0, state.width, state.height)

    -- Stylized border
    _drawPanelBorder()

    -- Unified stats section (gold, lives, wave, speed, void bar)
    if economy and waves then
        _drawStatsSection(economy, voidEntity, waves, speedLabel)
    end

    -- Wave progress section (with anger meter)
    if waves then
        _drawProgressSection(waves, voidEntity)
    end

    -- Tower cards (compact 2-row)
    for _, btn in ipairs(state.towerButtons) do
        _drawTowerCard(btn, economy)
    end

    -- Collapsible upgrades section
    _drawUpgradesSection(economy)

    -- Spawn all button (bottom)
    _drawSpawnAllButton()
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

function Panel.getX()
    return state.x
end

return Panel
