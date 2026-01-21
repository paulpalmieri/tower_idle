-- src/ui/settings.lua
-- Settings menu - full screen scene with void bullet style (matches main menu)

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Display = require("src.core.display")
local Fonts = require("src.rendering.fonts")
local Audio = require("src.systems.audio")
local Creep = require("src.entities.creep")
local Cursor = require("src.ui.cursor")

local Settings = {}

-- Setting definitions
local SETTINGS_ITEMS = {
    { id = "borderless", label = "Borderless", type = "checkbox" },
    { id = "resolution", label = "Resolution", type = "dropdown" },
    { id = "sound", label = "Sound", type = "checkbox" },
    { id = "volume", label = "Volume", type = "slider" },
    { id = "bloom", label = "Bloom", type = "checkbox" },
    { id = "vignette", label = "Vignette", type = "checkbox" },
    { id = "fog", label = "Fog Particles", type = "checkbox" },
    { id = "dust", label = "Dust Particles", type = "checkbox" },
    { id = "dither", label = "Dither", type = "checkbox" },
}

-- Private state
local state = {
    visible = false,
    time = 0,
    -- Setting values
    borderless = false,
    resolutionIndex = 1,
    soundEnabled = true,
    volume = 50,
    bloomEnabled = true,
    vignetteEnabled = true,
    fogParticlesEnabled = true,
    dustParticlesEnabled = true,
    ditherEnabled = true,
    -- UI state
    hoveredItem = nil,
    dropdownOpen = false,
    hoveredDropdownItem = nil,
    draggingVolume = false,
    backButtonHovered = false,
    -- Layout
    menuItems = {},
    -- Small voids for each menu item
    menuVoids = {},
    -- Hover scale interpolation per item
    itemScales = {},
    backButtonScale = 1.0,
}

-- =============================================================================
-- HELPERS
-- =============================================================================

local function _pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function _calculateLayout()
    local gameW, gameH = Display.getGameDimensions()
    local cfg = Config.SETTINGS_MENU

    state.menuItems = {}
    local font = Fonts.get("medium")
    local fontHeight = font:getHeight()

    -- Find max label width
    local maxLabelWidth = 0
    for _, item in ipairs(SETTINGS_ITEMS) do
        local w = font:getWidth(item.label)
        if w > maxLabelWidth then maxLabelWidth = w end
    end

    -- Total width = void + gap + label + gap + control
    local voidSize = cfg.voidSize
    local voidTextGap = cfg.voidTextGap
    local labelControlGap = cfg.labelControlGap
    local controlWidth = cfg.controlWidth

    local totalWidth = voidSize + voidTextGap + maxLabelWidth + labelControlGap + controlWidth

    -- Calculate positions (centered column)
    local columnX = (gameW - totalWidth) / 2
    local startY = cfg.columnY

    for i, item in ipairs(SETTINGS_ITEMS) do
        local itemH = fontHeight + 8
        local itemY = startY + (i - 1) * cfg.itemSpacing

        local menuItem = {
            id = item.id,
            label = item.label,
            type = item.type,
            -- Void position (center of the void)
            voidX = columnX + voidSize / 2,
            voidY = itemY + itemH / 2,
            -- Label position
            labelX = columnX + voidSize + voidTextGap,
            labelY = itemY,
            -- Control position
            controlX = columnX + voidSize + voidTextGap + maxLabelWidth + labelControlGap,
            controlY = itemY,
            controlWidth = controlWidth,
            controlHeight = itemH,
            -- Hit area (full row)
            hitX = columnX - 10,
            hitY = itemY - 4,
            hitWidth = totalWidth + 20,
            hitHeight = itemH + 8,
        }

        table.insert(state.menuItems, menuItem)

        -- Initialize scale for this item
        state.itemScales[item.id] = 1.0
    end

    -- Back button position
    state.backButtonX = 40
    state.backButtonY = 40
    state.backButtonW = 120
    state.backButtonH = 40
end

local function _createMenuVoids()
    state.menuVoids = {}
    for _, item in ipairs(SETTINGS_ITEMS) do
        local void = Creep(0, 0, "voidSpawn")
        void.spawnPhase = "active"
        state.menuVoids[item.id] = void
    end
    -- Back button void
    state.backVoid = Creep(0, 0, "voidSpawn")
    state.backVoid.spawnPhase = "active"
