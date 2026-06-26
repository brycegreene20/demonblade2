# DemonBlade2

DemonBlade2 is a Roblox experience developed with VS Code, Git, and Rojo. The repository is the source of truth for scripts, remotes, services, complex Studio assets, and deployment configuration.

## Project Shape

- `default.project.json` maps the repo into Roblox services for Rojo.
- `src/` contains the Roblox DataModel tree used by Rojo.
- `src/**/*.luau` contains scripts and modules.
- `src/**/*.model.json` contains simple instances such as remotes and values.
- `src/**/*.rbxm` contains complex Studio-authored assets such as models, terrain, VFX, UI, lighting children, and chat configuration.
- `tools/` contains repeatable export and verification helpers.
- `.github/workflows/roblox-ci.yml` validates and deploys the game.

## Codebase Digest

Server systems live in `src/ServerScriptService/Services`:

- `CombatServer` handles combat remotes and authoritative hit/combat behavior.
- `MovementServer` handles server-side movement/lunge behavior.
- `DemonSpawnerServer`, `NPCSpawnerServer`, and `TrainingDummyServer` create and manage world actors.
- `QuestServer`, `BountyServer`, and `LeaderboardServer` handle progression and player-facing systems.
- `SkillServer` connects skill activation to shared skill definitions.
- `ZoneServer` tracks zone changes.
- `DataStoreModule` owns player persistence.

Shared modules live in `src/ReplicatedStorage/Modules`:

- `CombatModule` centralizes combat constants and logic helpers.
- `PlayerDataModule` owns player data defaults and mutation helpers.
- `QuestDataModule` and `SkillSystemModule` define quest and skill behavior.
- `StatConfig` contains stat/faction rules.
- `EnemyAIModule` and `UIController` currently provide shared/stubbed interfaces.

Client controllers live in `src/StarterPlayer/StarterPlayerScripts/Controllers`:

- `CombatController` handles local combat input, effects, and remote calls.
- `MovementController` handles local movement/lunge input and state.
- `HUDController` builds and updates the main HUD.
- `QuestController` handles quest UI/interactions.
- `ControllerMapper` tracks input mode for keyboard/gamepad prompts.

Assets are intentionally source-controlled:

- `src/ReplicatedStorage/Assets`
- `src/ReplicatedStorage/VFXAssets`
- `src/ReplicatedStorage/NPCModels`
- `src/Workspace`
- `src/Lighting`
- `src/TextChatService`

Those `.rbxm` files preserve Studio-authored models, terrain, lighting children, VFX, UI, and chat settings.

## Local Development

Use Rojo to sync the filesystem into a local Roblox Studio session:

```powershell
rojo serve default.project.json
```

Then connect from the Rojo Studio plugin. Local Studio is for testing. VS Code and Git are the source of truth.

See [docs/DEV_ENVIRONMENT.md](docs/DEV_ENVIRONMENT.md) for full setup, Rojo usage, Lemonade/Studio asset import, and verification commands.

## Branch And Deploy Flow

```text
feature branch -> pull request -> dev -> staging place
main -> production place
```

- `dev` deploys to `Staging Env - Demon Blade 2`.
- `main` deploys to `Demon Blade 2 Publish`.
- Production should be protected with GitHub Environment approval.

See [docs/PULL_REQUESTS.md](docs/PULL_REQUESTS.md) for branch naming, PR expectations, checks, and merge rules.

## Bug Tracking

Use GitHub Issues for reproducible bugs and attach Studio Output logs for gameplay, data, inventory, movement, quest, and UI problems. See [docs/BUG_TRACKING.md](docs/BUG_TRACKING.md) for the bug template expectations, labels, and local multiplayer testing steps.

## Required Local Checks

Before accepting major Rojo changes or opening a PR:

```powershell
rojo build default.project.json -o build_check.rbxl
tools\lune\lune.exe run tools\compare_full_structure.luau
tools\lune\lune.exe run tools\compare_key_service_properties.luau
Remove-Item build_check.rbxl
```

The expected result is:

```text
Missing from build: 0
Extra in build: 0
Class changes: 0
Key service property mismatches: 0
```

## GitHub Secrets

Deployment uses Roblox Open Cloud keys stored as GitHub Actions secrets:

```text
STAGING_PLACE_ID
STAGING_UNIVERSE_ID
ROBLOXSTAGINGAPIKEY
PRODUCTION_PLACE_ID
PRODUCTION_UNIVERSE_ID
ROBLOXPRODUCTIONAPIKEY
```

Never commit real API keys.
