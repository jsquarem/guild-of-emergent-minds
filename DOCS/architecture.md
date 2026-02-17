# Architecture

## Engine

- **Godot 4.6** (2D, isometric view target)
- GL Compatibility renderer for broad hardware support
- Window: 1280x720, canvas_items stretch mode

## Camera / View

- **Isometric 2D** (angled top-down) is the target.
- MVP uses a basic Camera2D with zoom; full isometric tilemap comes with art pass.
- Placeholder shapes (ColorRect, draw calls) for all visuals in MVP.

## Behavior Tree

- **Custom GDScript implementation** in `scripts/ai/behavior_tree/`.
- `BTNode` (base, RefCounted), `BTSelector`, `BTSequence`, `BTCondition`, `BTAction`.
- `HeroBrain` (Node, child of Hero) builds the tree and ticks it each `_physics_process`.
- Unlockable behaviors add/enable branches: e.g. `avoid_fire` adds an avoidance sequence.
- Avoidance uses perpendicular steering to arc around hazard zones rather than walking through them.

## Role System (Phase 3+)

- Roles defined as data (Resource or enum): Tank, DPS, Enchanter.
- Each role has base stats, preferred range, and ability set.
- State machine (Idle, Moving, Attacking, UsingAbility, Fleeing) wraps the BT.

## Save System

- **Single save slot** at `user://save_data.json`.
- `SaveManager` autoload: pure I/O with in-memory cache; merge-on-write.
- Data stored: unlocked behaviors, death counts per cause, run count.
- `UnlockManager` reads from SaveManager on startup and persists on each hero death.

## Unlock / Learning System

- `UnlockManager` autoload tracks death counts per cause (e.g. "fire").
- Thresholds defined in `UNLOCK_THRESHOLDS` dict: `{ cause: { behavior, deaths_required } }`.
- When threshold is met, behavior is unlocked and `EventBus.behavior_unlocked` is emitted.
- `HeroBrain` checks `UnlockManager.is_unlocked()` via `BTCondition` nodes in the tree.

## Input

- **Keyboard + mouse + gamepad** from v1.
- Input actions registered programmatically in `GameManager._setup_input_actions()`.
- Speed: keys 1–5, +/-, gamepad LB/RB.
- Restart: R key, gamepad Start.

## Speed Control

- 1x, 2x, 3x, 4x, 5x via `Engine.time_scale`.
- HUD and notification timers use real-time delta (`delta / Engine.time_scale`).

## Scene Flow (MVP)

```
Main (Node2D)
├── Camera2D
├── DungeonRoom (created in code)
│   ├── Floor (ColorRect)
│   ├── Walls (StaticBody2D)
│   ├── FireHazard (Area2D)
│   ├── GoalZone (Area2D)
│   └── Hero (CharacterBody2D)
│       ├── CollisionShape2D
│       └── HeroBrain (Node)
└── UI (CanvasLayer)
    └── HUD (Control)
```

- On run end (death or goal reached): 2.5s real-time pause, then auto-restart room.
- Manual restart: R key / gamepad Start.
- UnlockManager persists learning across restarts.

## Autoload Order (matters for startup dependencies)

1. `EventBus` — no dependencies
2. `SaveManager` — no dependencies (reads save file)
3. `GameManager` — reads run_count from SaveManager
4. `UnlockManager` — reads unlock data from SaveManager, connects to EventBus

## Dungeon Structure (Phase 3+)

- **Hybrid:** hand-crafted rooms as prefabs/templates, procedural arrangement.
- Room format and procedural rules TBD; document here when locked.

## View Toggles and Background Progression (TBD)

- Target: toggle between party / base / map views.
- Dungeon run continues at 1x when not in party view.
- Small party-progress UI when viewing base or map.
- Scope and phasing not locked yet.

## Gear / Wipe Penalty (Post-MVP)

- Equipment: weapon, armor, accessory per hero.
- Sources: dungeon drops + base shop/craft.
- Wipe penalty: lose run drops or durability system (choose one, document here).

## Consumables (Post-MVP)

- Limited-use items (potions, scrolls).
- AI usage rules (e.g. "use health potion when HP < 30%").
- Add after gear system is stable.
