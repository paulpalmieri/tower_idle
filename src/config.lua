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
-- SCREEN (Fixed 16:9 canvas with letterboxing)
-- =============================================================================

Config.CANVAS_WIDTH = 1280       -- Fixed canvas width (16:9 ratio)
Config.CANVAS_HEIGHT = 720       -- Fixed canvas height (16:9 ratio)
Config.PANEL_WIDTH = 320         -- Narrower overlay panel width
Config.PANEL_ALPHA = 0.92        -- Semi-transparent panel background

-- Legacy aliases (for backwards compatibility)
Config.SCREEN_WIDTH = Config.CANVAS_WIDTH
Config.SCREEN_HEIGHT = Config.CANVAS_HEIGHT
Config.PLAY_AREA_RATIO = 0.75    -- Legacy: play area ratio (unused with fixed canvas)
Config.PANEL_RATIO = 0.25        -- Legacy: panel ratio (unused with fixed canvas)

-- =============================================================================
-- WORLD (Scrollable play area - larger than screen)
-- At zoom 0.5, visible area is 2560x1440, so world must be at least that size
-- =============================================================================

Config.WORLD_WIDTH = 2800     -- Total scrollable world width (fits zoom 0.5 + margin)
Config.WORLD_HEIGHT = 1800    -- Total scrollable world height (fits grid + void/exit zones + margin)

-- =============================================================================
-- CAMERA (drag-to-pan with zoom)
-- =============================================================================

Config.CAMERA = {
    -- Zoom settings
    minZoom = 0.5,            -- Zoomed out (see more) - at this zoom, most of world visible
    maxZoom = 1.5,            -- Zoomed in (see less)
    defaultZoom = 1.0,        -- Starting zoom level (1280x720 viewport)
    zoomSpeed = 0.1,          -- Mouse wheel sensitivity
    zoomSmoothing = 8.0,      -- Smooth zoom interpolation speed
}

-- =============================================================================
-- GRID
-- =============================================================================

Config.CELL_SIZE = 64          -- Must be multiple of 16 for clean sprite scaling (64/16 = 4x)
Config.GRID_COLS = 11          -- Odd number for true center column (center = column 6)
Config.GRID_ROWS = 15          -- Odd number for true center row (center = row 8)
Config.SPAWN_ROWS = 2          -- Top rows are spawn zone (walkable but not buildable)
Config.BASE_ROWS = 2           -- Bottom rows are base zone (walkable but not buildable)
Config.VOID_HEIGHT = 2         -- Void portal zone height in cell units (above grid)
Config.VOID_BUFFER = 1.0       -- Buffer between void portal and grid top (in cell units)
Config.EXIT_BUFFER = 1.0       -- Buffer between grid bottom and exit portal (in cell units)

-- =============================================================================
-- ECONOMY
-- =============================================================================

Config.STARTING_GOLD = 10000
Config.STARTING_LIVES = 20
Config.STARTING_VOID_SHARDS = 0
Config.STARTING_VOID_CRYSTALS = 0
Config.MAX_OFFLINE_HOURS = 4

-- =============================================================================
-- TOWERS
-- =============================================================================

-- Tower UI order (single source of truth for HUD, skill tree, hotkeys)
Config.TOWER_UI_ORDER = {"void_orb", "void_ring", "void_bolt", "void_eye", "void_star"}
Config.TOWER_HOTKEYS = {"1", "2", "3", "4", "5"}

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

-- Tower visual settings (scaled relative to cell size)
Config.TOWER_SIZE = Config.CELL_SIZE / 4        -- Base radius (1/4 of cell)
Config.TOWER_BARREL_LENGTH = 1.2  -- Multiplier of size

-- Tower building animation
Config.TOWER_BUILD = {
    duration = 5.0,           -- Total build time in seconds
    basePhaseDuration = 0.8,  -- Time before void entity starts appearing
}

