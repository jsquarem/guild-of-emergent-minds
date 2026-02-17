# Hero AI System

Technical reference for the behavior tree (BT) -based hero AI.

## Architecture Overview

```
Hero (CharacterBody2D)
 └─ HeroBrain (Node)
     └─ BTNode tree (in-memory, built in _build_tree())
```

Each Hero has one **HeroBrain** child node. The brain builds a role-specific behavior tree on `_ready()` and ticks it every `_physics_process()` frame. The tree reads world state through helper functions and writes to `hero.velocity` to move the character. After each tick, **separation steering** is applied so heroes path around each other (and nearby enemies) before `move_and_slide()`.

## Behavior Tree Primitives

All BT nodes live in `scripts/ai/`:

| Class | File | Purpose |
|---|---|---|
| `BTNode` | `bt_node.gd` | Base class. `tick(blackboard) -> Status` |
| `BTSelector` | `bt_selector.gd` | Runs children until one succeeds |
| `BTSequence` | `bt_sequence.gd` | Runs children until one fails |
| `BTCondition` | `bt_condition.gd` | Wraps a `Callable -> bool` as a BT condition |
| `BTAction` | `bt_action.gd` | Wraps a `Callable(blackboard) -> Status` as a BT action |

**Status enum** (defined on BTNode): `SUCCESS`, `FAILURE`, `RUNNING`.

## HeroBrain — Tree Structure

`scripts/ai/hero_brain.gd` builds a different tree depending on `hero.get_role_type()`.

### Shared Branch (all roles, first priority)

```
Selector (root)
 ├─ Sequence: Avoid Hazards
 │   ├─ Condition: has_avoid_fire (unlock check)
 │   ├─ Condition: is_near_hazard
 │   └─ Action: move_with_avoidance
```

The avoidance system uses a radius-based repulsion from any node in the `"fire_hazards"` group, blending away-from-hazard and toward-goal vectors.

### Tank Tree

```
 ├─ Sequence: Melee Combat
 │   ├─ Condition: has_any_alive_enemy
 │   └─ Action: tank_combat_tick
 └─ Action: move_to_goal
```

- **tank_combat_tick**: Picks nearest alive enemy. Closes to melee range, attacks when in range and cooldown ready. Never retreats. Tank leads the party: DPS/Healer will not outrun him.

### DPS Tree

```
 ├─ Sequence: Flee from melee
 │   ├─ Condition: is_any_enemy_in_melee_range
 │   └─ Action: flee_from_melee_tick
 ├─ Sequence: Ranged Combat
 │   ├─ Condition: has_any_alive_enemy
 │   └─ Action: ranged_combat_tick
 └─ Action: move_to_goal
```

- **flee_from_melee_tick**: If any enemy is within `MELEE_DANGER_RADIUS`, move away at 80% speed (state FLEEING). Avoids taking melee damage.
- **ranged_combat_tick**: Picks nearest alive enemy. Fires projectile when in attack range and cooldown ready. Backs away if closer than `preferred_range_distance`. Only moves *toward* the enemy if the tank is closer to that enemy (tank leads); otherwise moves toward a point behind the tank.

### Healer Tree

```
 ├─ Sequence: Heal Ally
 │   ├─ Condition: ally_needs_heal
 │   └─ Action: heal_tick
 ├─ Sequence: Flee from melee
 │   ├─ Condition: is_any_enemy_in_melee_range
 │   └─ Action: flee_from_melee_tick
 ├─ Sequence: Ranged Combat
 │   ├─ Condition: has_any_alive_enemy
 │   └─ Action: ranged_combat_tick
 └─ Action: move_to_goal
```

- **heal_tick**: Finds the lowest-HP ally below 80% HP. Moves into heal range, then fires a heal projectile. Heal uses `hero.heal_power`, `hero.heal_range`, `hero.heal_cooldown`.
- Same flee-from-melee and tank-lead rules as DPS for ranged combat.

## Separation Steering

After every BT tick, `_apply_separation(hero.velocity)` blends a repulsion vector from nearby units so heroes don't stack. Repulsion is summed from nodes in `"heroes"` and `"enemies"` within `SEPARATION_RADIUS`; the result is normalized and scaled by the original speed so desired movement direction is preserved while avoiding overlap.

