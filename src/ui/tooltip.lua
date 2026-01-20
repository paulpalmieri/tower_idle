-- src/ui/tooltip.lua
-- Tower selection menu UI component with stats, upgrade, and sell buttons

local Config = require("src.config")
local Fonts = require("src.rendering.fonts")
local PixelFrames = require("src.ui.pixel_frames")

local Tooltip = {}

local state = {
    visible = false,
    tower = nil,
    x = 0,
    y = 0,
    width = 0,
    height = 0,
    upgradeButton = nil,
    sellButton = nil,
}

local function _calculateTooltipPosition(tower)
    local cfg = Config.UI.tooltip
    local screenWidth = Config.SCREEN_WIDTH
    local screenHeight = Config.SCREEN_HEIGHT

    -- Calculate total height:
    -- Header (name + level)
    -- Stats rows (2 rows x 2 stats each)
    -- Separator
    -- Buttons (upgrade + sell)
    local headerHeight = cfg.headerHeight
    local statsHeight = cfg.statsRowHeight * 2 + cfg.buttonSpacing
    local buttonsHeight = cfg.buttonHeight + cfg.buttonSpacing

    state.width = cfg.width
    state.height = cfg.padding * 2 + headerHeight + statsHeight + buttonsHeight

    -- Position to the right of the tower by default
    local tooltipX = tower.x + cfg.offsetX
    local tooltipY = tower.y + cfg.offsetY

    -- Clamp to screen bounds
    if tooltipX + state.width > screenWidth then
        tooltipX = tower.x - state.width - cfg.offsetX
    end
    if tooltipX < 0 then
        tooltipX = 0
    end
    if tooltipY < 0 then
        tooltipY = 0
    end
    if tooltipY + state.height > screenHeight then
        tooltipY = screenHeight - state.height
    end

    state.x = tooltipX
    state.y = tooltipY
end

local function _buildButtons()
    local cfg = Config.UI.tooltip
    local tower = state.tower
    if not tower then return end

    -- Button Y position after stats
    local headerHeight = cfg.headerHeight
    local statsHeight = cfg.statsRowHeight * 2 + cfg.buttonSpacing
    local buttonY = state.y + cfg.padding + headerHeight + statsHeight

    -- Calculate button widths (upgrade takes more space than sell)
    local totalWidth = state.width - cfg.padding * 2
    local upgradeWidth = math.floor(totalWidth * 0.65)
    local sellWidth = totalWidth - upgradeWidth - cfg.buttonSpacing

    -- Upgrade button
    state.upgradeButton = {
        x = state.x + cfg.padding,
        y = buttonY,
        width = upgradeWidth,
        height = cfg.buttonHeight,
    }

    -- Sell button
    state.sellButton = {
        x = state.x + cfg.padding + upgradeWidth + cfg.buttonSpacing,
        y = buttonY,
        width = sellWidth,
        height = cfg.buttonHeight,
    }
end

function Tooltip.show(tower)
    state.visible = true
    state.tower = tower
    _calculateTooltipPosition(tower)
    _buildButtons()
end

function Tooltip.hide()
    state.visible = false
    state.tower = nil
    state.upgradeButton = nil
    state.sellButton = nil
end

function Tooltip.isVisible()
    return state.visible
end

function Tooltip.getTower()
    return state.tower
end

function Tooltip.isPointInside(x, y)
    if not state.visible then return false end
    return x >= state.x and x <= state.x + state.width and
           y >= state.y and y <= state.y + state.height
end

function Tooltip.isHoveringButton(x, y)
    if not state.visible or not state.tower then
        return false
    end

    -- Check upgrade button
    if state.upgradeButton then
        local btn = state.upgradeButton
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            return true
        end
    end

    -- Check sell button
    if state.sellButton then
        local btn = state.sellButton
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            return true
        end
    end

    return false
end

function Tooltip.handleClick(x, y, economy)
    if not state.visible or not state.tower then
        return nil
    end

    local tower = state.tower

    -- Check upgrade button
    if state.upgradeButton then
        local btn = state.upgradeButton
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            local cost = tower:getUpgradeCost()
            if cost and economy.canAfford(cost) then
                return {action = "upgrade", cost = cost}
            end
            return nil
        end
    end

    -- Check sell button
    if state.sellButton then
        local btn = state.sellButton
        if x >= btn.x and x <= btn.x + btn.width and
           y >= btn.y and y <= btn.y + btn.height then
            local refund = tower:getSellValue()
            return {action = "sell", refund = refund}
        end
    end

    return nil
end

