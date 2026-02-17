# Guild of Emergent Minds

## AI-Driven Dungeon Guild Game

---

## Design Summary

### Core Fantasy

- Heroes dungeon crawl autonomously  
- You can take control of any character at any time  
- Full autoplay is viable  
- Meta progression improves AI behavior and intelligence  
- Base building supports long-term incremental growth  

---

## Inspirations

- Our Adventurer Guild (management loop)  
- Auto-battlers / idle RPGs  
- Tactical RPG depth  
- MMO-style boss mechanics  
- Behavior-tree-driven AI evolution  

---

## Core Pillars

### 1. Autonomous Dungeon Crawling

#### Heroes

- Have defined roles (Tank, Enchanter, DPS, etc.)  
- Operate via behavior trees / state machines  
- Improve over time  
- Learn encounter mechanics  

#### The Player Can

- Let heroes autoplay  
- Intervene at any time  
- Discover mechanics manually  
- Teach the AI through direct gameplay  

---

### 2. AI Learning & Behavioral Unlocks

**Core differentiator:** Behavior is progression.

#### Examples

- Dodge fire once → unlock "Avoid Fire" behavior  
- Repeated wipes to a mechanic → AI eventually adapts  
- Manual discovery → permanent bot learning  
- Recognition of similar mechanics across encounters  

#### Meta Progression May Include

- Expanding behavior tree capacity  
- Unlocking new conditional logic nodes  
- Improving reaction speed and intelligence  
- Deepening role specialization  

**Concept:** Intelligence is a resource.

---

### 3. Boss Design Philosophy

#### Bosses Feature

- Real mechanics  
- Environmental triggers  
- Clear telegraphs  
- Punishing patterns  

#### Examples

- Standing in fire  
- Line attacks  
- Target swaps  
- Phase transitions  

#### Long-Term Vision

- AI gradually handles mechanics competently  
- Early wipes are part of progression  
- Late-game AI feels "trained"  

---

### 4. Base / Guild Layer (Incremental)

#### Home Base Is

- Incremental  
- Idle-supporting  
- Progression-focused  

#### Likely Systems

- Guild management  
- Quest selection  
- Reputation growth  
- Resource production  
- Hero training upgrades  

Everything outside the dungeon = strategic layer.

---

## Combat Model Direction

### Needs

- Auto-battle viability  
- Real-time or light tactical control  
- Smooth "observe or intervene" loop  

### Player Profile Insight

- Prefers auto systems over heavy micromanagement  
- Low tolerance for slow TRPG pacing  
- Enjoys idle/incremental hybrid depth  

---

## Technical Direction

### Potential Engines

- Godot (strong vibe, previous success)  
- Unity (possible with upgraded hardware)  
- TypeScript engine (sprite + JSON-driven design)  

### Art Strategy

- Placeholder shapes initially  
- AI spritesheets later  
- Systems-first development  

---

## System Architecture Focus

- Behavior trees  
- Role systems  
- State machines  
- Unlockable AI logic  
- Mechanic recognition  
- Adaptation memory  

An idle game where AI sophistication is the primary progression loop.

---

## Emotional North Star

- Watching trained heroes intelligently clear content  
- Two enchanters charming mobs and blowing through dungeons  
- Automation that feels earned  
- "They learned that because I taught them."  

---

## Immediate Next Steps

### Decide Engine

- Godot likely fastest vibe test  

### Prototype

- Basic unit  
- Basic behavior tree  
- Simple dungeon room  
- Fire-on-ground mechanic  
- Unlock "avoid fire" behavior  

### Validate

- Is watching improved AI satisfying?  
- Does intervention feel meaningful?  