end

local function _applyWindowMode()
    local desktopW, desktopH = love.window.getDesktopDimensions()

    if state.borderless then
        love.window.setMode(desktopW, desktopH, {
            borderless = true,
            fullscreen = true,
            fullscreentype = "desktop",
            resizable = false,
        })
    else
        local res = Config.SETTINGS.resolutions[state.resolutionIndex]
        love.window.setMode(res.width, res.height, {
            borderless = false,
            fullscreen = false,
            centered = true,
            resizable = false,
        })
    end

    Display.handleResize()
    _calculateLayout()
end

local function _applyAudioSettings()
    Audio.setEnabled(state.soundEnabled)
    Audio.setMasterVolume(state.volume / 100)
end

local function _getSettingValue(id)
    if id == "borderless" then return state.borderless
    elseif id == "sound" then return state.soundEnabled
    elseif id == "bloom" then return state.bloomEnabled
    elseif id == "vignette" then return state.vignetteEnabled
    elseif id == "fog" then return state.fogParticlesEnabled
    elseif id == "dust" then return state.dustParticlesEnabled
    elseif id == "dither" then return state.ditherEnabled
    end
    return false
end

local function _toggleSetting(id)
    if id == "borderless" then
        state.borderless = not state.borderless
        _applyWindowMode()
    elseif id == "sound" then
        state.soundEnabled = not state.soundEnabled
        _applyAudioSettings()
    elseif id == "bloom" then
        state.bloomEnabled = not state.bloomEnabled
        EventBus.emit("visual_setting_changed", {setting = "bloom", enabled = state.bloomEnabled})
    elseif id == "vignette" then
        state.vignetteEnabled = not state.vignetteEnabled
    elseif id == "fog" then
        state.fogParticlesEnabled = not state.fogParticlesEnabled
    elseif id == "dust" then
        state.dustParticlesEnabled = not state.dustParticlesEnabled
    elseif id == "dither" then
        state.ditherEnabled = not state.ditherEnabled
        Config.TOWER_DITHER.enabled = state.ditherEnabled
    end
end

local function _isDisabled(id)
    if id == "resolution" then return state.borderless end
    if id == "volume" then return not state.soundEnabled end
    return false
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function Settings.init()
    -- Set initial state from Config
    state.soundEnabled = Config.AUDIO.enabled
    state.volume = math.floor(Config.AUDIO.masterVolume * 100)

    local vfx = Config.SETTINGS.visualEffects
    state.bloomEnabled = vfx.bloom
    state.vignetteEnabled = vfx.vignette
    state.fogParticlesEnabled = vfx.fogParticles
    state.dustParticlesEnabled = vfx.dustParticles
    state.ditherEnabled = Config.TOWER_DITHER.enabled

    -- Find current resolution index
    local currentW, currentH = love.graphics.getDimensions()
    for i, res in ipairs(Config.SETTINGS.resolutions) do
        if res.width == currentW and res.height == currentH then
            state.resolutionIndex = i
            break
        end
    end

    -- Check if currently borderless
    local _, _, flags = love.window.getMode()
    state.borderless = flags.borderless or flags.fullscreen

    -- Initialize display scaling
    Display.init()
    Display.handleResize()

    _calculateLayout()
    _createMenuVoids()
end

