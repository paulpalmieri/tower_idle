-- src/ui/settings.lua
-- Settings menu modal with borderless, resolution, sound, and volume options

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Fonts = require("src.rendering.fonts")
local PixelFrames = require("src.ui.pixel_frames")
local Audio = require("src.systems.audio")

local Settings = {}

-- Fixed 16:9 canvas resolution (the game is designed for this)
-- Canvas is always this size, scaled to fit any screen with letterboxing
local CANVAS_WIDTH = 1280    -- Fixed canvas width
local CANVAS_HEIGHT = 720    -- Fixed canvas height (16:9 aspect ratio)
local ASPECT_RATIO = CANVAS_WIDTH / CANVAS_HEIGHT  -- 1.777...
local PANEL_WIDTH = 320      -- Narrower overlay panel width

-- Private state
local state = {
    visible = false,
    borderless = false,
    resolutionIndex = 1,
    soundEnabled = true,
    volume = 50,
    -- Visual effects toggles (all enabled by default)
    bloomEnabled = true,
    vignetteEnabled = true,
    fogParticlesEnabled = true,
    dustParticlesEnabled = true,
    ditherEnabled = true,
    controls = {},
    dropdownOpen = false,
    draggingVolume = false,
    hoverControl = nil,
    -- Computed layout positions (in game coordinates)
    x = 0,
    y = 0,
    width = 0,
    height = 0,
    -- Scaling state
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    windowWidth = CANVAS_WIDTH,
    windowHeight = CANVAS_HEIGHT,
    -- Fixed game dimensions (always 1280x720)
    gameWidth = CANVAS_WIDTH,
    gameHeight = CANVAS_HEIGHT,
}

-- =============================================================================
-- HELPERS
-- =============================================================================

local function _pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function _calculateLayout()
    local cfg = Config.UI.settings
    state.width = cfg.width
    state.height = cfg.height
    -- Center in actual window (not game coordinates)
    state.x = (state.windowWidth - state.width) / 2
    state.y = (state.windowHeight - state.height) / 2

    local padding = cfg.padding
    local rowSpacing = cfg.rowSpacing
    local labelWidth = cfg.labelWidth
    local controlWidth = cfg.controlWidth

    local contentX = state.x + padding
    local controlX = contentX + labelWidth
    local y = state.y + padding + 30  -- After title

    -- Close button (top right)
    state.controls.closeButton = {
        x = state.x + state.width - cfg.closeButtonSize - 8,
        y = state.y + 8,
        width = cfg.closeButtonSize,
        height = cfg.closeButtonSize,
        type = "close",
    }

    -- Borderless checkbox
    state.controls.borderless = {
        x = controlX,
        y = y,
        width = cfg.checkboxSize,
        height = cfg.checkboxSize,
        type = "checkbox",
    }
    y = y + cfg.checkboxSize + rowSpacing

    -- Resolution dropdown
    state.controls.resolution = {
        x = controlX,
        y = y,
        width = controlWidth,
        height = cfg.dropdownHeight,
        type = "dropdown",
    }
    y = y + cfg.dropdownHeight + rowSpacing + 10  -- Extra spacing before audio section

    -- Separator position
    state.separatorY = y - 5
    y = y + 10

    -- Sound checkbox
    state.controls.sound = {
        x = controlX,
        y = y,
        width = cfg.checkboxSize,
        height = cfg.checkboxSize,
        type = "checkbox",
    }
    y = y + cfg.checkboxSize + rowSpacing

    -- Volume slider
    state.controls.volume = {
        x = controlX,
        y = y,
        width = controlWidth - 40,  -- Leave room for percentage
        height = cfg.sliderHeight,
        type = "slider",
    }
    y = y + cfg.sliderHeight + rowSpacing + 10  -- Extra spacing before visual section

    -- Separator position for visual effects
    state.separatorY2 = y - 5
    y = y + 10

    -- Lighting checkbox
    state.controls.lighting = {
        x = controlX,
        y = y,
        width = cfg.checkboxSize,
        height = cfg.checkboxSize,
        type = "checkbox",
    }
    y = y + cfg.checkboxSize + rowSpacing

    -- Vignette checkbox
    state.controls.vignette = {
        x = controlX,
        y = y,
        width = cfg.checkboxSize,
        height = cfg.checkboxSize,
        type = "checkbox",
    }
    y = y + cfg.checkboxSize + rowSpacing

    -- Fog Particles checkbox
    state.controls.fogParticles = {
        x = controlX,
        y = y,
        width = cfg.checkboxSize,
        height = cfg.checkboxSize,
        type = "checkbox",
    }
    y = y + cfg.checkboxSize + rowSpacing

    -- Dust Particles checkbox
    state.controls.dustParticles = {
        x = controlX,
        y = y,
        width = cfg.checkboxSize,
        height = cfg.checkboxSize,
        type = "checkbox",
    }
    y = y + cfg.checkboxSize + rowSpacing

    -- Dither checkbox
    state.controls.dither = {
        x = controlX,
        y = y,
        width = cfg.checkboxSize,
        height = cfg.checkboxSize,
        type = "checkbox",
    }