-- Tower shadow (grounding effect)
Config.TOWER_SHADOW = {
    enabled = false,          -- Disabled in favor of dithering
    yRatio = 0.9,
    radiusMultiplier = 1.1,
    offsetY = 8,
    alpha = 0.35,
    color = {0.02, 0.01, 0.03},
}

-- Tower dithering (pixel-art grounding effect at tower base)
-- Values scaled relative to cell size for easy grid resizing
Config.TOWER_DITHER = {
    enabled = true,
    pixelSize = Config.CELL_SIZE / 16,    -- Scales with cell (64->4, 32->2)
    yRatio = 0.5,                          -- Flattened oval for perspective
    radius = Config.CELL_SIZE * 0.5625,    -- Extends slightly beyond tower base
    offsetY = Config.CELL_SIZE * 0.1875,   -- Centered beneath tower base
    alpha = 0.5,                           -- More subtle
    -- Dark void corruption stain
    coreColor = {0.02, 0.01, 0.04},  -- Deep desaturated indigo (almost black)
    coreRadius = 0.5,                -- Core extends to 50% of radius
    towerColorBlend = 0,             -- No tower color, pure void
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
        sendCost = 100,       -- cost to send
        size = 14,
        color = {0.5, 0.2, 0.7},
    },
    voidSpider = {
        name = "Void Spider",
        hp = 25,              -- Fragile (lower than voidSpawn)
        speed = 70,           -- Fast (higher than voidSpawn)
        reward = 4,           -- Lower reward
        sendCost = 60,        -- Cheaper to send
        size = 12,            -- Slightly smaller body
        color = {0.6, 0.2, 0.8},
    },
    voidBoss = {
        name = "Void Colossus",
        hp = 500,
        speed = 30,
        reward = 100,
        sendCost = 0,         -- Bosses can't be sent
        size = 28,
        color = {0.7, 0.1, 0.9},
        isBoss = true,
    },
    redBoss = {
        name = "Crimson Void",
        hp = 600,
        speed = 35,
        reward = 150,
        sendCost = 0,
        size = 30,
        color = {0.9, 0.15, 0.1},
        isBoss = true,
        isRedBoss = true,
    },
}

-- Creep path wobble (pixels of random offset when following flow field)
Config.CREEP_WOBBLE_SCALE = 10

-- Rendering perspective (isometric-style Y compression for shadows)
Config.PERSPECTIVE_Y_SCALE = 0.9

-- Visual configuration for void spawn rendering (pixel art style)
Config.VOID_SPAWN = {
    pixelSize = 3,            -- Size of each "pixel" in the sprite
    coreSize = 5,             -- Pitch black center region size (in pixels)
    distortionAmount = 0.25,
    distortionFrequency = 2.0,
    distortionSpeed = 1.5,
    octaves = 3,
    seed = 0,
    swirlSpeed = 0.8,         -- Slower, more ominous (matching portals)
    glowWidth = 0.3,
    pulseSpeed = 2.0,         -- Matching portals
    pulseAmount = 0.15,
    -- Edge wobble animation
    wobbleSpeed = 2.5,        -- Matching portals
    wobbleFrequency = 3.0,    -- Angular frequency (more = more bumps)
    wobbleAmount = 1.2,       -- Matching portals
    wobbleFalloff = 0.4,      -- Inner radius where wobble starts (0-1)
    sparkleThreshold = 0.96,  -- Rare sparkles (matching portals)
    colors = {
        core = {0.01, 0.005, 0.02},      -- Near-black void (matching portals)
        mid = {0.06, 0.03, 0.10},        -- Dark purple interior (matching portals)
        edgeGlow = {0.85, 0.50, 1.0},    -- Bright pink-purple edge
        sparkle = {0.9, 0.8, 1.0},       -- Subtle sparkles (matching portals)
    },
}

