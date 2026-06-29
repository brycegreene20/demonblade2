# Development Environment

This guide explains how to work on DemonBlade2 locally without breaking the Roblox Studio place or other developers.

## Mental Model

```text
VS Code + Git = source of truth for code and managed assets
Roblox Studio = source of truth for the snowy Workspace map
Rojo serve = local sync from VS Code into Studio
Roblox Studio = map editing, testing, and publishing
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

For complex managed assets outside `Workspace`:

1. Edit or prototype in Studio.
2. Save the place to `DemonBlade2.rbxl`.
3. Export only the required managed assets back into `src`.
4. Verify the Rojo build.
5. Commit the exported `.rbxm` files.

## Exporting Studio/Lemonade Changes Back To VS Code

Use this when Lemonade or Studio creates non-script instances you want to keep.

From the repo root:

```powershell
tools\lune\lune.exe run tools\export_non_scripts_from_rbxl.luau
```

Do not copy the snowy map into `src/Workspace` during normal development. `Workspace` is intentionally absent from the Rojo path mapping and remains in Studio.

Then verify:

```powershell
rojo build default.project.json -o build_check.rbxl
tools\lune\lune.exe run tests\unit\run.luau
Remove-Item build_check.rbxl
```

Expected result:

```text
UnitTests: all passing
Built project to build_check.rbxl
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

## Collaborative Map Workflow

Use this when a map designer needs to build in Studio without touching code, and the lead developer needs to merge their map with the latest scripts.

### Setup (one time)

Add the map designer as a collaborator on create.roblox.com:

```
Experience → Settings → Collaborators → Add by username → Edit access
```

### Map designer flow

1. File > Open from Roblox → select the shared experience
2. Build the map in Workspace only — do not edit scripts, ReplicatedStorage, or other services
3. File > Save to Roblox when done

### Lead developer merge flow

