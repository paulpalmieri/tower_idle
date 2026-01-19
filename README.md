# Tower Idle

A hybrid idle tower defense game where you control your own difficulty.

Send monsters to the Void to increase your passive income — but those same monsters come back in waves to attack you. How greedy can you get before your defense collapses?

## Quick Start

```bash
# Run the game
love .
```

## Documentation

- **[DESIGN.md](DESIGN.md)** — Game design document
- **[CLAUDE.md](CLAUDE.md)** — Architecture guidelines and code standards
- **[MIGRATION.md](MIGRATION.md)** — What was migrated from the prototype

---

## Development Roadmap

### Phase 1: Core Loop ✱ CURRENT

**Goal:** Playable prototype that answers "Is this fun?"

| Task | Status | Notes |
|------|--------|-------|
| Grid system | ✅ Scaffold | Needs pathfinding integration |
| Tower placement | ✅ Scaffold | Basic structure done |
| 4 tower types | 🔲 TODO | Turret, Rapid, Sniper, Cannon |
| Creep entity | ✅ Scaffold | Needs pathfinding movement |
| 4 creep types | 🔲 TODO | Triangle → Hexagon |
| A* pathfinding | 🔲 TODO | Port from prototype |
| Flow field | 🔲 TODO | Port from prototype |
| Economy system | ✅ Done | Gold, income, lives |
| Send-to-Void | ✅ Done | Core mechanic in economy |
| Wave spawning | 🔲 TODO | Based on sent enemies |
| Basic combat | 🔲 TODO | Targeting, projectiles |
| UI panel | ✅ Scaffold | Tower/enemy selection |
| HUD | ✅ Scaffold | Gold, income, lives, wave |

**Exit Criteria:**
- Can place towers
- Enemies spawn and pathfind
- Can send enemies to increase income
- Waves scale with sends
- Game ends when lives = 0
- Core loop is testable for fun

### Phase 2: Progression

**Goal:** Players want to play again and again.

| Task | Status | Notes |
|------|--------|-------|
| Save/load system | 🔲 TODO | Persist progress |
| Prestige unlock | 🔲 TODO | After wave 25 |
| Prestige reset | 🔲 TODO | Full reset with rewards |
| Void Essence currency | 🔲 TODO | Earned on prestige |
| Permanent upgrades | 🔲 TODO | Spend Void Essence |
| Offline progress | 🔲 TODO | Calculate on return |
| Offline summary | 🔲 TODO | "While you were away..." |

**Exit Criteria:**
- Players prestige willingly
- Permanent upgrades feel impactful
- Offline progress works correctly
- Save/load is reliable

### Phase 3: Polish

**Goal:** The game *feels* good to play.

| Task | Status | Notes |
|------|--------|-------|
| Screen shake | 🔲 TODO | On big hits, wave start |
| Hit feedback | 🔲 TODO | Enemy flash, knockback |
| Particle effects | 🔲 TODO | Death bursts, projectile trails |
| Sound effects | 🔲 TODO | Shots, hits, UI |
| Tower animations | 🔲 TODO | Recoil, rotation smooth |
| Income tick juice | 🔲 TODO | Visual pulse on tick |
| UI polish | 🔲 TODO | Hover states, transitions |
| Balance pass | 🔲 TODO | Tune all numbers |

**Exit Criteria:**
- Every action has feedback
- Sound enhances, not annoys
- Game feels "juicy"
- Balance allows progression

### Phase 4: Content & Release

**Goal:** Complete, shippable game.

| Task | Status | Notes |
|------|--------|-------|
| Additional towers | 🔲 TODO | If needed after testing |
| Additional enemies | 🔲 TODO | If needed after testing |
| Achievements | 🔲 TODO | Optional |
| Settings menu | 🔲 TODO | Volume, display |
| Tutorial/onboarding | 🔲 TODO | First-time experience |
| Build pipeline | 🔲 TODO | Windows, Mac, Linux |
| Release checklist | 🔲 TODO | itch.io / Steam |

**Exit Criteria:**
- Complete game loop
- No critical bugs
- Builds for target platforms
- Ready for players

---

## Project Structure

```
tower-idle/
├── main.lua              # Entry point (minimal)
├── conf.lua              # LÖVE config
├── lib/                  # Third-party libraries
├── src/
│   ├── init.lua          # Game initialization
│   ├── config.lua        # All tuning values
│   ├── core/             # Engine systems
│   ├── systems/          # Game logic
│   ├── entities/         # Game objects
│   ├── world/            # Play area
│   ├── ui/               # Interface
│   └── fx/               # Effects (Phase 3)
├── assets/               # Fonts, audio
└── tests/                # Test files
```

---

## Contributing

See [CLAUDE.md](CLAUDE.md) for code standards and architecture rules.

**Key Rules:**
1. No globals
2. All constants in config.lua
3. Systems communicate via events
4. Keep functions small and focused

---

## License

TBD
