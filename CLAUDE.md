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

5 tower types with distinct roles (see `src/config.lua` for stats):
- **Void Orb** — Starter tower: cheap, fast, short range
- **Void Ring** — Area specialist: slow but hits all enemies in range
- **Void Bolt** — Chain lightning: hits multiple targets
- **Void Eye** — Sniper: long range, high damage, single target
- **Void Star** — Fire tower: burning damage over time

### Enemies (Creeps)

Currently a single enemy type spawned from the Void (see `src/config.lua` for stats):
- **Void Spawn** — Amorphous shadowy creature, pixel-art rendered with procedural effects

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
│   ├── event_bus.lua         # Pub/sub event system
│   ├── display.lua           # Canvas scaling, letterboxing, coordinate conversion
│   ├── camera.lua            # World camera: pan, zoom, drag-to-pan
│   └── entity_manager.lua    # Entity collection management
│
├── systems/              # Game logic, no rendering
│   ├── economy.lua           # Gold, income, spending
│   ├── waves.lua             # Wave spawning and composition
│   ├── combat.lua            # Damage calculation, targeting
│   ├── pathfinding.lua       # A*, flow fields
│   ├── spawn_coordinator.lua # Creep spawn coordination
│   └── upgrades.lua          # Upgrade system
│
├── entities/             # Game objects
│   ├── tower.lua             # Tower entity with upgrades
│   ├── creep.lua             # Void Spawn enemy entity
│   ├── projectile.lua        # Projectile entity
│   └── void.lua              # The Void entity (clickable damage source)
│
├── rendering/            # Visual systems
│   ├── pixel_art.lua         # Pixel art sprite parsing and rendering
│   ├── background.lua        # Procedural pixelated ground texture
│   ├── procedural.lua        # Shared procedural noise functions (fbm, hash)
│   ├── fonts.lua             # Font loading and management
│   ├── atmosphere.lua        # Atmospheric visual effects
│   ├── game_renderer.lua     # Game rendering orchestration
│   └── grid_renderer.lua     # Grid overlay and path visualization
│
├── world/                # Play area
│   └── grid.lua              # Grid state and queries
│
└── ui/                   # User interface
    ├── panel.lua             # Side panel (stats, towers, void, upgrades)
    ├── tooltip.lua           # Tower upgrade tooltip
    ├── cursor.lua            # Custom pixel art cursor
    ├── shortcuts.lua         # Keyboard shortcuts overlay (toggle with ~)
    ├── settings.lua          # Settings menu modal
    └── pixel_frames.lua      # Pixel-perfect UI frame utilities
```

---

## Coordinate System

The game uses four coordinate spaces:

| Space | Range | Purpose |
|-------|-------|---------|
| Screen | 0 → window pixels | Physical mouse position |
| Game | 0 → 1280x720 | Fixed canvas (letterboxed) |
| World | Full world size (2800x1800) | Entity positions, camera |
| Grid | 1-11, 1-15 | Tile cell positions |

**Conversion flow:**
```
Screen → Display.screenToGame() → Game
Game → Camera.screenToWorld() → World
World → Grid.screenToGrid() → Grid
```

### Camera System (src/core/camera.lua)

Pan-and-zoom camera for the 2800x1800 world space:
- Zoom range: 0.5x to 1.5x with smooth interpolation
- Drag-to-pan with boundary clamping
- `Camera.push()/pop()` for world-space drawing

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
| `creep_killed` | `{creep, reward, position}` | init.lua (Game) |
| `creep_reached_base` | `{creep}` | init.lua (Game) |
| `tower_placed` | `{tower, gridX, gridY}` | init.lua (Game) |
| `tower_selected` | `{tower}` | init.lua (Game) |
| `tower_selection_cleared` | `{}` | init.lua (Game) |
| `tower_upgraded` | `{tower, stat, newLevel, cost}` | init.lua (Game) |
| `upgrade_purchased` | `{type, level, cost}` | init.lua (Game) |
| `spawn_creep` | `{creep}` | Waves |
| `creep_sent` | `{type, income, totalSent}` | Economy |
| `gold_changed` | `{amount, total}` | Economy |
| `income_tick` | `{amount, total}` | Economy |
| `wave_started` | `{waveNumber, enemyCount, angerLevel}` | Waves |
| `wave_cleared` | `{waveNumber}` | Waves |
| `life_lost` | `{remaining}` | Economy |
| `game_over` | `{reason}` | Economy |
| `void_clicked` | `{income, angerLevel}` | Void entity |
| `void_reset` | `{permanentAnger}` | Void entity |

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

## Pixel Art System

Tower sprites are defined as ASCII art in `Config.PIXEL_ART.TOWERS`. The system uses nearest-neighbor filtering for crisp pixel art.

### Sprite Format

Sprites are multi-line strings where each character maps to a color:

```lua
basic = {
    background = [[...]],  -- 16x16 static background
    base = [[...]],        -- 16x16 turret body (no rotation)
    barrel = [[...]],      -- Rotating barrel (variable size)
    projectile = [[...]],  -- Small projectile sprite
    recoil = { distance = 3, duration = 0.1 },
    sounds = { fire = nil, hit = nil },  -- Placeholder for future
}
```

### Color Mappings

| Char | Color | Usage |
|------|-------|-------|
| `.` | Transparent | Empty space |
| `#` | Dark metal | Outlines/frames |
| `=` | Mid metal | Body panels |
| `-` | Light metal | Highlights |
| `e` | Very dark | Edge rivets |
| `w` | White | Barrel bore |
| `G/g/o` | Greens | Basic tower |
| `Y/y/l` | Yellows | Sniper tower |
| `@` | Red/orange | Power indicator |
| `!` | Yellow-white | Muzzle flash |