end

local function _updateScale()
    local windowW, windowH = love.graphics.getDimensions()
    state.windowWidth = windowW
    state.windowHeight = windowH

    -- Fixed game dimensions (always 1280x720)
    state.gameWidth = CANVAS_WIDTH
    state.gameHeight = CANVAS_HEIGHT

    -- Scale to fit window, preserving 16:9 aspect ratio
    local windowAspect = windowW / windowH

    if windowAspect > ASPECT_RATIO then
        -- Window wider than 16:9: pillarbox (black bars on sides)
        state.scale = windowH / CANVAS_HEIGHT
        state.offsetX = math.floor((windowW - CANVAS_WIDTH * state.scale) / 2)
        state.offsetY = 0
    else
        -- Window taller than 16:9: letterbox (black bars top/bottom)
        state.scale = windowW / CANVAS_WIDTH
        state.offsetX = 0
        state.offsetY = math.floor((windowH - CANVAS_HEIGHT * state.scale) / 2)
    end
end

local function _applyWindowMode()
    local desktopW, desktopH = love.window.getDesktopDimensions()

    if state.borderless then
        -- Borderless fullscreen
        love.window.setMode(desktopW, desktopH, {
            borderless = true,
            fullscreen = true,
            fullscreentype = "desktop",
            resizable = false,
        })
    else
        -- Windowed mode with selected resolution
        local res = Config.SETTINGS.resolutions[state.resolutionIndex]
        love.window.setMode(res.width, res.height, {
            borderless = false,
            fullscreen = false,
            centered = true,
            resizable = false,
        })
    end

    -- Update scale after window mode change
    _updateScale()

    -- Notify other systems that window size changed
    EventBus.emit("window_resized", {
        width = state.windowWidth,
        height = state.windowHeight,
        scale = state.scale,
        offsetX = state.offsetX,
        offsetY = state.offsetY,
        gameWidth = state.gameWidth,
        gameHeight = state.gameHeight,
        -- Panel now overlays, so play area is full canvas width
        playAreaWidth = state.gameWidth,
        panelWidth = PANEL_WIDTH,
    })
end

local function _applyAudioSettings()
    Audio.setEnabled(state.soundEnabled)
    Audio.setMasterVolume(state.volume / 100)
end

-- =============================================================================
-- PUBLIC API
-- =============================================================================

function Settings.init()
    -- Set initial state from Config
    state.soundEnabled = Config.AUDIO.enabled
    state.volume = math.floor(Config.AUDIO.masterVolume * 100)

    -- Set visual effects from Config
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

    -- Initialize scale and dynamic dimensions
    _updateScale()

    -- Emit initial window dimensions so other systems can initialize properly
    EventBus.emit("window_resized", {
        width = state.windowWidth,
        height = state.windowHeight,
        scale = state.scale,
        offsetX = state.offsetX,
        offsetY = state.offsetY,
        gameWidth = state.gameWidth,
        gameHeight = state.gameHeight,
        -- Panel now overlays, so play area is full canvas width
        playAreaWidth = state.gameWidth,
        panelWidth = PANEL_WIDTH,
    })

    _calculateLayout()
end

