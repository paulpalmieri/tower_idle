-- src/config.lua
-- All game constants and tuning values
--
-- RULE: No magic numbers in code. Everything goes here.

local Config = {}

-- =============================================================================
-- TIMING
-- =============================================================================

Config.MAX_DELTA_TIME = 1/30  -- Cap delta time to prevent physics issues

-- =============================================================================
-- SCREEN
-- =============================================================================

Config.SCREEN_WIDTH = 1280
Config.SCREEN_HEIGHT = 920   -- Taller to fit 7x10 grid + exit portal
Config.PLAY_AREA_RATIO = 0.70  -- Left side is play area
Config.PANEL_RATIO = 0.30      -- Right side is UI panel (30%)

-- =============================================================================
-- GRID
-- =============================================================================

Config.CELL_SIZE = 64          -- Must be multiple of 16 for clean sprite scaling (64/16 = 4x)
Config.GRID_COLS = 7           -- Fixed grid width (narrower)
Config.GRID_ROWS = 10          -- Fixed grid height (taller - 10 rows + void + buffer fits 880px screen)
Config.BASE_ROWS = 1           -- Bottom row is base zone
Config.VOID_HEIGHT = 2         -- Void height in cell units (above grid) - more room for portal
Config.VOID_BUFFER = 0.5       -- Buffer below void where creeps move before entering grid (in cell units)

-- =============================================================================
-- ECONOMY
-- =============================================================================

Config.STARTING_GOLD = 10000
Config.STARTING_LIVES = 20
Config.BASE_INCOME = 10
Config.INCOME_TICK_SECONDS = 5
Config.MAX_OFFLINE_HOURS = 4

-- =============================================================================
-- TOWERS
-- =============================================================================

Config.TOWERS = {
    void_orb = {
        name = "Void Orb",
        cost = 75,
        damage = 8,
        fireRate = 1.2,       -- Fast attack
        range = 100,          -- Short range
        projectileSpeed = 1000,
        rotationSpeed = 12,
        color = {0.4, 0.95, 0.3},   -- Poison (green)
        description = "Starter: cheap, fast, short range.",
        voidVariant = 1,  -- orb shape
    },
    void_ring = {
        name = "Void Ring",
        cost = 125,
        damage = 15,
        fireRate = 0.8,
        range = 130,
        projectileSpeed = 900,
        rotationSpeed = 10,
        color = {0.4, 0.85, 1.0},   -- Ice (cyan)
        description = "Balanced: medium stats.",
        voidVariant = 2,  -- ring shape
    },
    void_bolt = {
        name = "Void Bolt",
        cost = 175,
        damage = 12,
        fireRate = 1.5,       -- Very fast
        range = 110,
        projectileSpeed = 1400,
        rotationSpeed = 15,
        color = {0.3, 0.6, 1.0},    -- Electric (blue)
        description = "Speed: fast attack, electric.",
        voidVariant = 3,  -- bolt shape
    },
    void_eye = {
        name = "Void Eye",
        cost = 225,
        damage = 35,
        fireRate = 0.4,       -- Slow
        range = 180,          -- Long range
        projectileSpeed = 800,
        rotationSpeed = 6,
        color = {0.75, 0.45, 0.95}, -- Shadow (purple)
        description = "Precision: high damage, slow.",
        voidVariant = 4,  -- eye shape
    },
    void_star = {
        name = "Void Star",
        cost = 300,
        damage = 25,
        fireRate = 0.7,
        range = 150,
        projectileSpeed = 1100,
        rotationSpeed = 10,
        color = {1.0, 0.6, 0.2},    -- Fire (orange)
        description = "Elite: all-around strong.",
        voidVariant = 5,  -- star shape
    },
}

-- Tower visual settings
Config.TOWER_SIZE = 16         -- Base radius
Config.TOWER_BARREL_LENGTH = 1.2  -- Multiplier of size

-- Tower building animation
Config.TOWER_BUILD = {
    duration = 5.0,           -- Total build time in seconds
    basePhaseDuration = 0.8,  -- Time before void entity starts appearing
}

-- =============================================================================
-- TOWER ATTACK TYPES (Unique attack mechanics per tower)
-- =============================================================================

Config.TOWER_ATTACKS = {
    void_orb = {
        type = "drip",                  -- Glow + drip effect, pool spawns at enemy
        glowDuration = 0.2,             -- Tower glow buildup time
        dripDuration = 0.3,             -- Visual drip travel time
        dripSegments = 4,               -- Drip trail segments
        cloudRadius = 40,               -- Radius of poison cloud
        cloudDuration = 4.0,            -- How long cloud lasts
        cloudDamagePerTick = 3,         -- Damage per tick
        cloudTickInterval = 0.5,        -- Time between damage ticks
    },
    void_ring = {
        type = "aura",                  -- Constant slow aura (no projectile)
        slowMultiplier = 0.5,           -- Speed multiplier (0.5 = 50% speed)
        slowDuration = 0.2,             -- How long slow lasts after leaving aura
    },
    void_bolt = {
        type = "piercing_bolt",         -- Fast piercing bolt
        boltSpeed = 1000,               -- Bolt travel speed
        pierceDamageMultiplier = 0.85,  -- Damage multiplier per pierce
        slowMultiplier = 0.7,           -- Slight slow on hit
        slowDuration = 0.5,             -- Brief slow duration
    },
    void_eye = {
        type = "blackhole",             -- Charge + spawn blackhole that pulls enemies
        chargeTime = 0.8,               -- Time to charge before spawning
        blackholeDuration = 4.5,        -- How long blackhole lasts
        blackholeRadius = 80,           -- Pull effect radius
        blackholePullStrength = 60,     -- Base pull speed
        blackholePullFalloff = 1.5,     -- Pull strength falloff exponent
        blackholeVisualSize = 12,       -- Visual size of event horizon (pixels)
    },
    void_star = {
        type = "lobbed",                -- Parabolic arc bomb with explosion burst
        arcHeightBase = 30,             -- Base arc height
        arcHeightPerDistance = 0.2,     -- Arc height scale per distance
        maxArcHeight = 80,              -- Maximum arc height cap
        lobSpeed = 400,                 -- Slower lobbed projectile speed
        spinSpeed = 6,                  -- Rotation speed during flight (radians/sec)
        explosionParticles = 8,         -- Explosion burst particle count
        explosionSpeed = 80,            -- Explosion particle speed
        explosionDuration = 0.25,       -- Explosion visual duration
        fireRadius = 35,                -- Radius of fire zone after explosion
        fireDuration = 3.0,             -- How long fire lasts
        fireDamagePerTick = 4,          -- Damage per tick
        fireTickInterval = 0.4,         -- Time between damage ticks
    },
}

