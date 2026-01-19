# CLAUDE.md - Tower Idle

## Quick Start

```bash
# Run the game
love .

# Run tests (when implemented)
love . --test
```

---

## Game Overview

**Genre:** Idle Tower Defense / Incremental
**Platform:** Desktop (Windows, Mac, Linux via LÖVE2D)
**Target Session:** 15-30 minutes active play

### Core Concept

A tower defense game where **you control your own difficulty**.

Send monsters to the Void to increase your passive income — but those same monsters come back in waves to attack you. The more you send, the richer you get, the harder it becomes.

**The Question:** How greedy can you get before your defense collapses?

### Player Fantasies

| Fantasy | How It Manifests |
|---------|------------------|
| **Greed & Risk** | Send harder monsters = more income = harder waves. Push until you break. |
| **Builder/Optimizer** | Design the perfect maze. Tower placement and synergy matter. |
| **Idle Satisfaction** | Set things up, walk away, return to accumulated gold and progress. |
| **Escalating Chaos** | Late game should be visually overwhelming — hundreds of enemies vs. your death maze. |

---

## Core Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                         ACTIVE PLAY                             │
│                                                                 │
│   ┌─────────┐      ┌─────────┐      ┌─────────┐                │
│   │  BUILD  │ ───► │  SEND   │ ───► │ SURVIVE │                │
│   │ TOWERS  │      │ TO VOID │      │  WAVES  │                │
│   └─────────┘      └─────────┘      └─────────┘                │
│        │                │                │                      │
│        │                ▼                │                      │
│        │         ┌───────────┐          │                      │
│        └───────► │  INCOME   │ ◄────────┘                      │
│                  │  TICKS    │                                  │
│                  └───────────┘                                  │
│                        │                                        │
│                        ▼                                        │
│              (Gold to build more / send more)                   │
└─────────────────────────────────────────────────────────────────┘
```

### Towers

4 tower types with distinct roles (see `src/config.lua` for stats):
- **Turret** — Balanced DPS
- **Rapid** — Crowd Control (fast fire, low damage)
- **Sniper** — Single Target (high damage, slow fire)
- **Cannon** — Area Damage (splash radius)

### Enemies (Creeps)

Geometric shapes where more sides = stronger (see `src/config.lua` for stats):
- **Triangle** (3) — Fast, weak
- **Square** (4) — Balanced
- **Pentagon** (5) — Slow, tanky
- **Hexagon** (6) — Very slow, very tanky

---

## Architecture Rules

### The Golden Rules

1. **No globals.** Ever. All state lives in explicit modules.
2. **Require what you use.** Each file declares its dependencies at the top.
3. **Single responsibility.** Each module does one thing well.
4. **Data in, data out.** Functions are predictable. Avoid side effects where possible.
5. **Config-driven.** No magic numbers in code. All tuning in `config.lua`.

---

## Code Style

### Naming Conventions

```lua
-- Constants: UPPER_SNAKE_CASE
local MAX_ENEMIES = 100
local TOWER_BASE_DAMAGE = 10

-- Modules/Classes: PascalCase
local Grid = {}
local TowerManager = {}

-- Functions and variables: camelCase
local function calculateDamage(base, multiplier)
local currentWave = 1

-- Private functions: prefix with underscore
local function _internalHelper()
```

### File Structure

Every module follows this structure:

```lua
-- src/systems/economy.lua
-- Economy system: manages gold, income, and spending

local Config = require("src.config")
local EventBus = require("src.core.event_bus")

local Economy = {}

-- Constants (module-level)
local INCOME_TICK_INTERVAL = 30

-- State (module-level, private)
local state = {
    gold = 0,
    income = 0,
}

-- Public functions
function Economy.init()
    state.gold = Config.STARTING_GOLD
    state.income = Config.BASE_INCOME
end

function Economy.getGold()
    return state.gold
end

function Economy.addGold(amount)
    state.gold = state.gold + amount
    EventBus.emit("gold_changed", state.gold)
end

-- Return the module
return Economy
```

### Indentation

- **4 spaces**, no tabs
- Consistent throughout the codebase

### Line Length

- Soft limit: 100 characters
- Hard limit: 120 characters
- Break long lines at logical points

---

## Module Map

```
src/
├── init.lua              # Game entry point, LÖVE callbacks
├── config.lua            # ALL constants and tuning values
│
├── core/                 # Engine-level, game-agnostic
│   ├── state_machine.lua     # Game state management
│   └── event_bus.lua         # Pub/sub event system
│
├── systems/              # Game logic, no rendering
│   ├── economy.lua           # Gold, income, spending
│   ├── waves.lua             # Wave spawning and composition
│   ├── combat.lua            # Damage calculation, targeting
│   └── pathfinding.lua       # A*, flow fields
│
├── entities/             # Game objects
│   ├── tower.lua             # Tower entity
│   ├── creep.lua             # Enemy entity
│   └── projectile.lua        # Projectile entity
│
├── world/                # Play area
│   └── grid.lua              # Grid state and queries
│
└── ui/                   # User interface
    ├── hud.lua               # In-game HUD
    ├── panel.lua             # Side panel
    └── screens/
        └── game.lua          # Main game screen