function Settings.update(mouseX, mouseY)
    if not state.visible then return end

    state.hoverControl = nil

    -- Check hover states
    for name, ctrl in pairs(state.controls) do
        if _pointInRect(mouseX, mouseY, ctrl.x, ctrl.y, ctrl.width, ctrl.height) then
            state.hoverControl = name
            break
        end
    end

    -- Check dropdown items if open
    if state.dropdownOpen then
        local cfg = Config.UI.settings
        local dropdownCtrl = state.controls.resolution
        for i, res in ipairs(Config.SETTINGS.resolutions) do
            local itemY = dropdownCtrl.y + dropdownCtrl.height + (i - 1) * cfg.dropdownItemHeight
            if _pointInRect(mouseX, mouseY, dropdownCtrl.x, itemY, dropdownCtrl.width, cfg.dropdownItemHeight) then
                state.hoverControl = "dropdown_item_" .. i
                break
            end
        end
    end

    -- Handle volume slider dragging
    if state.draggingVolume then
        local ctrl = state.controls.volume
        local relX = mouseX - ctrl.x
        local percent = math.max(0, math.min(1, relX / ctrl.width))
        state.volume = math.floor(percent * 100)
        _applyAudioSettings()
    end
end

function Settings.handleClick(x, y)
    if not state.visible then return false end

    -- Close button
    local closeBtn = state.controls.closeButton
    if _pointInRect(x, y, closeBtn.x, closeBtn.y, closeBtn.width, closeBtn.height) then
        Settings.hide()
        return true
    end

    -- Click outside modal closes it (and dropdown)
    if not _pointInRect(x, y, state.x, state.y, state.width, state.height) then
        if state.dropdownOpen then
            state.dropdownOpen = false
        else
            Settings.hide()
        end
        return true
    end

    -- Dropdown items (check before main dropdown)
    if state.dropdownOpen then
        local cfg = Config.UI.settings
        local dropdownCtrl = state.controls.resolution
        for i, res in ipairs(Config.SETTINGS.resolutions) do
            local itemY = dropdownCtrl.y + dropdownCtrl.height + (i - 1) * cfg.dropdownItemHeight
            if _pointInRect(x, y, dropdownCtrl.x, itemY, dropdownCtrl.width, cfg.dropdownItemHeight) then
                state.resolutionIndex = i
                state.dropdownOpen = false
                if not state.borderless then
                    _applyWindowMode()
                    _calculateLayout()
                end
                return true
            end
        end
        -- Click elsewhere closes dropdown
        state.dropdownOpen = false
        return true
    end

    -- Borderless checkbox
    local borderlessCtrl = state.controls.borderless
    if _pointInRect(x, y, borderlessCtrl.x, borderlessCtrl.y, borderlessCtrl.width, borderlessCtrl.height) then
        state.borderless = not state.borderless
        _applyWindowMode()
        _calculateLayout()
        return true
    end

    -- Resolution dropdown toggle (only if not borderless)
    local resCtrl = state.controls.resolution
    if not state.borderless and _pointInRect(x, y, resCtrl.x, resCtrl.y, resCtrl.width, resCtrl.height) then
        state.dropdownOpen = not state.dropdownOpen
        return true
    end

    -- Sound checkbox
    local soundCtrl = state.controls.sound
    if _pointInRect(x, y, soundCtrl.x, soundCtrl.y, soundCtrl.width, soundCtrl.height) then
        state.soundEnabled = not state.soundEnabled
        _applyAudioSettings()
        return true
    end

    -- Volume slider
    local volCtrl = state.controls.volume
    if state.soundEnabled and _pointInRect(x, y, volCtrl.x, volCtrl.y, volCtrl.width, volCtrl.height) then
        state.draggingVolume = true
        local relX = x - volCtrl.x
        local percent = math.max(0, math.min(1, relX / volCtrl.width))
        state.volume = math.floor(percent * 100)
        _applyAudioSettings()
        return true
    end

    -- Bloom checkbox
    local lightingCtrl = state.controls.lighting
    if _pointInRect(x, y, lightingCtrl.x, lightingCtrl.y, lightingCtrl.width, lightingCtrl.height) then
        state.bloomEnabled = not state.bloomEnabled
        -- Sync with Bloom module
        local Bloom = require("src.rendering.bloom")
        Bloom.setEnabled(state.bloomEnabled)
        return true
    end

    -- Vignette checkbox
    local vignetteCtrl = state.controls.vignette
    if _pointInRect(x, y, vignetteCtrl.x, vignetteCtrl.y, vignetteCtrl.width, vignetteCtrl.height) then
        state.vignetteEnabled = not state.vignetteEnabled
        return true
    end

    -- Fog Particles checkbox
    local fogCtrl = state.controls.fogParticles
    if _pointInRect(x, y, fogCtrl.x, fogCtrl.y, fogCtrl.width, fogCtrl.height) then
        state.fogParticlesEnabled = not state.fogParticlesEnabled
        return true
    end

    -- Dust Particles checkbox
    local dustCtrl = state.controls.dustParticles
    if _pointInRect(x, y, dustCtrl.x, dustCtrl.y, dustCtrl.width, dustCtrl.height) then
        state.dustParticlesEnabled = not state.dustParticlesEnabled
        return true
    end

    -- Dither checkbox
    local ditherCtrl = state.controls.dither
    if _pointInRect(x, y, ditherCtrl.x, ditherCtrl.y, ditherCtrl.width, ditherCtrl.height) then
        state.ditherEnabled = not state.ditherEnabled
        Config.TOWER_DITHER.enabled = state.ditherEnabled
        return true
    end

    return true  -- Consume click within modal
