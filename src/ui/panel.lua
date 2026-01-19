-- src/ui/panel.lua
-- Right-side UI panel for tower selection and upgrades

local Config = require("src.config")

local Panel = {}

local state = {
    x = 0,
    width = 0,
    height = 0,
    selectedTower = "wall",
    towerButtons = {},
    upgradeButtons = {},
    hoverButton = nil,
    upgradeLevels = {
        autoClicker = 0,
    },
}

-- Tower types in order
local TOWER_ORDER = {"wall", "basic", "rapid", "sniper", "cannon"}
local TOWER_KEYS = {"1", "2", "3", "4", "5"}

-- Upgrade types in order
local UPGRADE_ORDER = {"autoClicker"}
local UPGRADE_KEYS = {"Q"}

function Panel.init(playAreaWidth, panelWidth, height)
    state.x = playAreaWidth
    state.width = panelWidth
    state.height = height

    -- Build tower button layouts (top half)
    local padding = Config.UI.padding
    local buttonHeight = Config.UI.buttonHeight
    local buttonSpacing = Config.UI.buttonSpacing
    local buttonWidth = panelWidth - padding * 2

    local towerStartY = Config.UI.panel.towerSectionY

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

    -- Build upgrade button layouts (bottom half)
    local upgradeStartY = height / 2 + Config.UI.panel.enemySectionYOffset

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

    -- Check upgrade buttons
    for _, btn in ipairs(state.upgradeButtons) do
        if mouseX >= btn.x and mouseX <= btn.x + btn.width and
           mouseY >= btn.y and mouseY <= btn.y + btn.height then
            state.hoverButton = btn
            return
        end
    end
end

function Panel.handleClick(x, y, economy)
    -- Check tower buttons
    for _, btn in ipairs(state.towerButtons) do
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            state.selectedTower = btn.type
            return nil
        end
    end

    -- Check upgrade buttons
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

    return nil
end

-- Get cost for an upgrade at current level
function Panel.getUpgradeCost(upgradeType)
    local upgradeConfig = Config.UPGRADES.panel[upgradeType]
    if not upgradeConfig then return 0 end

    local currentLevel = state.upgradeLevels[upgradeType] or 0
    if currentLevel >= upgradeConfig.maxLevel then
        return 0  -- Max level
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

