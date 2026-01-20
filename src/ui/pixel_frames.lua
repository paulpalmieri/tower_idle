-- src/ui/pixel_frames.lua
-- Pixel-perfect UI frame drawing utilities (Dark Fantasy Theme)
-- All styles are centralized in Config.UI.frames

local Config = require("src.config")

local PixelFrames = {}

-- Get style from centralized config
local function _getStyle(styleName)
    local frames = Config.UI.frames
    return frames[styleName] or frames.standard
end

-- =============================================================================
-- CLEAN MINIMALISTIC FRAMES
-- =============================================================================

-- Draw subtle corner accent (small dot or pixel cluster)
local function _drawCornerAccent(cx, cy, size, color)
    love.graphics.setColor(color)
    -- Simple pixel cluster (cross pattern)
    love.graphics.rectangle("fill", cx, cy, size, size)
end

-- Draw clean frame with subtle texture and corner accents
function PixelFrames.draw8BitFrame(x, y, w, h, styleName)
    local style = _getStyle(styleName)
    local thickness = Config.UI.panel.frameThickness
    local cornerSize = Config.UI.panel.cornerSize

    -- Background fill
    love.graphics.setColor(style.background)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Clean border
    love.graphics.setColor(style.border)
    love.graphics.rectangle("fill", x, y, w, thickness)
    love.graphics.rectangle("fill", x, y + h - thickness, w, thickness)
    love.graphics.rectangle("fill", x, y, thickness, h)
    love.graphics.rectangle("fill", x + w - thickness, y, thickness, h)

    -- Subtle inner highlight (top-left edge)
    love.graphics.setColor(style.highlight[1], style.highlight[2], style.highlight[3], 0.4)
    love.graphics.rectangle("fill", x + thickness, y + thickness, w - thickness * 2, 1)
    love.graphics.rectangle("fill", x + thickness, y + thickness, 1, h - thickness * 2)

    -- Subtle inner shadow (bottom-right edge)
    love.graphics.setColor(style.shadow[1], style.shadow[2], style.shadow[3], 0.6)
    love.graphics.rectangle("fill", x + thickness, y + h - thickness - 1, w - thickness * 2, 1)
    love.graphics.rectangle("fill", x + w - thickness - 1, y + thickness, 1, h - thickness * 2)

    -- Corner accents (subtle dots)
    local inset = thickness + 3
    _drawCornerAccent(x + inset, y + inset, cornerSize, style.accent)
    _drawCornerAccent(x + w - inset - cornerSize, y + inset, cornerSize, style.accent)
    _drawCornerAccent(x + inset, y + h - inset - cornerSize, cornerSize, style.accent)
    _drawCornerAccent(x + w - inset - cornerSize, y + h - inset - cornerSize, cornerSize, style.accent)

    -- Subtle texture dots along edges (sparse)
    love.graphics.setColor(style.accent[1], style.accent[2], style.accent[3], 0.25)
    local dotSpacing = 16
    for dx = inset + cornerSize + 8, w - inset - cornerSize - 8, dotSpacing do
        love.graphics.rectangle("fill", x + dx, y + thickness + 2, 1, 1)
        love.graphics.rectangle("fill", x + dx, y + h - thickness - 3, 1, 1)
    end
end

-- Draw clean card frame (minimal, elegant)
function PixelFrames.draw8BitCard(x, y, w, h, styleName)
    local style = _getStyle(styleName)
    local thickness = 2

    -- Background fill
    love.graphics.setColor(style.background)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Clean thin border
    love.graphics.setColor(style.border)
    love.graphics.rectangle("fill", x, y, w, thickness)
    love.graphics.rectangle("fill", x, y + h - thickness, w, thickness)
    love.graphics.rectangle("fill", x, y, thickness, h)
    love.graphics.rectangle("fill", x + w - thickness, y, thickness, h)

    -- Subtle inner highlight (top edge only)
    love.graphics.setColor(style.highlight[1], style.highlight[2], style.highlight[3], 0.3)
    love.graphics.rectangle("fill", x + thickness, y + thickness, w - thickness * 2, 1)

    -- Minimal corner dots (just top corners)
    love.graphics.setColor(style.accent[1], style.accent[2], style.accent[3], 0.5)
    love.graphics.rectangle("fill", x + thickness + 2, y + thickness + 2, 2, 2)
    love.graphics.rectangle("fill", x + w - thickness - 4, y + thickness + 2, 2, 2)
end

-- =============================================================================
-- BASIC FRAME DRAWING
-- =============================================================================

-- Draw a pixel-perfect bordered frame
function PixelFrames.drawFrame(x, y, w, h, styleName)
    local style = _getStyle(styleName)

    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(2)

    -- Background fill
    love.graphics.setColor(style.background)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Shadow (bottom and right edges, inset by 1)
    love.graphics.setColor(style.shadow)
    love.graphics.line(x + 2, y + h - 1, x + w - 1, y + h - 1)
    love.graphics.line(x + w - 1, y + 2, x + w - 1, y + h - 1)

    -- Main border
    love.graphics.setColor(style.border)
    love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)

    -- Highlight (top and left edges)
    love.graphics.setColor(style.highlight)
    love.graphics.line(x + 1, y + 1, x + w - 2, y + 1)
    love.graphics.line(x + 1, y + 1, x + 1, y + h - 2)

    love.graphics.setLineStyle("smooth")
