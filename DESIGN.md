# Tower Idle - Game Design Document

## Overview

**Working Title:** Tower Idle
**Genre:** Idle Tower Defense / Incremental
**Platform:** Desktop (Windows, Mac, Linux via LÖVE2D)
**Target Session:** 15-30 minutes active play
**Scope:** Small polished release (itch.io / Steam)

---

## Core Concept

A tower defense game where **you control your own difficulty**.

Send monsters to the Void to increase your passive income — but those same monsters come back in waves to attack you. The more you send, the richer you get, the harder it becomes.

**The Question:** How greedy can you get before your defense collapses?

---

## Player Fantasies

The game supports four interlocking fantasies:

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
                         │
                         ▼ (close game)
┌─────────────────────────────────────────────────────────────────┐
│                        IDLE PLAY                                │
│                                                                 │
│   Tower auto-defends at current wave level                      │
│   Income continues to tick (capped)                             │
│   Return to accumulated gold                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼ (choose to prestige)
┌─────────────────────────────────────────────────────────────────┐
│                        PRESTIGE                                 │
│                                                                 │
│   Full reset: towers, waves, income all reset                   │
│   Gain: Permanent multipliers, unlocks, new mechanics           │
│   Next run starts stronger, progresses faster                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Void Mechanic (Core Hook)

### Sending Monsters

Players spend gold to "send" monsters to the Void:

| Monster | Send Cost | Income/Tick | Effect on Waves |
|---------|-----------|-------------|-----------------|
| Triangle | 50g | +5 | More triangles spawn |
| Square | 150g | +15 | Squares added to waves |
| Pentagon | 400g | +40 | Pentagons (tanky) added |
| Hexagon | 1000g | +100 | Hexagons (very tanky) added |

### The Trade-off

- **Send nothing:** Easy waves, but poverty. Can't build towers fast enough.
- **Send everything:** Rich, but waves become overwhelming.
- **Sweet spot:** Balance income growth with defensive capability.

### Wave Composition

Waves are built from:
1. **Base enemies:** Scales slowly with wave number
2. **Sent enemies:** Directly tied to what you've sent to the Void

Formula (simplified):
```
Wave N contains:
  - (3 + N) base triangles
  - (sent.triangle / 2) extra triangles
  - (sent.square / 3) squares
  - (sent.pentagon / 4) pentagons
  - (sent.hexagon / 5) hexagons
```

---

## Economy

### Currencies

| Currency | Source | Spent On |
|----------|--------|----------|
| **Gold** | Killing enemies, income ticks | Towers, sending monsters |
| **Void Essence** | Prestige only | Permanent upgrades |

### Income System

- Income ticks every **30 seconds**
- Base income: 10 gold/tick
- Sending monsters increases income permanently (until prestige)
- Offline income: Accumulates while away (capped at 4 hours)

### Gold Flow

Early game:
- Kill enemies for gold (primary)
- Small income ticks (secondary)

Mid game:
- Income ticks become primary
- Enemy gold becomes supplementary

Late game:
- Massive income from aggressive sending
- Enemy gold negligible

---

## Towers

### Design Philosophy

Start with **4 towers**. Each has a clear role. No overlap.

| Tower | Role | Stats |
|-------|------|-------|
| **Turret** | Balanced DPS | Medium damage, medium range, medium fire rate |
| **Rapid** | Crowd Control | Low damage, short range, very fast fire |
| **Sniper** | Single Target | High damage, long range, slow fire |
| **Cannon** | Area Damage | Medium damage, medium range, splash radius |

### Tower Placement Strategy

- Towers block enemy pathing (A* pathfinding)
- Cannot fully block the path (validation prevents this)
- Maze-building is the core strategic layer
- Range overlaps create kill zones

### Future Towers (Post-Launch)

Only add if they create new strategic decisions:
- Slow Tower (utility, not damage)
- Support Tower (buffs adjacent towers)
- Economy Tower (generates gold, no damage)

---

## Enemies (Creeps)

### Design Philosophy

Enemies are **geometric shapes**. More sides = stronger.

