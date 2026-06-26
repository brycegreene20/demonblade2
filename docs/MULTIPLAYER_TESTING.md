# Multiplayer Testing

## Local Studio Smoke Test

1. Open the Rojo-synced local place in Roblox Studio.
2. Open the `Test` tab.
3. Set the player count to `2` or more.
4. Click `Start`.
5. Verify each client can:
   - spawn with its own HUD,
   - equip a different scroll or fruit,
   - damage the same dummy or demon,
   - receive shared contributor rewards after helping with a kill,
   - see other players' attack and skill VFX.

## Staging Tester Test

1. Deploy the branch to the staging place.
2. Confirm the experience max player count is greater than `1`.
3. Have testers join the staging experience at the same time.
4. Use a private server link when you need everyone guaranteed in one instance.

## Current Group Reward Behavior

The combat reward path tracks recent contributors to an enemy. When that enemy dies, recent contributors near the primary killer receive the same XP, quest, bounty, and equipped-style mastery rewards.

A full party invite UI can be added later on top of this reward path without rewriting combat damage tracking.