function Tooltip.draw(economy)
    if not state.visible or not state.tower then
        return
    end

    local tower = state.tower
    local cfg = Config.UI.tooltip
    local colors = Config.COLORS

    -- Background frame with ornate pixel styling
    PixelFrames.drawOrnateFrame(state.x, state.y, state.width, state.height, "tooltip")

    -- Header: Tower name and level
    local towerConfig = Config.TOWERS[tower.towerType]
    local contentY = state.y + cfg.padding

    -- Tower name (left)
    Fonts.setFont("medium")
    love.graphics.setColor(towerConfig.color)
    love.graphics.print(towerConfig.name, state.x + cfg.padding, contentY)

    -- Level (right)
    local levelText = "Lv." .. tower.level
    local levelWidth = Fonts.get("medium"):getWidth(levelText)
    love.graphics.setColor(colors.gold)
    love.graphics.print(levelText, state.x + state.width - cfg.padding - levelWidth, contentY)

    -- Stats section
    contentY = contentY + cfg.headerHeight
    Fonts.setFont("small")

    -- Row 1: ATK and RATE
    local col1X = state.x + cfg.padding
    local col2X = state.x + state.width / 2 + 5

    -- ATK (damage)
    love.graphics.setColor(colors.upgrade.damage)
    love.graphics.print("ATK:", col1X, contentY)
    love.graphics.setColor(colors.textPrimary)
    love.graphics.print(string.format("%.0f", tower.damage), col1X + 32, contentY)

    -- RATE (fire rate)
    love.graphics.setColor(colors.upgrade.fireRate)
    love.graphics.print("RATE:", col2X, contentY)
    love.graphics.setColor(colors.textPrimary)
    love.graphics.print(string.format("%.1f/s", tower.fireRate), col2X + 38, contentY)

    -- Row 2: RNG and KILLS
    contentY = contentY + cfg.statsRowHeight

    -- RNG (range)
    love.graphics.setColor(colors.upgrade.range)
    love.graphics.print("RNG:", col1X, contentY)
    love.graphics.setColor(colors.textPrimary)
    love.graphics.print(string.format("%.0f", tower.range), col1X + 32, contentY)

    -- KILLS
    love.graphics.setColor(colors.emerald)
    love.graphics.print("KILLS:", col2X, contentY)
    love.graphics.setColor(colors.textPrimary)
    love.graphics.print(tostring(tower.kills), col2X + 42, contentY)

    -- Draw buttons
    local isMaxed = not tower:canUpgrade()
    local cost = tower:getUpgradeCost()
    local canAfford = cost and economy.canAfford(cost)
    local sellValue = tower:getSellValue()

    -- Upgrade button
    if state.upgradeButton then
        local btn = state.upgradeButton
        local styleName = "standard"
        if isMaxed then
            styleName = "disabled"
        elseif canAfford then
            styleName = "selected"
        else
            styleName = "standard"
        end
        PixelFrames.drawSimpleFrame(btn.x, btn.y, btn.width, btn.height, styleName)

        Fonts.setFont("small")
        if isMaxed then
            -- MAX label
            love.graphics.setColor(0.5, 0.8, 0.5)
            local maxText = "MAX"
            local maxWidth = Fonts.get("small"):getWidth(maxText)
            love.graphics.print(maxText, btn.x + (btn.width - maxWidth) / 2, btn.y + 4)
        else
            -- UPGRADE label
            if canAfford then
                love.graphics.setColor(colors.textPrimary)
            else
                love.graphics.setColor(colors.textDisabled)
            end
            love.graphics.print("UPGRADE", btn.x + 8, btn.y + 4)

            -- Cost
            if canAfford then
                love.graphics.setColor(colors.gold)
            else
                love.graphics.setColor(colors.textDisabled)
            end
            local costText = cost .. "g"
            local costWidth = Fonts.get("small"):getWidth(costText)
            love.graphics.print(costText, btn.x + btn.width - costWidth - 8, btn.y + 4)
        end
    end

    -- Sell button
    if state.sellButton then
        local btn = state.sellButton
        PixelFrames.drawSimpleFrame(btn.x, btn.y, btn.width, btn.height, "standard")

        Fonts.setFont("small")
        -- SELL label with red tint
        love.graphics.setColor(colors.ruby[1], colors.ruby[2], colors.ruby[3], 0.9)
        love.graphics.print("SELL", btn.x + 6, btn.y + 4)

        -- Refund amount (smaller, below)
        love.graphics.setColor(colors.gold[1], colors.gold[2], colors.gold[3], 0.8)
        local refundText = sellValue .. "g"
        local refundWidth = Fonts.get("small"):getWidth(refundText)
        love.graphics.print(refundText, btn.x + btn.width - refundWidth - 6, btn.y + 4)
    end
end

return Tooltip