function Panel.draw(economy)
    -- Panel background
    love.graphics.setColor(Config.COLORS.panel)
    love.graphics.rectangle("fill", state.x, 0, state.width, state.height)

    -- Border
    love.graphics.setColor(Config.COLORS.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.line(state.x, 0, state.x, state.height)

    -- TOWERS title
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.printf("TOWERS", state.x, 20, state.width, "center")

    -- Draw tower buttons
    for _, btn in ipairs(state.towerButtons) do
        local towerConfig = Config.TOWERS[btn.type]
        local canAfford = economy.canAfford(towerConfig.cost)
        local isSelected = state.selectedTower == btn.type
        local isHovered = state.hoverButton == btn

        -- Button background
        if isSelected then
            love.graphics.setColor(Config.UI.panel.buttonColors.selected)
        elseif isHovered and canAfford then
            love.graphics.setColor(Config.UI.panel.buttonColors.hovered)
        else
            love.graphics.setColor(Config.UI.panel.buttonColors.default)
        end
        love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 4)

        -- Selection border
        if isSelected then
            love.graphics.setColor(0, 1, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height, 4)
        end

        -- Tower icon (colored circle)
        local iconX = btn.x + Config.UI.panel.iconXOffset
        local iconY = btn.y + btn.height / 2
        if canAfford then
            love.graphics.setColor(towerConfig.color)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.circle("fill", iconX, iconY, Config.UI.panel.iconRadius)

        -- Tower name
        if canAfford then
            love.graphics.setColor(Config.COLORS.textPrimary)
        else
            love.graphics.setColor(Config.COLORS.textDisabled)
        end
        love.graphics.print(towerConfig.name, btn.x + Config.UI.panel.textXOffset, btn.y + Config.UI.panel.textYOffset)

        -- Tower cost
        if canAfford then
            love.graphics.setColor(Config.COLORS.gold)
        else
            love.graphics.setColor(Config.COLORS.textDisabled)
        end
        love.graphics.print(towerConfig.cost .. "g", btn.x + Config.UI.panel.textXOffset, btn.y + Config.UI.panel.costYOffset)

        -- Hotkey
        love.graphics.setColor(Config.COLORS.textSecondary)
        love.graphics.print("[" .. btn.hotkey .. "]", btn.x + btn.width - Config.UI.panel.hotkeyXOffset, btn.y + Config.UI.panel.textYOffset)

        -- Stats (damage/range or BLOCKS for walls)
        love.graphics.setColor(Config.COLORS.textSecondary)
        local statsText
        if towerConfig.fireRate == 0 then
            statsText = "BLOCKS"
        else
            statsText = "DMG:" .. towerConfig.damage .. " RNG:" .. towerConfig.range
        end
        love.graphics.print(statsText, btn.x + Config.UI.panel.textXOffset, btn.y + Config.UI.panel.statsYOffset)
    end

    -- UPGRADES title
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.printf("UPGRADES", state.x, state.height / 2, state.width, "center")

    -- Draw upgrade buttons
    for _, btn in ipairs(state.upgradeButtons) do
        local upgradeConfig = Config.UPGRADES.panel[btn.type]
        local currentLevel = state.upgradeLevels[btn.type] or 0
        local cost = Panel.getUpgradeCost(btn.type)
        local isMaxLevel = currentLevel >= upgradeConfig.maxLevel
        local canAfford = not isMaxLevel and economy.canAfford(cost)
        local isHovered = state.hoverButton == btn

        -- Button background
        if isHovered and canAfford then
            love.graphics.setColor(Config.UI.panel.buttonColors.enemyHovered)
        else
            love.graphics.setColor(Config.UI.panel.buttonColors.default)
        end
        love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 4)

        -- Upgrade icon (gear-like circle)
        local iconX = btn.x + Config.UI.panel.iconXOffset
        local iconY = btn.y + btn.height / 2
        if canAfford then
            love.graphics.setColor(Config.COLORS.income)
        elseif isMaxLevel then
            love.graphics.setColor(Config.COLORS.gold)
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.circle("fill", iconX, iconY, Config.UI.panel.iconRadius)

        -- Level indicator inside icon
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(tostring(currentLevel), iconX - 10, iconY - 7, 20, "center")

        -- Upgrade name
        if canAfford or isMaxLevel then
            love.graphics.setColor(Config.COLORS.textPrimary)
        else
            love.graphics.setColor(Config.COLORS.textDisabled)
        end
        love.graphics.print(upgradeConfig.name, btn.x + Config.UI.panel.textXOffset, btn.y + Config.UI.panel.textYOffset)

        -- Cost or MAX
        if isMaxLevel then
            love.graphics.setColor(Config.COLORS.gold)
            love.graphics.print("MAX", btn.x + Config.UI.panel.textXOffset, btn.y + Config.UI.panel.costYOffset)
        else
            if canAfford then
                love.graphics.setColor(Config.COLORS.gold)
            else
                love.graphics.setColor(Config.COLORS.textDisabled)
            end
            love.graphics.print(cost .. "g", btn.x + Config.UI.panel.textXOffset, btn.y + Config.UI.panel.costYOffset)
        end

        -- Effect description
        love.graphics.setColor(Config.COLORS.income)
        if btn.type == "autoClicker" then
            if currentLevel == 0 then
                love.graphics.print("Auto-click Void", btn.x + 100, btn.y + Config.UI.panel.costYOffset)
            else
                local interval = Panel.getAutoClickInterval()
                love.graphics.print(string.format("%.1fs", interval), btn.x + 100, btn.y + Config.UI.panel.costYOffset)
            end
        end

        -- Hotkey
        love.graphics.setColor(Config.COLORS.textSecondary)
        love.graphics.print("[" .. btn.hotkey .. "]", btn.x + btn.width - Config.UI.panel.hotkeyXOffset, btn.y + Config.UI.panel.textYOffset)

        -- Level progress
        love.graphics.setColor(Config.COLORS.textSecondary)
        local levelText = "Lv " .. currentLevel .. "/" .. upgradeConfig.maxLevel
        love.graphics.print(levelText, btn.x + Config.UI.panel.textXOffset, btn.y + Config.UI.panel.statsYOffset)
    end
end

function Panel.getSelectedTower()
    return state.selectedTower
end

function Panel.getSelectedTowerCost()
    return Config.TOWERS[state.selectedTower].cost
end

function Panel.selectTower(towerType)
    state.selectedTower = towerType
end

return Panel
