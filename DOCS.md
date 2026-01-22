# Project: Astral Combatant – Docs (WIP)

This file will eventually hold more detailed technical notes and usage examples for PAC.  
For now, here is a concrete example of the kind of data PAC exports for post‑match coaching and VOD review.

---

### Example: one real duel export

Future versions of this file will include more schemas, field explanations, and example exports for different brackets.

Below is a trimmed example of how PAC records a real duel round for later review (trimmed example from an older version being used in The War Within Season 3):

```lua
{
  ["map"]    = "Dornogal",
  ["mode"]   = "Duel",
  ["duration"] = 51.047,
  ["player"] = { ["name"] = "Paragøn", ["realm"] = "Tichondrius", ["spec"] = "Protection" },
  ["stats"]  = {
    ["damageDone"]  = 7989683,
    ["healingDone"] = 20023157,
    ["damageTaken"] = 15624712,
    ["hps"]         = 392249.44,
  },
  ["cds_used"] = {
    { ["t"] = 13.18, ["spell"] = "Ardent Defender",   ["target"] = "Paragøn" },
    { ["t"] = 14.27, ["spell"] = "Hammer of Justice", ["target"] = "REDACTED" },
  },
}
```

## Trust, accuracy, and what PAC will not do

PAC is built around a simple rule: only report what the game actually exposes through the combat log and round context. It does not invent stats, hidden scores, or outcomes that are not grounded in real events.

In practice, that means:

- If the combat log cannot see it reliably, PAC does not pretend to.
- Summaries are built from concrete events (damage, healing, cooldowns, results), not guesses about “who played well”.
- There are no secret rankings, hidden MMR clones, or “this player is bad” labels.

The goal is to make it easy to trust PAC’s outputs because they are boringly accurate: they come from the same stream of data the game itself provides, just cleaned up and organized for review.

AI can help format or interpret PAC’s exports outside the game, but it does not get to change the underlying numbers or invent new ones. If a round was messy, PAC will show that; if a round was clean, PAC will show that too – without rewriting history.
