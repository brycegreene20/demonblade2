# DemonBlade2 Studio Asset Import Checklist

Current status from VS Code/Rojo:

- `src/ReplicatedStorage/Remotes` has 34 `.model.json` remotes.
- `src/ReplicatedStorage/InputMode.model.json` exists.
- `src/ReplicatedStorage/Assets`, `NPCModels`, and `VFXAssets` contain exported `.rbxm` model files from `DemonBlade2.rbxl`.
- `src/Lighting` is mapped in `default.project.json` and contains exported `.rbxm` lighting instances.
- The snowy `Workspace` remains Studio-owned and is not mapped by Rojo.
- Script fixes are in `.luau` files, so do not overwrite scripts from Studio.

Automated export path:

1. Run `tools/lune/lune.exe run tools/export_non_scripts_from_rbxl.luau`.
2. Run `tools/lune/lune.exe run tests/unit/run.luau`.
3. Run `rojo build default.project.json -o build_check.rbxl`.

Safe import path:

1. Copy `tools/export_non_script_assets.plugin.luau` to `%LOCALAPPDATA%/Roblox/Plugins/`.
2. Restart Roblox Studio or reload local plugins.
3. Open `DemonBlade2.rbxl`.
4. Use the `DemonBlade2 Export` toolbar buttons.
5. Save the exported files somewhere outside `src` first, for example `assets/exported/`.
6. After export, copy/move only non-script `.rbxm` assets into the matching Rojo folders.

Recommended targets:

- `ReplicatedStorage_NonScripts.rbxm`: contains `Assets`, `NPCModels`, and `VFXAssets`.
- `ServerStorage_NonScripts.rbxm`: contains non-script ServerStorage children such as `Enemies`, `Templates`, and `Weapons`.
- `StarterGui_NonScripts.rbxm`: contains any Studio-built UI not already represented by scripts.
- Do not move `Workspace_NonScripts.rbxm` into `src`; keep map changes in the snowy Roblox place.

Important:

- Keep the fixed `.luau` scripts from VS Code as the source of truth.
- Keep snowy terrain, village props, and map geometry in Studio.
- Keep `Workspace.$ignoreUnknownInstances` enabled and do not add a Workspace `$path`.
- Do not run an old script extractor that overwrites `.luau` files from `DemonBlade2.rbxl`.
- Before replacing any existing folder under `src`, confirm it has no `.luau` or `.model.json` files inside.
