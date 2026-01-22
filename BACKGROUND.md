# Project: Astral Combatant – Background & Receipts

This document is the long‑form context behind Project: Astral Combatant (PAC):  
who built it, which ladders they actually played on, why a tank‑centric PvP addon was necessary, and how AI fits in without crossing automation lines.

---

## Who is behind PAC?

In‑game, this project comes from Paragøn‑Tichondrius – a Protection and Retribution Paladin player who has spent more than 15 years in organized PvP. 
Across that time, the focus has been consistent: making off‑meta, tank‑flavored PvP builds actually work in environments that were not designed for them, and then helping other players parse what is happening in their own games.

Key points of identity and experience:

- Long‑term Paladin main with a dual‑pillar Prot/Ret identity
- Experience across multiple expansions and systems, from older template eras to modern gear‑based ladders
- A playing style built around mitigation, cooldown trading, and “refusing to die” pressure rather than pure damage race

PAC is not a theorycraft project built from the outside; it is an attempt to codify a lot of lived, sometimes hostile ladder experience into something that other players can use.

---

## Ladder credentials (short version)

This project is grounded in real ladder time, not just skirmishes and duels.

Examples of competitive experience that inform PAC’s design include:

- Solo Shuffle peaks on both Protection and Retribution Paladin, with Prot reaching the low‑to‑mid 2300s and Ret reaching the 2400+ bracket in prior seasons
- Consistent Duelist/Elite‑range experience over multiple seasons, including both healer‑light and healer‑heavy brackets
- Practical experience dealing with being tunneled, blamed, or misread by teammates purely because of spec choice

The exact rating numbers, seasons, and screenshots are part of the receipts that can be linked from this repo or from a separate “PvP Identity & Credentials” page for anyone who needs that depth.

---

## The mislabel problem

The immediate catalyst for PAC was not a single season or a single bad group – it was a long, repeated pattern:

- Joining PvP communities and being written off as a “PvE troll” or meme spec before games even started
- Being used as the default scapegoat for losses regardless of what actually happened in the match
- Watching teammates and opponents ignore evidence from VODs and logs in favor of simple labels

Protection Paladin in PvP often sits at the intersection of “off‑meta”, “annoying to play against”, and “easy to blame when things go wrong”.  
Over time, that creates an environment where receipts matter more than vibes, because vibes are almost always against you.

That is the emotional and practical gap PAC is built to fill: replacing hand‑wavy blame with concrete, reviewable round summaries.

---

## Why a receipts machine?

Traditional meters and addons tend to focus on:

- Raw DPS/HPS charts
- Damage taken and done
- Interrupt counts and basic CC uptime

Those matter, but they do not tell the full story for tanks, hybrids, or players doing quiet, non‑dramatic work that keeps a team alive. 
For a Protection Paladin, the important questions are often:

- When were major defensives used, and were they aligned with enemy goes?
- Did the player actually die with important cooldowns up?
- How many goes were survived that should not have been, given the pressure?
- When did peels, off‑heals, or utility land, and did anyone notice?

PAC exists to answer those kinds of questions in a way that:

- Is lightweight enough to run in everyday play
- Produces text that can be shared, searched, and archived
- Does not require every teammate to run the same addon

Instead of trying to win arguments in Discord with feelings, PAC hands you round cards and says:  
“Here is what happened. Decide what you want to do with it.”

---

## From coaching notes to an addon

Before PAC, most of this work happened manually:

- Logging duels, arenas, and battlegrounds in text notes
- Timestamping VODs and cross‑referencing them with combat logs
- Writing out post‑match coaching feedback for other players

That workflow works, but it does not scale and it is exhausting when you are already dealing with stigma around your spec or playstyle.

PAC is a direct evolution of that manual process:

- Each round becomes a structured record (map, comp, result, key events)
- The addon automates the “write down the basics” part
- Notes, tags, and exports give you the same coaching surface area with far less overhead

In other words, PAC is the tooling that would have made those older seasons significantly easier to document and defend.

---

## Protection Paladin in PvP: system issues

A big part of why PAC focuses so much on receipts is that Protection Paladin lives inside several system‑level problems:

- The class is often balanced for PvE survivability, not PvP fairness.
- Queue systems and matchmaker behavior can produce lobbies where off‑meta specs become easy targets for blame.
- Tooltip and UI language frequently undersells or misrepresents what tank defensives are actually doing during burst windows.
- Match histories and UI summaries rarely capture mitigation correctly, which makes it harder for teammates to see the value of a tank who is playing well.

Because of this, players who commit to the spec end up carrying not just their team’s wins and losses, but also the burden of proof that they are not trolling the lobby.

PAC is not a balance fix, but it is a way to:

- Make mitigation visible in post‑match contexts
- Show when a tank or hybrid actually did their job
- Highlight the moments where teamplay broke down somewhere else

---

## Using AI with PAC (and its pitfalls)

AI is involved with PAC in two ways:

1. **Development assistance** – using models to help with:
   - Lua boilerplate and API lookups
   - Data modeling and export formatting
   - README and documentation polish

2. **Post‑match analysis** – formatting exports so they can be pasted into coaching tools, including language models, for deeper review.

Clear lines are in place:

- No in‑combat AI suggestions, rotations, or automation
- No “press this now” overlays
- No hidden callouts to external tools during play

The pitfalls are obvious: if left unchecked, AI could drift this kind of tool towards live decision support, which is not acceptable for the game or for fair competition.  
PAC is intentionally scoped on the other side of that line, and the documentation is explicit about that boundary so it can be audited.

If someone chooses not to use PAC because AI contributed to its development, that boundary is respected.

---

## How the Creator Edition fits in

There is a separate Creator Edition of PAC that tags rounds played by the original creator and enables a few extra lore/AI easter egg lines.

Important constraints:

- The public addon never ships with creator bootstrap or flags.
- Public builds can only see creator tags when reviewing data that already has them.
- Regular users cannot self‑tag or elevate their own rounds.

This keeps the public build clean, fair, and focused on its main job: tracking and summarizing rounds for anyone who wants receipts.

---

## Where this is going

PAC is still a prototype, but the direction is clear:

- Inclusive metrics that matter for all roles, not just DPS
- Better visibility into mitigation, cooldown trading, and clutch plays
- A smoother pipeline from “I just finished a round” to “I have something concrete to review”

Longer term, the project aims to:

- Support more specs and roles with tailored summaries
- Integrate more tightly with VOD workflows and coaching review
- Stay aligned with whatever the current addon/combat rules are for the game’s live era

For anyone reading this as part of a portfolio review:  
PAC is both a personal tool (built out of years of frustration with being misread on ladder) and a systems project – turning messy combat logs and social dynamics into structured, reviewable data.

---

## Contact and links

- In‑game: [Paragøn‑Tichondrius (World of Warcraft)](https://worldofwarcraft.blizzard.com/en-gb/character/us/tichondrius/parag%C3%B8n)
- GitHub: [Paragonsttv](https://github.com/ParagonsTTV/)
- Twitch / YouTube (WoW): [Paragonsttv](https://www.twitch.tv/paragonsttv) / [@ParagonTV](https://www.youtube.com/@ParagonTV)
- Variety / long‑form: [ParagonTheBear](https://www.youtube.com/@ParagonTheBear)

- ---

Additional receipts (screenshots, VODs, prior coaching examples) can be linked from this repo or from a dedicated “PvP Identity & Credentials” page for anyone who wants the full context.

This background.md will be updated slowly to include _my receipts and documentation_ as best as I am able to.

For a small in‑universe aside, see [ASTRAL_NOTE.md](./ASTRAL_NOTE.md).