function Settings.update(screenX, screenY)
    if not state.visible then return end

    -- Convert screen to game coordinates
    local mouseX, mouseY = Display.screenToGame(screenX, screenY)

    local dt = love.timer.getDelta()
    local cfg = Config.SETTINGS_MENU
    state.time = state.time + dt

    -- Update void spawn animation times
    for _, void in pairs(state.menuVoids) do
        void.time = void.time + dt
    end
    if state.backVoid then
        state.backVoid.time = state.backVoid.time + dt
    end

    -- Check back button hover
    state.backButtonHovered = _pointInRect(mouseX, mouseY,
        state.backButtonX, state.backButtonY, state.backButtonW, state.backButtonH)

    -- Check hover states for menu items
    state.hoveredItem = nil
    if not state.dropdownOpen then
        for _, item in ipairs(state.menuItems) do
            if not _isDisabled(item.id) and _pointInRect(mouseX, mouseY, item.hitX, item.hitY, item.hitWidth, item.hitHeight) then
                state.hoveredItem = item.id
                break
            end
        end
    end

    -- Check dropdown item hover
    state.hoveredDropdownItem = nil
    if state.dropdownOpen then
        local resItem = nil
        for _, item in ipairs(state.menuItems) do
            if item.id == "resolution" then resItem = item break end
        end
        if resItem then
            local dropdownItemH = cfg.dropdownItemHeight
            for i, res in ipairs(Config.SETTINGS.resolutions) do
                local itemY = resItem.controlY + resItem.controlHeight + (i - 1) * dropdownItemH
                if _pointInRect(mouseX, mouseY, resItem.controlX, itemY, resItem.controlWidth, dropdownItemH) then
                    state.hoveredDropdownItem = i
                    break
                end
            end
        end
    end

    -- Smoothly interpolate scales for hover effect
    for _, item in ipairs(SETTINGS_ITEMS) do
        local targetScale = (state.hoveredItem == item.id) and cfg.hoverScale or 1.0
        local currentScale = state.itemScales[item.id]
        state.itemScales[item.id] = currentScale + (targetScale - currentScale) * dt * 12
    end

    -- Back button scale
    local backTargetScale = state.backButtonHovered and cfg.hoverScale or 1.0
    state.backButtonScale = state.backButtonScale + (backTargetScale - state.backButtonScale) * dt * 12

    -- Handle volume slider dragging
    if state.draggingVolume then
        local volItem = nil
        for _, item in ipairs(state.menuItems) do
            if item.id == "volume" then volItem = item break end
        end
        if volItem then
            local relX = mouseX - volItem.controlX
            local percent = math.max(0, math.min(1, relX / volItem.controlWidth))
            state.volume = math.floor(percent * 100)
            _applyAudioSettings()
        end
    end

    -- Update cursor
    if state.hoveredItem or state.backButtonHovered or state.hoveredDropdownItem then
        Cursor.setCursor(Cursor.POINTER)
    else
        Cursor.setCursor(Cursor.ARROW)
    end
end

function Settings.handleClick(screenX, screenY)
    if not state.visible then return false end

    local x, y = Display.screenToGame(screenX, screenY)
    local cfg = Config.SETTINGS_MENU

    -- Back button
    if _pointInRect(x, y, state.backButtonX, state.backButtonY, state.backButtonW, state.backButtonH) then
        Settings.hide()
        return true
    end

    -- Close dropdown if clicking outside
    if state.dropdownOpen then
        local resItem = nil
        for _, item in ipairs(state.menuItems) do
            if item.id == "resolution" then resItem = item break end
        end

        -- Check dropdown items first
        if resItem then
            local dropdownItemH = cfg.dropdownItemHeight
            for i, res in ipairs(Config.SETTINGS.resolutions) do
                local itemY = resItem.controlY + resItem.controlHeight + (i - 1) * dropdownItemH
                if _pointInRect(x, y, resItem.controlX, itemY, resItem.controlWidth, dropdownItemH) then
                    state.resolutionIndex = i
                    state.dropdownOpen = false
                    if not state.borderless then
                        _applyWindowMode()
                    end
                    return true
                end
            end
        end

        -- Click elsewhere closes dropdown
        state.dropdownOpen = false
        return true
    end

    -- Check menu items
    for _, item in ipairs(state.menuItems) do
        if _pointInRect(x, y, item.hitX, item.hitY, item.hitWidth, item.hitHeight) then
            if _isDisabled(item.id) then
                return true
            end

            if item.type == "checkbox" then
                _toggleSetting(item.id)
            elseif item.type == "dropdown" then
                state.dropdownOpen = not state.dropdownOpen
            elseif item.type == "slider" then
                state.draggingVolume = true
                local relX = x - item.controlX
                local percent = math.max(0, math.min(1, relX / item.controlWidth))
                state.volume = math.floor(percent * 100)
                _applyAudioSettings()
            end
            return true
        end
    end

    return true