### Special Markers (Not Rendered)

| Marker | Purpose |
|--------|---------|
| `A` | Anchor - where barrel attaches to base |
| `P` | Pivot - barrel rotation point |
| `T` | Tip - muzzle flash position |

Only the **first occurrence** of each marker is used.

### Creating Symmetric Sprites

For 16x16 base sprites:
1. Every row must be exactly 16 characters
2. Mirror pattern around columns 7-8 boundary
3. Single `A` marker at center (around row 6-7)
4. Pad consistently: `....content....`

Example structure:
```
................  (row 0: 16 dots)
.....######.....  (row 1: 5 + 6 + 5 = 16)
....#-e==e-#....  (row 2: 4 + 8 + 4 = 16)
```

### Usage

```lua
local PixelArt = require("src.rendering.pixel_art")

-- Draw a tower
PixelArt.drawTower(towerType, x, y, barrelRotation, recoilOffset)

-- Draw a projectile
PixelArt.drawProjectile(towerType, x, y, angle, scale)

-- Draw muzzle flash
PixelArt.drawMuzzleFlash(towerType, x, y, barrelRotation)
```

---

## Procedural Creep Rendering

Creeps (enemies) use a **procedural pixel-art system** that creates organic, animated shapes without pre-drawn sprites. The system maintains pixel-perfect aesthetics while allowing each creep to have a unique, living appearance.

### Core Concept: Animated Boundary

Instead of moving individual pixels (which creates gaps), the system:

1. **Generates a pixel pool** at spawn — all potential pixels within an expanded radius
2. **Animates the boundary** at draw time using time-varying noise
3. **Shows/hides whole pixels** based on whether they fall inside the current boundary

This keeps pixels on their grid positions while the membrane appears to breathe and undulate.

### How It Works

```
┌─────────────────────────────────────────────────────────┐
│  SPAWN TIME                    DRAW TIME (each frame)  │
│                                                         │
│  ┌─────────────┐               ┌─────────────┐         │
│  │ Generate    │               │ Calculate   │         │
│  │ pixel pool  │ ────────────► │ animated    │         │
│  │ (expanded)  │   stored      │ boundary    │         │
│  └─────────────┘               └─────────────┘         │
│        │                              │                │
│        ▼                              ▼                │
│  Each pixel stores:            For each pixel:         │
│  - position (relX, relY)       - Is it inside boundary?│
│  - angle from center           - Yes → draw it         │
│  - base edge noise             - No → skip it          │
│  - random seeds                - Near edge → glow color│
└─────────────────────────────────────────────────────────┘
```

### Config Values (in `Config.VOID_SPAWN`)

| Value | Purpose | Typical Range |
|-------|---------|---------------|
| `pixelSize` | Size of each "pixel" in the sprite | 2-4 |
| `distortionFrequency` | How jagged the base shape is | 1.0-3.0 |
| `wobbleSpeed` | Animation speed of edge undulation | 1.0-4.0 |
| `wobbleFrequency` | Number of "bumps" around the edge | 2.0-5.0 |
| `wobbleAmount` | How much the boundary moves | 0.2-0.5 |
| `wobbleFalloff` | Inner radius unaffected by wobble (0-1) | 0.3-0.6 |
| `swirlSpeed` | Interior color animation speed | 0.5-2.0 |
| `pulseSpeed` | Edge glow pulse rate | 1.0-3.0 |

### Creating New Creep Variants

To add a new creep type with different visual style:

1. **Add config in `Config.CREEPS`** (stats: hp, speed, reward, size)

2. **Add visual config** (either extend `VOID_SPAWN` or create new section):

```lua
Config.FLYING_CREEP = {
    pixelSize = 2,              -- Smaller pixels = more detail
    distortionFrequency = 1.5,  -- Smoother edges
    wobbleSpeed = 4.0,          -- Faster flutter
    wobbleAmount = 0.3,         -- Subtle movement
    wobbleFalloff = 0.5,
    -- ... color palette ...
}
```

3. **Override `generatePixels()` for different shapes**:

```lua
-- Example: Elongated flying creep
local aspectRatio = 1.5  -- Wider than tall
local adjustedRelX = relX / aspectRatio
local dist = math.sqrt(adjustedRelX^2 + relY^2)
```

4. **Override color logic in `draw()` for different effects**:
   - Different color palettes
   - Wing shimmer effects
   - Transparency patterns
   - Trail effects