-- =============================================================================
-- STATUS EFFECTS
-- =============================================================================

Config.STATUS_EFFECTS = {
    poison = {
        damagePerTick = 3,
        tickInterval = 0.5,
        duration = 3.0,
        color = {0.4, 0.95, 0.3},       -- Green
    },
    burn = {
        damagePerTick = 4,
        tickInterval = 0.4,
        duration = 2.5,
        color = {1.0, 0.6, 0.2},        -- Orange
    },
    slow = {
        multiplier = 0.5,
        duration = 1.0,
        color = {0.4, 0.85, 1.0},       -- Cyan
    },
}

-- =============================================================================
-- GROUND EFFECTS (Poison Cloud, Burning Ground)
-- =============================================================================

Config.GROUND_EFFECTS = {
    perspectiveYScale = 0.9,  -- Y compression for ground effects (0.9 = 10% compression for subtle depth)
    poison_cloud = {
        pixelSize = 4,
        wobbleSpeed = 2.0,
        wobbleAmount = 0.3,
        pulseSpeed = 3.0,
        colors = {
            core = {0.15, 0.35, 0.1, 0.4},
            mid = {0.3, 0.7, 0.2, 0.5},
            edge = {0.5, 0.95, 0.3, 0.3},
            particle = {0.6, 1.0, 0.4},
        },
        particleCount = 8,
        particleSpeed = 20,
    },
    burning_ground = {
        pixelSize = 4,
        flickerSpeed = 8.0,
        pulseSpeed = 4.0,
        colors = {
            core = {0.4, 0.1, 0.0, 0.5},
            mid = {0.8, 0.3, 0.1, 0.6},
            edge = {1.0, 0.6, 0.2, 0.4},
            ember = {1.0, 0.8, 0.3},
        },
        emberCount = 6,
        emberSpeed = 40,
    },
    -- Chain lightning visual
    chain_lightning = {
        color = {0.5, 0.75, 1.0},
        glowColor = {0.4, 0.7, 1.0, 0.4},
        duration = 0.15,
        segments = 5,
        jaggedness = 8,
    },
    -- Beam visual for void_eye
    beam = {
        chargeColor = {0.75, 0.45, 0.95, 0.3},
        fireColor = {0.85, 0.6, 1.0},
        chargeWidth = 2,
        fireWidth = 6,
        glowWidth = 12,
    },
}

-- =============================================================================
-- CREEPS (ENEMIES)
-- =============================================================================

Config.CREEPS = {
    voidSpawn = {
        name = "Void Spawn",
        hp = 50,
        speed = 50,           -- pixels per second
        reward = 8,           -- gold on kill
        income = 10,          -- income per tick when sent
        sendCost = 100,       -- cost to send
        size = 14,
        color = {0.5, 0.2, 0.7},
    },
    voidSpider = {
        name = "Void Spider",
        hp = 25,              -- Fragile (lower than voidSpawn)
        speed = 70,           -- Fast (higher than voidSpawn)
        reward = 4,           -- Lower reward
        income = 6,           -- Lower income
        sendCost = 60,        -- Cheaper to send
        size = 12,            -- Slightly smaller body
        color = {0.6, 0.2, 0.8},
    },
}

-- Visual configuration for void spawn rendering (pixel art style)
Config.VOID_SPAWN = {
    pixelSize = 3,            -- Size of each "pixel" in the sprite
    distortionAmount = 0.25,
    distortionFrequency = 2.0,
    distortionSpeed = 1.5,
    octaves = 3,
    seed = 0,
    swirlSpeed = 1.2,
    glowWidth = 0.3,
    pulseSpeed = 2.5,
    pulseAmount = 0.15,
    -- Edge wobble animation
    wobbleSpeed = 3.0,        -- How fast edges undulate
    wobbleFrequency = 3.0,    -- Angular frequency (more = more bumps)
    wobbleAmount = 1.5,       -- Displacement in pixels (relative to pixelSize)
    wobbleFalloff = 0.4,      -- Inner radius where wobble starts (0-1)
    sparkleThreshold = 0.92,  -- Lower = more sparkles (was 0.96)
    colors = {
        core = {0.08, 0.03, 0.15},       -- Brighter purple-black
        mid = {0.25, 0.10, 0.40},        -- Brighter mid purple
        edgeGlow = {0.85, 0.50, 1.0},    -- Bright pink-purple edge
        sparkle = {1.0, 0.9, 1.0},       -- Nearly white sparkles
    },
}