| Enemy | Shape | HP | Speed | Behavior |
|-------|-------|-----|-------|----------|
| **Triangle** | 3 sides | Low | Fast | Rushes, dies easily |
| **Square** | 4 sides | Medium | Medium | Balanced |
| **Pentagon** | 5 sides | High | Slow | Tanky, absorbs damage |
| **Hexagon** | 6 sides | Very High | Very Slow | Mini-boss, threat |

### Pathfinding

- Enemies use **flow field** pathfinding (computed once when towers change)
- Always find shortest path to base
- Smoothly navigate around tower mazes

### Reaching Base

- Each enemy that reaches base costs **1 life**
- Start with **20 lives**
- Lose all lives = forced prestige (keep some progress)

---

## Prestige System

### When to Prestige

- Available after reaching **Wave 25** (first time)
- Later prestiges unlock at higher waves
- Can prestige anytime after unlocking

### What Resets

- All towers (removed)
- Wave count (back to 1)
- Current gold (reset to starting amount)
- Income (reset to base)
- Monsters sent (reset)

### What You Keep

- **Void Essence** earned from prestige
- Permanent upgrades purchased with Void Essence
- Unlocked tower types
- Unlocked mechanics

### Void Essence Calculation

```
Essence = (highest_wave * 10) + (total_gold_earned / 1000) + (monsters_sent * 2)
```

### Permanent Upgrades

| Upgrade | Cost | Effect |
|---------|------|--------|
| Gold Multiplier I | 100 VE | +10% gold from all sources |
| Income Multiplier I | 150 VE | +10% income per tick |
| Starting Gold I | 200 VE | Start with +100 gold |
| Tower Discount I | 250 VE | Towers cost 5% less |
| Life Bonus I | 300 VE | +2 starting lives |

---

## Idle Mechanics

### Active vs Idle

| Aspect | Active | Idle |
|--------|--------|------|
| Tower placement | Yes | No |
| Send monsters | Yes | No (or limited auto-send) |
| Waves | Real-time | Simulated |
| Income | Real-time ticks | Accumulated (capped) |
| Progression | Full speed | Reduced (80% efficiency) |

### Offline Calculation

When player returns:
1. Calculate time elapsed (max 4 hours)
2. Simulate income ticks
3. Simulate waves survived (simplified math, not full sim)
4. Award accumulated gold
5. Show summary screen: "While you were away..."

### Idle Upgrades (Late Game)

Unlocked via prestige:
- **Auto-Send:** Automatically send cheapest monster every N seconds
- **Idle Efficiency:** Increase offline progress rate
- **Extended Offline:** Increase offline cap beyond 4 hours

---

## Progression Timeline

### First Run (5-10 minutes)

- Learn tower placement
- Learn send mechanic
- Reach wave 10-15
- Probably die
- See prestige option

### Early Runs (10-15 minutes each)

- Prestige a few times
- Buy first permanent upgrades
- Reach wave 25-30 consistently
- Start understanding optimal send timing

### Mid Game (15-30 minute runs)

- Significant permanent bonuses
- Pushing to wave 50+
- Experimenting with aggressive send strategies
- Unlocking new tower types

### Late Game (variable)

- Pushing wave 100+
- Screen full of enemies and towers
- Income is massive
- Prestige for huge Void Essence gains
- Multiple prestige tiers unlocked

---

## Visual Design

### Philosophy

- **All assets drawn with code** (no sprites)
- **Readability first** — must instantly see enemy types, tower ranges, paths
- **Minimalist** — clean geometric shapes, no clutter
- **Spectacle at scale** — late game should look impressive through quantity, not individual complexity

### Color Language

| Element | Color | Meaning |
|---------|-------|---------|
| Towers | Green tones | Player-controlled, safe |
| Enemies | Red/Orange tones | Threat, danger |
| Void/Spawn | Dark red/purple | Ominous, source of enemies |
| Base | Bright green | Protect this |
| Gold | Yellow | Currency, reward |
| UI | White/Gray | Information |

### Visual Hierarchy

1. **Gameplay** — Towers, enemies, projectiles (brightest, most contrast)
2. **Grid** — Subtle lines, placement guidance
3. **UI** — Clear but not distracting
4. **Background** — Dark, unobtrusive

### Effects (Deferred — Phase 2+)