-- Visual configuration for void spider rendering (pixel art style)
-- Elongated rift body with floating shard legs:  / | \
--                                                / | \
Config.VOID_SPIDER = {
    pixelSize = 3,              -- Match standard creep pixel size
    coreSize = 4,               -- Pitch black center region size (in pixels)
    distortionFrequency = 2.0,
    octaves = 3,
    wobbleSpeed = 2.5,          -- Matching portals
    wobbleFrequency = 3.0,
    wobbleAmount = 0.4,
    wobbleFalloff = 0.4,
    swirlSpeed = 0.8,           -- Matching portals
    pulseSpeed = 2.0,           -- Matching portals
    sparkleThreshold = 0.96,    -- Rare sparkles (matching portals)
    -- Base leg settings (medium legs - fixed)
    legs = {
        length = 1.5,           -- Medium length
        width = 0.6,            -- Medium width
        bobAmount = 2,          -- Vertical bob in pixels
        bobSpeed = 3,           -- Slow bob
        gap = 1.4,              -- Gap from body center
        angle = 0.2,            -- Slight outward angle (~11 degrees)
    },
    -- Colors (pitch black matching portals)
    colors = {
        core = {0.01, 0.005, 0.02},      -- Near-black void
        mid = {0.06, 0.03, 0.10},        -- Dark purple interior
        edgeGlow = {0.85, 0.50, 1.0},    -- Bright pink-purple edge
        sparkle = {0.9, 0.8, 1.0},       -- Subtle sparkles
    },
    -- Body shape (gash variant - wider elongated rift)
    body = {
        width = 0.6,
        height = 1.6,
    },
}

-- Visual configuration for void boss rendering (larger, more imposing)
Config.VOID_BOSS = {
    pixelSize = 4,
    coreSize = 10,
    distortionFrequency = 1.5,
    octaves = 4,
    wobbleSpeed = 1.5,
    wobbleFrequency = 2.0,
    wobbleAmount = 1.5,
    wobbleFalloff = 0.3,
    swirlSpeed = 0.5,
    pulseSpeed = 1.5,
    sparkleThreshold = 0.94,
    colors = {
        core = {0.005, 0.002, 0.01},
        mid = {0.04, 0.02, 0.08},
        edgeGlow = {0.95, 0.40, 1.0},
        sparkle = {1.0, 0.9, 1.0},
    },
}

-- Visual configuration for red boss rendering (crimson void terror)
Config.RED_BOSS = {
    pixelSize = 4,
    coreSize = 10,
    distortionFrequency = 1.5,
    octaves = 4,
    wobbleSpeed = 1.8,
    wobbleFrequency = 2.0,
    wobbleAmount = 1.3,
    wobbleFalloff = 0.3,
    swirlSpeed = 0.6,
    pulseSpeed = 2.0,
    sparkleThreshold = 0.92,
    colors = {
        core = {0.15, 0.02, 0.02},
        mid = {0.35, 0.06, 0.06},
        edgeGlow = {1.0, 0.25, 0.15},
        sparkle = {1.0, 0.9, 0.7},
    },
}