end

function Settings.handleRelease(x, y)
    state.draggingVolume = false
end

function Settings.draw()
    if not state.visible then return end

    local gameW, gameH = Display.getGameDimensions()
    local cfg = Config.SETTINGS_MENU

    -- Draw solid dark background (full screen scene)
    love.graphics.setColor(cfg.backgroundColor)
    love.graphics.rectangle("fill", 0, 0, gameW, gameH)

    -- Draw back button with void
    local backScale = state.backButtonScale
    local backVoidX = state.backButtonX + 20
    local backVoidY = state.backButtonY + state.backButtonH / 2

    if state.backVoid then
        local voidScale = cfg.voidScale * backScale
        love.graphics.push()
        love.graphics.translate(backVoidX, backVoidY)
        love.graphics.scale(voidScale, voidScale)
        state.backVoid:draw()
        love.graphics.pop()
    end

    -- Back text
    Fonts.setFont("medium")
    local backText = "BACK"
    local font = Fonts.get("medium")
    local backTextX = backVoidX + 25
    local backTextY = state.backButtonY + (state.backButtonH - font:getHeight()) / 2

    if state.backButtonHovered then
        love.graphics.setColor(cfg.textHoverColor)
    else
        love.graphics.setColor(cfg.textColor)
    end

    love.graphics.push()
    love.graphics.translate(backTextX, backTextY + font:getHeight() / 2)
    love.graphics.scale(backScale, backScale)
    love.graphics.translate(-backTextX, -(backTextY + font:getHeight() / 2))
    love.graphics.print(backText, backTextX, backTextY)
    love.graphics.pop()

    -- Draw title
    Fonts.setFont("title")
    love.graphics.setColor(cfg.textColor)
    love.graphics.printf("SETTINGS", 0, cfg.titleY, gameW, "center")

    -- Draw menu items
    Fonts.setFont("medium")
    font = Fonts.get("medium")

    for _, item in ipairs(state.menuItems) do
        local isHovered = state.hoveredItem == item.id
        local scale = state.itemScales[item.id]
        local void = state.menuVoids[item.id]
        local disabled = _isDisabled(item.id)

        -- Draw void bullet
        if void then
            local voidScale = cfg.voidScale * scale
            if disabled then voidScale = voidScale * 0.7 end
            love.graphics.push()
            love.graphics.translate(item.voidX, item.voidY)
            love.graphics.scale(voidScale, voidScale)
            if disabled then
                love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
            end
            void:draw()
            love.graphics.pop()
        end

        -- Draw label with scale effect
        local labelCenterY = item.labelY + font:getHeight() / 2

        if disabled then
            love.graphics.setColor(cfg.textDisabledColor)
        elseif isHovered then
            love.graphics.setColor(cfg.textHoverColor)
        else
            love.graphics.setColor(cfg.textColor)
        end

        love.graphics.push()
        love.graphics.translate(item.labelX, labelCenterY)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-item.labelX, -labelCenterY)
        love.graphics.print(item.label, item.labelX, item.labelY)
        love.graphics.pop()

        -- Draw control based on type
        if item.type == "checkbox" then
            _drawCheckbox(item, _getSettingValue(item.id), isHovered, disabled, scale)
        elseif item.type == "dropdown" then
            _drawDropdown(item, Config.SETTINGS.resolutions[state.resolutionIndex].label,
                         isHovered, disabled, state.dropdownOpen, scale)
        elseif item.type == "slider" then
            _drawSlider(item, state.volume / 100, isHovered, disabled, scale)
        end
    end

    -- Draw dropdown items if open
    if state.dropdownOpen then
        local resItem = nil
        for _, item in ipairs(state.menuItems) do
            if item.id == "resolution" then resItem = item break end
        end
        if resItem then
            _drawDropdownItems(resItem)
        end
    end

    -- Draw hint at bottom
    Fonts.setFont("small")
    love.graphics.setColor(cfg.hintColor)
    love.graphics.printf("Press ESC or click BACK to return", 0, gameH - 40, gameW, "center")
end

