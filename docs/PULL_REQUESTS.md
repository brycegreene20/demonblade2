# Pull Request Workflow

This guide explains how developers should branch, test, open PRs, and merge changes for DemonBlade2.

## Branch Strategy

Use this flow:

```text
feature branch -> PR -> dev -> staging deploy -> main -> production deploy
```

Recommended branch names:

```text
feature/combat-parry-window
fix/demon-spawn-crash
ui/hud-leaderboard-polish
asset/forest-demon-vfx
```

Avoid committing directly to `main`. Prefer PRs for all meaningful changes.

## Before You Start Work

Update your local repo:

```powershell
git checkout main
git pull
git checkout -b feature/my-change
```

For team work, create branches from the current shared base. If the team uses `dev` as the integration branch, create feature branches from `dev` instead:

```powershell
git checkout dev
git pull
git checkout -b feature/my-change
```

## What Belongs In A PR

A PR should include one coherent change:

- one feature,
- one bug fix,
- one asset import,
- or one refactor with a clear reason.

Avoid mixing unrelated code, assets, formatting, and pipeline changes in one PR.

## Required Local Checks

Before opening a PR, run:

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

If you changed Studio assets or used Lemonade, also run:

```powershell
tools\lune\lune.exe run tools\export_non_scripts_from_rbxl.luau
tools\lune\lune.exe run tools\export_workspace_duplicate_scripts.luau
```

Then rerun the verification checks.

## CI Checks

GitHub Actions validates PRs into `dev` and `main`.

The workflow:

- installs Rojo,
- installs Selene,
- installs Lune,
- lints Luau with Selene,
- builds the Rojo project,
- generates a sourcemap,
- verifies non-script structure,
- verifies full structure,
- verifies important service properties,
- uploads a build artifact.

Do not merge a PR while CI is failing.

## PR Description Template

Use this structure:

```markdown
## Summary
Briefly describe the change.

## Testing
- [ ] Ran `rojo build default.project.json -o build_check.rbxl`
- [ ] Ran `tools\lune\lune.exe run tools\compare_full_structure.luau`
- [ ] Ran `tools\lune\lune.exe run tools\compare_key_service_properties.luau`
- [ ] Tested locally in Roblox Studio through Rojo

## Studio / Asset Changes
List any `.rbxm`, `.model.json`, or `default.project.json` changes.

## Risk
Mention gameplay, data, deployment, or asset risks.
```

## Reviewing PRs

Reviewers should check:

- Does the PR solve one clear problem?
- Are `.luau` changes readable and scoped?
- Are `.rbxm` asset changes intentional?
- Did `default.project.json` preserve service properties and avoid unsafe deletes?
- Does CI pass?
- Was the change tested in Studio through Rojo?

For server or data changes, be extra careful around:

- `DataStoreModule`
- player data shape,
- combat remotes,
- quest/bounty progression,
- deployment workflow changes.

## Merging To Dev

When a PR merges to `dev`, GitHub Actions deploys to:

```text
Staging Env - Demon Blade 2
```

After staging deploys:

1. Open the staging Roblox experience.
2. Smoke test the changed feature.
3. Watch the Output window for runtime errors.
4. Confirm core loops still work: spawn, HUD, movement, combat, quests, enemies.

## Promoting To Main

After staging is good:

1. Open a PR from `dev` to `main`.
2. Confirm CI passes.
3. Get review/approval.
4. Merge to `main`.
5. GitHub deploys to:

```text
Demon Blade 2 Publish
```

Production should use GitHub Environment approval so publishing requires an explicit human approval step.

## Handling Conflicts

For `.luau` conflicts:

1. Resolve in VS Code.
2. Keep the clearest current behavior.
3. Rerun local checks.

For `.rbxm` conflicts:

1. Decide which Studio asset version is correct.
2. Re-export from the correct `.rbxl` if needed.
3. Do not hand-edit binary `.rbxm` files.

For `default.project.json` conflicts:

1. Preserve service mappings.
2. Preserve `$properties` that protect Studio parity.
3. Preserve `$ignoreUnknownInstances` on visual-only/runtime services.
4. Rerun full structure and property checks.

## What Not To Commit

Do not commit:

- Roblox API keys,
- local temporary build outputs like `build_check.rbxl`,
- generated `sourcemap.json`,
- personal Studio/editor files,
- secrets or credentials.

The real project `.rbxm` files under `src` are source files and should be committed.

## Emergency Fix Flow

For urgent fixes:

1. Branch from `main`.
2. Make the smallest safe change.
3. Run local checks.
4. Open PR to `main`.
5. Require review unless production is fully blocked.
6. After merge, cherry-pick or merge back to `dev` if needed.
