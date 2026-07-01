# Clan System

Clans are persistent communities. Teams remain temporary groups of up to five
players and continue to control shared kill and quest credit.

## Player Flow

Open the `CLAN` button and use:

- `Overview`: clan identity, level progress, clearly labeled progression values,
  proximity bonuses, and owner settings.
- `Members`: roles, individual contribution reputation, and member bounty.
- `Recruitment`: join requests, lobby invitations, invite responses, and clan
  browsing.
- `Leaderboard`: rankings by shared Clan Prestige.
- `Achievements`: shared goals and their clan/member rewards.

Players can create a clan with a filtered name, description, and emblem. Clan
leaders and officers can invite lobby players and review join requests.

## Progression

Clan levels use these cumulative prestige thresholds:

```text
Level 1:     0
Level 2:   5,000
Level 3:  15,000
Level 4:  40,000
Level 5:  90,000
Level 6: 180,000
Level 7: 350,000
Level 8: 650,000
```

The thresholds are balanced around as many as 40 contributing members.

Clan progression uses three intentionally separate values:

- `Clan Prestige`: shared clan XP. This is the only value that raises Clan Level.
- `Member Reputation`: one member's contribution score inside the clan.
- `Bounty`: personal combat notoriety from the wider game. `Clan Combat Bounty`
  is the combined member total; it is informational and never increases Clan Level.

Prestige and member reputation come from enemy kills, boss kills, quests, and
clan achievements. Activity writes are batched every 30 seconds to avoid issuing
a DataStore write for every kill. Same-clan friendly fire is blocked.

## Proximity Bonuses

Each nearby clan member within 180 studs grants:

- `+5% XP`, capped at `+20%`.
- `+4% damage`, capped at `+16%`.

These bonuses apply to the individual earner. Team membership still determines
whether kill and quest credit is shared. A player who is both a clan member and
a teammate receives the clan proximity bonus and the normal team-sharing rules.

## Social Markers

- Team only: blue.
- Clan only: green.
- Team and clan: cyan.

Related players have an outline and overhead marker. Off-screen markers use
replicated lobby positions to keep the player's name and direction visible even
when Workspace streaming has removed the distant character model.

## Persistence

Clan records use `ClanData_v1`. Player-to-clan lookup uses
`ClanMembership_v1`. Player save data also stores `ClanId` and
`ClanReputation` as a recovery path.

Studio tests require `Enable Studio Access to API Services` on the local or
staging experience. Do not point Studio tests at the production experience.

## Enemy Levels

Enemy combat stats come from `EnemyProgressionModule`:

- Health: base 80, plus 55% of base for each level above 1.
- Damage: base 5, plus 55% of base for each level above 1.
- XP: base 30, plus 65% of base for each level above 1.
- Damage reduction: +1.5 percentage points per level above 1, capped at 45%.
- Frost enemies apply a 1.12 variant multiplier.
- Bosses apply additional health, damage, XP, and mitigation modifiers.

Both forest and frost spawners use the same formula and expose `Level`,
`Damage`, `DamageReduction`, and `XPReward` attributes on each enemy model.
Enemy health displays include a separate `LEVEL N` badge above the enemy name.

Quest cards show their required player level. The server rejects acceptance
until the player's current level meets that requirement, even if a modified
client tries to bypass the disabled quest card.