end

-- Draw a simpler frame (just border, no highlight/shadow)
function PixelFrames.drawSimpleFrame(x, y, w, h, styleName)
    local style = _getStyle(styleName)

    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(2)

    love.graphics.setColor(style.background)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(style.border)
    love.graphics.rectangle("line", x, y, w, h)

    love.graphics.setLineStyle("smooth")
end

-- =============================================================================
-- ORNATE FRAME SYSTEM
-- =============================================================================

-- Draw a corner decoration (diamond with inner detail)
local function _drawCornerDecoration(cx, cy, style)
    local cfg = Config.UI.ornateFrame
    local size = cfg.cornerSize
    local halfSize = size / 2

    -- Outer diamond
    love.graphics.setColor(style.accent)
    love.graphics.polygon("fill",
        cx, cy - halfSize,
        cx + halfSize, cy,
        cx, cy + halfSize,
        cx - halfSize, cy
    )

    -- Inner highlight dot
    love.graphics.setColor(style.highlight)
    love.graphics.circle("fill", cx, cy, 1)
end

-- Draw edge accent lines between corners
local function _drawEdgeAccents(x, y, w, h, style)
    local cfg = Config.UI.ornateFrame
    local inset = cfg.edgeInset + cfg.cornerSize

    love.graphics.setColor(style.accent[1], style.accent[2], style.accent[3], 0.5)
    love.graphics.setLineWidth(1)

    -- Top edge accent (small line segments)
    local topY = y + 2
    love.graphics.line(x + inset + 4, topY, x + w - inset - 4, topY)

    -- Bottom edge accent
    local botY = y + h - 2
    love.graphics.line(x + inset + 4, botY, x + w - inset - 4, botY)
end

-- Draw ornate frame with corner decorations
function PixelFrames.drawOrnateFrame(x, y, w, h, styleName)
    local style = _getStyle(styleName)
    local cfg = Config.UI.ornateFrame

    -- Base frame
    PixelFrames.drawFrame(x, y, w, h, styleName)

    -- Corner decorations
    if cfg.showCorners then
        local inset = cfg.edgeInset
        _drawCornerDecoration(x + inset, y + inset, style)
        _drawCornerDecoration(x + w - inset, y + inset, style)
        _drawCornerDecoration(x + inset, y + h - inset, style)
        _drawCornerDecoration(x + w - inset, y + h - inset, style)
    end

    -- Edge accent lines
    if cfg.showEdgeAccents then
        _drawEdgeAccents(x, y, w, h, style)
    end
end

-- =============================================================================
-- PROGRESS BARS
-- =============================================================================

-- Draw a pixel-styled progress bar
function PixelFrames.drawProgressBar(x, y, w, h, percent, fillColor, bgColor)
    percent = math.max(0, math.min(1, percent))

    love.graphics.setColor(bgColor or Config.COLORS.frameDark)
    love.graphics.rectangle("fill", x, y, w, h)

    if percent > 0 then
        love.graphics.setColor(fillColor or Config.COLORS.emerald)
        love.graphics.rectangle("fill", x, y, w * percent, h)
    end

    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(1)
    love.graphics.setColor(Config.COLORS.frameMid)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineStyle("smooth")
end

-- Draw a segmented progress bar with ornate end caps
function PixelFrames.drawSegmentedBar(x, y, w, h, percent, segments, fillColor, bgColor)
    percent = math.max(0, math.min(1, percent))
    local segWidth = w / segments
    local filledSegments = math.floor(percent * segments + 0.5)

    -- Background
    love.graphics.setColor(bgColor or Config.COLORS.frameDark)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Filled segments (with 1px gap between)
    local gap = 1
    for i = 1, filledSegments do
        local segX = x + (i - 1) * segWidth + gap
        love.graphics.setColor(fillColor or Config.COLORS.emerald)
        love.graphics.rectangle("fill", segX, y + 1, segWidth - gap * 2, h - 2)
    end

    -- Ornate end caps
    love.graphics.setColor(Config.COLORS.frameMid)
    love.graphics.polygon("fill",
        x - 3, y + h / 2,
        x, y,
        x, y + h
    )
    love.graphics.polygon("fill",
        x + w + 3, y + h / 2,
        x + w, y,
        x + w, y + h
    )

    -- Border
    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(1)
    love.graphics.setColor(Config.COLORS.frameMid)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineStyle("smooth")
end