-- Visual configuration for void spider rendering (pixel art style)
-- Elongated rift body with floating shard legs:  / | \
--                                                / | \
Config.VOID_SPIDER = {
    pixelSize = 3,              -- Match standard creep pixel size
    distortionFrequency = 2.0,
    octaves = 3,
    wobbleSpeed = 3.0,
    wobbleFrequency = 3.0,
    wobbleAmount = 0.4,
    wobbleFalloff = 0.4,
    swirlSpeed = 1.2,
    pulseSpeed = 2.5,
    sparkleThreshold = 0.92,
    -- Base leg settings (medium legs - fixed)
    legs = {
        length = 1.5,           -- Medium length
        width = 0.6,            -- Medium width
        bobAmount = 2,          -- Vertical bob in pixels
        bobSpeed = 3,           -- Slow bob
        gap = 1.4,              -- Gap from body center
        angle = 0.2,            -- Slight outward angle (~11 degrees)
    },
    -- Colors (same as standard void spawn)
    colors = {
        core = {0.08, 0.03, 0.15},
        mid = {0.25, 0.10, 0.40},
        edgeGlow = {0.85, 0.50, 1.0},
        sparkle = {1.0, 0.9, 1.0},
    },
    -- Body shape (gash variant - wider elongated rift)
    body = {
        width = 0.6,
        height = 1.6,
    },
}

-- Visual configuration for the Void Portal (circular, creep-style rendering)
Config.VOID_PORTAL = {
    baseSize = 42,              -- 3x creep size (14 * 3)
    maxSize = 120,              -- Maximum growth (fills spawn area)
    topPadding = 20,            -- Padding from top of spawn area
    pixelSize = 3,              -- Same as creep
    distortionFrequency = 2.0,  -- Same as creep
    octaves = 3,                -- Same as creep
    wobbleSpeed = 3.0,          -- Same as creep
    wobbleFrequency = 3.0,      -- Same as creep
    wobbleAmount = 1.5,         -- Same as creep
    wobbleFalloff = 0.4,        -- Same as creep
    swirlSpeed = 1.2,           -- Same as creep
    pulseSpeed = 2.5,           -- Same as creep
    sparkleThreshold = 0.92,    -- Same as creep
    colors = {                  -- Same brighter colors as creep
        core = {0.08, 0.03, 0.15},       -- Brighter purple-black
        mid = {0.25, 0.10, 0.40},        -- Brighter mid purple
        edgeGlow = {0.85, 0.50, 1.0},    -- Bright pink-purple edge
        sparkle = {1.0, 0.9, 1.0},       -- Nearly white sparkles
    },
    growthPerDamage = 0.3,      -- Size increase per damage point
    growthSpeed = 15,           -- Animated growth rate (pixels/sec)
    -- Shadow settings
    shadow = {
        offsetY = 1.4,          -- Shadow Y offset as multiplier of size (towards bottom of void)
        width = 1.6,            -- Shadow width as multiplier of size
        height = 0.4,           -- Shadow height as multiplier of size
        alpha = 0.25,           -- Shadow opacity
    },
}

-- =============================================================================
-- WAVES
-- =============================================================================

Config.WAVE_DURATION = 5       -- Seconds between waves
Config.WAVE_BASE_ENEMIES = 3   -- Starting enemies per wave
Config.WAVE_SCALING = 1        -- Additional enemies per wave
Config.WAVE_SPAWN_INTERVAL = 0.5  -- Time between spawning each creep

-- Wave composition based on anger level (replaces old send ratios)
Config.WAVE_ANGER_COMPOSITION = {
    [0] = { voidSpawn = 2, voidSpider = 2 },
    [1] = { voidSpawn = 4, voidSpider = 3 },
    [2] = { voidSpawn = 5, voidSpider = 4 },
    [3] = { voidSpawn = 6, voidSpider = 6 },
}

-- =============================================================================
-- VOID
-- =============================================================================

Config.VOID = {
    maxHealth = 100,
    clickDamage = 1,
    baseIncomePerClick = 5,
    angerThresholds = {75, 50, 25},  -- Health thresholds that increase anger
    maxAnger = 4,                     -- Maximum anger level (0-3 + permanent)
    baseRadius = 60,
    yOffset = 30,                     -- Distance from top of play area
    pulseSpeed = 2,                   -- Pulse animation speed
    pulseAmount = 0.1,                -- Pulse size variation (10%)
    clickFlashDuration = 0.15,        -- Flash duration on click
}

-- =============================================================================
-- COMBAT
-- =============================================================================

Config.PROJECTILE_SIZE = 4         -- Collision radius for projectiles
Config.CREEP_ROTATION_SPEED = 0.5  -- Rotation speed for visual effect

-- Floating numbers configuration (damage & gold popups)
Config.FLOATING_NUMBERS = {
    duration = 0.9,           -- Total lifetime in seconds
    floatDistance = 45,       -- How far numbers float up

    -- Colors
    damageColor = {1.0, 1.0, 1.0},      -- White for damage
    goldColor = {0.95, 0.78, 0.25},     -- Gold for rewards

    -- Spread/variation
    spreadX = 20,             -- Random horizontal spread

    -- Style: Pop & Float
    popScale = 1.35,          -- Initial scale burst

    -- Style: Bounce & Wiggle
    wiggleFrequency = 14,     -- Wiggle speed
    wiggleAmplitude = 6,      -- Wiggle distance

    -- Style: Punch & Arc
    punchDistance = 25,       -- Outward burst distance
    punchRotation = 0.4,      -- Max rotation in radians
}

-- Hit feedback
Config.CREEP_HIT = {
    flashDuration = 0.06,      -- Brief white flash
    particleCount = 6,         -- More particles for impact
    particleSpeed = 120,       -- Faster spray
    particleLife = 0.3,        -- Slightly longer for visibility
    particleSize = 4,          -- Matches pixel aesthetic
    particleSpread = 1.2,      -- Cone spread in radians (~70 degrees)
}

-- Cadaver (dead creep remains)
Config.CADAVER_FADE_DURATION = 10  -- Seconds before cadaver fully fades out

-- =============================================================================
-- PRESTIGE (Phase 2)
-- =============================================================================

Config.PRESTIGE_UNLOCK_WAVE = 25
Config.ESSENCE_PER_WAVE = 10
Config.ESSENCE_PER_1000_GOLD = 1
Config.ESSENCE_PER_SEND = 2

-- =============================================================================
-- COLORS (Dark Fantasy Jewel-Tone Palette)
-- =============================================================================

