-- src/ui/main_menu.lua
-- Main menu scene with small void bullets for each menu option

local Config = require("src.config")
local Display = require("src.core.display")
local Fonts = require("src.rendering.fonts")
local Creep = require("src.entities.creep")
local Cursor = require("src.ui.cursor")

local MainMenu = {}

-- Private state
local state = {
    visible = true,         -- Starts visible (game launches to main menu)
    time = 0,
    -- Menu item hover states
    hoveredItem = nil,      -- "play" | "skills" | "settings" | nil
    -- Layout (calculated in init based on config)
    menuItems = {},
    -- Small voids for each menu item (used as bullet points)
    menuVoids = {},
    -- Hover scale interpolation per item
    itemScales = {},
}

-- Menu item definitions
local MENU_ITEMS = {
    { id = "play", label = "PLAY" },
    { id = "skills", label = "SKILLS" },
    { id = "settings", label = "SETTINGS" },
}

-- =============================================================================
-- HELPERS
-- =============================================================================

local function _pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function _calculateLayout()
    local gameW, gameH = Display.getGameDimensions()
    local cfg = Config.MAIN_MENU

    -- Calculate menu items layout
    state.menuItems = {}
    local font = Fonts.get("title")

    -- Find max text width (without the void bullet)
    local maxTextWidth = 0
    for _, item in ipairs(MENU_ITEMS) do
        local w = font:getWidth(item.label)
        if w > maxTextWidth then maxTextWidth = w end
    end

    -- Total width = void size + gap + text
    local voidSize = cfg.voidSize
    local voidTextGap = cfg.voidTextGap
    local totalWidth = voidSize + voidTextGap + maxTextWidth

    -- Calculate positions (centered column)
    local columnX = (gameW - totalWidth) / 2
    local startY = cfg.columnY

    for i, item in ipairs(MENU_ITEMS) do
        local itemH = font:getHeight() + 8
        local itemY = startY + (i - 1) * cfg.itemSpacing

        table.insert(state.menuItems, {
            id = item.id,
            label = item.label,
            -- Void position (center of the void)
            voidX = columnX + voidSize / 2,
            voidY = itemY + itemH / 2,
            -- Text position
            textX = columnX + voidSize + voidTextGap,
            textY = itemY,
            -- Hit area
            hitX = columnX - 10,
            hitY = itemY - 4,
            hitWidth = totalWidth + 20,
            hitHeight = itemH + 8,
        })

        -- Initialize scale for this item
        state.itemScales[item.id] = 1.0
    end
end

-- Create void spawns for each menu item
local function _createMenuVoids()
    state.menuVoids = {}
    for _, item in ipairs(MENU_ITEMS) do
        local void = Creep(0, 0, "voidSpawn")
        void.spawnPhase = "active"  -- Skip spawn animation
        state.menuVoids[item.id] = void
    end
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function MainMenu.init()
    -- Calculate layout
    _calculateLayout()

    -- Create void spawns for menu items
    _createMenuVoids()
end

function MainMenu.show()
    state.visible = true
    state.time = 0
    state.hoveredItem = nil

    -- Reset scales
    for _, item in ipairs(MENU_ITEMS) do
        state.itemScales[item.id] = 1.0
    end

    -- Recreate void spawns
    _createMenuVoids()

    -- Recalculate layout
    _calculateLayout()
end

function MainMenu.hide()
    state.visible = false
end

function MainMenu.isVisible()
    return state.visible
end

function MainMenu.update(mouseX, mouseY)
    if not state.visible then return end

    local dt = love.timer.getDelta()
    local cfg = Config.MAIN_MENU
    state.time = state.time + dt

    -- Update void spawn animation times
    for _, void in pairs(state.menuVoids) do
        void.time = void.time + dt
    end

    -- Check hover states for menu items
    state.hoveredItem = nil
    for _, item in ipairs(state.menuItems) do
        if _pointInRect(mouseX, mouseY, item.hitX, item.hitY, item.hitWidth, item.hitHeight) then
            state.hoveredItem = item.id
            break
        end
    end

    -- Smoothly interpolate scales for hover effect
    for _, item in ipairs(MENU_ITEMS) do
        local targetScale = (state.hoveredItem == item.id) and cfg.hoverScale or 1.0
        local currentScale = state.itemScales[item.id]
        state.itemScales[item.id] = currentScale + (targetScale - currentScale) * dt * 12
    end

    -- Update cursor
    if state.hoveredItem then
        Cursor.setCursor(Cursor.POINTER)
    else
        Cursor.setCursor(Cursor.ARROW)
    end
end

function MainMenu.handleClick(x, y, button)
    if not state.visible then return nil end
    if button ~= 1 then return nil end

    -- Check menu items
    for _, item in ipairs(state.menuItems) do
        if _pointInRect(x, y, item.hitX, item.hitY, item.hitWidth, item.hitHeight) then
            return { action = item.id }
        end
    end

    return nil
end

function MainMenu.draw()
    if not state.visible then return end

    local gameW, gameH = Display.getGameDimensions()
    local cfg = Config.MAIN_MENU

    -- Draw solid dark background (this is a separate scene)
    love.graphics.setColor(cfg.backgroundColor)
    love.graphics.rectangle("fill", 0, 0, gameW, gameH)

    -- Draw menu items with void bullets
    for _, item in ipairs(state.menuItems) do
        local isHovered = state.hoveredItem == item.id
        local scale = state.itemScales[item.id]
        local void = state.menuVoids[item.id]

        -- Draw void bullet (small void as bullet point)
        if void then
            local voidScale = cfg.voidScale * scale
            love.graphics.push()
            love.graphics.translate(item.voidX, item.voidY)
            love.graphics.scale(voidScale, voidScale)
            void:draw()
            love.graphics.pop()
        end

        -- Draw text with scale effect (scale around text center)
        Fonts.setFont("title")
        local font = Fonts.get("title")
        local textW = font:getWidth(item.label)
        local textH = font:getHeight()

        -- Calculate scaled text position (scale from left-center of text area)
        local textCenterX = item.textX
        local textCenterY = item.textY + textH / 2

        if isHovered then
            love.graphics.setColor(cfg.textHoverColor)
        else
            love.graphics.setColor(cfg.textColor)
        end

        love.graphics.push()
        love.graphics.translate(textCenterX, textCenterY)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-textCenterX, -textCenterY)
        love.graphics.print(item.label, item.textX, item.textY)
        love.graphics.pop()
    end

    -- Draw hint at bottom
    Fonts.setFont("small")
    love.graphics.setColor(cfg.hintColor)
    love.graphics.printf("Press ESC to quit", 0, gameH - 40, gameW, "center")
end

return MainMenu