-- Visual configuration for the Void Portal (circular, creep-style rendering)
Config.VOID_PORTAL = {
    baseSize = 84,              -- 3x creep size doubled (42 * 2)
    maxSize = 240,              -- Maximum growth doubled (120 * 2)
    topPadding = 40,            -- Padding from top of spawn area doubled (20 * 2)
    pixelSize = 3,              -- Same as exit portal
    coreSize = 12,              -- Dark squared center size (in pixels)
    distortionFrequency = 2.0,  -- Same as exit portal
    octaves = 3,                -- Same as exit portal
    wobbleSpeed = 2.5,          -- Same as exit portal
    wobbleFrequency = 3.0,      -- Same as exit portal
    wobbleAmount = 1.2,         -- Same as exit portal
    wobbleFalloff = 0.4,        -- Same as exit portal
    swirlSpeed = 0.8,           -- Same as exit portal
    pulseSpeed = 2.0,           -- Same as exit portal
    sparkleThreshold = 0.96,    -- Same as exit portal (rare sparkles)
    colors = {                  -- Dark void colors (matching exit portal)
        core = {0.01, 0.005, 0.02},      -- Near-black void
        mid = {0.06, 0.03, 0.10},        -- Dark purple interior
        edgeGlow = {0.85, 0.50, 1.0},    -- Bright pink-purple edge
        sparkle = {0.9, 0.8, 1.0},       -- Subtle sparkles
    },
    -- Shadow ellipse settings
    shadow = {
        offsetY = 10,           -- Offset below portal bottom edge
        width = 0.9,            -- Shadow width as multiplier of radius (0.9 perspective)
        height = 0.25,          -- Shadow height (flattened horizontal ellipse)
        alpha = 0.4,            -- Shadow opacity
        color = {0, 0, 0},      -- Shadow color (black)
    },
    -- Outward spewing particles
    spewParticles = {
        count = 25,                       -- Active particles
        coreRadius = 0.3,                 -- Spawn from inner 30% of portal
        maxRadius = 1.8,                  -- Despawn at 1.8x portal radius
        speed = 35,                       -- Outward movement speed
        size = 3,                         -- Match pixel size
        color = {0.75, 0.45, 0.95},       -- Light purple (matching edge glow)
    },
    -- Bloom/glow settings (reduced compared to player portal)
    bloom = {
        intensity = 0.6,                  -- Lower bloom intensity
        radiusMult = 0.7,                 -- Smaller glow radius
    },
}

-- =============================================================================
-- WAVES
-- =============================================================================

Config.WAVE_DURATION = 5       -- Seconds between waves
Config.WAVE_BASE_ENEMIES = 4   -- Starting enemies at wave 1
Config.WAVE_SCALING = 0.5      -- Additional enemies per wave (so wave 20 has ~14 enemies)
Config.WAVE_SPAWN_INTERVAL = 0.5  -- Time between spawning each creep
Config.WAVE_HEALTH_SCALING = 0.03  -- HP increase per wave (3% more HP each wave)

-- Wave progression (level structure)
Config.WAVE_PROGRESSION = {
    totalWaves = 20,
    bossWaves = {10, 20},
}

-- Note: Wave composition (enemy count) scales with wave number only.
-- Anger/tier only boosts enemy stats (HP/speed), not wave size.

-- =============================================================================
-- VOID
-- =============================================================================

Config.VOID = {
    maxClicks = 100,
    baseIncomePerClick = 5,
    angerThresholds = {25, 50, 75, 100},  -- Click counts for tiers 1-4
    tierHpBonus = 0.10,      -- +10% HP per tier
    tierSpeedBonus = 0.10,   -- +10% speed per tier
    baseRadius = 60,
    yOffset = 30,
    clickFlashDuration = 0.15,
    thresholdPulse = {
        duration = 0.5,
        scaleAmount = 0.15,
        speed = 8,
    },
}

-- Void Shards (meta-currency earned from killing enemies)
Config.VOID_SHARDS = {
    levelReward = 10,   -- Shards earned for completing a level
    bossBonus = 5,      -- Bonus shards for killing a boss
    dropChance = 0.10,  -- 10% chance to drop a shard on any kill
    dropAmount = 1,     -- Amount of shards dropped
}

-- Void Crystals (rare currency from boss kills for keystones)
Config.VOID_CRYSTALS = {
    -- Boss wave -> crystal reward
    bossRewards = {
        [10] = 1,   -- Wave 10 boss gives 1 crystal
        [20] = 2,   -- Wave 20 boss gives 2 crystals
    },
}

-- =============================================================================
-- SKILL TREE
-- =============================================================================