Config.COLORS = {
    -- Base tones (darker, richer)
    background = {0.04, 0.03, 0.06},           -- Deep midnight
    panel = {0.06, 0.05, 0.08},                -- Dark purple-black
    panelBorder = {0.25, 0.18, 0.30},          -- Muted purple border

    -- Grid and zones
    grid = {0.30, 0.25, 0.35, 0.4},            -- Purple-tinted grid
    spawnZone = {0.18, 0.12, 0.22},            -- Subtle purple
    baseZone = {0.12, 0.10, 0.08},             -- Dark stone base

    -- Jewel tones
    gold = {0.95, 0.78, 0.25},                 -- Rich gold
    goldDark = {0.65, 0.50, 0.15},             -- Tarnished gold (shadows)
    emerald = {0.20, 0.65, 0.35},              -- Emerald green
    ruby = {0.75, 0.20, 0.25},                 -- Ruby red
    amethyst = {0.55, 0.30, 0.70},             -- Amethyst purple
    sapphire = {0.25, 0.45, 0.75},             -- Sapphire blue

    -- Text hierarchy
    textPrimary = {0.92, 0.88, 0.82},          -- Warm parchment
    textSecondary = {0.55, 0.50, 0.45},        -- Aged text
    textDisabled = {0.30, 0.28, 0.26},         -- Faded
    textGlow = {1.0, 0.95, 0.80},              -- Glowing text

    -- Frame colors (for ornate borders)
    frameDark = {0.12, 0.10, 0.15},            -- Inner shadow
    frameMid = {0.22, 0.18, 0.28},             -- Border base
    frameLight = {0.35, 0.28, 0.42},           -- Highlight edge
    frameAccent = {0.50, 0.35, 0.55},          -- Corner decorations
    frameGlow = {0.60, 0.40, 0.70},            -- Glow effect

    -- Functional
    towerBase = {0.2, 0.2, 0.22},
    income = {0.25, 0.60, 0.35},               -- Muted emerald
    lives = {0.75, 0.25, 0.30},                -- Ruby

    -- Base zone (player camp)
    camp = {
        stone = {0.18, 0.16, 0.14},            -- Dark stone
        stoneLight = {0.25, 0.22, 0.20},       -- Light stone
        wood = {0.30, 0.20, 0.12},             -- Dark wood
        woodLight = {0.40, 0.28, 0.18},        -- Light wood
        metal = {0.35, 0.32, 0.30},            -- Iron
    },

    -- Void colors (indexed by anger level 0-3)
    void = {
        [0] = {0.4, 0.2, 0.6},    -- Purple (calm)
        [1] = {0.6, 0.2, 0.5},    -- Magenta (annoyed)
        [2] = {0.8, 0.2, 0.3},    -- Red-purple (angry)
        [3] = {1.0, 0.1, 0.1},    -- Red (furious)
    },
    voidGlow = {0.6, 0.3, 0.8, 0.3},
    voidFlash = {1.0, 1.0, 1.0, 0.8},
    voidHealthBar = {0.8, 0.2, 0.8},
    voidHealthBarBg = {0.2, 0.1, 0.2},
    angerPipEmpty = {0.3, 0.15, 0.3},
    angerPipFilled = {1.0, 0.3, 0.1},
}

-- =============================================================================
-- UI
-- =============================================================================

Config.UI = {
    padding = 10,             -- Comfortable padding
    buttonHeight = 56,        -- Taller cards for bigger sprites
    buttonSpacing = 6,        -- Nice spacing between cards
    hudHeight = 0,            -- No longer used - stats are in panel
    -- Layout constants for panel sections
    LAYOUT = {
        sectionSpacing = 10,
        statsHeight = 85,     -- More space for stats + void bar
        voidHeight = 0,       -- Merged into stats section
        sectionTitleHeight = 0,  -- No section headers
        borderDecorStart = 8,
        borderDecorSpacing = 24,
    },
    -- Panel visual settings
    panel = {
        iconScale = 2.0,      -- 32px icons (16 * 2) - bigger sprites
        frameThickness = 2,   -- Clean thin border
        cornerSize = 4,       -- Subtle corner accents
        cardPadding = 8,      -- Inner padding in cards
        -- Border ornament settings
        ornament = {
            dotSize = 2,           -- Small accent dots
            dotSpacing = 20,       -- Spacing between dots
            lineInset = 4,         -- Inner line distance from border
        },
        -- Legacy settings (kept for compatibility)
        towerSectionY = 50,
        enemySectionYOffset = 30,
        buttonColors = {
            selected = {0.1, 0.3, 0.1},
            hovered = {0.15, 0.15, 0.2},
            default = {0.08, 0.08, 0.12},
            enemyHovered = {0.2, 0.1, 0.1},
        },
        iconXOffset = 25,
        iconRadius = 12,
        textXOffset = 45,
        textYOffset = 10,
        costYOffset = 30,
        hotkeyXOffset = 35,
        statsYOffset = 48,
    },
    -- Frame styles (Dark Fantasy theme)
    -- Each style defines: background, border, highlight, shadow, accent
    frames = {
        standard = {
            background = {0.08, 0.06, 0.10, 0.95},
            border = {0.28, 0.22, 0.32},
            highlight = {0.38, 0.30, 0.42},
            shadow = {0.04, 0.03, 0.05},
            accent = {0.45, 0.35, 0.50},
        },
        selected = {
            background = {0.10, 0.08, 0.12, 0.95},
            border = {0.75, 0.60, 0.25},
            highlight = {0.90, 0.75, 0.35},
            shadow = {0.35, 0.25, 0.10},
            accent = {0.95, 0.78, 0.25},
        },
        highlight = {
            background = {0.12, 0.10, 0.14, 0.95},
            border = {0.42, 0.35, 0.48},
            highlight = {0.52, 0.45, 0.58},
            shadow = {0.05, 0.04, 0.06},
            accent = {0.55, 0.45, 0.60},
        },
        disabled = {
            background = {0.06, 0.05, 0.07, 0.9},
            border = {0.18, 0.15, 0.20},
            highlight = {0.22, 0.18, 0.24},
            shadow = {0.03, 0.02, 0.04},
            accent = {0.25, 0.20, 0.28},
        },
        hud = {
            background = {0.07, 0.05, 0.09, 0.92},
            border = {0.28, 0.22, 0.32},
            highlight = {0.35, 0.28, 0.40},
            shadow = {0.03, 0.02, 0.04},
            accent = {0.40, 0.32, 0.45},
        },
        void = {
            background = {0.10, 0.06, 0.14, 0.95},
            border = {0.50, 0.25, 0.55},
            highlight = {0.60, 0.35, 0.65},
            shadow = {0.05, 0.02, 0.06},
            accent = {0.70, 0.40, 0.75},
        },
        tooltip = {
            background = {0.09, 0.07, 0.11, 0.95},
            border = {0.50, 0.40, 0.45},
            highlight = {0.60, 0.50, 0.55},
            shadow = {0.04, 0.03, 0.05},
            accent = {0.55, 0.45, 0.50},
        },
    },
    -- Ornate frame decoration settings
    ornateFrame = {
        cornerSize = 6,              -- Size of corner diamonds
        edgeInset = 3,               -- How far corners sit from edge
        showCorners = true,          -- Toggle corner decorations
        showEdgeAccents = true,      -- Toggle edge accent lines
    },
}

