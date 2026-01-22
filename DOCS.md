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
