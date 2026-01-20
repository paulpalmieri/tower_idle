-- src/systems/skill_tree_data.lua
-- Skill tree node definitions and allocation state
-- Structure per branch: Tier1(1) -> Tier2(3) -> Tier3(3) -> Tier4(1) -> Tier5(keystone)

local Config = require("src.config")
local EventBus = require("src.core.event_bus")
local Economy = require("src.systems.economy")

local SkillTreeData = {}

-- =============================================================================
-- EFFECT TYPES
-- =============================================================================
SkillTreeData.EFFECT = {
    TOWER_STAT = "tower_stat",
    TOWER_FLAG = "tower_flag",
    GLOBAL_STAT = "global_stat",
}

SkillTreeData.OP = {
    ADD = "add",
    MULTIPLY = "multiply",
    SET = "set",
}

-- =============================================================================
-- NODE DEFINITIONS
-- =============================================================================
-- Structure: Tier1(1) -> Tier2(3) -> Tier3(3) -> Tier4(1) -> Tier5(keystone)

local NODES = {
    -- =========================================================================
    -- VOID BOLT (Chain Lightning) - Top branch
    -- =========================================================================
    -- Tier 1: Entry
    {
        id = "void_bolt_t1",
        name = "Conduction",
        description = "+15% damage",
        branch = "void_bolt",
        tier = 1,
        position = { side = "center" },
        cost = { shards = 5 },
        requires = {},
        effects = {
            { type = "tower_stat", tower = "void_bolt", stat = "damage", op = "multiply", value = 1.15 }
        },
    },
    -- Tier 2: Three choices
    {
        id = "void_bolt_t2_left",
        name = "Arc Jump",
        description = "+1 chain target",
        branch = "void_bolt",
        tier = 2,
        position = { side = "left" },
        cost = { shards = 10 },
        requires = { "void_bolt_t1" },
        effects = {
            { type = "tower_stat", tower = "void_bolt", stat = "chain_count", op = "add", value = 1 }
        },
    },
    {
        id = "void_bolt_t2_center",
        name = "Spark Reach",
        description = "+20% range",
        branch = "void_bolt",
        tier = 2,
        position = { side = "center" },
        cost = { shards = 10 },
        requires = { "void_bolt_t1" },
        effects = {
            { type = "tower_stat", tower = "void_bolt", stat = "range", op = "multiply", value = 1.20 }
        },
    },
    {
        id = "void_bolt_t2_right",
        name = "Overcharge",
        description = "+25% attack speed",
        branch = "void_bolt",
        tier = 2,
        position = { side = "right" },
        cost = { shards = 10 },
        requires = { "void_bolt_t1" },
        effects = {
            { type = "tower_stat", tower = "void_bolt", stat = "fireRate", op = "multiply", value = 1.25 }
        },
    },
    -- Tier 3: Three choices (each continues from its tier 2)
    {
        id = "void_bolt_t3_left",
        name = "Branching Path",
        description = "Bolts fork on hit",
        branch = "void_bolt",
        tier = 3,
        position = { side = "left" },
        cost = { shards = 20 },
        requires = { "void_bolt_t2_left" },
        effects = {
            { type = "tower_flag", tower = "void_bolt", flag = "fork_on_hit", value = true }
        },
    },
    {
        id = "void_bolt_t3_center",
        name = "Static Field",
        description = "+10% damage per chain",
        branch = "void_bolt",
        tier = 3,
        position = { side = "center" },
        cost = { shards = 20 },
        requires = { "void_bolt_t2_center" },
        effects = {
            { type = "tower_stat", tower = "void_bolt", stat = "chain_damage_bonus", op = "add", value = 0.10 }
        },
    },
    {
        id = "void_bolt_t3_right",
        name = "Surge",
        description = "+50% first hit damage",
        branch = "void_bolt",
        tier = 3,
        position = { side = "right" },
        cost = { shards = 20 },
        requires = { "void_bolt_t2_right" },
        effects = {
            { type = "tower_stat", tower = "void_bolt", stat = "first_hit_bonus", op = "add", value = 0.50 }
        },
    },
    -- Tier 4: Convergence (requires all tier 3)
    {
        id = "void_bolt_t4",
        name = "Lightning Rod",
        description = "+2 chain, +20% damage",
        branch = "void_bolt",
        tier = 4,
        position = { side = "center" },
        cost = { shards = 35 },
        requires = { "void_bolt_t3_left", "void_bolt_t3_center", "void_bolt_t3_right" },
        effects = {
            { type = "tower_stat", tower = "void_bolt", stat = "chain_count", op = "add", value = 2 },
            { type = "tower_stat", tower = "void_bolt", stat = "damage", op = "multiply", value = 1.20 }
        },
    },
    -- Tier 5: Keystone
    {
        id = "void_bolt_keystone",
        name = "Tesla Coil",
        description = "Infinite chain in range\n-30% base damage",
        branch = "void_bolt",
        tier = 5,
        position = { side = "center" },
        cost = { crystals = 1 },
        requires = { "void_bolt_t4" },
        effects = {
            { type = "tower_flag", tower = "void_bolt", flag = "infinite_chain", value = true },
            { type = "tower_stat", tower = "void_bolt", stat = "damage", op = "multiply", value = 0.70 }
        },
        isKeystone = true,
    },

    -- =========================================================================
    -- VOID ORB (Poison/DoT) - Upper right branch
    -- =========================================================================
    -- Tier 1
    {
        id = "void_orb_t1",
        name = "Potent Toxins",
        description = "+20% poison damage",
        branch = "void_orb",
        tier = 1,
        position = { side = "center" },
        cost = { shards = 5 },
        requires = {},
        effects = {
            { type = "tower_stat", tower = "void_orb", stat = "poison_damage", op = "multiply", value = 1.20 }
        },
    },
    -- Tier 2
    {
        id = "void_orb_t2_left",
        name = "Expanding Vapors",
        description = "+25% cloud radius",
        branch = "void_orb",
        tier = 2,
        position = { side = "left" },
        cost = { shards = 10 },
        requires = { "void_orb_t1" },
        effects = {
            { type = "tower_stat", tower = "void_orb", stat = "cloud_radius", op = "multiply", value = 1.25 }
        },
    },
    {
        id = "void_orb_t2_center",
        name = "Lingering Miasma",
        description = "+30% cloud duration",
        branch = "void_orb",
        tier = 2,
        position = { side = "center" },
        cost = { shards = 10 },
        requires = { "void_orb_t1" },
        effects = {
            { type = "tower_stat", tower = "void_orb", stat = "cloud_duration", op = "multiply", value = 1.30 }
        },
    },
    {
        id = "void_orb_t2_right",
        name = "Virulence",
        description = "Poison can stack 3x",
        branch = "void_orb",
        tier = 2,
        position = { side = "right" },
        cost = { shards = 10 },
        requires = { "void_orb_t1" },
        effects = {
            { type = "tower_stat", tower = "void_orb", stat = "poison_stacks", op = "set", value = 3 }
        },
    },
    -- Tier 3
    {
        id = "void_orb_t3_left",
        name = "Death Bloom",
        description = "Mini-clouds on death",
        branch = "void_orb",
        tier = 3,
        position = { side = "left" },
        cost = { shards = 20 },
        requires = { "void_orb_t2_left" },
        effects = {
            { type = "tower_flag", tower = "void_orb", flag = "death_cloud", value = true }
        },
    },
    {
        id = "void_orb_t3_center",
        name = "Festering Wounds",
        description = "+15% damage to poisoned",
        branch = "void_orb",
        tier = 3,
        position = { side = "center" },
        cost = { shards = 20 },
        requires = { "void_orb_t2_center" },
        effects = {
            { type = "tower_stat", tower = "void_orb", stat = "poisoned_damage_bonus", op = "add", value = 0.15 }
        },
    },
    {
        id = "void_orb_t3_right",
        name = "Pandemic",
        description = "Poison spreads on tick",
        branch = "void_orb",
        tier = 3,
        position = { side = "right" },
        cost = { shards = 20 },
        requires = { "void_orb_t2_right" },
        effects = {
            { type = "tower_flag", tower = "void_orb", flag = "poison_spread", value = true }
        },
    },
    -- Tier 4
    {
        id = "void_orb_t4",
        name = "Toxic Mastery",
        description = "+40% poison, +20% radius",
        branch = "void_orb",
        tier = 4,
        position = { side = "center" },
        cost = { shards = 35 },
        requires = { "void_orb_t3_left", "void_orb_t3_center", "void_orb_t3_right" },
        effects = {
            { type = "tower_stat", tower = "void_orb", stat = "poison_damage", op = "multiply", value = 1.40 },
            { type = "tower_stat", tower = "void_orb", stat = "cloud_radius", op = "multiply", value = 1.20 }
        },
    },
    -- Tier 5: Keystone
    {
        id = "void_orb_keystone",
        name = "Plague Bearer",
        description = "Poison never expires\nNo direct cloud damage",
        branch = "void_orb",
        tier = 5,
        position = { side = "center" },
        cost = { crystals = 1 },
        requires = { "void_orb_t4" },
        effects = {
            { type = "tower_flag", tower = "void_orb", flag = "eternal_poison", value = true },
            { type = "tower_stat", tower = "void_orb", stat = "cloud_damage", op = "multiply", value = 0 }
        },
        isKeystone = true,
    },

    -- =========================================================================
    -- VOID RING (Control/Slow) - Lower right branch
    -- =========================================================================
    -- Tier 1
    {
        id = "void_ring_t1",
        name = "Bitter Cold",
        description = "+15% slow strength",
        branch = "void_ring",
        tier = 1,
        position = { side = "center" },
        cost = { shards = 5 },
        requires = {},
        effects = {
            { type = "tower_stat", tower = "void_ring", stat = "slow_strength", op = "multiply", value = 1.15 }
        },
    },
    -- Tier 2
    {
        id = "void_ring_t2_left",
        name = "Permafrost",
        description = "+50% slow duration",
        branch = "void_ring",
        tier = 2,
        position = { side = "left" },
        cost = { shards = 10 },
        requires = { "void_ring_t1" },
        effects = {
            { type = "tower_stat", tower = "void_ring", stat = "slow_duration", op = "multiply", value = 1.50 }
        },
    },
    {
        id = "void_ring_t2_center",
        name = "Frost Reach",
        description = "+20% aura range",
        branch = "void_ring",
        tier = 2,
        position = { side = "center" },
        cost = { shards = 10 },
        requires = { "void_ring_t1" },
        effects = {
            { type = "tower_stat", tower = "void_ring", stat = "range", op = "multiply", value = 1.20 }
        },
    },
    {
        id = "void_ring_t2_right",
        name = "Frigid Pulse",
        description = "Deal damage every 2s",
        branch = "void_ring",
        tier = 2,
        position = { side = "right" },
        cost = { shards = 10 },
        requires = { "void_ring_t1" },
        effects = {
            { type = "tower_flag", tower = "void_ring", flag = "frigid_pulse", value = true }
        },
    },
    -- Tier 3
    {
        id = "void_ring_t3_left",
        name = "Deep Freeze",
        description = "Root at <30% speed",
        branch = "void_ring",
        tier = 3,
        position = { side = "left" },
        cost = { shards = 20 },
        requires = { "void_ring_t2_left" },
        effects = {
            { type = "tower_flag", tower = "void_ring", flag = "deep_freeze", value = true }
        },
    },
    {
        id = "void_ring_t3_center",
        name = "Shatter",
        description = "+25% damage to rooted",
        branch = "void_ring",
        tier = 3,
        position = { side = "center" },
        cost = { shards = 20 },
        requires = { "void_ring_t2_center" },
        effects = {
            { type = "tower_stat", tower = "void_ring", stat = "rooted_damage_bonus", op = "add", value = 0.25 }
        },
    },
    {
        id = "void_ring_t3_right",
        name = "Cryo Nova",
        description = "AoE burst on root",
        branch = "void_ring",
        tier = 3,
        position = { side = "right" },
        cost = { shards = 20 },
        requires = { "void_ring_t2_right" },
        effects = {
            { type = "tower_flag", tower = "void_ring", flag = "cryo_nova", value = true }
        },
    },
    -- Tier 4
    {
        id = "void_ring_t4",
        name = "Absolute Zero",
        description = "+30% slow, no healing",
        branch = "void_ring",
        tier = 4,
        position = { side = "center" },
        cost = { shards = 35 },
        requires = { "void_ring_t3_left", "void_ring_t3_center", "void_ring_t3_right" },
        effects = {
            { type = "tower_stat", tower = "void_ring", stat = "slow_strength", op = "multiply", value = 1.30 },
            { type = "tower_flag", tower = "void_ring", flag = "no_heal", value = true }
        },
    },
    -- Tier 5: Keystone
    {
        id = "void_ring_keystone",
        name = "Frozen Heart",
        description = "Permanent slow effect\n-50% tower damage",
        branch = "void_ring",
        tier = 5,
        position = { side = "center" },
        cost = { crystals = 1 },
        requires = { "void_ring_t4" },
        effects = {
            { type = "tower_flag", tower = "void_ring", flag = "permanent_slow", value = true },
            { type = "tower_stat", tower = "void_ring", stat = "damage", op = "multiply", value = 0.50 }
        },
        isKeystone = true,
    },

    -- =========================================================================
    -- VOID EYE (Gravity/Blackhole) - Lower left branch
    -- =========================================================================
    -- Tier 1
    {
        id = "void_eye_t1",
        name = "Event Horizon",
        description = "+25% blackhole radius",
        branch = "void_eye",
        tier = 1,
        position = { side = "center" },
        cost = { shards = 5 },
        requires = {},
        effects = {
            { type = "tower_stat", tower = "void_eye", stat = "blackhole_radius", op = "multiply", value = 1.25 }
        },
    },
    -- Tier 2
    {
        id = "void_eye_t2_left",
        name = "Void Crush",
        description = "5 DPS in blackhole",
        branch = "void_eye",
        tier = 2,
        position = { side = "left" },
        cost = { shards = 10 },
        requires = { "void_eye_t1" },
        effects = {
            { type = "tower_stat", tower = "void_eye", stat = "blackhole_dps", op = "add", value = 5 }
        },
    },
    {
        id = "void_eye_t2_center",
        name = "Graviton Surge",
        description = "+30% pull strength",
        branch = "void_eye",
        tier = 2,
        position = { side = "center" },
        cost = { shards = 10 },
        requires = { "void_eye_t1" },
        effects = {
            { type = "tower_stat", tower = "void_eye", stat = "pull_strength", op = "multiply", value = 1.30 }
        },
    },
    {
        id = "void_eye_t2_right",
        name = "Prolonged Collapse",
        description = "+40% duration",
        branch = "void_eye",
        tier = 2,
        position = { side = "right" },
        cost = { shards = 10 },
        requires = { "void_eye_t1" },
        effects = {
            { type = "tower_stat", tower = "void_eye", stat = "blackhole_duration", op = "multiply", value = 1.40 }
        },
    },
    -- Tier 3
    {
        id = "void_eye_t3_left",
        name = "Mass Compression",
        description = "+20% damage at center",
        branch = "void_eye",
        tier = 3,
        position = { side = "left" },
        cost = { shards = 20 },
        requires = { "void_eye_t2_left" },
        effects = {
            { type = "tower_stat", tower = "void_eye", stat = "center_damage_bonus", op = "add", value = 0.20 }
        },
    },
    {
        id = "void_eye_t3_center",
        name = "Singularity",
        description = "Can have 2 blackholes",
        branch = "void_eye",
        tier = 3,
        position = { side = "center" },
        cost = { shards = 20 },
        requires = { "void_eye_t2_center" },
        effects = {
            { type = "tower_stat", tower = "void_eye", stat = "max_blackholes", op = "add", value = 1 }
        },
    },
    {
        id = "void_eye_t3_right",
        name = "Hawking Radiation",
        description = "Explode on expire",
        branch = "void_eye",
        tier = 3,
        position = { side = "right" },
        cost = { shards = 20 },
        requires = { "void_eye_t2_right" },
        effects = {
            { type = "tower_flag", tower = "void_eye", flag = "blackhole_explode", value = true }
        },
    },
    -- Tier 4
    {
        id = "void_eye_t4",
        name = "Accretion Disk",
        description = "Pulled enemies vulnerable\n+15% pull",
        branch = "void_eye",
        tier = 4,
        position = { side = "center" },
        cost = { shards = 35 },
        requires = { "void_eye_t3_left", "void_eye_t3_center", "void_eye_t3_right" },
        effects = {
            { type = "tower_flag", tower = "void_eye", flag = "vulnerability", value = true },
            { type = "tower_stat", tower = "void_eye", stat = "pull_strength", op = "multiply", value = 1.15 }
        },
    },
    -- Tier 5: Keystone
    {
        id = "void_eye_keystone",
        name = "Spaghettification",
        description = "Execute <20% HP enemies\n-50% pull strength",
        branch = "void_eye",
        tier = 5,
        position = { side = "center" },
        cost = { crystals = 1 },
        requires = { "void_eye_t4" },
        effects = {
            { type = "tower_flag", tower = "void_eye", flag = "execute", value = true },
            { type = "tower_stat", tower = "void_eye", stat = "execute_threshold", op = "set", value = 0.20 },
            { type = "tower_stat", tower = "void_eye", stat = "pull_strength", op = "multiply", value = 0.50 }
        },
        isKeystone = true,
    },

    -- =========================================================================
    -- VOID STAR (Fire/Explosion) - Upper left branch
    -- =========================================================================
    -- Tier 1
    {
        id = "void_star_t1",
        name = "Inferno",
        description = "+20% fire damage",
        branch = "void_star",
        tier = 1,
        position = { side = "center" },
        cost = { shards = 5 },
        requires = {},
        effects = {
            { type = "tower_stat", tower = "void_star", stat = "fire_damage", op = "multiply", value = 1.20 }
        },
    },
    -- Tier 2
    {
        id = "void_star_t2_left",
        name = "Blazing Impact",
        description = "+30% explosion radius",
        branch = "void_star",
        tier = 2,
        position = { side = "left" },
        cost = { shards = 10 },
        requires = { "void_star_t1" },
        effects = {
            { type = "tower_stat", tower = "void_star", stat = "explosion_radius", op = "multiply", value = 1.30 }
        },
    },
    {
        id = "void_star_t2_center",
        name = "Spreading Flames",
        description = "+30% burn duration",
        branch = "void_star",
        tier = 2,
        position = { side = "center" },
        cost = { shards = 10 },
        requires = { "void_star_t1" },
        effects = {
            { type = "tower_stat", tower = "void_star", stat = "burn_duration", op = "multiply", value = 1.30 }
        },
    },
    {
        id = "void_star_t2_right",
        name = "Pyromaniac",
        description = "+25% attack speed",
        branch = "void_star",
        tier = 2,
        position = { side = "right" },
        cost = { shards = 10 },
        requires = { "void_star_t1" },
        effects = {
            { type = "tower_stat", tower = "void_star", stat = "fireRate", op = "multiply", value = 1.25 }
        },
    },
    -- Tier 3
    {
        id = "void_star_t3_left",
        name = "Chain Reaction",
        description = "Explode on death",
        branch = "void_star",
        tier = 3,
        position = { side = "left" },
        cost = { shards = 20 },
        requires = { "void_star_t2_left" },
        effects = {
            { type = "tower_flag", tower = "void_star", flag = "chain_explosion", value = true }
        },
    },
    {
        id = "void_star_t3_center",
        name = "White Hot",
        description = "Crit = 2x burn",
        branch = "void_star",
        tier = 3,
        position = { side = "center" },
        cost = { shards = 20 },
        requires = { "void_star_t2_center" },
        effects = {
            { type = "tower_flag", tower = "void_star", flag = "crit_burn", value = true }
        },
    },
    {
        id = "void_star_t3_right",
        name = "Meltdown",
        description = "+50% damage to burning",
        branch = "void_star",
        tier = 3,
        position = { side = "right" },
        cost = { shards = 20 },
        requires = { "void_star_t2_right" },
        effects = {
            { type = "tower_stat", tower = "void_star", stat = "burning_damage_bonus", op = "add", value = 0.50 }
        },
    },
    -- Tier 4
    {
        id = "void_star_t4",
        name = "Conflagration",
        description = "Fire spreads to nearby\n+25% burn",
        branch = "void_star",
        tier = 4,
        position = { side = "center" },
        cost = { shards = 35 },
        requires = { "void_star_t3_left", "void_star_t3_center", "void_star_t3_right" },
        effects = {
            { type = "tower_flag", tower = "void_star", flag = "fire_spread", value = true },
            { type = "tower_stat", tower = "void_star", stat = "fire_damage", op = "multiply", value = 1.25 }
        },
    },
    -- Tier 5: Keystone
    {
        id = "void_star_keystone",
        name = "Supernova",
        description = "First hit/wave = 500%\n3x cooldown",
        branch = "void_star",
        tier = 5,
        position = { side = "center" },
        cost = { crystals = 1 },
        requires = { "void_star_t4" },
        effects = {
            { type = "tower_flag", tower = "void_star", flag = "supernova", value = true },
            { type = "tower_stat", tower = "void_star", stat = "first_hit_multiplier", op = "set", value = 5.0 },
            { type = "tower_stat", tower = "void_star", stat = "fireRate", op = "multiply", value = 0.333 }
        },
        isKeystone = true,
    },

    -- =========================================================================
    -- CROSS-BRANCH CONNECTIONS
    -- Nodes that bridge adjacent branches at the outer edges of tier 2/3
    -- Requires ANY node from the facing sides of adjacent branches
    -- =========================================================================

    -- Lightning + Poison: Electro-toxic synergy
    -- bolt's RIGHT side faces orb's LEFT side
    {
        id = "cross_bolt_orb",
        name = "Conductive Toxins",
        description = "Chain lightning spreads\npoison to hit targets",
        branch = "cross",
        tier = "cross",
        position = { connectsBranches = {"void_bolt", "void_orb"} },
        cost = { shards = 15 },
        requires = { "void_bolt_t2_right", "void_bolt_t3_right", "void_orb_t2_left", "void_orb_t3_left" },
        effects = {
            { type = "tower_flag", tower = "void_bolt", flag = "chain_poisons", value = true },
            { type = "tower_stat", tower = "void_orb", stat = "damage", op = "multiply", value = 1.10 }
        },
        isCrossBranch = true,
    },

    -- Poison + Control: Debilitating synergy
    -- orb's RIGHT side faces ring's LEFT side
    {
        id = "cross_orb_ring",
        name = "Crippling Miasma",
        description = "Poisoned enemies are\nslowed 15% more",
        branch = "cross",
        tier = "cross",
        position = { connectsBranches = {"void_orb", "void_ring"} },
        cost = { shards = 15 },
        requires = { "void_orb_t2_right", "void_orb_t3_right", "void_ring_t2_left", "void_ring_t3_left" },
        effects = {
            { type = "tower_stat", tower = "void_ring", stat = "poisoned_slow_bonus", op = "add", value = 0.15 },
            { type = "tower_stat", tower = "void_orb", stat = "slow_duration", op = "multiply", value = 1.20 }
        },
        isCrossBranch = true,
    },

    -- Control + Gravity: Lockdown synergy
    -- ring's RIGHT side faces eye's LEFT side
    {
        id = "cross_ring_eye",
        name = "Gravitational Lock",
        description = "Slowed enemies pulled\n20% stronger",
        branch = "cross",
        tier = "cross",
        position = { connectsBranches = {"void_ring", "void_eye"} },
        cost = { shards = 15 },
        requires = { "void_ring_t2_right", "void_ring_t3_right", "void_eye_t2_left", "void_eye_t3_left" },
        effects = {
            { type = "tower_stat", tower = "void_eye", stat = "slowed_pull_bonus", op = "add", value = 0.20 },
            { type = "tower_stat", tower = "void_ring", stat = "range", op = "multiply", value = 1.10 }
        },
        isCrossBranch = true,
    },

    -- Gravity + Fire: Implosion synergy
    -- eye's RIGHT side faces star's LEFT side
    {
        id = "cross_eye_star",
        name = "Stellar Collapse",
        description = "Blackholes ignite enemies\n+10% explosion radius",
        branch = "cross",
        tier = "cross",
        position = { connectsBranches = {"void_eye", "void_star"} },
        cost = { shards = 15 },
        requires = { "void_eye_t2_right", "void_eye_t3_right", "void_star_t2_left", "void_star_t3_left" },
        effects = {
            { type = "tower_flag", tower = "void_eye", flag = "ignite_pulled", value = true },
            { type = "tower_stat", tower = "void_star", stat = "explosion_radius", op = "multiply", value = 1.10 }
        },
        isCrossBranch = true,
    },

    -- Fire + Lightning: Storm synergy
    -- star's RIGHT side faces bolt's LEFT side
    {
        id = "cross_star_bolt",
        name = "Firestorm",
        description = "Burning enemies chain\nlightning on death",
        branch = "cross",
        tier = "cross",
        position = { connectsBranches = {"void_star", "void_bolt"} },
        cost = { shards = 15 },
        requires = { "void_star_t2_right", "void_star_t3_right", "void_bolt_t2_left", "void_bolt_t3_left" },
        effects = {
            { type = "tower_flag", tower = "void_star", flag = "death_chain", value = true },
            { type = "tower_stat", tower = "void_bolt", stat = "damage", op = "multiply", value = 1.10 }
        },
        isCrossBranch = true,
    },
}