-- =============================================================================
-- UPGRADES
-- =============================================================================

Config.UPGRADES = {
    maxLevel = 5,
    baseCost = 150,           -- Base cost for first upgrade
    costMultiplier = 1.8,     -- Each level costs 1.8x previous
    bonusPerLevel = {
        range = 0.10,         -- +10% per level = +50% at max
        fireRate = 0.15,      -- +15% per level = +75% at max
        damage = 0.20,        -- +20% per level = +100% at max
    },
    -- Panel upgrades (Void-related)
    panel = {
        autoClicker = {
            name = "Auto-Clicker",
            baseCost = 500,
            costMultiplier = 2.0,
            maxLevel = 5,
            baseInterval = 2.0,       -- Seconds between auto-clicks at level 1
            intervalReduction = 0.2,  -- Reduce interval by 0.2s per level
        },
    },
}

-- Tower sell refund percentage
Config.TOWER_SELL_REFUND = 0.75  -- 75% refund of total investment

Config.COLORS.upgrade = {
    range = {0.5, 0.7, 0.85},             -- Soft blue
    fireRate = {0.85, 0.7, 0.4},          -- Warm amber
    damage = {0.85, 0.5, 0.45},           -- Muted red
    tooltip = {0.11, 0.10, 0.13, 0.95},
    tooltipBorder = {0.45, 0.42, 0.38},   -- Warm border
    selected = {0.6, 0.55, 0.4, 0.35},    -- Warm gold highlight
    hover = {0.7, 0.65, 0.5, 0.25},       -- Warm gold glow for tower hover
}

Config.UI.tooltip = {
    width = 200,
    padding = 12,
    buttonHeight = 32,
    buttonSpacing = 8,
    offsetX = 20,
    offsetY = -10,
    statsRowHeight = 22,
    headerHeight = 28,
}

Config.UI.rangePreview = {
    fillAlpha = 0.1,
    strokeAlpha = 0.4,
    strokeWidth = 2,
}

-- Settings menu configuration
Config.UI.settings = {
    width = 320,
    height = 420,
    checkboxSize = 20,
    sliderHeight = 16,
    sliderTrackHeight = 8,
    dropdownHeight = 28,
    dropdownItemHeight = 24,
    padding = 20,
    labelWidth = 120,
    controlWidth = 140,
    rowSpacing = 16,
    closeButtonSize = 24,
}

Config.UI.frames.settings = {
    background = {0.08, 0.06, 0.10, 0.98},
    border = {0.45, 0.35, 0.50},
    highlight = {0.55, 0.45, 0.60},
    shadow = {0.04, 0.03, 0.05},
    accent = {0.60, 0.50, 0.65},
}

Config.SETTINGS = {
    resolutions = {
        { width = 1280, height = 920, label = "1280 x 920" },
        { width = 1600, height = 1150, label = "1600 x 1150" },
        { width = 1920, height = 1380, label = "1920 x 1380" },
    },
    -- Visual effects defaults
    visualEffects = {
        lighting = false,      -- Dynamic lighting system
        vignette = true,       -- Edge darkening effect
        fogParticles = true,   -- Atmospheric fog wisps
        dustParticles = true,  -- Floating dust motes
    },
}

-- =============================================================================
-- GAME SPEED
-- =============================================================================

Config.GAME_SPEEDS = {1, 5, 0}              -- x1, x5, paused
Config.GAME_SPEED_LABELS = {"x1", "x5", "||"}  -- Display labels

-- =============================================================================
-- FONTS
-- =============================================================================

Config.FONTS = {
    path = "assets/fonts/m5x7.ttf",
    sizes = {
        small = 16,
        medium = 24,
        large = 32,
        title = 48,
    },
}

-- =============================================================================
-- BACKGROUND
-- =============================================================================

Config.BACKGROUND = {
    pixelSize = 4,
    colors = {
        base = {0.07, 0.06, 0.08},
        baseDark = {0.04, 0.035, 0.05},
        baseLight = {0.10, 0.09, 0.11},
        crack = {0.03, 0.025, 0.04},
        cluster = {0.14, 0.08, 0.20},
        clusterBright = {0.22, 0.12, 0.30},
    },
}

-- =============================================================================
-- EXIT PORTAL (Red portal at base zone)
-- =============================================================================