### Visual Effect Ideas for Future Creeps

| Creep Type | Shape Modification | Color Effect |
|------------|-------------------|--------------|
| **Flying** | Elongated, wing appendages | Shimmer, transparency |
| **Armored** | Hexagonal boundary | Metallic highlights |
| **Swarm** | Tiny, minimal wobble | Synchronized pulse |
| **Boss** | Large, slow wobble | Multiple color layers |
| **Ghost** | High wobble, low falloff | Fade at edges |
| **Splitter** | Symmetric halves | Split color zones |

### Pixel-Perfect Rendering Rules

**CRITICAL:** All procedural pixel-art rendering must follow these rules to avoid subpixel artifacts:

1. **Use integer grid offsets for pixels**
   - Store pixel positions as integer grid offsets (gridX, gridY) from the entity center
   - Never use floating point offsets for pixel positions within a sprite

2. **Snap entity positions when rendering**
   ```lua
   -- Snap creep position to pixel grid before drawing
   local creepSnapX = floor(self.x / ps + 0.5) * ps
   local creepSnapY = floor(self.y / ps + 0.5) * ps
   ```

3. **Snap all screen positions**
   ```lua
   -- Final screen position must always be floored
   local screenX = floor(creepSnapX + p.gridX * pixelW)
   local screenY = floor(creepSnapY + p.gridY * pixelH)
   ```

4. **Snap animation offsets**
   ```lua
   -- Bob/movement offsets must be snapped to whole pixels
   local rawBob = sin(bobPhase) * bobAmount
   local bob = floor(rawBob + 0.5) * floor(scale + 0.5)
   ```

5. **Multi-part sprites (legs, limbs)**
   - Treat each part as a pixel chunk that moves as a unit
   - Anchor positions must be snapped to pixel grid during generation
   - Animation = visibility/color changes, not subpixel movement

### Key Files

- `src/entities/creep.lua` — Creep entity with procedural rendering
- `src/rendering/procedural.lua` — Shared noise functions (fbm, hash)
- `src/config.lua` — All visual tuning values

---

## Entity Pattern

Entities are simple data + behavior objects.

```lua
-- src/entities/tower.lua
local Object = require("lib.classic")
local Config = require("src.config")
local Projectile = require("src.entities.projectile")
local Combat = require("src.systems.combat")

local Tower = Object:extend()

function Tower:new(x, y, towerType, gridX, gridY)
    self.x = x
    self.y = y
    self.gridX = gridX
    self.gridY = gridY
    self.towerType = towerType

    local stats = Config.TOWERS[towerType]
    self.damage = stats.damage
    self.range = stats.range
    self.fireRate = stats.fireRate
    self.color = stats.color

    self.cooldown = 0
    self.target = nil
    self.dead = false
end

function Tower:update(dt, creeps, projectiles)
    if self.cooldown > 0 then
        self.cooldown = self.cooldown - dt
    end

    -- Find target using Combat system
    self.target = Combat.findTarget(self, creeps)

    -- Fire if ready
    if self.cooldown <= 0 and self.target then
        -- Create projectile and add to projectiles list
        self.cooldown = 1 / self.fireRate
    end
end

function Tower:draw()
    love.graphics.setColor(Config.COLORS.towerBase)
    love.graphics.circle("fill", self.x, self.y, Config.TOWER_SIZE)
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

## Keyboard Shortcuts

Press `~` (backtick/tilde) in-game to see all keyboard shortcuts.

### Current Shortcuts

| Key | Action |
|-----|--------|
| `1` | Select Void Orb tower |
| `2` | Select Void Ring tower |
| `3` | Select Void Bolt tower |
| `4` | Select Void Eye tower |
| `5` | Select Void Star tower |
| `Q` | Buy Auto-Clicker upgrade |
| `S` | Cycle game speed |
| `P` | Open settings menu |
| `L` | Toggle lighting |
| `G` | Cycle floating numbers style |
| `ESC` | Cancel / Deselect / Quit |
| `~` | Toggle shortcuts overlay |

### Adding a New Keyboard Shortcut

When adding a new keyboard shortcut, you **must update two places**:

1. **`src/init.lua`** — Add the key handler in `Game.keypressed(key)`
2. **`src/ui/shortcuts.lua`** — Add the shortcut to the `SHORTCUTS` table

The `SHORTCUTS` table in `shortcuts.lua` defines what appears in the overlay:

```lua
local SHORTCUTS = {
    { category = "CATEGORY NAME" },           -- Section header
    { key = "X", description = "Do thing" },  -- Shortcut entry
}
```

This keeps the in-game overlay synchronized with actual functionality.

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
local screenX, screenY = Grid.gridToScreen(gridX, gridY)

-- Screen to grid
local gridX, gridY = Grid.screenToGrid(screenX, screenY)
```

---

## Development Phases

### Phase 1: Core Loop (Current)

- [x] Grid system with tower placement
- [x] 2 tower types (Turret, Sniper) with pixel art sprites
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
