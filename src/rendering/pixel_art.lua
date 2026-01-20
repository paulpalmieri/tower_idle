-- src/rendering/pixel_art.lua
-- Pixel art sprite rendering system using proper LÖVE2D images
-- Uses nearest-neighbor filtering for crisp pixel art rotation

local Config = require("src.config")

local PixelArt = {}

-- Cache for created images and sprite metadata
local imageCache = {}

-- Easing function for recoil animation
local function _easeOutQuad(t)
    return t * (2 - t)
end

-- Parse a sprite string and extract metadata (anchor, pivot, tip positions)
-- Returns: { width, height, pixels = {{x, y, r, g, b, a}}, anchor, pivot, tip }
local function _parseSprite(matrixString)
    local colors = Config.PIXEL_ART.COLORS
    local lines = {}

    -- Split string into lines
    for line in matrixString:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local height = #lines
    local width = 0

    -- Find max width
    for _, line in ipairs(lines) do
        if #line > width then
            width = #line
        end
    end

    -- Track marker positions and pixels
    local anchor = nil
    local pivot = nil
    local tip = nil
    local pixels = {}

    for y, line in ipairs(lines) do
        for x = 1, #line do
            local char = line:sub(x, x)

            -- Extract special markers (use first occurrence only)
            if char == 'A' and not anchor then
                anchor = {x = x - 1, y = y - 1}
            elseif char == 'P' and not pivot then
                pivot = {x = x - 1, y = y - 1}
            elseif char == 'T' and not tip then
                tip = {x = x - 1, y = y - 1}
            end

            -- Get color for this character
            local color = colors[char]
            if color then
                table.insert(pixels, {
                    x = x - 1,
                    y = y - 1,
                    r = color[1],
                    g = color[2],
                    b = color[3],
                    a = 1.0
                })
            end
        end
    end

    return {
        width = width,
        height = height,
        pixels = pixels,
        anchor = anchor,
        pivot = pivot,
        tip = tip,
    }
end

-- Create a LÖVE2D Image from parsed sprite data
local function _createImage(spriteData)
    local imageData = love.image.newImageData(spriteData.width, spriteData.height)

    -- Set all pixels (default is transparent)
    for _, pixel in ipairs(spriteData.pixels) do
        imageData:setPixel(pixel.x, pixel.y, pixel.r, pixel.g, pixel.b, pixel.a)
    end

    local image = love.graphics.newImage(imageData)
    image:setFilter("nearest", "nearest")  -- Crisp pixel art, no blur

    return image
end

-- Get or create cached image and metadata for a sprite string
local function _getSprite(matrixString)
    if imageCache[matrixString] then
        return imageCache[matrixString]
    end

    local spriteData = _parseSprite(matrixString)
    local image = _createImage(spriteData)

    local cached = {
        image = image,
        width = spriteData.width,
        height = spriteData.height,
        anchor = spriteData.anchor,
        pivot = spriteData.pivot,
        tip = spriteData.tip,
    }

    imageCache[matrixString] = cached
    return cached
end

-- Draw a sprite image at position with optional rotation
-- x, y: center position
-- rotation: angle in radians (default 0)
-- scale: pixel size multiplier (default from config)
function PixelArt.drawSprite(sprite, x, y, rotation, scale)
    rotation = rotation or 0
    scale = scale or Config.PIXEL_ART.SCALE

    -- Origin at center of sprite for centered rotation
    local ox = sprite.width / 2
    local oy = sprite.height / 2

    love.graphics.setColor(1, 1, 1, 1)  -- Full color, no tint
    love.graphics.draw(sprite.image, x, y, rotation, scale, scale, ox, oy)
end

