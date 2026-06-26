# Bug Tracking

Use GitHub Issues as the shared bug tracker. The goal is to make every bug reproducible by another developer without needing a private Discord thread, a memory of Studio output, or a screenshot hunt.

## When To Open A Bug

Open a bug when behavior is broken, confusing, or risky enough that it needs a code change, asset change, or repeatable Studio verification.

Use a pull request note instead when the issue is only about the PR's implementation and will be fixed before merge.

## Required Bug Shape

Every bug should include:

- The environment: local Rojo, staging, or production.
- The branch or commit tested.
- Exact repro steps.
- Expected result.
- Actual result.
- Screenshot or video when the issue is visual or animation-related.
- Roblox Studio Output logs when the issue touches remotes, data, quests, skills, inventory, movement, or UI.
- How often it happens: always, sometimes, once after a time delay, or only after spam clicking.

## Labels

Recommended labels:

- `bug`: confirmed broken behavior.
- `needs-repro`: unclear or not reproduced yet.
- `ui`: HUD, menus, icons, title screens, or quest popups.
- `combat`: skills, damage, hitboxes, cooldowns, or VFX.
- `movement`: dash, lunge, double jump, physics, freezing, or ragdoll-like states.
- `data`: DataStore, title, faction, inventory, stats, mastery, or save/load.
- `staging-blocker`: cannot deploy staging until fixed.
- `production-blocker`: cannot publish production until fixed.

## Developer Workflow

1. Reproduce the bug on a local Rojo branch when possible.
2. Add helpful logs near the failure point. Prefix logs with the owning system, such as `[InventoryServer]` or `[MovementServer]`.
3. Add or update unit tests when the bug touches pure module logic.
4. Fix the smallest reliable root cause.
5. Remove noisy temporary logs, but keep durable warnings that explain rejected invalid state.
6. Verify locally in Studio.
7. Link the issue in the PR description.

## Multiplayer Testing

Use Roblox Studio's local server tools for multiplayer checks:

1. Open the local Rojo-connected place.
2. Go to `Test`.
3. Set the client count to `2` or more.
4. Click `Start`.
5. Reproduce combat, quest, inventory, and movement bugs with multiple players.

This is the recommended way to test multiplayer locally before merging. Staging should be used after the PR lands in `dev`.