Config.SKILL_TREE = {
    -- Full screen layout (centered on play area, not panel)
    centerX = 640,  -- Screen center X
    centerY = 460,  -- Screen center Y

    -- Tower circle (5 towers arranged in circle at center)
    towerCircleRadius = 145,  -- Was 90 (+55)

    -- Background (Voronoi ground texture, same style as game)
    background = {
        worldRadius = 1400,          -- World units from center (must be >= 1280 for minZoom 0.5)
        pixelSize = 4,
        perspectiveYRatio = 0.9,     -- Less squash than game (0.5) - tilted ground look
        cellSize = 9,
        fissureThreshold = 0.16,
        mossIntensity = 1.2,
        -- Reuse game background colors (set in init after Config.BACKGROUND is defined)
    },

    -- Camera bounds
    -- Note: maxPanX/Y are computed dynamically in skill_tree.lua from worldRadius
    cameraBounds = {
        minZoom = 0.5,               -- Minimum zoom (zoomed out) - matches main game
        maxZoom = 1.5,               -- Maximum zoom (zoomed in) - matches main game
        zoomSpeed = 0.1,             -- How much zoom changes per wheel tick - matches main game
        zoomSmoothing = 10.0,        -- Interpolation speed for smooth zoom
    },

    -- Paths (simple pixelated lines with shy glow)
    carvedPaths = {
        colors = {
            dormant = {0.04, 0.03, 0.05},     -- Very dim, blends with ground
            active = {0.5, 0.3, 0.7},         -- Soft purple glow
        },
        glowPulseSpeed = 1.5,
    },

    -- Node tiers (distance from center, accounting for tower circle)
    tierRadius = {
        [0] = 0,
        [1] = 280,   -- First tier of nodes (tower circle at 145, gap of 135)
        [2] = 380,   -- Second tier
        [3] = 480,   -- Third tier
        [4] = 580,   -- Fourth tier
        [5] = 680,   -- Keystones
    },
    nodeSize = 24,
    keystoneSize = 32,

    -- Cross-branch connections (nodes between branches forming a ring)
    crossBranch = {
        radius = 430,   -- Between tier 2 (380) and tier 3 (480)
        nodeSize = 20,  -- Slightly smaller than regular nodes
        -- Angles halfway between adjacent branches
        -- Each connects two adjacent tower types
        connections = {
            { id = "cross_bolt_orb", branches = {"void_bolt", "void_orb"} },
            { id = "cross_orb_ring", branches = {"void_orb", "void_ring"} },
            { id = "cross_ring_eye", branches = {"void_ring", "void_eye"} },
            { id = "cross_eye_star", branches = {"void_eye", "void_star"} },
            { id = "cross_star_bolt", branches = {"void_star", "void_bolt"} },
        },
        cost = 15,  -- Shards cost for cross-branch nodes
    },

    -- Branch angles (radians, starting from top, 72° apart)
    branchAngles = {
        void_bolt = -math.pi / 2,                    -- Top (lightning)
        void_orb = -math.pi / 2 + math.pi * 2 / 5,   -- Upper right (poison)
        void_ring = -math.pi / 2 + math.pi * 4 / 5,  -- Lower right (control)
        void_eye = -math.pi / 2 + math.pi * 6 / 5,   -- Lower left (gravity)
        void_star = -math.pi / 2 + math.pi * 8 / 5,  -- Upper left (fire)
    },

    -- Tower type to variant index mapping (for TurretConcepts rendering)
    towerVariants = {
        void_orb = 1,
        void_ring = 2,
        void_bolt = 3,
        void_eye = 4,
        void_star = 5,
    },

    -- Costs (in shards for regular nodes, crystals for keystones)
    nodeCosts = {
        [1] = 5,    -- Tier 1 cost
        [2] = 10,   -- Tier 2 cost
        [3] = 20,   -- Tier 3 cost
        [4] = 35,   -- Tier 4 cost
        keystone = 1,  -- crystals
    },

    -- Colors
    colors = {
        locked = {0.3, 0.3, 0.3},
        available = {0.5, 0.4, 0.6},
        allocated = {0.8, 0.6, 1.0},
        keystone = {0.4, 0.85, 1.0},
        keystoneAllocated = {0.2, 0.95, 0.8},
        connection = {0.4, 0.3, 0.5, 0.5},
        connectionActive = {0.7, 0.5, 0.9, 0.8},
    },

    -- UI (full scene mode)
    startButtonY = 850,
    startButtonWidth = 200,
    startButtonHeight = 50,

    -- Gravity dust effect (particles pulled toward center void)
    gravityDust = {
        particleCount = 80,          -- Number of active particles
        spawnRadius = {50, 90},      -- Min/max spawn distance from center
        pullStrength = 45,           -- Base gravity pull toward center
        pullAcceleration = 60,       -- Additional acceleration as particles get closer
        maxSpeed = 150,              -- Maximum particle velocity
        particleSize = {2, 4},       -- Min/max pixel size
        fadeStartRadius = 50,        -- Start fading when this close to center
        despawnRadius = 20,          -- Respawn when this close to center
        -- Colors (void-themed purples and teals, subtle)
        colors = {
            {0.5, 0.3, 0.7, 0.5},    -- Deep purple
            {0.6, 0.4, 0.8, 0.4},    -- Mid purple
            {0.4, 0.5, 0.7, 0.35},   -- Muted blue-purple
            {0.3, 0.6, 0.7, 0.4},    -- Teal
            {0.7, 0.5, 0.9, 0.5},    -- Bright purple
        },
        trailLength = 2,             -- Number of trail segments
        trailFade = 0.5,             -- Trail opacity multiplier per segment
        wobbleAmount = 8,            -- Slight orbital wobble
        wobbleSpeed = 2.0,           -- Wobble animation speed
    },
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
    shardColor = {0.65, 0.45, 0.95},    -- Purple for void shards
    crystalColor = {0.4, 0.85, 1.0},    -- Cyan for void crystals
    lifeColor = {1.0, 0.3, 0.35},       -- Red for life loss

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

    -- Wave progress bar
    progressBar = {0.45, 0.30, 0.60},
    progressBarBg = {0.08, 0.06, 0.10},
    bossMarker = {0.95, 0.35, 0.25},
    voidShard = {0.65, 0.45, 0.95},
}

