# DemonBlade2

> An anime-inspired action RPG on Roblox — forge your path through demon-infested lands, master forbidden techniques, and rise from an unknown fighter to an unstoppable force.

Drawn from the worlds of **Demon Slayer**, **Jujutsu Kaisen**, **Solo Leveling**, and **Frieren: Beyond Journey's End**, DemonBlade2 blends fast-paced sword combat, supernatural power systems, and a deep progression loop into a single Roblox experience.

---

## What Is DemonBlade2?

You start as an ordinary blade in a world overrun by demons. Through combat, mastery, and sheer discipline you unlock ancient techniques and push past the limits of human strength. Every fight builds toward something. Every death teaches you something. Eventually, the demons fear you.

The game pulls from four universes:

- **Demon Slayer** — breathing forms, blade mastery, and the relentless war against demonic corruption
- **Jujutsu Kaisen** — cursed energy states, techniques that cost something to use, and the razor edge between power and self-destruction
- **Solo Leveling** — the awakening loop: grind, break limits, awaken again, repeat until nothing can touch you
- **Frieren: Beyond Journey's End** — patient mastery of forgotten arts and the weight of a long, difficult journey

---

## Core Features

### Combat
Fast, skill-based melee combat with light attack combos, blocking, guard breaks, and lunges. Land hits, read your opponent, and manage your stamina or lose everything.

### Power States
- **Total Focus** — enter a heightened state of concentration that accelerates movement and sharpens every strike. Drains stamina while active. Builds Total Focus XP with each fight, unlocking stronger tiers up to V10.
- **Selfless State** — a defensive resonance that converts the pain of battle — damage taken and dealt — directly into mastery progression. Ten tiers of increasing power for those willing to endure.

### The Demon World
Hunt Forest Demons and Snow Demons across a hand-crafted snowy village and surrounding wilderness. Stronger demons guard deeper zones. A field boss waits at the most dangerous ground.

### Progression Systems
- **Mastery Styles** — master your chosen combat style through PvP kills, training, and repeated use
- **Titles** — earn and equip titles that reflect your power and history
- **Quests and Bounties** — pursue quest objectives and place or claim PvP bounties on other players
- **Training Dummies** — sharpen your combos before stepping into the field

---

## Developer Setup

This repository is the source of truth for all game code and managed assets. The authored snowy map lives in the Roblox place and is not version-controlled.

```powershell
rojo serve default.project.json
```

Open the local place in Studio first, then connect the Rojo plugin. See [docs/DEV_ENVIRONMENT.md](docs/DEV_ENVIRONMENT.md) for full setup, asset import workflow, and verification steps.

### Branch Flow

```text
feature branch -> pull request -> dev -> validate -> Studio staging publish
main -> validate -> Studio production publish
```

### Required Checks Before PR

```powershell
tools\lune\lune.exe run tests\unit\run.luau
rojo build default.project.json -o build_check.rbxl
Remove-Item build_check.rbxl
```

See [docs/PULL_REQUESTS.md](docs/PULL_REQUESTS.md) for branch naming, PR expectations, and merge rules.
See [docs/BUG_TRACKING.md](docs/BUG_TRACKING.md) for bug reporting format and Studio Output log requirements.
