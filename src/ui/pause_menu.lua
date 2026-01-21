-- src/ui/pause_menu.lua
-- Pause menu overlay shown when ESC is pressed during gameplay
-- Offers Resume and Abandon Run options

local Config = require("src.config")
local Fonts = require("src.rendering.fonts")
local PixelFrames = require("src.ui.pixel_frames")
local Settings = require("src.ui.settings")

local PauseMenu = {}

local state = {
    visible = false,
    time = 0,
    hoverResume = false,
    hoverAbandon = false,
    resumeButton = nil,
    abandonButton = nil,
}

local function _calculateLayout()
    local gameW, gameH = Settings.getGameDimensions()
    local buttonWidth = 180
    local buttonHeight = 44
    local buttonSpacing = 16
    local centerX = gameW / 2
    local centerY = gameH / 2

    state.resumeButton = {
        x = centerX - buttonWidth / 2,
        y = centerY - buttonHeight - buttonSpacing / 2,
        width = buttonWidth,
        height = buttonHeight,
    }

    state.abandonButton = {
        x = centerX - buttonWidth / 2,
        y = centerY + buttonSpacing / 2,
        width = buttonWidth,
        height = buttonHeight,
    }
end

function PauseMenu.init()
    state.visible = false
    state.time = 0
    state.hoverResume = false
    state.hoverAbandon = false
    _calculateLayout()
end

function PauseMenu.show()
    state.visible = true
    state.time = 0
end

function PauseMenu.hide()
    state.visible = false
end

function PauseMenu.isVisible()
    return state.visible
end

local function _pointInRect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.width and
           py >= rect.y and py <= rect.y + rect.height
end

function PauseMenu.update(mx, my)
    if not state.visible then return end

    state.time = state.time + love.timer.getDelta()

    -- Check hover states
    state.hoverResume = _pointInRect(mx, my, state.resumeButton)
    state.hoverAbandon = _pointInRect(mx, my, state.abandonButton)
end

function PauseMenu.handleClick(x, y)
    if not state.visible then return nil end

    if _pointInRect(x, y, state.resumeButton) then
        return { action = "resume" }
    end

    if _pointInRect(x, y, state.abandonButton) then
        return { action = "abandon" }
    end

    return nil
end

function PauseMenu.draw()
    if not state.visible then return end

    -- Recalculate layout in case window dimensions changed
    _calculateLayout()

    local screenW, screenH = Settings.getGameDimensions()

    -- Darken background
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Animated pulse for title
    local pulse = math.sin(state.time * 2) * 0.15 + 0.85

    -- Title
    Fonts.setFont("large")
    local title = "PAUSED"
    local titleWidth = Fonts.get("large"):getWidth(title)
    local titleX = (screenW - titleWidth) / 2
    local titleY = screenH / 2 - 120

    -- Glow effect
    love.graphics.setColor(0.6 * pulse, 0.4 * pulse, 0.8 * pulse, 0.5)
    love.graphics.print(title, titleX - 2, titleY - 2)
    love.graphics.print(title, titleX + 2, titleY + 2)

    -- Main title
    love.graphics.setColor(0.8, 0.7, 1.0)
    love.graphics.print(title, titleX, titleY)

    -- Resume button
    local btn1 = state.resumeButton
    local style1 = state.hoverResume and "highlight" or "standard"
    PixelFrames.draw8BitCard(btn1.x, btn1.y, btn1.width, btn1.height, style1)

    Fonts.setFont("medium")
    local text1 = "RESUME"
    local text1Width = Fonts.get("medium"):getWidth(text1)
    local text1Height = Fonts.get("medium"):getHeight()
    local text1X = btn1.x + (btn1.width - text1Width) / 2
    local text1Y = btn1.y + (btn1.height - text1Height) / 2

    if state.hoverResume then
        love.graphics.setColor(Config.COLORS.emerald)
    else
        love.graphics.setColor(Config.COLORS.textPrimary)
    end
    love.graphics.print(text1, text1X, text1Y)

    -- Abandon Run button
    local btn2 = state.abandonButton
    local style2 = state.hoverAbandon and "highlight" or "standard"
    PixelFrames.draw8BitCard(btn2.x, btn2.y, btn2.width, btn2.height, style2)

    local text2 = "ABANDON RUN"
    local text2Width = Fonts.get("medium"):getWidth(text2)
    local text2Height = Fonts.get("medium"):getHeight()
    local text2X = btn2.x + (btn2.width - text2Width) / 2
    local text2Y = btn2.y + (btn2.height - text2Height) / 2

    if state.hoverAbandon then
        love.graphics.setColor(Config.COLORS.ruby)
    else
        love.graphics.setColor(Config.COLORS.textSecondary)
    end
    love.graphics.print(text2, text2X, text2Y)

    -- Hint text
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textSecondary)
    local hint = "Press ESC to resume"
    local hintWidth = Fonts.get("small"):getWidth(hint)
    love.graphics.print(hint, (screenW - hintWidth) / 2, btn2.y + btn2.height + 24)
end

return PauseMenu