function Settings.show()
    state.visible = true
    state.dropdownOpen = false
    state.draggingVolume = false
    state.time = 0

    -- Reset scales
    for _, item in ipairs(SETTINGS_ITEMS) do
        state.itemScales[item.id] = 1.0
    end
    state.backButtonScale = 1.0

    _calculateLayout()
    _createMenuVoids()
end

function Settings.hide()
    state.visible = false
    state.dropdownOpen = false
    state.draggingVolume = false
end

function Settings.toggle()
    if state.visible then
        Settings.hide()
    else
        Settings.show()
    end
end

function Settings.isVisible()
    return state.visible
end

-- =============================================================================
-- VISUAL EFFECTS API
-- =============================================================================

function Settings.isBloomEnabled()
    return state.bloomEnabled
end

function Settings.isVignetteEnabled()
    return state.vignetteEnabled
end

function Settings.isFogParticlesEnabled()
    return state.fogParticlesEnabled
end

function Settings.isDustParticlesEnabled()
    return state.dustParticlesEnabled
end

function Settings.isDitherEnabled()
    return state.ditherEnabled
end

function Settings.setBloomEnabled(enabled)
    state.bloomEnabled = enabled
end

function Settings.toggleBloom()
    state.bloomEnabled = not state.bloomEnabled
    EventBus.emit("visual_setting_changed", {setting = "bloom", enabled = state.bloomEnabled})
    return state.bloomEnabled
end

function Settings.toggleBorderless()
    state.borderless = not state.borderless
    _applyWindowMode()
    return state.borderless
end

-- =============================================================================
-- UI DRAWING HELPERS
-- =============================================================================

function _drawCheckbox(item, checked, hovered, disabled, scale)
    local cfg = Config.SETTINGS_MENU
    local size = cfg.checkboxSize

    local cx = item.controlX + size / 2
    local cy = item.controlY + item.controlHeight / 2

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-cx, -cy)

    local x = item.controlX
    local y = item.controlY + (item.controlHeight - size) / 2

    -- Background
    if disabled then
        love.graphics.setColor(0.15, 0.12, 0.18, 0.5)
    elseif hovered then
        love.graphics.setColor(0.25, 0.2, 0.3, 0.8)
    else
        love.graphics.setColor(0.12, 0.1, 0.15, 0.8)
    end
    love.graphics.rectangle("fill", x, y, size, size)

    -- Border
    if disabled then
        love.graphics.setColor(0.3, 0.25, 0.35, 0.5)
    elseif hovered then
        love.graphics.setColor(cfg.textHoverColor)
    else
        love.graphics.setColor(0.5, 0.4, 0.6, 0.8)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, size, size)

    -- Checkmark
    if checked then
        if disabled then
            love.graphics.setColor(0.4, 0.6, 0.4, 0.5)
        else
            love.graphics.setColor(Config.COLORS.emerald)
        end
        local inset = 5
        love.graphics.setLineWidth(3)
        love.graphics.line(
            x + inset, y + size / 2,
            x + size / 2 - 1, y + size - inset,
            x + size - inset, y + inset
        )
    end

    love.graphics.pop()
end

function _drawDropdown(item, label, hovered, disabled, open, scale)
    local cfg = Config.SETTINGS_MENU

    local cx = item.controlX + item.controlWidth / 2
    local cy = item.controlY + item.controlHeight / 2

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-cx, -cy)

    local x = item.controlX
    local y = item.controlY
    local w = item.controlWidth
    local h = item.controlHeight

    -- Background
    if disabled then
        love.graphics.setColor(0.15, 0.12, 0.18, 0.5)
    elseif hovered or open then
        love.graphics.setColor(0.25, 0.2, 0.3, 0.8)
    else
        love.graphics.setColor(0.12, 0.1, 0.15, 0.8)
    end
    love.graphics.rectangle("fill", x, y, w, h)

    -- Border
    if disabled then
        love.graphics.setColor(0.3, 0.25, 0.35, 0.5)
    elseif hovered or open then
        love.graphics.setColor(cfg.textHoverColor)
    else
        love.graphics.setColor(0.5, 0.4, 0.6, 0.8)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)

    -- Label
    Fonts.setFont("small")
    if disabled then
        love.graphics.setColor(cfg.textDisabledColor)
    else
        love.graphics.setColor(cfg.textColor)
    end
    love.graphics.print(label, x + 10, y + (h - Fonts.get("small"):getHeight()) / 2)

    -- Arrow
    local arrowChar = open and "^" or "v"
    love.graphics.print(arrowChar, x + w - 20, y + (h - Fonts.get("small"):getHeight()) / 2)

    love.graphics.pop()
