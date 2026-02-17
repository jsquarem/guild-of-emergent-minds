# Next Steps Plan

**Status:** Phase 1–2 done. Phase 3 implemented: roles (Tank/DPS/Healer; only Tank+DPS spawned for now), state machine (Idle/Moving/Attacking), combat, 2 heroes, simple enemies (patrol/aggro), hybrid dungeon doc.

---

## Immediate next: Phase 3 — Roles, state machines, combat (implemented)

**Goal:** 2–3 heroes with distinct roles, simple enemy AI, state-driven behavior. Target run length 5–10 minutes.

| Step | Task | Notes |
|------|------|--------|
| **3.1** | Role system | Define Tank, DPS, Healer as data (Resource or enum): base stats, preferred range, 1–2 abilities each. One unit type per role. |
| **3.2** | Combat model | Real-time auto-battle; AI picks targets and abilities by role. No player control (post-MVP). |
| **3.3** | State machine (per unit) | Wrap BT in states: Idle, Moving, Attacking, UsingAbility, Fleeing. Clear transitions for debugging and future “reaction speed.” |
| **3.4** | Simple encounters | 2–3 enemy types: patrol or aggro on sight, basic attack only. Heroes (AI) clear them. |
| **3.5** | Hybrid dungeon structure | Hand-crafted room prefabs; procedural arrangement (pick 2–4 rooms, connect with doors). Document format in `architecture.md`. |

**Deliverable:** Party of 2–3 heroes, distinct roles, simple combat, simple enemies, 1–2 rooms (optionally procedurally arranged). Placeholder art. Run length trending toward 5–10 min.

---

## After Phase 3: Phase 4 — Boss and mechanic recognition

| Step | Task |
|------|------|
| **4.1** | Boss entity with phases, telegraph system, one “fire on ground”–style ability |
| **4.2** | 2–3 mechanics: stand in fire, line attack (move aside), target swap (reposition) |
| **4.3** | Mechanic types as IDs; EventBus emits mechanic type + target/area |
| **4.4** | Persist “deaths/wipes per mechanic”; use later for behavior unlocks |
| **4.5** | Defeat screen on wipe, then return to base (or retry) |

**Deliverable:** One boss with telegraphs; party can wipe and retry; game records which mechanics caused wipes.

---

## Then: Phase 5 — Base / guild layer

| Step | Task |
|------|------|
| **5.1** | Base scene: “select quest” → “start run”; after run, defeat screen then base (or win → base) |
| **5.2** | Quest list (data-driven: dungeon id, difficulty, rewards); unlock by completion/reputation |
| **5.3** | Meta resources (e.g. reputation, gold); persist and show on base UI |
| **5.4** | One hero training upgrade path (e.g. behavior capacity, reaction speed); spend resources at base |
| **5.5** | (Optional) Idle: passive income or training over time at base |
| **5.6** | (Post-MVP) Gear hook: drops + base shop; wipe penalty |

**Deliverable:** Base as hub; choose quest → dungeon → return; earn and spend on one upgrade path.

---

## Later: Phase 6 — Content and polish

- More dungeons/rooms and 1–2 more bosses
- Full gear system + consumables (one type + AI use rule first)
- Art pass (replace placeholders)
- Balancing: wipe rates, unlock pacing, 5–10 min runs, medium difficulty
- Smarter enemy AI (abilities, tactics)
- UI polish, accessibility, sound expansion

---

## Optional before Phase 3

- **Validate MVP feel:** Play a few runs; confirm “watching AI improve” is satisfying. Tweak fire size/damage, avoidance strength, or unlock threshold if needed.
- **Isometric pass:** Lock isometric camera/tilemap so Phase 3 content is built in the final view (see `architecture.md`).
- **Audio:** Add placeholder SFX (hit, death, goal) and one music loop if not already in (plan called for “basic” in MVP).

---

## Doc references

- **Design vision:** [design-summary.md](design-summary.md)
- **Technical decisions:** [architecture.md](architecture.md)
- **Full phased plan:** (Cursor plan; not edited here)
