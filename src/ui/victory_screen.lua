-- src/ui/victory_screen.lua
-- End game recap screen showing victory/defeat with detailed stats
-- Two buttons: "Skill Tree" (opens skill tree scene) and "Play Again" (restart)

local Config = require("src.config")
local Fonts = require("src.rendering.fonts")
local PixelFrames = require("src.ui.pixel_frames")
local Economy = require("src.systems.economy")
local Settings = require("src.ui.settings")

local VictoryScreen = {}

local state = {
    visible = false,
    isVictory = true,
    time = 0,
    hoverSkillTree = false,
    hoverPlayAgain = false,
    skillTreeButton = nil,
    playAgainButton = nil,
}

-- Helper to format time as MM:SS
local function _formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

-- Helper to format large numbers with K/M suffixes
local function _formatNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 1000 then
        return string.format("%.1fK", num / 1000)
    else
        return tostring(math.floor(num))
    end
end

local function _calculateLayout()
    local gameW, gameH = Settings.getGameDimensions()
    local buttonWidth = 140
    local buttonHeight = 40
    local buttonSpacing = 20
    local totalWidth = buttonWidth * 2 + buttonSpacing
    local startX = (gameW - totalWidth) / 2
    local buttonY = gameH / 2 + 140

    state.skillTreeButton = {
        x = startX,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight,
    }

    state.playAgainButton = {
        x = startX + buttonWidth + buttonSpacing,
        y = buttonY,
        width = buttonWidth,
        height = buttonHeight,
    }
end

function VictoryScreen.init()
    state.visible = false
    state.isVictory = true
    state.time = 0
    state.hoverSkillTree = false
    state.hoverPlayAgain = false
    _calculateLayout()
end

function VictoryScreen.show()
    state.visible = true
    state.isVictory = true
    state.time = 0
end

function VictoryScreen.showDefeat()
    state.visible = true
    state.isVictory = false
    state.time = 0
end

function VictoryScreen.hide()
    state.visible = false
end

function VictoryScreen.isVisible()
    return state.visible
end

local function _pointInRect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.width and
           py >= rect.y and py <= rect.y + rect.height
end

function VictoryScreen.update(mx, my)
    if not state.visible then return end

    state.time = state.time + love.timer.getDelta()

    -- Check hover states
    state.hoverSkillTree = _pointInRect(mx, my, state.skillTreeButton)
    state.hoverPlayAgain = _pointInRect(mx, my, state.playAgainButton)
end

function VictoryScreen.handleClick(x, y)
    if not state.visible then return nil end

    if _pointInRect(x, y, state.skillTreeButton) then
        return { action = "skill_tree" }
    end

    if _pointInRect(x, y, state.playAgainButton) then
        return { action = "restart" }
    end

    return nil
end