-- Draw a barrel sprite with rotation around its pivot point
-- barrelSprite: cached barrel sprite
-- baseSprite: cached base sprite (for anchor position)
-- x, y: tower center position
-- rotation: angle toward target
-- recoilOffset: pixels to push barrel back along aim direction
-- scale: pixel scale
function PixelArt.drawBarrel(barrelSprite, baseSprite, x, y, rotation, recoilOffset, scale)
    scale = scale or Config.PIXEL_ART.SCALE
    recoilOffset = recoilOffset or 0

    -- Get anchor from base sprite (where barrel attaches)
    local spriteSize = Config.PIXEL_ART.SPRITE_SIZE
    local spriteCenter = spriteSize / 2
    local anchor = baseSprite.anchor or {x = spriteCenter, y = spriteCenter}

    -- Calculate attachment point (relative to tower center)
    local attachX = x + (anchor.x - spriteCenter) * scale
    local attachY = y + (anchor.y - spriteCenter) * scale

    -- Apply recoil (push back along aim direction)
    local cos = math.cos(rotation)
    local sin = math.sin(rotation)
    attachX = attachX - cos * recoilOffset * scale
    attachY = attachY - sin * recoilOffset * scale

    -- Pivot point: X from marker (or left edge), Y at vertical center
    local pivotX = barrelSprite.pivot and barrelSprite.pivot.x or 0
    local pivotY = barrelSprite.height / 2  -- Always center vertically

    -- Draw barrel rotated around pivot
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        barrelSprite.image,
        attachX, attachY,
        rotation,
        scale, scale,
        pivotX + 0.5, pivotY  -- +0.5 on X to center on the pivot pixel
    )
end

-- High-level function to draw a complete tower with pixel art
-- towerType: "basic", "sniper", etc.
-- x, y: tower center position
-- barrelRotation: angle in radians
-- recoilOffset: current recoil animation value (0-1, where 1 = max recoil)
-- customScale: optional scale override (default uses Config.PIXEL_ART.SCALE)
function PixelArt.drawTower(towerType, x, y, barrelRotation, recoilOffset, customScale)
    local artConfig = Config.PIXEL_ART.TOWERS[towerType]

    -- Fallback if no pixel art defined
    if not artConfig then
        return false
    end

    local scale = customScale or Config.PIXEL_ART.SCALE

    -- 1. Draw background (no rotation)
    if artConfig.background then
        local bgSprite = _getSprite(artConfig.background)
        PixelArt.drawSprite(bgSprite, x, y, 0, scale)
    end

    -- 2. Draw base/turret body (no rotation)
    local baseSprite = _getSprite(artConfig.base)
    PixelArt.drawSprite(baseSprite, x, y, 0, scale)

    -- 3. Draw barrel if this tower has one (rotated toward target)
    if artConfig.barrel then
        local barrelSprite = _getSprite(artConfig.barrel)

        -- Calculate actual recoil distance
        local recoilDist = 0
        if artConfig.recoil and recoilOffset > 0 then
            recoilDist = artConfig.recoil.distance * recoilOffset
        end

        -- Draw barrel shadow on the base (rotates with barrel)
        local spriteSize = Config.PIXEL_ART.SPRITE_SIZE
        local spriteCenter = spriteSize / 2
        local anchor = baseSprite.anchor or {x = spriteCenter, y = spriteCenter}
        local attachX = x + (anchor.x - spriteCenter) * scale
        local attachY = y + (anchor.y - spriteCenter) * scale

        -- Shadow follows barrel rotation with slight Y offset (light from above)
        local shadowOffsetY = scale * 2
        local cos = math.cos(barrelRotation)
        local sin = math.sin(barrelRotation)

        -- Get barrel dimensions for shadow size
        local pivotX = barrelSprite.pivot and barrelSprite.pivot.x or 0
        local pivotY = barrelSprite.height / 2
        local barrelLength = barrelSprite.width - pivotX
        local barrelHeight = barrelSprite.height

        -- Apply recoil to shadow position too
        local shadowAttachX = attachX - cos * recoilDist * scale
        local shadowAttachY = attachY - sin * recoilDist * scale + shadowOffsetY

        -- Draw rotated shadow rectangle
        love.graphics.setColor(0, 0, 0, Config.PIXEL_ART.SHADOW_ALPHA)
        love.graphics.push()
        love.graphics.translate(shadowAttachX, shadowAttachY)
        love.graphics.rotate(barrelRotation)
        -- Draw shadow as rectangle extending from pivot
        love.graphics.rectangle("fill", 0, -barrelHeight * scale / 2, barrelLength * scale, barrelHeight * scale)
        love.graphics.pop()

        PixelArt.drawBarrel(
            barrelSprite,
            baseSprite,
            x, y,
            barrelRotation,
            recoilDist,
            scale
        )
    end

    return true
