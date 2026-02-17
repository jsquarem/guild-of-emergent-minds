# Guild of Emergent Minds

An AI-driven dungeon guild game. Heroes dungeon-crawl autonomously; **behavior is progression** — meta progression unlocks and improves AI behavior (e.g. learning to avoid hazards after repeated failures).

**Tech:** Godot 4.6, GDScript, 2D (isometric target).

---

## Current status (MVP)

- Single AI hero in a dungeon room with a fire hazard and goal
- **Behavior unlock:** After 3 deaths to fire, the hero unlocks “Avoid Fire” and steers around the hazard
- Single save (unlocks and death counts persist)
- Speed control 1x–5x (keys 1–5, +/-, gamepad LB/RB)
- HUD: HP, speed, run count, fire deaths, unlock notification
- Defeat/complete messages; auto-restart; manual restart (R / gamepad Start)

---

## How to run

1. Open the project in **Godot 4.6** (Engine → Manage Export Templates if needed).
2. Press **Play** (F5) or run the main scene `scenes/main.tscn`.

**Controls:** 1–5 speed, +/- or LB/RB to change speed, R or Start to restart run.

---

## Docs

- [Design summary](DOCS/design-summary.md) — vision, pillars, combat direction
- [Architecture](DOCS/architecture.md) — engine, BT, save, input, scene flow
- [Next steps](DOCS/next-steps-plan.md) — Phase 3 (roles, combat) and beyond

---

## License

Proprietary. All rights reserved.