```

---

## Do's and Don'ts

### DO

```lua
-- DO: Require dependencies explicitly
local Config = require("src.config")
local Grid = require("src.world.grid")

-- DO: Use config values
local tower = Tower.new(x, y, Config.TOWERS.basic)

-- DO: Communicate via events
EventBus.emit("enemy_killed", { enemy = enemy, reward = reward })

-- DO: Keep functions small and focused
function Tower.canFire(self)
    return self.cooldown <= 0
end

-- DO: Return early for clarity
function Economy.spendGold(amount)
    if amount > state.gold then
        return false
    end
    state.gold = state.gold - amount
    return true
end

-- DO: Use descriptive variable names
local enemiesInRange = Tower.getEnemiesInRange(self, creeps)
local closestEnemy = findClosest(enemiesInRange, self.x, self.y)
```

### DON'T

```lua
-- DON'T: Use globals
enemies = {}  -- BAD
gold = 1000   -- BAD

-- DON'T: Hard-code values
local damage = 10  -- BAD: magic number
local damage = Config.TOWERS.basic.damage  -- GOOD

-- DON'T: Reach across module boundaries
function Tower.update(self)
    -- BAD: Tower shouldn't know about Economy internals
    Economy.state.gold = Economy.state.gold + 10
end

-- DON'T: Create god objects
function Game.update(dt)
    -- BAD: 500 lines of update logic
end

-- DON'T: Premature optimization
-- BAD: Complex object pooling before you know you need it
local projectilePool = ObjectPool.new(Projectile, 1000)

-- DON'T: Deep nesting
-- BAD:
if condition1 then
    if condition2 then
        if condition3 then
            doThing()
        end
    end
end
-- GOOD:
if not condition1 then return end
if not condition2 then return end
if not condition3 then return end
doThing()
```

---

## Event Bus Usage

Events decouple systems. Use them for cross-system communication.

### Emitting Events

```lua
-- When something happens, emit an event
EventBus.emit("creep_killed", {
    creep = creep,
    killer = tower,
    position = { x = creep.x, y = creep.y },
})

EventBus.emit("income_tick", {
    amount = state.income,
    total = state.gold,
})
```

### Listening to Events

```lua
-- Subscribe in init
function Particles.init()
    EventBus.on("creep_killed", function(data)
        Particles.spawnDeathBurst(data.position.x, data.position.y)
    end)
end
```

### Event Naming Convention

- Past tense for things that happened: `creep_killed`, `wave_started`, `gold_changed`
- Present tense for requests: `spawn_creep`, `place_tower`

### Standard Events

| Event | Data | Emitted By |
|-------|------|------------|
| `creep_killed` | `{creep, killer, position}` | Combat |
| `creep_reached_base` | `{creep}` | Creep |
| `tower_placed` | `{tower, gridX, gridY}` | Grid |
| `tower_fired` | `{tower, target}` | Tower |
| `gold_changed` | `{amount, total}` | Economy |
| `income_tick` | `{amount}` | Economy |
| `wave_started` | `{waveNumber, composition}` | Waves |
| `wave_cleared` | `{waveNumber}` | Waves |
| `life_lost` | `{remaining}` | Game |
| `game_over` | `{reason}` | Game |

---

## Config System

All game tuning lives in `src/config.lua`. See that file for current values.

### Accessing Config

```lua
local Config = require("src.config")

local tower = Tower.new(x, y, Config.TOWERS.basic)
local startingGold = Config.STARTING_GOLD
```

---

## Entity Pattern

Entities are simple data + behavior objects.

```lua
-- src/entities/tower.lua
local Object = require("lib.classic")
local Config = require("src.config")

local Tower = Object:extend()

function Tower:new(x, y, towerType)
    self.x = x
    self.y = y

    local stats = Config.TOWERS[towerType]
    self.damage = stats.damage
    self.range = stats.range
    self.fireRate = stats.fireRate
    self.color = stats.color

    self.cooldown = 0
    self.target = nil
    self.dead = false
end

function Tower:update(dt)
    if self.cooldown > 0 then
        self.cooldown = self.cooldown - dt
    end
end

function Tower:canFire()
    return self.cooldown <= 0 and self.target ~= nil
end

function Tower:fire()
    self.cooldown = 1 / self.fireRate
    return {
        x = self.x,
        y = self.y,
        target = self.target,
        damage = self.damage,
    }
end

function Tower:draw()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.x, self.y, 16)
end