end

function Settings.handleRelease(x, y)
    state.draggingVolume = false
end

function Settings.draw()
    if not state.visible then return end

    local cfg = Config.UI.settings
    local padding = cfg.padding
    local labelWidth = cfg.labelWidth

    -- Darken background (use window dimensions, not game dimensions)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, state.windowWidth, state.windowHeight)

    -- Main frame
    PixelFrames.draw8BitFrame(state.x, state.y, state.width, state.height, "settings")

    -- Title
    Fonts.setFont("medium")
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print("SETTINGS", state.x + padding, state.y + padding)

    -- Close button
    local closeBtn = state.controls.closeButton
    local closeHovered = state.hoverControl == "closeButton"
    love.graphics.setColor(closeHovered and Config.COLORS.ruby or Config.COLORS.textSecondary)
    love.graphics.print("X", closeBtn.x + 6, closeBtn.y + 3)

    local contentX = state.x + padding
    local controlX = contentX + labelWidth

    -- Borderless row
    local borderlessCtrl = state.controls.borderless
    Fonts.setFont("small")
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print("Borderless", contentX, borderlessCtrl.y + 2)
    _drawCheckbox(borderlessCtrl, state.borderless, state.hoverControl == "borderless")

    -- Resolution row
    local resCtrl = state.controls.resolution
    local resDisabled = state.borderless
    if resDisabled then
        love.graphics.setColor(Config.COLORS.textDisabled)
    else
        love.graphics.setColor(Config.COLORS.textPrimary)
    end
    love.graphics.print("Resolution", contentX, resCtrl.y + 6)
    _drawDropdown(resCtrl, Config.SETTINGS.resolutions[state.resolutionIndex].label,
                  state.hoverControl == "resolution", resDisabled, state.dropdownOpen)

    -- Draw dropdown items if open
    if state.dropdownOpen and not resDisabled then
        _drawDropdownItems(resCtrl)
    end

    -- Separator
    love.graphics.setColor(Config.COLORS.frameMid)
    love.graphics.rectangle("fill", contentX, state.separatorY, state.width - padding * 2, 2)

    -- Sound row
    local soundCtrl = state.controls.sound
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print("Sound", contentX, soundCtrl.y + 2)
    _drawCheckbox(soundCtrl, state.soundEnabled, state.hoverControl == "sound")

    -- Volume row
    local volCtrl = state.controls.volume
    local volDisabled = not state.soundEnabled
    if volDisabled then
        love.graphics.setColor(Config.COLORS.textDisabled)
    else
        love.graphics.setColor(Config.COLORS.textPrimary)
    end
    love.graphics.print("Volume", contentX, volCtrl.y)
    _drawSlider(volCtrl, state.volume / 100, state.hoverControl == "volume", volDisabled)

    -- Volume percentage
    love.graphics.setColor(volDisabled and Config.COLORS.textDisabled or Config.COLORS.textSecondary)
    love.graphics.print(state.volume .. "%", volCtrl.x + volCtrl.width + 8, volCtrl.y)

    -- Separator for visual effects
    love.graphics.setColor(Config.COLORS.frameMid)
    love.graphics.rectangle("fill", contentX, state.separatorY2, state.width - padding * 2, 2)

    -- Bloom row
    local lightingCtrl = state.controls.lighting
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print("Bloom", contentX, lightingCtrl.y + 2)
    _drawCheckbox(lightingCtrl, state.bloomEnabled, state.hoverControl == "lighting")

    -- Vignette row
    local vignetteCtrl = state.controls.vignette
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print("Vignette", contentX, vignetteCtrl.y + 2)
    _drawCheckbox(vignetteCtrl, state.vignetteEnabled, state.hoverControl == "vignette")

    -- Fog Particles row
    local fogCtrl = state.controls.fogParticles
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print("Fog", contentX, fogCtrl.y + 2)
    _drawCheckbox(fogCtrl, state.fogParticlesEnabled, state.hoverControl == "fogParticles")

    -- Dust Particles row
    local dustCtrl = state.controls.dustParticles
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print("Dust", contentX, dustCtrl.y + 2)
    _drawCheckbox(dustCtrl, state.dustParticlesEnabled, state.hoverControl == "dustParticles")

    -- Dither row
    local ditherCtrl = state.controls.dither
    love.graphics.setColor(Config.COLORS.textPrimary)
    love.graphics.print("Dither", contentX, ditherCtrl.y + 2)
    _drawCheckbox(ditherCtrl, state.ditherEnabled, state.hoverControl == "dither")