Config.EXIT_PORTAL = {
    baseSize = 42,              -- Same size as Void
    bottomPadding = 30,         -- Padding from bottom of screen
    pixelSize = 3,              -- Same as creep
    distortionFrequency = 2.0,  -- Same as creep
    octaves = 3,                -- Same as creep
    wobbleSpeed = 3.0,          -- Same as creep
    wobbleFrequency = 3.0,      -- Same as creep
    wobbleAmount = 1.5,         -- Same as creep
    wobbleFalloff = 0.4,        -- Same as creep
    swirlSpeed = 1.2,           -- Same as creep
    pulseSpeed = 2.5,           -- Same as creep
    sparkleThreshold = 0.92,    -- Same as creep
    -- Red color palette (instead of purple)
    colors = {
        core = {0.15, 0.03, 0.03},       -- Dark red-black
        mid = {0.40, 0.08, 0.08},        -- Mid red
        edgeGlow = {1.0, 0.35, 0.25},    -- Bright orange-red edge
        sparkle = {1.0, 0.95, 0.85},     -- Warm white sparkles
    },
    -- Shadow settings
    shadow = {
        offsetY = 1.4,          -- Shadow Y offset as multiplier of size
        width = 1.6,            -- Shadow width as multiplier of size
        height = 0.4,           -- Shadow height as multiplier of size
        alpha = 0.25,           -- Shadow opacity
    },
}

-- =============================================================================
-- EXIT ANIMATION (Red rift when creeps reach base)
-- =============================================================================

Config.EXIT_ANIMATION = {
    -- Timing (seconds)
    tearOpenDuration = 0.25,
    devouringDuration = 0.35,
    tearCloseDuration = 0.2,

    -- Visual settings
    tearWidth = 10,           -- Pixels wide at max open
    tearHeight = 45,          -- Vertical tear height
    tearPixelSize = 4,        -- Match void pixel size

    -- Red tear colors
    tearColors = {
        edge = {1.0, 0.35, 0.2},      -- Bright orange-red edge
        inner = {1.0, 0.75, 0.6},      -- Warm orange-white inner glow
        void = {0.12, 0.02, 0.02},     -- Dark red void through tear
    },

    -- Particle settings (orange-red)
    particles = {
        spawnRate = 4,        -- particles per frame during tear_open
        speed = 50,           -- pixels/second
        life = 0.35,          -- seconds
        size = 3,             -- pixel size
        color = {1.0, 0.6, 0.3},  -- bright orange
    },

    -- Pull animation during devouring
    pullDistance = 20,        -- How far creep is pulled toward portal center
}

-- =============================================================================
-- SPAWN ANIMATION
-- =============================================================================

Config.SPAWN_ANIMATION = {
    -- Timing (seconds)
    tearOpenDuration = 0.3,
    emergeDuration = 0.4,
    tearCloseDuration = 0.2,

    -- Visual settings
    tearWidth = 8,           -- Pixels wide at max open
    tearHeight = 40,         -- Vertical tear height
    tearPixelSize = 4,       -- Match void pixel size

    -- Colors (matches void palette)
    tearColors = {
        edge = {0.6, 0.3, 0.8},      -- Bright purple edge
        inner = {0.9, 0.7, 1.0},      -- White-pink inner glow
        void = {0.03, 0.01, 0.08},    -- Dark void through tear
    },

    -- Particle settings
    particles = {
        spawnRate = 3,        -- particles per frame during tear_open
        speed = 40,           -- pixels/second
        life = 0.3,           -- seconds
        size = 3,             -- pixel size
        color = {0.9, 0.7, 1.0},  -- bright purple-white
    },
}

-- =============================================================================
-- PIXEL ART
-- =============================================================================

Config.PIXEL_ART = {
    SPRITE_SIZE = 16,  -- Base sprite size in pixels (16x16 for chunky pixel art)
    SCALE = Config.CELL_SIZE / 16,  -- Derive scale from cell size (64/16 = 4.0 exact)
    PROJECTILE_SCALE = 1.5,  -- Smaller scale for projectiles (5x5 sprite = 7.5px)
    SHADOW_ALPHA = 0.5,  -- Shadow opacity for barrel shadows

    COLORS = {
        -- Metals/Structure (darker, more ominous)
        ['.'] = nil,                          -- Transparent
        ['#'] = {0.12, 0.10, 0.14},           -- Dark metal (outline/frame) - purple tinted
        ['='] = {0.22, 0.20, 0.26},           -- Mid metal (body panels) - desaturated
        ['-'] = {0.35, 0.32, 0.40},           -- Light metal (highlights) - purple tinted
        ['e'] = {0.08, 0.06, 0.10},           -- Edge rivets (very dark, near black)
        ['w'] = {0.70, 0.65, 0.80},           -- Pale purple-white (barrel bore)

        -- Basic Tower (dark teal/slate with void corruption)
        ['G'] = {0.12, 0.18, 0.20},           -- Dark teal (shadows)
        ['g'] = {0.18, 0.26, 0.28},           -- Mid teal-slate (main body)
        ['o'] = {0.28, 0.38, 0.42},           -- Desaturated teal (highlights)

        -- Sniper Tower (dark brass/bronze with void corruption)
        ['Y'] = {0.22, 0.18, 0.14},           -- Dark bronze (shadows)
        ['y'] = {0.32, 0.26, 0.20},           -- Mid brass-brown (main body)
        ['l'] = {0.45, 0.38, 0.30},           -- Pale bronze (highlights)

        -- Void Corruption Accents
        ['@'] = {0.55, 0.20, 0.50},           -- Deep magenta core (void power)
        ['!'] = {0.85, 0.60, 0.95},           -- Muzzle flash (purple-white)
        ['V'] = {0.40, 0.15, 0.45},           -- Void purple accent
        ['v'] = {0.60, 0.30, 0.65},           -- Light void purple glow

        -- Brass/Bullet colors
        ['B'] = {0.85, 0.65, 0.25},           -- Brass (bullet outer)
        ['b'] = {1.0, 0.85, 0.4},             -- Bright brass (bullet center)

        -- Special markers (rendered AND used for positioning)
        -- These colors blend in with surrounding pixels
        ['A'] = {0.28, 0.38, 0.42},  -- Anchor - same as 'o' (teal highlight)
        ['P'] = {0.22, 0.20, 0.26},  -- Pivot - same as '=' (mid metal)
        ['T'] = {0.12, 0.10, 0.14},  -- Tip - same as '#' (dark metal outline)
    },

    TOWERS = {},

    -- Cursors (pixel art) - minimalist style
    CURSORS = {
        -- Arrow cursor (6x8) - simple arrow
        arrow = [[
#.....
##....
#-#...
#--#..
#---#.
#-##..
##....
#.....
]],
        -- Pointer/click cursor (5x7) - simple hand
        pointer = [[
.#...
#-#..
#-#..
#-#..
#--#.
#--#.
.##..
]],
    },

    -- UI Icons (small pixel art)
    ICONS = {
        -- Gold coin icon (6x6)
        gold = [[
.yyyy.
yYYYYy
yY@@Yy
yY@@Yy
yYYYYy
.yyyy.
]],
        -- Heart icon (7x7)
        heart = [[
.##.##.
#@@#@@#
#@@@@@#
#@@@@@#
.#@@@#.
..#@#..
...#...
]],
        -- Wave indicator (5x5)
        wave = [[
..#..
.###.
#####
.###.
..#..
]],
        -- Sword icon (5x7) - for damage stat
        sword = [[
..#..
..#..
.###.
..#..
..#..
.###.
..#..
]],
        -- Clock icon (5x5) - for fire rate
        clock = [[
.###.
#.#.#
###.#
#...#
.###.
]],
        -- Target icon (5x5) - for range
        target = [[
.###.
#.#.#
##.##
#.#.#
.###.
]],
        -- Gem icon (5x5) - amethyst for void
        gem = [[
.###.
#=-=#
#-=-#
.#=#.
..#..
]],
        -- Shield icon (6x6) - for defense/lives
        shield = [[
.####.
######
######
.####.
..##..
...#..
]],
    },
}

