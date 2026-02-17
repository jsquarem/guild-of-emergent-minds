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

- Roles defined as data (Resource or enum): Tank, DPS, Healer.
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

## Boss System (Phase 4+)

- `Boss` (CharacterBody2D) in `scripts/units/boss.gd`. In group `"enemies"` and `"bosses"`.
- **Phases:** `NORMAL` → `ENRAGED` at configurable HP threshold (default 50%). Enraged phase reduces ability cooldowns and unlocks additional mechanics.
- **State loop:** `IDLE` → `TELEGRAPH` → `EXECUTE` → `IDLE`. Melee attacks happen during IDLE/MELEE when no ability is charging.
- **Telegraph system:** Each ability has a configurable telegraph duration with pulsing visual indicators. `EventBus.mechanic_telegraph` emits mechanic ID + data dict (position, direction, extent, duration, target) so AI/UI can react.
- **Mechanics:**
  - `fire` — Spawns a temporary `FireHazard` at target position; auto-removed after duration.
  - `line_attack` — Damages all heroes in a line segment (configurable width/length).
  - `target_swap` — Marks a non-aggro hero, deals high damage after telegraph, switches aggro.
- `EventBus.mechanic_triggered` emits when ability executes.
- Boss-spawned fire hazards use cause `"fire"`; line and target_swap use `"line_attack"` and `"target_swap"` respectively, feeding into UnlockManager death tracking.

## Run End Screen (Phase 4+)

- `RunEndScreen` (Control) in `scripts/ui/run_end_screen.gd`. Built in code, added to UI CanvasLayer by Main.
- Shows "DEFEAT" or "VICTORY" overlay with run stats (deaths by cause, unlocks).
- **Retry** button: emits `retry_requested`; Main restarts room.
- **Reset Progress** button: confirmation prompt, then calls `SaveManager.reset_to_default()` + `EventBus.game_reset.emit()`.
- No auto-restart on fail; player must press Retry (or R key). Manual restart still available via R key / gamepad Start.

## Full Game Reset

- `SaveManager.reset_to_default()` replaces cache with default save shape and writes to disk.
- `EventBus.game_reset` signal notifies all autoloads to reload from SaveManager.
- `UnlockManager` clears `unlocked_behaviors` and `death_counts`.
- `GameManager` resets `run_count` and `current_state`.

## Scene Flow (MVP)

```
Main (Node2D)
├── Camera2D
├── DungeonRoom (created in code)
│   ├── Floor (ColorRect)
│   ├── Walls (StaticBody2D)
│   ├── Boss (CharacterBody2D) — if is_boss_room
│   ├── Enemy × N (CharacterBody2D) — if not is_boss_room
│   ├── FireHazard (Area2D) — spawned by Boss or room
│   ├── GoalZone (Area2D)
│   └── Hero × 3 (CharacterBody2D)
│       ├── CollisionShape2D
│       └── HeroBrain (Node)
└── UI (CanvasLayer)
    ├── HUD (Control)
    └── RunEndScreen (Control)
```

- On run end: defeat/victory screen shown; player presses Retry to restart.
- Manual restart: R key / gamepad Start (bypasses screen).
- UnlockManager persists learning across restarts.

## Autoload Order (matters for startup dependencies)

1. `EventBus` — no dependencies
2. `SaveManager` — no dependencies (reads save file)
3. `GameManager` — reads run_count from SaveManager
4. `UnlockManager` — reads unlock data from SaveManager, connects to EventBus

## Dungeon Structure (Phase 3+)

- **Hybrid:** hand-crafted rooms as prefabs/templates, procedural arrangement.
- **Room format:** Each room is a scene or script (e.g. `DungeonRoom`) that defines:
  - Size (`room_size: Vector2`), walls, floor, hazards, goal zone, spawn points for heroes and enemies.
  - Optional: navigation regions, door nodes (for future multi-room).
- **Procedural arrangement:** Pick 2–4 room templates; instantiate and position them; connect with "door" positions (future: spawn doors/transitions). For Phase 3 MVP, a single hand-crafted room is used; multi-room layout is deferred.
- **Encounters:** Enemies are placed in the room at design time or via spawn points; hero party (2–3) spawns at a designated entry.

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