return Tower
```

### Entity Lifecycle

1. **Create:** `local tower = Tower(x, y, "basic")`
2. **Update:** `tower:update(dt)`
3. **Draw:** `tower:draw()`
4. **Destroy:** `tower.dead = true`, remove from collection

---

## State Machine

Game states are explicit and managed.

```lua
-- States: "menu", "playing", "paused", "prestige", "gameover"

local StateMachine = require("src.core.state_machine")

-- Register states
StateMachine.register("playing", {
    enter = function() ... end,
    update = function(dt) ... end,
    draw = function() ... end,
    exit = function() ... end,
})

-- Transition
StateMachine.transition("playing")
```

---

## Adding New Features

### Adding a New Tower

1. Add stats to `Config.TOWERS`
2. Add to UI panel tower list
3. Test placement and firing
4. Balance against existing towers

### Adding a New Enemy

1. Add stats to `Config.CREEPS`
2. Add to send panel
3. Update wave composition logic
4. Test pathfinding and death

### Adding a New System

1. Create file in appropriate directory
2. Follow module pattern (state, init, public functions)
3. Use events for communication
4. Add to CLAUDE.md module map

---

## Common Patterns

### Collection Iteration (Remove Dead)

```lua
-- Iterate backwards when removing
for i = #entities, 1, -1 do
    if entities[i].dead then
        table.remove(entities, i)
    end
end
```

### Safe Table Access

```lua
-- Use or for defaults
local value = table.key or defaultValue

-- Use and for chained access
local nested = table and table.nested and table.nested.value
```

### Coordinate Conversion

```lua
-- Grid to screen
local screenX, screenY = Grid.toScreen(gridX, gridY)

-- Screen to grid
local gridX, gridY = Grid.toGrid(screenX, screenY)
```

---

## Development Phases

### Phase 1: Core Loop (Current)

- [x] Grid system with tower placement
- [x] 4 tower types (Turret, Rapid, Sniper, Cannon)
- [x] 4 enemy types (Triangle, Square, Pentagon, Hexagon)
- [x] A* pathfinding with flow fields
- [x] Basic economy (gold, income ticks)
- [x] Send-to-Void mechanic
- [x] Wave spawning based on sends
- [x] Win/lose condition (lives)
- [x] Basic UI (tower panel, send panel, HUD)

**Success Criteria:** Is the core loop fun? Is the send mechanic creating interesting decisions?

### Phase 2: Progression

- [ ] Prestige system
- [ ] Void Essence currency
- [ ] Permanent upgrades
- [ ] Save/load
- [ ] Basic offline progress

### Phase 3: Polish

- [ ] Screen shake and hit feedback
- [ ] Particle effects
- [ ] Sound effects
- [ ] Visual improvements
- [ ] Balance pass

### Phase 4: Content & Release

- [ ] Additional towers (if needed)
- [ ] Additional enemies (if needed)
- [ ] Achievements
- [ ] Settings menu
- [ ] Release build

---

## Phase Gates

Code quality requirements per phase:

### Phase 1 (Core Loop)

- [ ] No globals
- [ ] All values in config
- [ ] Basic event usage
- [ ] Code runs without errors

### Phase 2 (Progression)

- [ ] Save/load works
- [ ] Events used consistently
- [ ] No memory leaks (entities cleaned up)

### Phase 3 (Polish)

- [ ] All effects are toggleable
- [ ] Performance acceptable (60 FPS)
- [ ] No visual glitches

### Phase 4 (Release)

- [ ] All code documented
- [ ] Tested on multiple machines

---

## Forbidden Patterns

These patterns are NOT allowed in this codebase:

```lua
-- FORBIDDEN: Global variables
enemies = {}

-- FORBIDDEN: Anonymous modules
return {
    update = function() end,  -- Use named modules instead
}

-- FORBIDDEN: String-based type checking
if type(entity) == "table" and entity.isTower then

-- FORBIDDEN: Circular requires
-- fileA requires fileB, fileB requires fileA

-- FORBIDDEN: Modifying library code
-- Never edit lib/classic.lua or lib/lume.lua

-- FORBIDDEN: Platform-specific code without abstraction
if love.system.getOS() == "Windows" then
```

---

## Testing Guidelines

### What to Test

- **Config values:** Sanity checks (no negative HP, etc.)
- **Pure functions:** Pathfinding, damage calculation, economy math
- **Edge cases:** Empty collections, zero values, max values

### What NOT to Test (Yet)

- Rendering
- Input handling
- LÖVE callbacks

---

## Performance Guidelines

### Do Now

- Use local variables (not global lookups)
- Cache repeated calculations
- Remove dead entities promptly

### Do Later (When Needed)

- Object pooling for projectiles/particles
- Spatial partitioning for collision
- Flow field caching

### Never Do

- Premature optimization
- Complex caching without measurement
- "Clever" code that's hard to read

---

## Getting Help

- **LÖVE2D Questions:** https://love2d.org/wiki
- **Lua Questions:** https://www.lua.org/manual/5.1/