function VictoryScreen.draw()
    if not state.visible then return end

    -- Recalculate layout in case window dimensions changed
    _calculateLayout()

    local screenW, screenH = Settings.getGameDimensions()
    local stats = Economy.getStats()

    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Animated glow pulse
    local pulse = math.sin(state.time * 2) * 0.2 + 0.8

    -- Title based on victory/defeat
    local title, subtitle, titleColor, glowColor
    if state.isVictory then
        title = "VICTORY"
        subtitle = "All waves cleared!"
        titleColor = {1, 0.9, 0.5}
        glowColor = {0.8 * pulse, 0.6 * pulse, 1.0 * pulse, 0.5}
    else
        title = "DEFEAT"
        subtitle = "The void consumed you..."
        titleColor = {1, 0.3, 0.2}
        glowColor = {1.0 * pulse, 0.2 * pulse, 0.1 * pulse, 0.5}
    end

    -- Title
    Fonts.setFont("large")
    local titleWidth = Fonts.get("large"):getWidth(title)
    local titleX = (screenW - titleWidth) / 2
    local titleY = screenH / 2 - 160

    -- Glow effect
    love.graphics.setColor(glowColor)
    love.graphics.print(title, titleX - 2, titleY - 2)
    love.graphics.print(title, titleX + 2, titleY + 2)

    -- Main title
    love.graphics.setColor(titleColor)
    love.graphics.print(title, titleX, titleY)

    -- Subtitle
    Fonts.setFont("medium")
    local subtitleWidth = Fonts.get("medium"):getWidth(subtitle)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.print(subtitle, (screenW - subtitleWidth) / 2, titleY + 45)

    -- Stats panel
    local panelWidth = 300
    local panelHeight = 180
    local panelX = (screenW - panelWidth) / 2
    local panelY = titleY + 90

    -- Panel background
    PixelFrames.draw8BitFrame(panelX, panelY, panelWidth, panelHeight, "hud")

    -- Stats content
    local padding = 16
    local lineHeight = 24
    local labelX = panelX + padding
    local valueX = panelX + panelWidth - padding
    local y = panelY + padding

    Fonts.setFont("small")

    local statsList = {
        { label = "Wave Reached", value = tostring(stats.waveReached), color = Config.COLORS.gold },
        { label = "Enemies Killed", value = _formatNumber(stats.kills), color = Config.COLORS.ruby },
        { label = "Gold Earned", value = _formatNumber(stats.goldEarned), color = Config.COLORS.gold },
        { label = "Damage Dealt", value = _formatNumber(stats.damageDealt), color = Config.COLORS.amethyst },
        { label = "Towers Built", value = tostring(stats.towersBuilt), color = Config.COLORS.emerald },
        { label = "Time Played", value = _formatTime(stats.timePlayed), color = Config.COLORS.sapphire },
    }

    for _, stat in ipairs(statsList) do
        -- Label (left)
        love.graphics.setColor(Config.COLORS.textSecondary)
        love.graphics.print(stat.label, labelX, y)

        -- Value (right-aligned)
        local valueWidth = Fonts.get("small"):getWidth(stat.value)
        love.graphics.setColor(stat.color)
        love.graphics.print(stat.value, valueX - valueWidth, y)

        y = y + lineHeight
    end

    -- Skill Tree button
    local btn1 = state.skillTreeButton
    local style1 = state.hoverSkillTree and "highlight" or "standard"
    PixelFrames.draw8BitCard(btn1.x, btn1.y, btn1.width, btn1.height, style1)

    Fonts.setFont("medium")
    local text1 = "SKILL TREE"
    local text1Width = Fonts.get("medium"):getWidth(text1)
    local text1Height = Fonts.get("medium"):getHeight()
    local text1X = btn1.x + (btn1.width - text1Width) / 2
    local text1Y = btn1.y + (btn1.height - text1Height) / 2

    if state.hoverSkillTree then
        love.graphics.setColor(Config.COLORS.amethyst)
    else
        love.graphics.setColor(Config.COLORS.textPrimary)
    end
    love.graphics.print(text1, text1X, text1Y)

    -- Play Again button
    local btn2 = state.playAgainButton
    local style2 = state.hoverPlayAgain and "highlight" or "standard"
    PixelFrames.draw8BitCard(btn2.x, btn2.y, btn2.width, btn2.height, style2)

    local text2 = "PLAY AGAIN"
    local text2Width = Fonts.get("medium"):getWidth(text2)
    local text2Height = Fonts.get("medium"):getHeight()
    local text2X = btn2.x + (btn2.width - text2Width) / 2
    local text2Y = btn2.y + (btn2.height - text2Height) / 2

    if state.hoverPlayAgain then
        love.graphics.setColor(Config.COLORS.gold)
    else
        love.graphics.setColor(Config.COLORS.textPrimary)
    end
    love.graphics.print(text2, text2X, text2Y)

    -- Currency earned this run hint
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    local hint = "Spend shards in the Skill Tree to power up future runs"
    local hintWidth = Fonts.get("small"):getWidth(hint)
    love.graphics.print(hint, (screenW - hintWidth) / 2, btn1.y + btn1.height + 20)
end

return VictoryScreen
