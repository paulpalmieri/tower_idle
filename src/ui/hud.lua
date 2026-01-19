-- src/ui/hud.lua
-- In-game heads-up display

local Config = require("src.config")

local HUD = {}

function HUD.init()
    -- Nothing to init yet
end

function HUD.draw(economy, waves)
    local y = Config.SCREEN_HEIGHT - Config.UI.hudHeight + 15

    -- Gold
    love.graphics.setColor(Config.COLORS.gold)
    love.graphics.print(string.format("GOLD: %d", economy.getGold()), 20, y)

    -- Income
    love.graphics.setColor(Config.COLORS.income)
    love.graphics.print(string.format("+%d/tick", economy.getIncome()), 150, y)

    -- Income timer
    local progress = economy.getIncomeProgress()
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 260, y, 100, 16)
    love.graphics.setColor(Config.COLORS.income)
    love.graphics.rectangle("fill", 260, y, 100 * progress, 16)

    -- Lives
    love.graphics.setColor(Config.COLORS.lives)
    love.graphics.print(string.format("LIVES: %d", economy.getLives()), 400, y)

    -- Wave
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print(string.format("WAVE: %d", waves.getWaveNumber()), 520, y)
end

return HUD
