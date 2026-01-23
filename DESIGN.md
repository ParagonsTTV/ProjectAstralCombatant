# Project: Astral Combatant – DESIGN

PAC is a **post‑match receipts machine** for World of Warcraft that wraps Blizzard’s own combat/meter data and turns it into boringly honest, reviewable views for any spec, any bracket, meta or off‑meta.

This document describes what PAC is allowed to do, what it will never do, and how the Creator and public builds stay aligned.

---

## 1. Mission and scope

- **Mission:** Give players neutral, spec‑agnostic receipts for their rounds so they can argue about reality, not vibes.  
- **Scope:**  
  - Post‑match only (no in‑combat rotations, macroing, or callouts).  
  - PvP‑first (arenas, battlegrounds, world PvP), with optional PvE logging for dungeons/raids.  
  - Focused on *your* performance and contribution; it is not a raid leading or opponent‑scouting tool.

PAC is intentionally narrow: it shows what happened using Blizzard’s own numbers, and stops there.

---

## 2. Core constraints (Blizzard / Midnight)

PAC is designed to be safe under Blizzard’s Midnight‑era combat addon rules:

- **Blizzard data only.**  
  - PAC uses Blizzard’s exposed APIs (combat meter/scoreboard, instance info, system messages, saved variables).  
  - In Midnight, PAC does **not** rely on raw combat log parsing for live advantage; stats are filled from Blizzard’s own meter/scoreboard at the end of a round.

- **Post‑match only.**  
  - PAC logs rounds and shows receipts **after** or between fights.  
  - It never suggests what button to press, never runs rotations, and never calls out “kick this cast” in real time.

- **No hidden heuristics.**  
  - PAC can reorganize Blizzard’s numbers (sums, averages, ratios) and present them as neutral metrics.  
  - It does not inject secret scoring, matchmaking, or “AI rating” that users cannot see explained in plain language.

- **Honest exports.**  
  - Anything PAC can screenshot or export must match the in‑addon views and Blizzard’s numbers.  
  - If PAC cannot see a thing from Blizzard’s APIs, it does not pretend to.

---

## 3. Core metrics and perspectives

PAC’s core is **spec‑agnostic**: the same data model must work for tanks, healers, melee, and casters.

### 3.1 Per‑round core metrics

For each round PAC tracks, at minimum:

- Damage done, healing done.  
- Damage taken, healing taken, mitigation (where Blizzard exposes it).  
- Uptime and basic tempo: duration, rough DPS/HPS.  
- Control: crowd control applied, breaks, interrupts.  
- Important cooldown usage (defensives / major throughput CDs), where trackable.  
- Deaths and simple death context (count, timing, who died).

These are stored on a per‑round, per‑player basis in a single neutral structure (`round.stats` and `round.players[...]`), and all UI views must draw from that same structure.

### 3.2 Perspectives (presets, not special cases)

PAC can offer different **perspective presets** while using the same data:

- Tank‑leaning view (impact + mitigation emphasis).  
- Healer‑leaning view (sustain, damage contribution, defensive trades).  
- Melee / caster views (pressure, setup, control).  

These are presets over the same numbers, not separate code paths. Tank is **one preset**, not the focal point.

---

## 4. Outputs: “boringly honest” receipts

PAC’s outputs are intentionally plain and clearly labeled.

- **Neutral language.**  
  - Labels like “Impact,” “Sustain,” “Taken,” and “Control” instead of spec‑specific jargon.  
  - No spec‑flaming or balance takes baked into the UI copy.

- **No fake precision.**  
  - Use whole numbers or simple decimals where they help (e.g., `87K`, `2.3M`, `%.0f DPS`).  
  - Avoid pretending to know more than Blizzard exposes (no invented hit/miss breakdowns if not available).

- **Visible classification logic.**  
  - Simple performance classifications (“Below baseline / Baseline / Above baseline”) are derived from rolling averages on your own previous rounds.  
  - The logic is in the Lua file, not hidden on a server; if PAC says “Below baseline,” you can see exactly why in code.