-- =============================================================================
-- MAIN MENU
-- =============================================================================

Config.MAIN_MENU = {
    -- Void bullets (small voids as bullet points for menu items)
    voidScale = 0.6,              -- Base scale for void bullet (small)
    voidSize = 40,                -- Hitbox/layout size for void bullet
    voidTextGap = 20,             -- Gap between void and text
    -- Menu items column
    columnY = 280,                -- Y position where menu column starts (centered vertically)
    itemSpacing = 80,             -- Spacing between menu items
    -- Hover effect
    hoverScale = 1.15,            -- Scale multiplier on hover (void + text)
    -- Colors
    backgroundColor = {0.02, 0.015, 0.03, 1.0},  -- Dark purple-black background
    textColor = {0.85, 0.75, 0.95, 1.0},         -- Purple-tinted text (matches void theme)
    textHoverColor = {1.0, 0.9, 0.7, 1.0},       -- Bright gold on hover
    hintColor = {0.4, 0.35, 0.5, 0.6},           -- Dim hint text at bottom
}

-- =============================================================================
-- SETTINGS MENU (full screen, same style as main menu)
-- =============================================================================

Config.SETTINGS_MENU = {
    -- Void bullets (small voids as bullet points for settings items)
    voidScale = 0.5,              -- Base scale for void bullet (smaller than main menu)
    voidSize = 30,                -- Hitbox/layout size for void bullet
    voidTextGap = 15,             -- Gap between void and text
    labelControlGap = 30,         -- Gap between label and control
    controlWidth = 160,           -- Width of control area (checkbox, dropdown, slider)
    -- Layout
    titleY = 60,                  -- Title Y position
    columnY = 140,                -- Y position where settings column starts
    itemSpacing = 50,             -- Spacing between settings items
    -- Control sizes
    checkboxSize = 24,            -- Checkbox size
    dropdownItemHeight = 28,      -- Height of each dropdown item
    -- Hover effect
    hoverScale = 1.1,             -- Scale multiplier on hover (slightly less than main menu)
    -- Colors (same as main menu)
    backgroundColor = {0.02, 0.015, 0.03, 1.0},  -- Dark purple-black background
    textColor = {0.85, 0.75, 0.95, 1.0},         -- Purple-tinted text
    textHoverColor = {1.0, 0.9, 0.7, 1.0},       -- Bright gold on hover
    textDisabledColor = {0.4, 0.35, 0.45, 0.6},  -- Dimmed text for disabled items
    hintColor = {0.4, 0.35, 0.5, 0.6},           -- Dim hint text at bottom
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
        statsHeight = 55,     -- Reduced: no void bar (gold, lives, wave, speed only)
        voidHeight = 0,       -- Merged into stats section
        sectionTitleHeight = 0,  -- No section headers
        borderDecorStart = 8,
        borderDecorSpacing = 24,
        progressHeight = 90,  -- Wave progress bar + anger meter section
    },
    -- Anger meter UI config
    angerMeter = {
        height = 16,
        thresholdMarkerWidth = 2,
        colors = {
            background = {0.08, 0.04, 0.10},
            fill = {0.8, 0.2, 0.5},
            fillTier2 = {0.9, 0.3, 0.4},
            fillTier3 = {1.0, 0.2, 0.2},
            fillTier4 = {1.0, 0.1, 0.1},
            thresholdMarker = {0.6, 0.3, 0.7},
            border = {0.4, 0.2, 0.5},
        },
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
        bloom = true,          -- Post-processing bloom effect
        vignette = false,      -- Edge darkening effect
        fogParticles = true,   -- Atmospheric fog wisps
        dustParticles = true,  -- Floating dust motes
    },
}