-- Draw a health bar (for void)
function PixelFrames.drawHealthBar(x, y, w, h, percent, damageColor)
    percent = math.max(0, math.min(1, percent))

    love.graphics.setColor(Config.COLORS.voidHealthBarBg)
    love.graphics.rectangle("fill", x, y, w, h)

    if percent > 0 then
        love.graphics.setColor(damageColor or Config.COLORS.voidHealthBar)
        love.graphics.rectangle("fill", x + 1, y + 1, (w - 2) * percent, h - 2)
    end

    love.graphics.setLineStyle("rough")
    love.graphics.setLineWidth(1)
    love.graphics.setColor(Config.COLORS.amethyst)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineStyle("smooth")
end

-- =============================================================================
-- INDICATORS (Pips, Orbs)
-- =============================================================================

-- Draw anger pips (small squares)
function PixelFrames.drawAngerPips(x, y, count, filled, permanentAnger)
    local pipSize = 6
    local pipSpacing = 10

    for i = 1, count do
        local pipX = x + (i - 1) * pipSpacing
        local isFilled = i <= filled

        love.graphics.setColor(isFilled and Config.COLORS.angerPipFilled or Config.COLORS.angerPipEmpty)
        love.graphics.rectangle("fill", pipX, y, pipSize, pipSize)

        love.graphics.setLineStyle("rough")
        love.graphics.setLineWidth(1)
        love.graphics.setColor(Config.COLORS.amethyst)
        love.graphics.rectangle("line", pipX, y, pipSize, pipSize)
        love.graphics.setLineStyle("smooth")
    end

    if permanentAnger and permanentAnger > 0 then
        love.graphics.setColor(Config.COLORS.angerPipFilled)
        love.graphics.print("+" .. permanentAnger, x + count * pipSpacing + 4, y - 2)
    end
end

-- Draw glowing pips (orbs) for anger indicator
function PixelFrames.drawGlowingPips(x, y, count, filled, permanentAnger, time)
    local pipSize = 8
    local pipSpacing = 14
    time = time or 0

    for i = 1, count do
        local pipX = x + (i - 1) * pipSpacing
        local centerX = pipX + pipSize / 2
        local centerY = y + pipSize / 2
        local isFilled = i <= filled

        if isFilled then
            local pulse = math.sin(time * 3 + i) * 0.15 + 0.85
            -- Glow
            love.graphics.setColor(
                Config.COLORS.angerPipFilled[1] * pulse,
                Config.COLORS.angerPipFilled[2] * pulse,
                Config.COLORS.angerPipFilled[3] * pulse,
                0.4
            )
            love.graphics.circle("fill", centerX, centerY, pipSize / 2 + 2)
            -- Core
            love.graphics.setColor(Config.COLORS.angerPipFilled)
            love.graphics.circle("fill", centerX, centerY, pipSize / 2)
            -- Highlight
            love.graphics.setColor(1.0, 0.8, 0.5, 0.7)
            love.graphics.circle("fill", centerX - 1, centerY - 1, 2)
        else
            -- Empty orb (dark socket)
            love.graphics.setColor(Config.COLORS.angerPipEmpty)
            love.graphics.circle("fill", centerX, centerY, pipSize / 2)
            -- Inner shadow
            love.graphics.setColor(Config.COLORS.frameDark)
            love.graphics.circle("fill", centerX, centerY, pipSize / 2 - 2)
        end

        -- Border
        love.graphics.setColor(Config.COLORS.amethyst)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", centerX, centerY, pipSize / 2)
    end

    if permanentAnger and permanentAnger > 0 then
        love.graphics.setColor(Config.COLORS.gold)
        love.graphics.print("+" .. permanentAnger, x + count * pipSpacing + 4, y - 2)
    end
end

-- =============================================================================
-- BUTTONS
-- =============================================================================

-- Draw a button frame with hover/selected states
function PixelFrames.drawButton(x, y, w, h, isSelected, isHovered, isDisabled)
    local styleName = "standard"
    if isDisabled then
        styleName = "disabled"
    elseif isSelected then
        styleName = "selected"
    elseif isHovered then
        styleName = "highlight"
    end

    PixelFrames.drawFrame(x, y, w, h, styleName)
end

-- Draw a shop button with ornate frame and glow effects
function PixelFrames.drawShopButton(x, y, w, h, isSelected, isHovered, isDisabled, canAfford)
    local styleName = "standard"

    if isDisabled then
        styleName = "disabled"
    elseif isSelected then
        -- Gold glow for selected
        love.graphics.setColor(Config.COLORS.gold[1], Config.COLORS.gold[2], Config.COLORS.gold[3], 0.2)
        love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4)
        styleName = "selected"
    elseif isHovered and canAfford then
        styleName = "highlight"
    elseif not canAfford then
        styleName = "disabled"
    end

    PixelFrames.drawOrnateFrame(x, y, w, h, styleName)
end

-- =============================================================================
-- UTILITY
-- =============================================================================

-- Get a style for external use
function PixelFrames.getStyle(styleName)
    return _getStyle(styleName)
end

return PixelFrames