Polish effects to add later:
- Screen shake on big hits
- Particle bursts on enemy death
- Tower muzzle flashes
- Glow/bloom on projectiles
- Income tick visual pulse

**Do not implement these in Phase 1.** Get the game fun first.

---

## UI Layout

```
┌──────────────────────────────────────────┬─────────────────────┐
│                                          │                     │
│                                          │      TOWERS         │
│                                          │                     │
│              PLAY AREA                   │   [Turret  100g]    │
│                (70%)                     │   [Rapid   150g]    │
│                                          │   [Sniper  200g]    │
│           Grid with towers               │   [Cannon  250g]    │
│           Enemies pathing                │                     │
│           Projectiles                    ├─────────────────────┤
│                                          │                     │
│                                          │   SEND TO VOID      │
│                                          │                     │
│                                          │   [▲ +5   50g]      │
│                                          │   [■ +15  150g]     │
│                                          │   [⬠ +40  400g]     │
│                                          │   [⬡ +100 1000g]    │
│                                          │                     │
├──────────────────────────────────────────┴─────────────────────┤
│  GOLD: 1,234    +45/tick    ████░░ 18s    LIVES: 18   WAVE: 12 │
└────────────────────────────────────────────────────────────────┘
```

---

## Technical Architecture

See `CLAUDE.md` for full architecture specification.

### Key Principles

1. **No globals** — All state in explicit modules
2. **Data-driven** — All tuning in config files
3. **Event-based** — Systems communicate via events, not direct calls
4. **Simple first** — No optimization until needed

### Core Systems

| System | Responsibility |
|--------|----------------|
| Grid | Cell state, tower placement validation |
| Pathfinding | A*, flow fields, path validation |
| Economy | Gold, income, ticks, spending |
| Waves | Spawn timing, composition, difficulty |
| Combat | Targeting, damage, projectiles |
| Prestige | Reset logic, permanent upgrades |
| Save | Persistence, offline calculation |

---

## Development Phases

### Phase 1: Core Loop (Target: Playable prototype)

- [ ] Grid system with tower placement
- [ ] 4 tower types (Turret, Rapid, Sniper, Cannon)
- [ ] 4 enemy types (Triangle, Square, Pentagon, Hexagon)
- [ ] A* pathfinding with flow fields
- [ ] Basic economy (gold, income ticks)
- [ ] Send-to-Void mechanic
- [ ] Wave spawning based on sends
- [ ] Win/lose condition (lives)
- [ ] Basic UI (tower panel, send panel, HUD)

**Success Criteria:** Is the core loop fun? Is the send mechanic creating interesting decisions?

### Phase 2: Progression

- [ ] Prestige system
- [ ] Void Essence currency
- [ ] Permanent upgrades
- [ ] Save/load
- [ ] Basic offline progress

**Success Criteria:** Do players want to prestige? Does progression feel rewarding?

### Phase 3: Polish

- [ ] Screen shake and hit feedback
- [ ] Particle effects
- [ ] Sound effects
- [ ] Visual improvements
- [ ] Balance pass

**Success Criteria:** Does the game *feel* good to play?

### Phase 4: Content & Release

- [ ] Additional towers (if needed)
- [ ] Additional enemies (if needed)
- [ ] Achievements
- [ ] Settings menu
- [ ] Release build

---

## What We're NOT Building (Scope Control)

- Multiplayer (Hero Line Wars was MP, this is single-player)
- Story/narrative
- Complex upgrade trees (keep it simple)
- Multiple game modes (one mode, done well)
- Mobile version (desktop first, maybe later)
- Procedural generation (fixed rules, not random)

---

## Open Questions

1. **Should waves be timed or kill-based?** (Current: timed at 15-30 seconds)
2. **How punishing should losing be?** (Current: forced prestige, keep some progress)
3. **Should there be a "pause" or "slow" option?** (Affects idle purity)
4. **How many prestige tiers?** (Current design: 1, could expand)

---

## References

- **Hero Line Wars** (WC3 custom) — Send mechanic inspiration
- **Bloons TD** — Tower placement, maze building
- **Cookie Clicker** — Prestige loop, idle mechanics
- **Vampire Survivors** — Session length, escalating chaos
- **Mindustry** — Clean geometric aesthetic
