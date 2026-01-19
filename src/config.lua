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
Config.PLAY_AREA_RATIO = 0.70  -- Left 70% is play area
Config.PANEL_RATIO = 0.30      -- Right 30% is UI panel

-- =============================================================================
-- GRID
-- =============================================================================

Config.CELL_SIZE = 40
Config.SPAWN_ROWS = 2          -- Top rows are spawn zone
Config.BASE_ROWS = 1           -- Bottom row is base zone

-- =============================================================================
-- ECONOMY
-- =============================================================================

Config.STARTING_GOLD = 200
Config.STARTING_LIVES = 20
Config.BASE_INCOME = 10
Config.INCOME_TICK_SECONDS = 30
Config.MAX_OFFLINE_HOURS = 4

-- =============================================================================
-- TOWERS
-- =============================================================================

Config.TOWERS = {
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

Config.WAVE_DURATION = 20      -- Seconds between waves
Config.WAVE_BASE_ENEMIES = 3   -- Starting enemies per wave
Config.WAVE_SCALING = 1        -- Additional enemies per wave

-- Wave composition based on sent enemies
Config.WAVE_SEND_RATIOS = {
    triangle = 2,   -- 1 extra per 2 sent
    square = 3,     -- 1 extra per 3 sent
    pentagon = 4,   -- 1 extra per 4 sent
    hexagon = 5,    -- 1 extra per 5 sent
}

-- =============================================================================
-- COMBAT
-- =============================================================================

Config.PROJECTILE_SIZE = 4
Config.DAMAGE_NUMBER_SPEED = 40   -- Rise speed
Config.DAMAGE_NUMBER_DURATION = 0.6

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
    gold = {1.0, 0.9, 0.2},
    income = {0.3, 0.8, 0.3},
    lives = {1.0, 0.3, 0.3},
    textPrimary = {1.0, 1.0, 1.0},
    textSecondary = {0.6, 0.6, 0.6},
    textDisabled = {0.4, 0.4, 0.4},
}

-- =============================================================================
-- UI
-- =============================================================================

Config.UI = {
    padding = 15,
    buttonHeight = 70,
    buttonSpacing = 10,
    hudHeight = 60,
}

return Config