-- Build lookup table for quick access
local nodeById = {}
for _, node in ipairs(NODES) do
    nodeById[node.id] = node
end

-- =============================================================================
-- STATE
-- =============================================================================
local state = {
    allocatedNodes = {},
    towerBonuses = {},
    globalBonuses = { stats = {} },
}

-- =============================================================================
-- PRIVATE FUNCTIONS
-- =============================================================================

local function _areRequirementsMet(node)
    if not node.requires or #node.requires == 0 then
        return true
    end
    -- Only need ONE of the required nodes to be allocated (loosened from ALL)
    for _, reqId in ipairs(node.requires) do
        if state.allocatedNodes[reqId] then
            return true
        end
    end
    return false
end

local function _getNodeCost(node)
    if node.cost.crystals then
        return { crystals = node.cost.crystals }
    else
        return { shards = node.cost.shards or Config.SKILL_TREE.nodeCosts[node.tier] or 10 }
    end
end

local function _canAffordNode(node)
    local cost = _getNodeCost(node)
    if cost.crystals then
        return Economy.canAffordCrystals(cost.crystals)
    else
        return Economy.canAffordShards(cost.shards)
    end
end

local function _spendForNode(node)
    local cost = _getNodeCost(node)
    if cost.crystals then
        return Economy.spendVoidCrystals(cost.crystals)
    else
        return Economy.spendVoidShards(cost.shards)
    end
