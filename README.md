# DemonBlade2

DemonBlade2 is a Roblox experience developed with VS Code, Git, and Rojo. The repository is the source of truth for code and managed assets. The authored snowy `Workspace` remains Studio-owned.

## Project Shape

- `default.project.json` maps the repo into Roblox services for Rojo.
- `src/` contains the Roblox DataModel tree used by Rojo.
- `src/**/*.luau` contains scripts and modules.
- `src/**/*.model.json` contains simple instances such as remotes and values.
- `src/**/*.rbxm` contains managed assets such as models, VFX, UI, lighting children, and chat configuration.
- `tools/` contains repeatable export and verification helpers.
- `.github/workflows/roblox-ci.yml` validates the code project.

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
- `src/Lighting`
- `src/TextChatService`

The snowy terrain, village, trees, and map props stay in the Roblox place's `Workspace`. `default.project.json` deliberately does not map `src/Workspace`.

## Local Development

Use Rojo to sync the filesystem into a local Roblox Studio session:

```powershell
rojo serve default.project.json
```

Open the snowy local place first, then connect from the Rojo Studio plugin. Rojo updates managed code without replacing the Studio-owned `Workspace`.

See [docs/DEV_ENVIRONMENT.md](docs/DEV_ENVIRONMENT.md) for full setup, Rojo usage, Lemonade/Studio asset import, and verification commands.

## Branch And Deploy Flow

```text
feature branch -> pull request -> dev -> validate -> Studio staging publish
main -> validate -> Studio production publish
```

- GitHub Actions validates `dev` and `main`.
- Publish by opening the correct snowy place in Studio, connecting Rojo, testing, and using **Publish to Roblox**.
- Direct `rojo upload default.project.json` is disabled because it would publish a complete place without the Studio-owned map.

See [docs/PULL_REQUESTS.md](docs/PULL_REQUESTS.md) for branch naming, PR expectations, checks, and merge rules.

## Bug Tracking

Use GitHub Issues for reproducible bugs and attach Studio Output logs for gameplay, data, inventory, movement, quest, and UI problems. See [docs/BUG_TRACKING.md](docs/BUG_TRACKING.md) for the bug template expectations, labels, and local multiplayer testing steps.

## Required Local Checks

Before accepting major Rojo changes or opening a PR:

```powershell
tools\lune\lune.exe run tests\unit\run.luau
rojo build default.project.json -o build_check.rbxl
Remove-Item build_check.rbxl
```

The expected result is:

```text
UnitTests: all passing
Built project to build_check.rbxl
```

Open Cloud deployment secrets are reserved for a future map-preserving deployment process. They are not used by the current validation-only workflow.
