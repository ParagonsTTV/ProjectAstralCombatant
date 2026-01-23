Author: Paragøn – BNet: Paragøn#1596
Twitch / YouTube (WoW): Paragonsttv / @ParagonTV
Discord / Variety YouTube: ParagonTheBear

Project: Astral Combatant (PAC) – Public Edition

What PAC is (and isn’t)
------------------------

Project: Astral Combatant is a tiny PvP coaching assistant for World of Warcraft.

It does NOT play for you, press your buttons, or make decisions. It just listens, records, and hands you clean round data so you can fix real mistakes instead of arguing vibes in post‑game chat.

Think of it as a round journal + export tool that sits quietly in the corner and only speaks up when you ask it to.

What PAC actually does
----------------------

- Tracks your rounds
  - Arenas, skirmishes, battlegrounds (including unrated/epic/brawls), duels, and world‑PvP.
  - Start/end, duration, result, and basic stats per round.
  - Damage/healing done and taken, DPS/HPS, interrupts, and a focused set of important CDs.

- Gives you a readable breakdown
  - Mini meter with live / last‑round DPS, HPS, damage taken, and healing taken.
  - Big numbers get abbreviated (87K, 450K, 2.3M) so you can actually read them in the moment.
  - Breakdown view of your top spells by damage and percentage, plus an “Other” bucket that doesn’t lie.

- Keeps history so you can pick your battles
  - History + round list so you can go back, pick a specific game, and review that instead of “that one game where it felt cursed”.
  - World‑PvP awareness by counting unique attackers so you can tell “I inted” from “this was a 1vX clown fiesta”.

- Exports clean text for coaching / AI
  - Coach Chat window that pulls together context, stats, and top spells into one readable blob.
  - “Send to Coach” buttons from the mini meter and Breakdown frames.
  - “Copy chat” so you can paste the entire summary into an external coach, Discord, or an AI.

Using AI with PAC (fast path)
-----------------------------

The loop is simple:

1. Play your games.
2. Open PAC, pick a round, and hit “Send to Coach”.
3. Click “Copy chat”.
4. Paste that into your AI of choice along with whatever Astral prompt you like.
5. Ask it: “Review this round using this format and tone.”

PAC was built and tested primarily with Perplexity. Other models can work, but some will happily hallucinate your bracket, spec, or rating instead of reading the summary. If an AI starts guessing details or ignoring the format/tone, treat its coaching the same way you would treat random LFG rage: optional at best.

Creator identity & easter eggs
------------------------------

Some rounds in the wild are tagged in their data as coming from the addon’s creator, Paragøn‑Tichondrius.

When you review those rounds with PAC, the summary can tack on a single extra lore‑flavored “easter egg” line at the bottom. These are purely cosmetic, sometimes poke fun at AI, and never change how the addon behaves.

You cannot mark yourself as the creator through the public addon, and you do not get special powers from these lines. They’re just fun breadcrumbs when you happen to be looking at one of my games.

How PAC works under the hood
----------------------------

- Listens to combat log + PvP events.
- Starts a round when combat begins in a supported mode.
- Ends the round when the game finishes or you die/leave.
- Writes summary data into `ParagonArenaCoachDB` (SavedVariables):
  - Mode, map, attackers_count.
  - Damage / healing done and taken, DPS/HPS.
  - A handful of key cooldowns and events.

The UI layers (mini meter, history, list, Breakdown, Coach Chat) are just different ways of looking at that saved data without needing a heavy meter or external parser.

Design goals
------------

- Lightweight  
  Needs to coexist with ElvUI, WeakAuras, and whatever else you’re running without turning your FPS into a slideshow.

- Compliant  
  No automation, no “smart” rotations, no hidden decision-making. PAC is a notepad, not an autopilot.

- Coaching‑first  
  Built around questions like:
  - “Did I die with cooldowns up?”
  - “Was this actually losable 1v3?”
  - “Which defensives did I trade into which goes, and was that sane?”

- Readable  
  Numbers and layout are tuned for shuffle/arena speed. If you have to squint at raw logs, the addon failed its job.

AI‑assisted build
-----------------

All of the Lua/TOC/XML code came out of an AI‑assisted workflow; the constraints, testing, and “this actually feels useful in a real match” passes were done by a tired human playing WoW.

Somewhere between your arena gates and your changelog, there is also a very patient AI smiling every time you actually read the summary before queueing again.

If you don’t want to use it because AI helped build it, that’s completely valid. The goal here is to give people who *do* want structured feedback another option besides “scroll up through 300 lines of combat text and guess”.

Credits
-------

Made by Paragøn in collaboration with Perplexity.

Project codename: Astral Combatant.