## Key Constants (HeroBrain)

| Constant | Value | Purpose |
|---|---|---|
| `HAZARD_AVOIDANCE_RADIUS` | 140.0 | Detection radius for nearby hazards |
| `HAZARD_AVOIDANCE_STRENGTH` | 3.0 | Weight multiplier for avoidance vector |
| `HEAL_HP_THRESHOLD` | 0.80 | Ally HP ratio below which healing triggers |
| `RANGE_TOLERANCE` | 15.0 | Buffer zone for "too close" check on ranged units |
| `SEPARATION_RADIUS` | 28.0 | Distance within which separation from other units is applied |
| `SEPARATION_STRENGTH` | 1.2 | Weight of separation vector when blending with desired velocity |
| `MELEE_DANGER_RADIUS` | 50.0 | Enemy distance below which DPS/Healer flee (melee avoidance) |
| `TANK_LEAD_MARGIN` | 20.0 | Ranged only advance if tank is at least this much closer to target |

## Hero Stats Interface

Stats are defined in `HeroRole` (Resource) and copied to `Hero` on `_ready()`:

- `max_hp`, `move_speed`, `armor`
- `attack_power`, `attack_range`, `attack_cooldown`
- `heal_power`, `heal_range`, `heal_cooldown` (Healer only)
- `preferred_range_distance` (governs ranged positioning)

## UnitState

`scripts/units/unit_state.gd` tracks the current action state for debugging / HUD display:

- `IDLE`, `MOVING`, `ATTACKING`, `USING_ABILITY`, `FLEEING`

Set by the brain during each tick. Read by the HUD for the hero status display.

## Unlock System Integration

The brain checks `UnlockManager.is_unlocked("avoid_fire")` to gate the hazard avoidance branch. Unlocks can be driven by **deaths** or **mechanic hits**: when a hero takes damage from a mechanic (`fire`, `line_attack`, `target_swap`), `UnlockManager` increments a hit count for that cause. When either `deaths_required` or `hits_required` is reached, the behavior unlocks so heroes "eventually learn" from being hit, not only from dying.

1. Add a `BTCondition` that checks `UnlockManager.is_unlocked("behavior_id")`.
2. Place the condition at the start of the behavior's `BTSequence`.
3. In `UnlockManager.UNLOCK_THRESHOLDS`, register the cause with `behavior`, `deaths_required`, and optionally `hits_required`. Add the cause to `MECHANIC_CAUSES` if it should count hero_damaged events.

## Adding a New Role or Behavior

1. **New role**: Add enum value to `HeroRole.RoleType`, create `get_default_<role>()` static factory, add `match` branch in `HeroBrain._build_tree()`.
2. **New behavior**: Write condition and action callables in `HeroBrain`, add a `BTSequence` to the appropriate role branch. Gate behind an unlock if progression-driven.
3. **New projectile type**: Modify `Projectile.setup()` or add a variant factory; call from the brain's action callable.

## Visual Effects

| Effect | Script | Trigger |
|---|---|---|
| Floating damage number | `effects/floating_number.gd` | `Hero.take_damage()`, `Enemy.take_damage()`, `Boss.take_damage()` |
| Floating heal number | `effects/floating_number.gd` | `Hero.heal()` |
| Heal ring | `effects/heal_effect.gd` | `Hero.heal()` |
| Attack projectile | `effects/projectile.gd` | `HeroBrain._spawn_attack_projectile()` |
| Heal projectile | `effects/projectile.gd` | `HeroBrain._spawn_heal_projectile()` |
| Fire zone burst | `effects/fire_zone_effect.gd` | `Boss._execute_fire()` |

## Dungeon Flow

1. `Main` creates a mob room (`DungeonRoom`, `is_boss_room = false`).
2. Killing all enemies emits `EventBus.room_cleared`.
3. `Main` captures hero HP via `DungeonRoom.get_hero_states()`, frees the mob room, creates a boss room with carried-over HP.
4. Boss kill calls `GameManager.complete_run()`. All heroes dead calls `GameManager.fail_run()`.
5. `RunEndScreen` overlay with Retry / Reset Progress. R key also restarts.
