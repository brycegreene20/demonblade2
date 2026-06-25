# Development Environment

This guide explains how to work on DemonBlade2 locally without breaking the Roblox Studio place or other developers.

## Mental Model

```text
VS Code + Git = source of truth
Rojo serve = local sync from VS Code into Studio
Roblox Studio = testing and visual editing
Lemonade -> Studio = prototype path
tools/export... = controlled Studio back to VS Code path
```

Rojo is mostly one-way during day-to-day work:

```text
filesystem -> Rojo -> Roblox Studio
```

There is no normal live `rojo pull` flow. If Studio or Lemonade creates something you want to keep, export it back into the repo deliberately.

## Prerequisites

Install or have available:

- Roblox Studio
- Rojo 7.6.1
- Git
- VS Code
- Rojo Studio plugin

This repo also includes a local Lune binary at:

```text
tools/lune/lune.exe
```

The verification and export scripts use that local binary.

## First-Time Setup

1. Clone the repo.

```powershell
git clone https://github.com/brycegreene20/demonblade2.git
cd demonblade2
```

2. Open the folder in VS Code.

3. Open Roblox Studio with your local testing place.

4. Start Rojo from the repo root.

```powershell
rojo serve default.project.json
```

5. In Roblox Studio, open the Rojo plugin and connect to the local server.

6. When Rojo previews changes, inspect the delete/update list before accepting.

Do not accept changes that delete runtime instances such as:

```text
Players/<your player>
NetworkClient/ClientReplicator
```

Those are runtime/local Studio instances. The project file uses `$ignoreUnknownInstances` for visual-only services so Rojo should preserve them.

## Local Testing Flow

For code changes:

1. Edit `.luau`, `.model.json`, or project files in VS Code.
2. Let Rojo sync into Studio.
3. Test in Studio.
4. Commit the repo changes.

For complex Studio assets:

1. Edit or prototype in Studio.
2. Save the place to `DemonBlade2.rbxl`.
3. Export Studio assets back into `src`.
4. Verify the Rojo build matches the Studio place.
5. Commit the exported `.rbxm` files.

## Exporting Studio/Lemonade Changes Back To VS Code

Use this when Lemonade or Studio creates non-script instances you want to keep.

From the repo root:

```powershell
tools\lune\lune.exe run tools\export_non_scripts_from_rbxl.luau
tools\lune\lune.exe run tools\export_workspace_duplicate_scripts.luau
```

The first script exports non-script services and assets into `.rbxm` files. The second preserves the duplicate `Workspace.Script` that exists in the original place.

Then verify:

```powershell
rojo build default.project.json -o build_check.rbxl
tools\lune\lune.exe run tools\compare_full_structure.luau
tools\lune\lune.exe run tools\compare_key_service_properties.luau
Remove-Item build_check.rbxl
```

Expected result:

```text
Missing from build: 0
Extra in build: 0
Class changes: 0
Key service property mismatches: 0
```

## Script Changes From Studio Or Lemonade

Do not blindly overwrite `.luau` scripts from Studio.

Recommended flow:

1. Prototype in Studio or Lemonade.
2. Copy script changes into the matching `.luau` file manually.
3. Review the diff in Git.
4. Run Rojo and tests/checks.

This protects previous lint/type fixes and avoids accidental script drift.

## Important Rojo Details In This Repo

The project preserves service-level properties in `default.project.json`, including:

- Lighting visual settings
- `Players.RespawnTime`
- `SoundService.RespectFilteringEnabled`
- `StarterPlayer.CharacterUseJumpPower`

Several empty/default services are mapped for visual completeness:

- `Players`
- `MaterialService`
- `NetworkClient`
- `StarterPack`
- `Teams`
- `SoundService`

These use `$ignoreUnknownInstances` so Rojo does not delete runtime children.

## Deployment Environments

Use three Roblox environments:

```text
Local Studio place: individual developer testing
Staging Env - Demon Blade 2: deployed from dev
Demon Blade 2 Publish: deployed from main
```

Local development should not publish directly to production.

## Common Commands

Start local sync:

```powershell
rojo serve default.project.json
```

Build a local place:

```powershell
rojo build default.project.json -o build_check.rbxl
```

Generate sourcemap:

```powershell
rojo sourcemap default.project.json --include-non-scripts -o sourcemap.json
```

Compare Studio place and Rojo build:

```powershell
tools\lune\lune.exe run tools\compare_full_structure.luau
tools\lune\lune.exe run tools\compare_key_service_properties.luau
```

Clean temporary build:

```powershell
Remove-Item build_check.rbxl
```

## Troubleshooting Rojo Deletes

If Rojo says it will delete something:

1. Identify whether it is a real source-controlled object or runtime/local Studio state.
2. Runtime examples that should not be source-controlled:

```text
Players/<player name>
NetworkClient/ClientReplicator
```

3. Real project data should be represented under `src` or in `default.project.json`.
4. If accepting Rojo would delete real project data, stop and export/map it first.

## Files That Matter

- `default.project.json`: Rojo DataModel map and service properties.
- `DemonBlade2.rbxl`: source Studio place used by comparison/export tools.
- `src/`: source-controlled Roblox tree.
- `tools/export_non_scripts_from_rbxl.luau`: exports non-script Studio data.
- `tools/compare_full_structure.luau`: verifies instance parity.
- `tools/compare_key_service_properties.luau`: verifies important service properties.
- `.github/workflows/roblox-ci.yml`: CI/CD.