end

local function _refundForNode(node)
    local cost = _getNodeCost(node)
    if cost.crystals then
        Economy.addVoidCrystals(cost.crystals)
    else
        Economy.addVoidShards(cost.shards)
    end
end

-- =============================================================================
-- PUBLIC FUNCTIONS
-- =============================================================================

function SkillTreeData.init()
    state.allocatedNodes = {}
    state.towerBonuses = {}
    state.globalBonuses = { stats = {} }
end

function SkillTreeData.getAllNodes()
    return NODES
end

function SkillTreeData.getNodeById(nodeId)
    return nodeById[nodeId]
end

function SkillTreeData.isAllocated(nodeId)
    return state.allocatedNodes[nodeId] == true
end

function SkillTreeData.isAvailable(nodeId)
    local node = nodeById[nodeId]
    if not node then return false end
    if state.allocatedNodes[nodeId] then return false end
    return _areRequirementsMet(node)
end

function SkillTreeData.canAllocate(nodeId)
    local node = nodeById[nodeId]
    if not node then return false end
    if state.allocatedNodes[nodeId] then return false end
    if not _areRequirementsMet(node) then return false end
    return _canAffordNode(node)
end

function SkillTreeData.canUnallocate(nodeId)
    if not state.allocatedNodes[nodeId] then
        return false
    end
    for _, node in ipairs(NODES) do
        if state.allocatedNodes[node.id] and node.requires then
            for _, reqId in ipairs(node.requires) do
                if reqId == nodeId then
                    return false
                end
            end
        end
    end
    return true