end

-- Draw muzzle flash at barrel tip
function PixelArt.drawMuzzleFlash(towerType, x, y, barrelRotation, scale)
    local artConfig = Config.PIXEL_ART.TOWERS[towerType]
    if not artConfig or not artConfig.barrel then
        return
    end

    scale = scale or Config.PIXEL_ART.SCALE

    local baseSprite = _getSprite(artConfig.base)
    local barrelSprite = _getSprite(artConfig.barrel)

    -- Need tip position from barrel sprite
    if not barrelSprite.tip then
        return
    end

    local cos = math.cos(barrelRotation)
    local sin = math.sin(barrelRotation)

    -- Get anchor position
    local spriteSize = Config.PIXEL_ART.SPRITE_SIZE
    local spriteCenter = spriteSize / 2
    local anchor = baseSprite.anchor or {x = spriteCenter, y = spriteCenter}

    -- Calculate attachment point
    local attachX = x + (anchor.x - spriteCenter) * scale
    local attachY = y + (anchor.y - spriteCenter) * scale

    -- Calculate tip position relative to pivot, then rotate
    local pivotX = barrelSprite.pivot and barrelSprite.pivot.x or 0
    local pivotY = barrelSprite.height / 2
    local tip = barrelSprite.tip

    local tipOffsetX = tip.x - pivotX + 0.5
    local tipOffsetY = tip.y - pivotY + 0.5

    local tipX = attachX + (tipOffsetX * cos - tipOffsetY * sin) * scale
    local tipY = attachY + (tipOffsetX * sin + tipOffsetY * cos) * scale

    -- Draw flash (rectangle aligned with barrel rotation)
    local flashColor = Config.PIXEL_ART.COLORS['!']
    if flashColor then
        love.graphics.setColor(flashColor[1], flashColor[2], flashColor[3], 0.8)
        local flashWidth = scale * 2   -- Perpendicular to barrel
        local flashLength = scale * 3  -- Along barrel direction
        love.graphics.push()
        love.graphics.translate(tipX, tipY)
        love.graphics.rotate(barrelRotation)
        love.graphics.rectangle("fill", 0, -flashWidth / 2, flashLength, flashWidth)
        love.graphics.pop()
    end
end

-- Draw projectile sprite
-- towerType: "basic", "sniper", etc.
-- x, y: projectile center position
-- angle: direction of travel in radians
-- scale: pixel scale
function PixelArt.drawProjectile(towerType, x, y, angle, scale)
    local artConfig = Config.PIXEL_ART.TOWERS[towerType]
    if not artConfig or not artConfig.projectile then
        return false
    end

    -- Use projectile-specific scale (smaller than tower scale)
    scale = scale or Config.PIXEL_ART.PROJECTILE_SCALE
    local sprite = _getSprite(artConfig.projectile)
    PixelArt.drawSprite(sprite, x, y, angle, scale)
    return true
end

-- Calculate recoil animation value
-- Returns a value between 0 and 1 (1 = max recoil, 0 = no recoil)
function PixelArt.calculateRecoil(timer, duration)
    if timer <= 0 then
        return 0
    end
    local t = timer / duration
    return _easeOutQuad(t)
end

-- Clear image cache (useful if config changes)
function PixelArt.clearCache()
    imageCache = {}
end

-- Preload all tower sprites (call during game init for smoother gameplay)
function PixelArt.preloadTowers()
    for towerType, artConfig in pairs(Config.PIXEL_ART.TOWERS) do
        if artConfig.background then
            _getSprite(artConfig.background)
        end
        if artConfig.base then
            _getSprite(artConfig.base)
        end
        if artConfig.barrel then
            _getSprite(artConfig.barrel)
        end
        if artConfig.projectile then
            _getSprite(artConfig.projectile)
        end
    end
end

return PixelArt