end

function _drawDropdownItems(item)
    local cfg = Config.SETTINGS_MENU
    local itemHeight = cfg.dropdownItemHeight

    for i, res in ipairs(Config.SETTINGS.resolutions) do
        local itemY = item.controlY + item.controlHeight + (i - 1) * itemHeight
        local hovered = state.hoveredDropdownItem == i
        local selected = i == state.resolutionIndex

        -- Background
        if hovered then
            love.graphics.setColor(0.3, 0.25, 0.35, 0.95)
        else
            love.graphics.setColor(0.12, 0.1, 0.15, 0.95)
        end
        love.graphics.rectangle("fill", item.controlX, itemY, item.controlWidth, itemHeight)

        -- Border
        love.graphics.setColor(0.5, 0.4, 0.6, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", item.controlX, itemY, item.controlWidth, itemHeight)

        -- Label
        Fonts.setFont("small")
        if selected then
            love.graphics.setColor(Config.COLORS.gold)
        elseif hovered then
            love.graphics.setColor(cfg.textHoverColor)
        else
            love.graphics.setColor(cfg.textColor)
        end
        love.graphics.print(res.label, item.controlX + 10, itemY + (itemHeight - Fonts.get("small"):getHeight()) / 2)
    end
end

function _drawSlider(item, percent, hovered, disabled, scale)
    local cfg = Config.SETTINGS_MENU

    local cx = item.controlX + item.controlWidth / 2
    local cy = item.controlY + item.controlHeight / 2

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-cx, -cy)

    local x = item.controlX
    local y = item.controlY
    local w = item.controlWidth - 50  -- Leave room for percentage
    local h = item.controlHeight
    local trackHeight = 8
    local trackY = y + (h - trackHeight) / 2

    -- Track background
    if disabled then
        love.graphics.setColor(0.15, 0.12, 0.18, 0.5)
    else
        love.graphics.setColor(0.12, 0.1, 0.15, 0.8)
    end
    love.graphics.rectangle("fill", x, trackY, w, trackHeight)

    -- Filled portion
    if not disabled then
        love.graphics.setColor(Config.COLORS.emerald[1], Config.COLORS.emerald[2], Config.COLORS.emerald[3], 0.8)
        love.graphics.rectangle("fill", x, trackY, w * percent, trackHeight)
    end

    -- Track border
    if disabled then
        love.graphics.setColor(0.3, 0.25, 0.35, 0.5)
    elseif hovered then
        love.graphics.setColor(cfg.textHoverColor)
    else
        love.graphics.setColor(0.5, 0.4, 0.6, 0.8)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, trackY, w, trackHeight)

    -- Handle
    local handleX = x + w * percent
    local handleSize = 16
    if disabled then
        love.graphics.setColor(0.3, 0.25, 0.35, 0.5)
    elseif hovered or state.draggingVolume then
        love.graphics.setColor(Config.COLORS.gold)
    else
        love.graphics.setColor(0.6, 0.5, 0.7, 1.0)
    end
    love.graphics.rectangle("fill", handleX - handleSize / 2, y + (h - handleSize) / 2, handleSize, handleSize)
    love.graphics.setColor(0.5, 0.4, 0.6, 0.8)
    love.graphics.rectangle("line", handleX - handleSize / 2, y + (h - handleSize) / 2, handleSize, handleSize)

    -- Percentage text
    Fonts.setFont("small")
    if disabled then
        love.graphics.setColor(cfg.textDisabledColor)
    else
        love.graphics.setColor(cfg.textColor)
    end
    love.graphics.print(math.floor(percent * 100) .. "%", x + w + 10, y + (h - Fonts.get("small"):getHeight()) / 2)

    love.graphics.pop()
end

return Settings