end

function SkillTreeData.allocate(nodeId)
    if not SkillTreeData.canAllocate(nodeId) then
        return false
    end
    local node = nodeById[nodeId]
    if not _spendForNode(node) then
        return false
    end
    state.allocatedNodes[nodeId] = true
    SkillTreeData.recomputeBonuses()
    EventBus.emit("skill_tree_changed", { nodeId = nodeId, action = "allocate" })
    return true
end

function SkillTreeData.unallocate(nodeId)
    if not SkillTreeData.canUnallocate(nodeId) then
        return false
    end
    local node = nodeById[nodeId]
    _refundForNode(node)
    state.allocatedNodes[nodeId] = nil
    SkillTreeData.recomputeBonuses()
    EventBus.emit("skill_tree_changed", { nodeId = nodeId, action = "unallocate" })
    return true
end

function SkillTreeData.recomputeBonuses()
    state.towerBonuses = {}
    state.globalBonuses = { stats = {} }

    for nodeId, _ in pairs(state.allocatedNodes) do
        local node = nodeById[nodeId]
        if node and node.effects then
            for _, effect in ipairs(node.effects) do
                if effect.type == "tower_stat" then
                    local tower = effect.tower
                    if not state.towerBonuses[tower] then
                        state.towerBonuses[tower] = { stats = {}, flags = {} }
                    end
                    local stats = state.towerBonuses[tower].stats
                    if not stats[effect.stat] then
                        stats[effect.stat] = { additive = 0, multiplicative = 1.0, setValue = nil }
                    end
                    if effect.op == "add" then
                        stats[effect.stat].additive = stats[effect.stat].additive + effect.value
                    elseif effect.op == "multiply" then
                        stats[effect.stat].multiplicative = stats[effect.stat].multiplicative * effect.value
                    elseif effect.op == "set" then
                        stats[effect.stat].setValue = effect.value
                    end
                elseif effect.type == "tower_flag" then
                    local tower = effect.tower
                    if not state.towerBonuses[tower] then
                        state.towerBonuses[tower] = { stats = {}, flags = {} }
                    end
                    state.towerBonuses[tower].flags[effect.flag] = effect.value
                elseif effect.type == "global_stat" then
                    if not state.globalBonuses.stats[effect.stat] then
                        state.globalBonuses.stats[effect.stat] = { additive = 0, multiplicative = 1.0 }
                    end
                    if effect.op == "add" then
                        state.globalBonuses.stats[effect.stat].additive = state.globalBonuses.stats[effect.stat].additive + effect.value
                    elseif effect.op == "multiply" then
                        state.globalBonuses.stats[effect.stat].multiplicative = state.globalBonuses.stats[effect.stat].multiplicative * effect.value
                    end
                end
            end
        end
    end
