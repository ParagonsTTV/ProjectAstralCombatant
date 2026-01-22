# Project: Astral Combatant (PAC)

*A post‑match PvP coach and round tracker for World of Warcraft (Midnight‑era safe).*

---

## What PAC is (and is not)

Project: Astral Combatant is a tiny PvP coaching assistant for World of Warcraft.  
It does **not** play for you, press your buttons, or make decisions. It just listens, records, and hands you clean round data so you can see what actually happened and make better calls next time.

PAC lives strictly in the “post‑match review” lane. It is meant to sit alongside VODs, notes, and coaching sessions as a receipts machine, not as an in‑match decision engine.

---

## What PAC tracks

Right now PAC focuses on the parts of PvP rounds that actually matter when you sit down to review:

- Arenas, battlegrounds, skirmishes, duels, and world‑PvP rounds
- Basic round context: bracket, map, result, duration
- High‑level stats like damage, healing, and crowd control
- Key defensive and offensive cooldown usage (where possible from the combat log)
- Per‑round notes and tags you can add for later review
- Exportable text summaries formatted for human or AI coaching tools

The goal is to give you a clean “round card” you can pull up later and say:  
“Here is what happened, here is what I pressed, here is what my team and the enemy team did.”

---

## Origin (short version)

PAC exists because being “the tank player” in PvP often means getting labeled as a meme, a troll, or the problem even when the logs and VODs say otherwise.  
After 15 years playing Protection and Retribution Paladin in rated PvP, the fastest way to cut through that noise turned out to be simple: build a receipts machine that makes post‑match review trivial instead of exhausting.

For the long version of that story – the ladder history, the mislabels, and how this turned into a coaching tool – see [BACKGROUND.md](./BACKGROUND.md).

---

## Design constraints and safety

PAC is built to be Midnight‑era safe and future‑proof:

- Post‑match only: no real‑time rotation, targeting, or automation
- No keypresses, no macros, no “do this now” recommendations in combat
- Lightweight footprint: minimal UI, minimal saved data, focused exports
- Honest outputs: no “hype” scores or fake ratings, just what the combat log and round context can actually support

If PAC cannot see something in a trustworthy way, it does not pretend to. Gaps are left as gaps instead of being filled with guesses.

---

## Creator rounds and easter eggs

The public build does not ship with any creator‑only bootstrap or flags.  
It only knows about creator rounds when it is reviewing data that was originally recorded with a separate creator‑tagged client.

- Regular users cannot mark themselves as a creator.
- The only time PAC shows creator‑flavored lines is when it sees a round that already carries a `PAC_CREATOR` tag from the private Creator Edition.
- This lets public users benefit from richer lore/AI easter eggs on those specific rounds without adding any special treatment to their own games.

If you are just here to track and review your own matches, the public build is all you need.

---

## Status

PAC is currently an early prototype:

- Focused first on arenas, battlegrounds, and Solo Shuffle‑style rounds
- UI is intentionally minimal and evolving as more rounds are logged
- Data model and exports are still being tightened as real games expose edge cases

Expect rough edges and missing pieces. The priority is correctness and clarity over flash.

---

## Coaching personalities and creator voices

PAC is built to support different “coaching personalities” – text presets that change how post‑match summaries talk to you (tone, focus, level of detail) without changing the underlying data.

In the future, some of these personalities may be built in collaboration with other players or creators. When that happens:

- Each creator keeps full rights to their own name, likeness, personality, and voice.
- Any creator‑inspired preset is added only with their explicit permission.
- Creators can ask for their preset to be removed or changed at any time.

### No AI voice training

First‑party and third‑party AI systems are **not** granted permission to:

- Train on, clone, or imitate any creator’s voice or personality from this project.
- Build TTS/voice models, “soundalike” voices, or persona models based on PAC coaching personalities, names, or text.
- Use this project’s personalities as raw material for commercial or non‑commercial voice cloning.

- See [PERSONALITY_POLICY.md](./PERSONALITY_POLICY.md) for details on identity and voice protections.

The intent is for PAC to open a door that did not exist when this project started: to let other PvP players and personalities be represented in a way that respects their identity and boundaries, not to feed their voices into training data.

---

## Using AI with PAC

AI helped build parts of PAC and is one of the targets for its exports.  
The addon itself stays strict: it only collects data and formats summaries. What you do with those summaries – share with a coach, paste into a model, or keep for your own notes – is up to you.

If someone does not want to use the addon because AI was involved in its development, that is entirely their choice.

---


## Background and receipts

For the full background on who built PAC, PvP credentials, and why this project exists, see:

- [BACKGROUND.md](./BACKGROUND.md) – long‑form story and identity
- [PvP Credentials](https://check-pvp.fr/us/Tichondrius/Parag%C3%B8n)
- See [DOCS.md](./DOCS.md) for a sample export and future technical notes.
- Selected VODs (TBD)

---

## License and credits

PAC is released under the MIT License. See [LICENSE](./LICENSE) for details.

Created by [Paragøn‑Tichondrius (WoW)](https://worldofwarcraft.blizzard.com/en-gb/character/us/tichondrius/parag%C3%B8n) / [Paragonsttv](https://www.twitch.tv/paragonsttv) / [@ParagonTV](https://www.youtube.com/@ParagonTV) / [ParagonTheBear](https://www.youtube.com/@ParagonTheBear).  
Made in collaboration with [Perplexity (AI‑assisted development)](https://perplexity.ai/).

Project codename: Astral Combatant.