-- =============================================================================
-- AUDIO
-- =============================================================================

Config.AUDIO = {
    enabled = false,
    masterVolume = 0.5,
    sampleRate = 44100,
    bitDepth = 16,
    channels = 1,

    -- Sound design: simple, clean, non-fatiguing
    -- These play hundreds of times per session
    sounds = {
        -- Void turret fire: ethereal "whoosh" with void resonance
        void_fire = {
            volume = 0.18,
            duration = 0.08,
            poolSize = 6,      -- More sources for rapid firing
            freq = 180,        -- Mid frequency
            decay = 20,        -- Medium decay
        },
        -- Spawn: rift crack - sharp snap
        creep_spawn = {
            volume = 0.25,
            duration = 0.08,
            poolSize = 4,
            freq = 180,        -- Audible thump frequency
            decay = 35,        -- Fast but not instant
        },
        -- Hit: tiny tap - just enough feedback
        creep_hit = {
            volume = 0.06,
            duration = 0.03,
            poolSize = 6,
            freq = 320,
            decay = 50,        -- Very fast decay
        },
        -- Death: quick descending pop
        creep_death = {
            volume = 0.12,
            duration = 0.1,
            poolSize = 4,
            freqStart = 280,
            freqEnd = 80,      -- Descending
            decay = 18,
        },
    },

    -- Ambient soundscape: alien/deep space atmosphere
    ambient = {
        enabled = true,
        volume = 0.12,           -- Low background volume
        minInterval = 8,         -- Min seconds between sounds
        maxInterval = 20,        -- Max seconds between sounds
        files = {
            "assets/sounds/ambient/ambient_01.mp3",
            "assets/sounds/ambient/ambient_02.mp3",
            "assets/sounds/ambient/ambient_03.mp3",
            "assets/sounds/ambient/ambient_04.mp3",
            "assets/sounds/ambient/ambient_05.mp3",
            "assets/sounds/ambient/ambient_06.mp3",
        },
    },
}

-- =============================================================================
-- TURRET CONCEPTS (Showcase mode)
-- =============================================================================