end

function Settings.show()
    state.visible = true
    state.dropdownOpen = false
    state.draggingVolume = false
    _calculateLayout()
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
-- SCALING API
-- =============================================================================

-- Get the current scale factor
function Settings.getScale()
    return state.scale
end

-- Get the offset to center the game
function Settings.getOffset()
    return state.offsetX, state.offsetY
end

-- Get the current window dimensions
function Settings.getWindowDimensions()
    return state.windowWidth, state.windowHeight
end

-- Get the current game dimensions (width is dynamic based on aspect ratio)
function Settings.getGameDimensions()
    return state.gameWidth, state.gameHeight
end

-- Get the fixed panel width
function Settings.getPanelWidth()
    return PANEL_WIDTH
end

-- Get the play area width (full canvas width since panel overlays)
function Settings.getPlayAreaWidth()
    return state.gameWidth
end

-- Get the panel X position (where panel overlay starts)
function Settings.getPanelX()
    return state.gameWidth - PANEL_WIDTH
end

-- Convert screen coordinates to game coordinates
function Settings.screenToGame(screenX, screenY)
    local gameX = (screenX - state.offsetX) / state.scale
    local gameY = (screenY - state.offsetY) / state.scale
    return gameX, gameY
end

-- Convert game coordinates to screen coordinates
function Settings.gameToScreen(gameX, gameY)
    local screenX = gameX * state.scale + state.offsetX
    local screenY = gameY * state.scale + state.offsetY
    return screenX, screenY
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

-- Set bloom state (for keyboard shortcut)
function Settings.setBloomEnabled(enabled)
    state.bloomEnabled = enabled
end

-- Toggle bloom (for keyboard shortcut)
function Settings.toggleBloom()
    state.bloomEnabled = not state.bloomEnabled
    -- Sync with Bloom module
    local Bloom = require("src.rendering.bloom")
    Bloom.setEnabled(state.bloomEnabled)
    return state.bloomEnabled
end

-- Toggle borderless mode (for keyboard shortcut)
function Settings.toggleBorderless()
    state.borderless = not state.borderless
    _applyWindowMode()
    _calculateLayout()
    return state.borderless
end

-- =============================================================================
-- UI DRAWING HELPERS
-- =============================================================================

function _drawCheckbox(ctrl, checked, hovered)
    local cfg = Config.UI.settings
    local size = cfg.checkboxSize

    -- Background
    if hovered then
        love.graphics.setColor(Config.UI.frames.highlight.background)
    else
        love.graphics.setColor(Config.UI.frames.standard.background)
    end
    love.graphics.rectangle("fill", ctrl.x, ctrl.y, size, size)

    -- Border
    if hovered then
        love.graphics.setColor(Config.UI.frames.highlight.border)
    else
        love.graphics.setColor(Config.UI.frames.standard.border)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", ctrl.x, ctrl.y, size, size)

    -- Checkmark
    if checked then
        love.graphics.setColor(Config.COLORS.emerald)
        local inset = 4
        love.graphics.setLineWidth(3)
        love.graphics.line(
            ctrl.x + inset, ctrl.y + size / 2,
            ctrl.x + size / 2 - 1, ctrl.y + size - inset,
            ctrl.x + size - inset, ctrl.y + inset
        )
    end
end

