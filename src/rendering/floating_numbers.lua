-- src/rendering/floating_numbers.lua
-- Floating damage and gold numbers with multiple animation styles

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Fonts = require("src.rendering.fonts")

local FloatingNumbers = {}

-- Animation styles
FloatingNumbers.STYLES = {
    "pop",      -- Pop & Float: classic with scale burst
    "bounce",   -- Bounce & Wiggle: elastic with sway
    "punch",    -- Punch & Arc: dramatic outward burst
}

-- State
local state = {
    numbers = {},
    currentStyle = 1,
}

-- Easing functions for smooth animations
local function easeOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local function easeOutElastic(t)
    if t == 0 or t == 1 then return t end
    local p = 0.3
    return math.pow(2, -10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
end

local function easeOutBack(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2)
end

local function easeInQuad(t)
    return t * t
end

-- Number types for color selection
FloatingNumbers.TYPE_DAMAGE = "damage"
FloatingNumbers.TYPE_GOLD = "gold"
FloatingNumbers.TYPE_SHARD = "shard"
FloatingNumbers.TYPE_CRYSTAL = "crystal"

-- Create a new floating number
local function createNumber(x, y, value, numberType)
    local cfg = Config.FLOATING_NUMBERS
    local style = FloatingNumbers.STYLES[state.currentStyle]

    local number = {
        x = x,
        y = y,
        startX = x,
        startY = y,
        value = value,
        numberType = numberType or FloatingNumbers.TYPE_DAMAGE,
        time = 0,
        duration = cfg.duration,
        style = style,
        -- Random values for variation
        seed = math.random() * 1000,
        offsetX = (math.random() - 0.5) * cfg.spreadX,
        angle = math.random() * math.pi * 2,  -- For punch style
    }

    table.insert(state.numbers, number)
end

function FloatingNumbers.init()
    -- Listen for damage events
    EventBus.on("creep_hit", function(data)
        if data.damage and data.damage > 0 then
            createNumber(data.position.x, data.position.y, math.floor(data.damage), FloatingNumbers.TYPE_DAMAGE)
        end
    end)

    -- Listen for kill events (gold)
    EventBus.on("creep_killed", function(data)
        if data.reward and data.reward > 0 then
            -- Offset gold number slightly so it doesn't overlap with last damage
            local offsetY = -10
            createNumber(data.position.x, data.position.y + offsetY, data.reward, FloatingNumbers.TYPE_GOLD)
        end
    end)

    -- Listen for shard drop events
    EventBus.on("void_shard_dropped", function(data)
        if data.amount and data.amount > 0 then
            local offsetY = -20  -- Offset to avoid overlap with gold
            createNumber(data.position.x, data.position.y + offsetY, data.amount, FloatingNumbers.TYPE_SHARD)
        end
    end)

    -- Listen for crystal drop events
    EventBus.on("void_crystal_dropped", function(data)
        if data.amount and data.amount > 0 then
            local offsetY = -20
            createNumber(data.position.x, data.position.y + offsetY, data.amount, FloatingNumbers.TYPE_CRYSTAL)
        end
    end)
end

function FloatingNumbers.update(dt)
    -- Update all floating numbers
    for i = #state.numbers, 1, -1 do
        local num = state.numbers[i]
        num.time = num.time + dt

        if num.time >= num.duration then
            table.remove(state.numbers, i)
        end
    end
end

-- Draw functions for each style
local function drawPop(num, cfg)
    local t = num.time / num.duration
    local progress = easeOutQuad(t)

    -- Scale: pop up then settle
    local scaleT = math.min(t * 4, 1)  -- Quick scale animation in first 25%
    local scale = 1 + (cfg.popScale - 1) * (1 - easeOutBack(scaleT))

    -- Position: gentle float upward with slight drift
    local floatY = -cfg.floatDistance * progress
    local driftX = num.offsetX * progress

    -- Alpha: hold then fade
    local fadeStart = 0.6
    local alpha = t < fadeStart and 1 or (1 - (t - fadeStart) / (1 - fadeStart))
    alpha = alpha * alpha  -- Smoother fade curve

    return {
        x = num.startX + driftX,
        y = num.startY + floatY,
        scale = scale,
        alpha = alpha,
        rotation = 0,
    }
end

local function drawBounce(num, cfg)
    local t = num.time / num.duration

    -- Elastic bounce for Y position
    local bounceT = math.min(t * 2.5, 1)  -- Bounce happens in first 40%
    local bounce = easeOutElastic(bounceT)
    local floatY = -cfg.floatDistance * bounce

    -- Horizontal wiggle (sine wave)
    local wiggleFreq = cfg.wiggleFrequency
    local wiggleAmp = cfg.wiggleAmplitude * (1 - t)  -- Dampens over time
    local wiggleX = math.sin(num.time * wiggleFreq + num.seed) * wiggleAmp

    -- Scale pulse during bounce
    local scaleT = math.min(t * 3, 1)
    local scalePulse = 1 + 0.15 * math.sin(num.time * 12) * (1 - scaleT)
    local scale = scalePulse

    -- Alpha: hold longer then fade with slight shrink
    local fadeStart = 0.65
    local alpha = t < fadeStart and 1 or (1 - (t - fadeStart) / (1 - fadeStart))
    if t > fadeStart then
        scale = scale * (0.8 + 0.2 * alpha)
    end

    return {
        x = num.startX + wiggleX + num.offsetX * 0.3,
        y = num.startY + floatY,
        scale = scale,
        alpha = alpha * alpha,
        rotation = 0,
    }
end

local function drawPunch(num, cfg)
    local t = num.time / num.duration

    -- Outward burst then float up
    local burstT = math.min(t * 5, 1)  -- Quick burst in first 20%
    local burstDist = cfg.punchDistance * easeOutBack(burstT)

    -- Arc path: burst out then curve upward
    local angle = num.angle
    local burstX = math.cos(angle) * burstDist * (1 - t * 0.7)  -- X dampens
    local burstY = math.sin(angle) * burstDist * 0.5  -- Less vertical burst

    -- Add upward float after burst
    local floatY = -cfg.floatDistance * easeOutQuad(t)

    -- Rotation during flight
    local rotationDir = num.seed > 500 and 1 or -1
    local rotation = rotationDir * t * cfg.punchRotation * (1 - t)  -- Peaks in middle

    -- Scale: start big, shrink down
    local scaleT = math.min(t * 2, 1)
    local scale = 1.4 - 0.4 * easeOutQuad(scaleT)

    -- Alpha: quick hold then fade
    local fadeStart = 0.5
    local alpha = t < fadeStart and 1 or (1 - (t - fadeStart) / (1 - fadeStart))
    alpha = math.pow(alpha, 1.5)

    return {
        x = num.startX + burstX,
        y = num.startY + burstY + floatY,
        scale = scale,
        alpha = alpha,
        rotation = rotation,
    }
end

function FloatingNumbers.draw()
    local cfg = Config.FLOATING_NUMBERS
    local font = Fonts.get("floatingNumber")
    if not font then return end

    love.graphics.setFont(font)

    for _, num in ipairs(state.numbers) do
        -- Get animation state based on style
        local anim
        if num.style == "pop" then
            anim = drawPop(num, cfg)
        elseif num.style == "bounce" then
            anim = drawBounce(num, cfg)
        elseif num.style == "punch" then
            anim = drawPunch(num, cfg)
        end

        if anim.alpha <= 0 then goto continue end

        -- Format text
        local text = tostring(num.value)
        if num.numberType ~= FloatingNumbers.TYPE_DAMAGE then
            text = "+" .. text
        end

        -- Get text dimensions for centering
        local textWidth = font:getWidth(text)
        local textHeight = font:getHeight()

        -- Choose color based on number type
        local color
        if num.numberType == FloatingNumbers.TYPE_DAMAGE then
            color = cfg.damageColor
        elseif num.numberType == FloatingNumbers.TYPE_GOLD then
            color = cfg.goldColor
        elseif num.numberType == FloatingNumbers.TYPE_SHARD then
            color = cfg.shardColor
        elseif num.numberType == FloatingNumbers.TYPE_CRYSTAL then
            color = cfg.crystalColor
        else
            color = cfg.damageColor
        end

        -- Draw with transform
        love.graphics.push()
        love.graphics.translate(anim.x, anim.y)
        love.graphics.rotate(anim.rotation)
        love.graphics.scale(anim.scale, anim.scale)

        -- Draw shadow/outline for readability
        local shadowAlpha = anim.alpha * 0.6
        love.graphics.setColor(0, 0, 0, shadowAlpha)
        local shadowOffset = 1
        for ox = -shadowOffset, shadowOffset do
            for oy = -shadowOffset, shadowOffset do
                if ox ~= 0 or oy ~= 0 then
                    love.graphics.print(text, -textWidth / 2 + ox, -textHeight / 2 + oy)
                end
            end
        end

        -- Draw main text
        love.graphics.setColor(color[1], color[2], color[3], anim.alpha)
        love.graphics.print(text, -textWidth / 2, -textHeight / 2)

        love.graphics.pop()

        ::continue::
    end
end

function FloatingNumbers.cycleStyle()
    state.currentStyle = state.currentStyle + 1
    if state.currentStyle > #FloatingNumbers.STYLES then
        state.currentStyle = 1
    end
    return FloatingNumbers.STYLES[state.currentStyle]
end

function FloatingNumbers.getCurrentStyle()
    return FloatingNumbers.STYLES[state.currentStyle]
end

function FloatingNumbers.getStyleIndex()
    return state.currentStyle
end

return FloatingNumbers