-- =============================================================================
-- GAME SPEED
-- =============================================================================

Config.GAME_SPEEDS = {1, 5, 50, 0}              -- x1, x5, x50, paused
Config.GAME_SPEED_LABELS = {"x1", "x5", "x50", "||"}  -- Display labels

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
        floatingNumber = 34,  -- 1.4x the previous medium (24)
    },
}

-- =============================================================================
-- BACKGROUND
-- =============================================================================

Config.BACKGROUND = {
    pixelSize = 4,
    perspectiveYRatio = 0.5,  -- Vertical compression for top-down perspective (1.0 = none)

    -- Corrupted Grove style - mossy plates with dark crevices
    cellSize = 9,
    fissureThreshold = 0.16,
    mossIntensity = 1.4,
    colors = {
        base = {0.06, 0.055, 0.07},
        plateVariation = 0.02,
        fissure = {0.025, 0.035, 0.025},
        moss = {0.04, 0.07, 0.03},
        mossLight = {0.06, 0.10, 0.045},
        glowFalloff = 0.12,
    },
}

-- =============================================================================
-- EXIT PORTAL (Red portal at base zone)
-- =============================================================================

Config.EXIT_PORTAL = {
    baseSize = 84,              -- Same size as Void doubled (42 * 2)
    bottomPadding = 140,        -- Padding from bottom doubled (70 * 2)
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
-- VOID CORE (Organic procedural black hole - player base)
-- =============================================================================

Config.VOID_CORE = {
    -- Pixel rendering (match existing style)
    pixelSize = 3,

    -- Size
    baseSize = 38,                    -- Organic boundary radius
    coreSize = 10,                    -- Dark squared center size (in pixels, not grid)

    -- Organic boundary animation (same as Void entity)
    distortionFrequency = 2.0,
    octaves = 3,
    wobbleSpeed = 2.5,                -- Slightly slower than void
    wobbleFrequency = 3.0,
    wobbleAmount = 1.2,               -- Less extreme than creeps
    wobbleFalloff = 0.4,
    swirlSpeed = 0.8,                 -- Slower, more ominous
    pulseSpeed = 2.0,

    -- Colors (dark void with purple edge)
    colors = {
        core = {0.01, 0.005, 0.02},       -- Near-black void
        mid = {0.06, 0.03, 0.10},         -- Dark purple interior
        edgeGlow = {0.6, 0.35, 0.85},     -- Purple edge glow
        sparkle = {0.9, 0.8, 1.0},        -- Subtle sparkles
    },
    sparkleThreshold = 0.96,              -- Rare sparkles

    -- Gravity particles (intense suction effect)
    particles = {
        count = 40,                       -- More particles for denser effect
        spawnRadius = 1.6,                -- Spawn further out for more visible trails
        pullSpeed = 65,                   -- Faster inward pull
        size = 3,                         -- Match pixel size
        color = {0.85, 0.65, 1.0},        -- Brighter purple-pink
    },

    -- Shadow
    shadow = {
        offsetY = 1.2,
        width = 1.3,
        height = 0.35,
        alpha = 0.3,
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
-- POST-PROCESSING & BLOOM
-- =============================================================================

Config.POST_PROCESSING = {
    enabled = true,

    bloom = {
        enabled = true,
        intensity = 0.4,      -- Overall bloom brightness (subtle)
        radius = 6,           -- Blur kernel size
        passes = 2,           -- Number of blur passes
    },

    -- Per-entity glow settings (intensity and radius multipliers)
    glow = {
        void = {
            intensity = 0.4,      -- Subtle void glow
            radius_mult = 1.0,
            pulse_speed = 2.0,
        },
        creep = {
            intensity = 0.25,     -- Subtle creep glow
            radius_mult = 0.8,
            pulse_speed = 3.0,
        },
        tower = {
            intensity = 0.2,      -- Subtle tower glow
            radius_mult = 0.6,
        },
        projectile = {
            intensity = 0.3,      -- Subtle projectile glow
            radius_mult = 0.8,
        },
        ground_effect = {
            intensity = 0.25,
            radius_mult = 0.8,
        },
    },

    -- Glow colors per tower type (element-themed, saturated)
    colors = {
        tower = {
            void_orb = {0.3, 1.0, 0.2},     -- Poison (bright green)
            void_ring = {0.3, 0.9, 1.0},    -- Ice (bright cyan)
            void_bolt = {0.2, 0.5, 1.0},    -- Electric (bright blue)
            void_eye = {0.8, 0.3, 1.0},     -- Shadow (bright purple)
            void_star = {1.0, 0.4, 0.1},    -- Fire (bright orange)
        },
        creep = {0.9, 0.2, 1.0},            -- Bright purple/magenta
        projectile = {
            void_orb = {0.4, 1.0, 0.3},     -- Poison (green)
            void_ring = {0.4, 1.0, 1.0},    -- Ice (cyan)
            void_bolt = {0.3, 0.6, 1.0},    -- Electric (blue)
            void_eye = {0.9, 0.4, 1.0},     -- Shadow (purple)
            void_star = {1.0, 0.5, 0.1},    -- Fire (orange)
        },
        -- Void portal colors indexed by anger level
        void = {
            [0] = {0.8, 0.2, 1.0},    -- Bright purple (calm)
            [1] = {1.0, 0.2, 0.9},    -- Bright magenta (annoyed)
            [2] = {1.0, 0.15, 0.5},   -- Bright red-purple (angry)
            [3] = {1.0, 0.1, 0.15},   -- Bright red (furious)
        },
    },

    -- Glow radii in pixels (larger = more visible bloom spread)
    radii = {
        tower = 150,
        creep = 100,
        projectile = 60,
        void = 300,
    },
}

return Config
