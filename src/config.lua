-- src/config.lua
-- All game constants and tuning values
--
-- RULE: No magic numbers in code. Everything goes here.

local Config = {}

-- =============================================================================
-- SCREEN
-- =============================================================================

Config.SCREEN_WIDTH = 1280
Config.SCREEN_HEIGHT = 720
Config.PLAY_AREA_RATIO = 0.35  -- Left 35% is play area
Config.PANEL_RATIO = 0.65      -- Right 65% is UI panel

-- =============================================================================
-- GRID
-- =============================================================================

Config.CELL_SIZE = 40
Config.SPAWN_ROWS = 2          -- Top rows are spawn zone
Config.BASE_ROWS = 1           -- Bottom row is base zone

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
    wall = {
        name = "Wall",
        cost = 1,
        damage = 0,
        fireRate = 0,
        range = 0,
        projectileSpeed = 0,
        color = {0.5, 0.5, 0.5},
        description = "Blocks paths. Cannot attack.",
    },
    basic = {
        name = "Turret",
        cost = 100,
        damage = 10,
        fireRate = 1.0,       -- shots per second
        range = 120,          -- pixels
        projectileSpeed = 400,
        color = {0.0, 1.0, 0.0},
        description = "Balanced damage dealer.",
    },
    rapid = {
        name = "Rapid",
        cost = 150,
        damage = 4,
        fireRate = 4.0,
        range = 80,
        projectileSpeed = 500,
        color = {0.0, 1.0, 1.0},
        description = "Fast fire, low damage.",
    },
    sniper = {
        name = "Sniper",
        cost = 200,
        damage = 40,
        fireRate = 0.5,
        range = 200,
        projectileSpeed = 800,
        color = {1.0, 1.0, 0.0},
        description = "High damage, slow fire.",
    },
    cannon = {
        name = "Cannon",
        cost = 250,
        damage = 15,
        fireRate = 0.8,
        range = 100,
        splashRadius = 50,
        projectileSpeed = 300,
        color = {1.0, 0.5, 0.0},
        description = "Area damage.",
    },
}

-- Tower visual settings
Config.TOWER_SIZE = 16         -- Base radius
Config.TOWER_BARREL_LENGTH = 1.2  -- Multiplier of size

-- =============================================================================
-- CREEPS (ENEMIES)
-- =============================================================================

Config.CREEPS = {
    triangle = {
        name = "Triangle",
        sides = 3,
        hp = 30,
        speed = 60,           -- pixels per second
        reward = 5,           -- gold on kill
        income = 5,           -- income per tick when sent
        sendCost = 50,        -- cost to send
        size = 12,
        color = {1.0, 0.3, 0.3},
    },
    square = {
        name = "Square",
        sides = 4,
        hp = 60,
        speed = 50,
        reward = 10,
        income = 15,
        sendCost = 150,
        size = 14,
        color = {0.3, 0.8, 1.0},
    },
    pentagon = {
        name = "Pentagon",
        sides = 5,
        hp = 120,
        speed = 40,
        reward = 20,
        income = 40,
        sendCost = 400,
        size = 16,
        color = {1.0, 1.0, 0.3},
    },
    hexagon = {
        name = "Hexagon",
        sides = 6,
        hp = 250,
        speed = 30,
        reward = 50,
        income = 100,
        sendCost = 1000,
        size = 20,
        color = {1.0, 0.5, 0.0},
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
    [0] = { triangle = 3 },
    [1] = { triangle = 4, square = 1 },
    [2] = { triangle = 5, square = 2, pentagon = 1 },
    [3] = { triangle = 6, square = 3, pentagon = 2, hexagon = 1 },
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

Config.PROJECTILE_SIZE = 4
Config.DAMAGE_NUMBER_SPEED = 40   -- Rise speed
Config.DAMAGE_NUMBER_DURATION = 0.6
Config.CREEP_ROTATION_SPEED = 0.5  -- Rotation speed for visual effect

-- =============================================================================
-- PRESTIGE (Phase 2)
-- =============================================================================

Config.PRESTIGE_UNLOCK_WAVE = 25
Config.ESSENCE_PER_WAVE = 10
Config.ESSENCE_PER_1000_GOLD = 1
Config.ESSENCE_PER_SEND = 2

-- =============================================================================
-- COLORS
-- =============================================================================

Config.COLORS = {
    background = {0.02, 0.02, 0.04},
    grid = {0.0, 0.25, 0.0, 0.5},
    spawnZone = {0.15, 0.02, 0.02},
    baseZone = {0.02, 0.15, 0.02},
    panel = {0.05, 0.05, 0.08},
    panelBorder = {0, 0.5, 0},
    towerBase = {0.15, 0.15, 0.2},
    gold = {1.0, 0.9, 0.2},
    income = {0.3, 0.8, 0.3},
    lives = {1.0, 0.3, 0.3},
    textPrimary = {1.0, 1.0, 1.0},
    textSecondary = {0.6, 0.6, 0.6},
    textDisabled = {0.4, 0.4, 0.4},
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
    padding = 15,
    buttonHeight = 70,
    buttonSpacing = 10,
    hudHeight = 60,
    panel = {
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
}

-- =============================================================================
-- UPGRADES
-- =============================================================================

Config.UPGRADES = {
    maxLevel = 5,
    baseCost = {
        range = 50,
        fireRate = 75,
        damage = 100,
    },
    costMultiplier = 1.5,  -- Each level costs 1.5x previous
    bonusPerLevel = {
        range = 0.15,      -- +15% per level
        fireRate = 0.20,   -- +20% per level
        damage = 0.25,     -- +25% per level
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

Config.COLORS.upgrade = {
    range = {0.3, 0.8, 1.0},
    fireRate = {1.0, 0.8, 0.2},
    damage = {1.0, 0.4, 0.4},
    tooltip = {0.1, 0.1, 0.15, 0.95},
    tooltipBorder = {0.3, 0.8, 0.3},
    selected = {0.0, 1.0, 0.0, 0.4},
}

Config.UI.tooltip = {
    width = 180,
    padding = 10,
    buttonHeight = 35,
    buttonSpacing = 5,
    offsetX = 20,
    offsetY = -10,
}

Config.UI.rangePreview = {
    fillAlpha = 0.1,
    strokeAlpha = 0.4,
    strokeWidth = 2,
}

-- =============================================================================
-- GAME SPEED
-- =============================================================================

Config.GAME_SPEEDS = {1, 5, 0}              -- x1, x5, paused
Config.GAME_SPEED_LABELS = {"x1", "x5", "||"}  -- Display labels

return Config
