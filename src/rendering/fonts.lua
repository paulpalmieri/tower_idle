-- src/rendering/fonts.lua
-- Pixel font loading and management

local Config = require("src.config")

local Fonts = {}

-- Cache for loaded fonts at different sizes
local fontCache = {}

-- Initialize all configured font sizes
function Fonts.init()
    local fontPath = Config.FONTS.path
    local sizes = Config.FONTS.sizes

    for name, size in pairs(sizes) do
        local font = love.graphics.newFont(fontPath, size)
        font:setFilter("nearest", "nearest")  -- Crisp pixel font rendering
        fontCache[name] = font
        fontCache[size] = font  -- Also cache by size number
    end
end

-- Get a font by name ("small", "medium", "large", "title") or size number
function Fonts.get(sizeOrName)
    return fontCache[sizeOrName]
end

-- Set the current font by name or size
function Fonts.setFont(sizeOrName)
    local font = fontCache[sizeOrName]
    if font then
        love.graphics.setFont(font)
    end
end

-- Get the height of a font
function Fonts.getHeight(sizeOrName)
    local font = fontCache[sizeOrName]
    if font then
        return font:getHeight()
    end
    return 0
end

-- Get the width of text at a given font size
function Fonts.getWidth(sizeOrName, text)
    local font = fontCache[sizeOrName]
    if font then
        return font:getWidth(text)
    end
    return 0
end

return Fonts