- **“What this shows / what this misses.”**  
  - PAC should be honest in tooltips/docs about blind spots, for example:  
    - It cannot see opponent comms, pre‑game strategy, or positioning nuance.  
    - It cannot know whether a “low DPS” round was actually correct because you babysat a teammate at 10% all game.  
  - Dismissing PAC should mean dismissing Blizzard’s own data, not some secret model.

---

## 5. Creator vs public builds

PAC has two code paths but **one receipts contract**.

### 5.1 Shared behavior (must be identical)

Both Creator and public builds must:

- Use the same data model and math for rounds, stats, and performance.  
- Show the same numbers and summaries for a given round and Blizzard dataset.  
- Obey the same constraints in sections 2–4 above.

In practice: if you load the same saved round into both builds, the meter text, breakdown numbers, and performance badge must match.

### 5.2 Creator Edition (local, private)

The Creator Edition can add:

- **Identity flavor.**  
  - Creator‑only easter eggs (“this round was played by the original PAC author”) and provenance notes.  
- **Debug/dev tools.**  
  - Extra logging, test harnesses, internal slash commands, or experimental UI.

Rules for Creator Edition:

- It must **not** change how rounds are recorded or how core metrics are computed.  
- Any Creator‑only code must be clearly guarded (e.g., `PAC_IsCreatorBuild`, `PAC_IsCreatorClient()`) so it can be safely stripped.  
- Creator bootstrap is never shipped in the public build; public clients can only passively see `PAC_CREATOR` tags in imported rounds, not generate them.

### 5.3 Public build (GitHub / CurseForge)

The public build is:

- The Midnight‑safe, creator‑free addon that ships on GitHub and CurseForge.  
- Built from the same code as Creator Edition, with all Creator identity/easter eggs/debug‑only paths removed.  
- The only thing regular users install.

Rules for public build:

- No Creator flags, creator tags, or easter‑egg strings in the shipped Lua.  
- Optional “power user” features (PvE logging, AI‑ready summaries, auto‑send to Coach Chat) remain available but default to off.  
- Any new feature must be design‑reviewed against sections 2–4 before going live.

---

## 6. AI and coaching

PAC integrates with AI **only** as a text‑preparation tool.

- PAC composes post‑match summaries (round header, stats line, top spells, basic performance label) and shows them in a “Coach Chat” window.  
- If a user enables AI coaching, those summaries are formatted so they can be copy‑pasted into an external AI; PAC itself does not call external APIs or automate combat.

Design rules:

- No in‑combat AI calls, and no real‑time “press X now” suggestions.  
- No hidden server‑side scoring; all logic is in the Lua and visible.  
- NPC‑style comments (“Coach: no kicks that round…”) remain simple, stats‑based, and clearly marked as flavor.

---

## 7. Social goal and provenance

PAC is also **protective infrastructure**:

- Social goal: turn years of being misread (especially off‑meta/tank players) into tools that let anyone show receipts instead of reliving the same arguments.  
- The repo itself documents origin and authorship via `README`, `ASTRAL_NOTE.md`, and related notes so forks can build on the work but cannot erase where it came from.

Design implications:

- PAC’s UI and docs must avoid framing only one spec or playstyle as “correct.”  
- Any player—meta or off‑meta—should be able to point at PAC’s output as a neutral artifact in a discussion: “this is what actually happened.”

---

## 8. Change process

To keep PAC aligned with this design:

- **Creator‑first:**  
  - New features and refactors are developed and tested in Creator Edition (local/private).  
- **Design check:**  
  - Before promoting to public, confirm:  
    - Uses Blizzard data only.  
    - Respects Midnight/post‑match rules.  
    - Keeps metrics and language spec‑agnostic and transparent.  
- **Public promotion:**  
  - Strip Creator‑only hooks.  
  - Commit updated public Lua to `Interface/AddOns/ProjectAstralCombatant/`.  
  - Package for CurseForge / Releases from that public source.

If a future change would violate any of the constraints above, it should be rejected or redesigned before shipping.

---