1. File > Open from Roblox → select the shared experience (loads designer's map)
2. Run `rojo serve default.project.json` in terminal
3. Connect Rojo plugin in Studio — latest scripts sync in on top of the map
4. Verify everything looks correct in Studio
5. File > Save to Roblox to lock in the combined state (map + code)
6. Save `DemonBlade2.rbxl` locally and commit

### Important rules

- Map designer owns Workspace only — terrain, props, decorations
- Lead developer owns all scripts and ReplicatedStorage
- Rojo is one-way (filesystem → Studio) so it will correct any accidental script changes from the designer's save
- Never have two people connected to Rojo serve at the same time against the same place

### Map assets — free from Toolbox

You don't need to create every map asset from scratch. Roblox's Toolbox has a large library of free, community-made assets:

- In Studio, open the **Toolbox** panel (View → Toolbox)
- Search for trees, rocks, buildings, terrain props, terrain kits, etc.
- Filter by **Free** to avoid paid assets
- Insert directly into Workspace — no export needed

Recommended searches for this game's aesthetic:
- `Japanese village`, `feudal Japan`, `samurai ruins` — environment props
- `forest terrain`, `snow terrain kit` — terrain packs
- `demon`, `monster` — NPC templates (check rig type before using)

Always check the asset's rig type (R6 vs R15) before committing to it for animated characters.

## Blender Animation Import Workflow

Use this to create a custom animation in Blender, import it into Roblox Studio, and get a reusable asset ID for use in scripts.

### Step 1 — Create the animation in Blender

- Rig and animate your character in Blender
- When done, export as **FBX** (File > Export > FBX)
- Make sure "Armature" and "Baked Animation" are included in the export settings

### Step 2 — Get an R15-compatible rig in Studio

You need a rig with the same bone structure as your animation target (R15 for standard humanoids):

- From the **Toolbox** sidebar, search "Dummy" and insert an R15 Dummy into the workspace, OR
- Use any existing NPC/character rig already in your workspace

The rig must be **R15** (has LowerTorso, UpperTorso, limb bones). R6 rigs will not work with R15 animations.

### Step 3 — Open the Animation Editor

1. **Click the rig** in the viewport to select it
2. Go to the **Avatar** tab in the Studio toolbar
3. Click **Clip Editor** — this opens the Animation Editor panel at the bottom

> "Clip Editor" and "Animation Editor" are the same thing. The button is labeled Clip Editor; the panel title says Animation Editor.

### Step 4 — Import the FBX animation

1. In the Animation Editor panel, click the **...** menu (top-left of the panel)
2. Select **Import** → browse to your `.fbx` file
3. The animation keyframes load into the timeline

### Step 5 — Test the animation

- Press **Play** in the Animation Editor to preview on the rig
- Toggle **Loop** to check it loops cleanly
- Scrub the timeline to inspect individual frames
- If the animation looks wrong, go back to Blender and re-export

### Step 6 — Publish to Roblox

1. In the Animation Editor, click **...** → **Save to Roblox**
2. Give it a clear name (e.g. `DemonSlayer_Walk`)
3. Click save — Roblox uploads it and returns an **asset ID**

The asset ID looks like: `rbxassetid://1234567890`

### Step 7 — Use the asset ID in scripts

```lua
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://1234567890"
local track = humanoid:LoadAnimation(anim)
track:Play()
```

The same asset ID works on **any R15-compatible rig** across the codebase — NPCs, players, dummies. You only publish once.

### Applying the asset ID to any rig in code

Once published, the animation asset ID works on **any rig that has a Humanoid** — players, NPCs, dummies — as long as the bone structure matches. Wire it in scripts like this:

```lua
local anim = Instance.new("Animation")
anim.AnimationId = "rbxassetid://YOUR_ASSET_ID_HERE"
local track = humanoid:LoadAnimation(anim)
track:Play()          -- start playing
track:Stop()          -- stop
track.Looped = true   -- set before Play() for looping animations
```

For NPCs, load the track once on spawn and store it on the NPC state table so the AI loop can call `Play()`/`Stop()` based on movement state (idle, walk, attack).

### Animation complexity tiers

| Tier | Use | Tool |
|---|---|---|
| **Simple** | Walk, idle, run — looping movement cycles | Free Roblox animations from Toolbox, or Roblox's default Animate script |
| **Intermediate** | Custom poses, ability animations, NPC attacks | Create in Blender (current workflow above) |
| **Complex** | Realistic full-body motion, cutscenes, finishers | [DeepMotion / SayMotion](https://www.deepmotion.com) — record video or describe motion in text, outputs FBX |

**SayMotion** is DeepMotion's text-to-animation product: type a description like "demon lunges forward and slashes downward" and it generates the animation. Use this for complex NPC attack animations without manual keyframing.

All tiers export FBX and follow the same import workflow above (Steps 3–7).

### Notes

- The Dummy used for testing can be deleted from the workspace after publishing; it served as a preview rig only
- If the animation looks distorted on the target NPC, the NPC rig may have a different bone structure — compare with the Dummy
- glTF (`.glb`) is also supported as an import format if you prefer it over FBX

## 3D Asset Generation Workflow

Use this when you need a character, NPC, weapon, or prop that doesn't exist in the Toolbox.

### Free assets — Roblox Toolbox

Before generating anything, check the Toolbox first:

- View → Toolbox → filter by **Free**
- Search by type: `demon NPC`, `sword`, `Japanese lantern`, `rock prop`, etc.
- Works for static props, simple NPCs, and environment assets
- Limitation: most Toolbox NPCs are R6 — check before committing to one for animation

### AI-generated assets — when Toolbox isn't enough

Use AI generation when you need a custom character or item that doesn't exist in the Toolbox, or when you need R15 rigging for animation support.

| Tool | Best for | Rigging |
|---|---|---|
| **[Nilo](https://nilo.io)** | Roblox-style characters and NPCs, full pipeline in one tab | R15 and R6, one-click |
| **[Meshy](https://www.meshy.ai)** | High-quality PBR textures, broader asset types, native Roblox Bridge export | Auto-rig, may need cleanup |

### When to use each

- **New NPC or enemy character** → Nilo (Roblox-style output, R15 rigged, no Blender step needed)
- **Weapon, armor, or detailed prop** → Meshy (better texture quality for items)
- **Quick test placeholder** → Toolbox dummy, swap the mesh later

### Exporting into the codebase

1. Generate the model in Nilo or Meshy
2. Export as `.fbx` or `.glb`
3. In Studio: import via **Avatar → Rig Builder** (for skinned characters) or drag into workspace (for props)
4. Right-click in Explorer → **Save to File** → save as `.rbxm`
5. Place the `.rbxm` in `src/ReplicatedStorage/Assets/` and commit

For R15 rigged characters: verify the exported model has `LowerTorso`, `UpperTorso`, `HumanoidRootPart` before wiring animations to it.

## Deployment Environments

Use three Roblox environments:

```text
Local Studio place: individual developer testing
Staging Env - Demon Blade 2: manually published after dev validation
Demon Blade 2 Publish: manually published after main validation
```

Local development should not publish directly to production.

### Map-preserving publish flow

1. Open the existing snowy staging or production place from Roblox.
2. Run `rojo serve default.project.json`.
3. Connect Rojo and verify that `Workspace` is unchanged.
4. Test the game in Studio.
5. Use **File > Publish to Roblox** for that same place.

Do not use `rojo upload default.project.json`. It publishes a complete code-only place and cannot preserve a `Workspace` that is intentionally owned only by Studio.

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

Compare managed non-Workspace services when investigating asset drift:

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

3. The snowy `Workspace` is real project data but deliberately remains Studio-owned.
4. If Rojo proposes deleting snowy terrain, village props, or map geometry, stop. `Workspace` should have `$ignoreUnknownInstances: true` and no `$path`.

## Files That Matter

- `default.project.json`: Rojo DataModel map and service properties.
- `DemonBlade2.rbxl`: source Studio place used by comparison/export tools.
- `src/`: source-controlled Roblox tree.
- `tools/export_non_scripts_from_rbxl.luau`: exports non-script Studio data.
- `tools/compare_full_structure.luau`: verifies instance parity.
- `tools/compare_key_service_properties.luau`: verifies important service properties.
- `.github/workflows/roblox-ci.yml`: CI/CD.