end

function SkillTreeData.getTowerBonuses(towerType)
    return state.towerBonuses[towerType] or { stats = {}, flags = {} }
end

function SkillTreeData.getGlobalBonuses()
    return state.globalBonuses
end

function SkillTreeData.applyStatBonus(towerType, statName, baseValue)
    local value = baseValue
    local globalStats = state.globalBonuses.stats[statName]
    if globalStats then
        value = value + globalStats.additive
        value = value * globalStats.multiplicative
    end
    local towerBonuses = state.towerBonuses[towerType]
    if towerBonuses and towerBonuses.stats[statName] then
        local stat = towerBonuses.stats[statName]
        if stat.setValue ~= nil then
            value = stat.setValue
        else
            value = value + stat.additive
            value = value * stat.multiplicative
        end
    end
    return value
end

function SkillTreeData.hasTowerFlag(towerType, flagName)
    local towerBonuses = state.towerBonuses[towerType]
    if towerBonuses and towerBonuses.flags then
        return towerBonuses.flags[flagName] == true
    end
    return false
end

function SkillTreeData.getAllocatedCount()
    local count = 0
    for _ in pairs(state.allocatedNodes) do
        count = count + 1
    end
    return count
end

function SkillTreeData.getTotalNodesCount()
    return #NODES
end

return SkillTreeData