function _drawDropdown(ctrl, label, hovered, disabled, open)
    local cfg = Config.UI.settings

    -- Background
    if disabled then
        love.graphics.setColor(Config.UI.frames.disabled.background)
    elseif hovered or open then
        love.graphics.setColor(Config.UI.frames.highlight.background)
    else
        love.graphics.setColor(Config.UI.frames.standard.background)
    end
    love.graphics.rectangle("fill", ctrl.x, ctrl.y, ctrl.width, ctrl.height)

    -- Border
    if disabled then
        love.graphics.setColor(Config.UI.frames.disabled.border)
    elseif hovered or open then
        love.graphics.setColor(Config.UI.frames.highlight.border)
    else
        love.graphics.setColor(Config.UI.frames.standard.border)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", ctrl.x, ctrl.y, ctrl.width, ctrl.height)

    -- Label
    Fonts.setFont("small")
    if disabled then
        love.graphics.setColor(Config.COLORS.textDisabled)
    else
        love.graphics.setColor(Config.COLORS.textPrimary)
    end
    love.graphics.print(label, ctrl.x + 8, ctrl.y + 6)

    -- Arrow
    local arrowChar = open and "^" or "v"
    love.graphics.print(arrowChar, ctrl.x + ctrl.width - 16, ctrl.y + 6)
end

function _drawDropdownItems(ctrl)
    local cfg = Config.UI.settings
    local itemHeight = cfg.dropdownItemHeight

    for i, res in ipairs(Config.SETTINGS.resolutions) do
        local itemY = ctrl.y + ctrl.height + (i - 1) * itemHeight
        local hovered = state.hoverControl == "dropdown_item_" .. i
        local selected = i == state.resolutionIndex

        -- Background
        if hovered then
            love.graphics.setColor(Config.UI.frames.highlight.background)
        else
            love.graphics.setColor(Config.UI.frames.settings.background)
        end
        love.graphics.rectangle("fill", ctrl.x, itemY, ctrl.width, itemHeight)

        -- Border
        love.graphics.setColor(Config.UI.frames.standard.border)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", ctrl.x, itemY, ctrl.width, itemHeight)

        -- Label
        Fonts.setFont("small")
        if selected then
            love.graphics.setColor(Config.COLORS.gold)
        elseif hovered then
            love.graphics.setColor(Config.COLORS.textPrimary)
        else
            love.graphics.setColor(Config.COLORS.textSecondary)
        end
        love.graphics.print(res.label, ctrl.x + 8, itemY + 4)
    end
end

function _drawSlider(ctrl, percent, hovered, disabled)
    local cfg = Config.UI.settings
    local trackHeight = cfg.sliderTrackHeight
    local trackY = ctrl.y + (ctrl.height - trackHeight) / 2

    -- Track background
    if disabled then
        love.graphics.setColor(Config.UI.frames.disabled.background)
    else
        love.graphics.setColor(Config.UI.frames.standard.background)
    end
    love.graphics.rectangle("fill", ctrl.x, trackY, ctrl.width, trackHeight)

    -- Filled portion
    if not disabled then
        love.graphics.setColor(Config.COLORS.emerald[1], Config.COLORS.emerald[2], Config.COLORS.emerald[3], 0.8)
        love.graphics.rectangle("fill", ctrl.x, trackY, ctrl.width * percent, trackHeight)
    end

    -- Track border
    if disabled then
        love.graphics.setColor(Config.UI.frames.disabled.border)
    elseif hovered then
        love.graphics.setColor(Config.UI.frames.highlight.border)
    else
        love.graphics.setColor(Config.UI.frames.standard.border)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", ctrl.x, trackY, ctrl.width, trackHeight)

    -- Handle
    local handleX = ctrl.x + ctrl.width * percent
    local handleSize = ctrl.height
    if disabled then
        love.graphics.setColor(Config.UI.frames.disabled.accent)
    elseif hovered or state.draggingVolume then
        love.graphics.setColor(Config.COLORS.gold)
    else
        love.graphics.setColor(Config.UI.frames.standard.accent)
    end
    love.graphics.rectangle("fill", handleX - handleSize / 2, ctrl.y, handleSize, handleSize)
    love.graphics.setColor(Config.UI.frames.standard.border)
    love.graphics.rectangle("line", handleX - handleSize / 2, ctrl.y, handleSize, handleSize)
end

return Settings
