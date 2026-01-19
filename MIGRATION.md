# Migration Guide - Tower Refined → Tower Idle

## Migration Philosophy

**Be ruthless.** Only migrate code that is:
1. **Proven** — It works well in the current game
2. **Relevant** — It applies to the new game's mechanics
3. **Clean** — It follows good patterns (or can be cleaned easily)

**When in doubt, rewrite.** Fresh code with good architecture beats migrated code with hidden assumptions.

---

## Migration Tiers

### Tier 1: Copy Directly (Libraries)

These are third-party libraries. Copy without modification.

| File | Why |
|------|-----|
| `lib/classic.lua` | Standard OOP library, battle-tested |
| `lib/lume.lua` | Utility functions, well-maintained |

**Action:** Copy `lib/` directory as-is.

---

### Tier 2: Adapt & Clean (Systems)

These systems are good but need adaptation for the new architecture.

#### Event Bus (`src/event_bus.lua`)

**Current State:** Works, but used inconsistently in original game.

**Migration Notes:**
- Keep the core pub/sub pattern
- Remove any game-specific events
- Add event validation (optional)
- Document standard events

**Effort:** Low (30 min)

```lua
-- Core to keep:
EventBus.on(event, callback)
EventBus.emit(event, data)
EventBus.off(event, callback)
```

---

### Tier 3: Rewrite Inspired By (Valuable Patterns)

These systems have good ideas but should be rewritten cleanly.

#### Feedback System (`src/feedback.lua`)

**Current State:** Excellent shake/hitstop implementation, but tightly coupled to old game.

**What to Keep (Concepts):**
- Preset-based configuration
- Intensity scaling based on damage
- Decay over time
- Hitstop (freeze frames)

**What to Change:**
- Decouple from specific game events
- Make it purely reactive (call with params, not game state)
- Simplify presets for new game's needs

**Effort:** Medium (1-2 hours)
**When:** Phase 3 (Polish), not Phase 1

#### Pathfinding (`src/prototype/pathfinding.lua`)

**Current State:** Already clean from prototype.

**What to Keep:**
- A* implementation
- Flow field computation
- Path validation (can't block completely)

**What to Change:**
- Minor cleanup
- Add caching (compute flow field only when grid changes)

**Effort:** Low (30 min)

---

### Tier 4: Reference Only (Don't Migrate Code)

These systems have good ideas but the code shouldn't be migrated.

#### Post-FX Shaders (`src/postfx.lua`)

**Current State:** Complex, feature-rich, but overkill for Phase 1.

**Decision:** Don't migrate. Revisit in Phase 3.

**Reasoning:**
- Bloom, CRT, glitch effects are polish
- They add complexity before the game is fun
- Visual identity might change
- Better to build minimal version when needed

**What to Document (for later):**
- Bloom: Downsample → blur → composite
- CRT: Scanlines + curvature in fragment shader
- Heat distortion: Sine wave UV offset

#### Particle System (`src/debris_manager.lua`)

**Current State:** Works but tightly coupled to old enemy types.

**Decision:** Don't migrate. Rewrite when needed in Phase 3.

**What to Reference:**
- Particle spawn patterns (burst, trail)
- Velocity inheritance from source
- Fade over lifetime
- Color from source entity

#### Lighting System (`src/lighting.lua`)

**Current State:** Additive glow, nice but not essential.

**Decision:** Don't migrate. Optional for Phase 3+.

---

### Tier 5: Do Not Migrate (Irrelevant or Problematic)

These should not be migrated at all.

| System | Reason |
|--------|--------|
| `main.lua` (1800 lines) | Monolith, bad patterns, different game |
| `EntityManager` + global sync | Architectural hack, not needed with clean design |
| `AbilityManager` | Different game mechanics |
| `Roguelite` system | Different progression model |
| `SkillTree` | Need different progression for idle |
| `CompositeEnemy` | Overcomplicated, not needed |
| `Drone/Silo/Shield` | Different game mechanics |
| `LaserSystem/PlasmaSystem` | Different weapons |
| Intro cinematic | Not needed |
| HUD (current) | Different layout |

---

## What We're Building Fresh

These will be written from scratch with clean architecture:

| System | Why Fresh |
|--------|-----------|
| `Grid` | New requirements (tower placement TD style) |
| `Economy` | Core mechanic, must be right |
| `Waves` | Based on send mechanic (new) |
| `Prestige` | New system entirely |
| `Save/Load` | New requirements (offline progress) |
| `UI` | Completely different layout |
| `Towers` | Simpler than current turret |
| `Creeps` | Pathfinding-based, not 360° |

---

## Migration Checklist

### Before Starting New Repo

- [x] Design document complete
- [x] CLAUDE.md guidelines complete
- [x] Migration list defined
- [ ] Directory structure created
- [ ] Phase 1 scope locked

### Phase 1 Migration

- [ ] Copy `lib/classic.lua`
- [ ] Copy `lib/lume.lua`
- [ ] Adapt `event_bus.lua` (clean version)
- [ ] Port `pathfinding.lua` from prototype
- [ ] Create fresh: config, grid, economy, towers, creeps, waves, UI

### Phase 3 Migration (Polish)

- [ ] Rewrite feedback system (inspired by original)
- [ ] Create minimal particle system (reference original)
- [ ] Decide on visual effects (bloom? CRT? neither?)

---

## Code Quality Gates

Before migrating any code, verify:

1. **No globals** — Convert any global access to proper requires
2. **No magic numbers** — Extract to config
3. **Single responsibility** — Split if doing too much
4. **Documented** — Add comment header explaining purpose

---

## File-by-File Decisions

| Original File | Decision | Notes |
|---------------|----------|-------|
| `lib/classic.lua` | COPY | As-is |
| `lib/lume.lua` | COPY | As-is |
| `src/event_bus.lua` | ADAPT | Clean up, document events |
| `src/feedback.lua` | DEFER | Phase 3, rewrite inspired by |
| `src/postfx.lua` | DEFER | Phase 3+, maybe skip entirely |
| `src/debris_manager.lua` | DEFER | Phase 3, rewrite |
| `src/lighting.lua` | SKIP | Maybe Phase 4 |
| `src/audio.lua` | DEFER | Phase 3 |
| `src/config.lua` | REWRITE | New config structure |
| `src/camera.lua` | SIMPLIFY | Much simpler for TD view |
| `src/prototype/*.lua` | ADAPT | Clean up and integrate |
| Everything else | SKIP | Not relevant |

---

## Risk Assessment

### Low Risk Migrations

- Libraries (copy)
- Event bus (simple)
- Pathfinding (already clean)

### Medium Risk

- Feedback system (good but needs adaptation)
- Camera (simpler needs, but easy to over-engineer)

### High Risk (Defer)

- Post-FX (complex, might not want it)
- Particle system (tightly coupled to old game)
- Any UI code (completely different layout)

---

## Summary

**Phase 1 migrations:** 4 files
- `lib/classic.lua` (copy)
- `lib/lume.lua` (copy)
- `event_bus.lua` (adapt)
- `pathfinding.lua` (from prototype)

**Everything else:** Write fresh or defer.

This keeps Phase 1 focused on getting the core loop working with clean architecture, not fighting legacy code.