Config.TURRET_CONCEPTS = {
    -- Shared settings
    pixelSize = 3,
    baseHeight = 50,      -- Tall towers (~50px height)
    baseWidth = 36,       -- Tower width
    shadowAlpha = 0.4,    -- Drop shadow opacity

    -- Concept 1: Crimson Sentinel (Mechanical)
    crimson_sentinel = {
        name = "Crimson Sentinel",
        style = "mechanical",
        colors = {
            core = {0.08, 0.04, 0.04},           -- Near-black rust
            mid = {0.18, 0.10, 0.08},            -- Dark rust
            edgeGlow = {0.95, 0.25, 0.15},       -- Bright crimson
            sparkle = {1.0, 0.85, 0.7},          -- Orange-white flash
            accent = {0.6, 0.15, 0.1},           -- Deep crimson accent
            conduit = {1.0, 0.4, 0.2},           -- Glowing conduit
        },
        idle = {
            vibrationAmount = 0.5,              -- Pixels of vibration
            vibrationSpeed = 15,                -- Vibration frequency (Hz-like)
            conduitPulseSpeed = 2.5,            -- Power conduit pulse rate
        },
        recoil = {
            distance = 4,
            duration = 0.12,
        },
        barrel = {
            width = 0.5,
            height = 0.12,
            pivotOffset = 0.1,
        },
    },

    -- Concept 2: Azure Geode (Crystal)
    azure_geode = {
        name = "Azure Geode",
        style = "crystal",
        colors = {
            core = {0.02, 0.04, 0.12},           -- Deep void blue
            mid = {0.08, 0.15, 0.35},            -- Dark sapphire
            edgeGlow = {0.4, 0.85, 1.0},         -- Bright cyan
            sparkle = {0.95, 1.0, 1.0},          -- White-cyan flash
            accent = {0.2, 0.5, 0.8},            -- Mid blue accent
            facet = {0.5, 0.7, 0.95},            -- Facet highlight
        },
        idle = {
            innerPulseSpeed = 1.8,              -- Inner glow pulse rate
            facetShimmerSpeed = 3.0,            -- Facet shimmer rate
            facetPhaseOffset = 0.4,             -- Phase offset between facets
        },
        recoil = {
            distance = 2,
            duration = 0.08,
        },
        barrel = {
            width = 0.45,
            height = 0.1,
            pivotOffset = 0.08,
        },
    },

    -- Concept 3: Amber Hive (Organic)
    amber_hive = {
        name = "Amber Hive",
        style = "organic",
        colors = {
            core = {0.12, 0.06, 0.02},           -- Dark amber-brown
            mid = {0.35, 0.20, 0.08},            -- Mid amber
            edgeGlow = {1.0, 0.75, 0.25},        -- Golden honey edge
            sparkle = {1.0, 0.95, 0.7},          -- Warm white flash
            accent = {0.7, 0.45, 0.15},          -- Honey accent
            membrane = {0.8, 0.55, 0.2},         -- Membrane color
        },
        idle = {
            breathSpeed = 1.2,                  -- Breathing rate
            breathAmount = 0.02,                -- 2% size pulse
            cellActivitySpeed = 4.0,            -- Internal cell activity rate
        },
        recoil = {
            distance = 3,
            duration = 0.15,
        },
        barrel = {
            width = 0.4,
            height = 0.14,
            pivotOffset = 0.06,
        },
    },

    -- Concept 4: Void Prism (Integrated)
    void_prism = {
        name = "Void Prism",
        style = "integrated",
        colors = {
            core = {0.03, 0.01, 0.06},           -- Void black-purple
            mid = {0.12, 0.05, 0.18},            -- Dark purple
            edgeGlow = {0.75, 0.4, 1.0},         -- Bright violet
            sparkle = {0.95, 0.85, 1.0},         -- Purple-white flash
            accent = {0.5, 0.25, 0.7},           -- Mid violet
            void = {0.0, 0.0, 0.02},             -- Impossible depth void
        },
        idle = {
            scanSpeed = 0.25,                   -- 4s full rotation (1/4 rev/s)
            flickerSpeed = 8.0,                 -- Dimensional flicker rate
            flickerChance = 0.02,               -- Chance of flicker per frame
        },
        recoil = {
            distance = 1,
            duration = 0.06,
        },
        barrel = {
            width = 0.42,
            height = 0.08,
            pivotOffset = 0.05,
        },
    },
}

Config.SHOWCASE = {
    turretSpacing = 180,
    backgroundColor = {0.04, 0.03, 0.06},
    targetSpeed = 80,                           -- Target movement speed for rotation demo
    fireInterval = 1.2,                         -- Seconds between shots in shooting state
}

-- =============================================================================
-- LIGHTING
-- =============================================================================

Config.LIGHTING = {
    -- PERFORMANCE: Lighting quality setting
    -- "high" = 5 circles per light (original), "medium" = 3 circles, "low" = 2 circles
    quality = "medium",

    -- PERFORMANCE: Frame throttling - update lighting every N frames
    -- 1 = every frame (60 FPS lighting), 2 = every other frame (30 FPS lighting)
    updateEveryNFrames = 2,

    -- Ambient light (base brightness before lights are added)
    ambient = {0.55, 0.50, 0.60},  -- Brighter ambient (was 0.45, 0.40, 0.50)

    -- Light radii (pixels) - larger for diffuse feel
    radii = {
        tower = {
            void_orb = 130,
            void_ring = 150,
            void_bolt = 140,
            void_eye = 200,
            void_star = 170,
        },
        creep = 100,          -- Larger creep glow (was 70)
        projectile = 60,
        void = 700,           -- HUGE void light radius
    },

    -- Light colors (saturated for visibility, element-themed)
    colors = {
        tower = {
            void_orb = {0.5, 0.95, 0.4},    -- Poison (green)
            void_ring = {0.5, 0.85, 1.0},   -- Ice (cyan)
            void_bolt = {0.4, 0.7, 1.0},    -- Electric (blue)
            void_eye = {0.75, 0.45, 0.95},  -- Shadow (purple)
            void_star = {1.0, 0.65, 0.3},   -- Fire (orange)
        },
        creep = {0.9, 0.45, 1.0},   -- Even brighter purple
        projectile = {
            void_orb = {0.6, 1.0, 0.5},     -- Poison (green)
            void_ring = {0.6, 0.9, 1.0},    -- Ice (cyan)
            void_bolt = {0.5, 0.75, 1.0},   -- Electric (blue)
            void_eye = {0.85, 0.60, 1.0},   -- Shadow (purple)
            void_star = {1.0, 0.75, 0.4},   -- Fire (orange)
        },
        -- Void light colors indexed by anger level - BRIGHT and saturated
        void = {
            [0] = {0.8, 0.4, 1.0},    -- Bright purple (calm)
            [1] = {1.0, 0.4, 0.9},    -- Bright magenta (annoyed)
            [2] = {1.0, 0.3, 0.6},    -- Bright red-purple (angry)
            [3] = {1.0, 0.2, 0.3},    -- Bright red (furious)
        },
    },

    -- Intensities - creeps much brighter
    intensities = {
        tower = {
            void_orb = 1.0,
            void_ring = 1.1,
            void_bolt = 1.2,
            void_eye = 1.0,
            void_star = 1.3,
        },
        creep = 2.5,          -- Much more intense creep glow (was 1.5)
        projectile = 1.3,
        void = {
            min = 2.0,        -- STRONG minimum pulsing intensity
            max = 3.5,        -- STRONG maximum pulsing intensity
        },
    },

    -- Self-illumination boost (multiplier for sprite brightness when lighting is on)
    selfIllumination = {
        creep = 1.35,         -- Boost creep brightness
        void = 1.4,           -- Boost void brightness
    },
}

return Config
