# Pull Request Workflow

This guide explains how developers should branch, test, open PRs, and merge changes for DemonBlade2.

## Branch Strategy

Use this flow:

```text
feature branch -> PR -> dev -> Studio staging publish -> main -> Studio production publish
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
tools\lune\lune.exe run tests\unit\run.luau
rojo build default.project.json -o build_check.rbxl
Remove-Item build_check.rbxl
```

Expected result:

```text
UnitTests: all passing
Built project to build_check.rbxl
```

If you changed Studio assets or used Lemonade, also run:

```powershell
tools\lune\lune.exe run tools\export_non_scripts_from_rbxl.luau
```

Do not export or map the snowy `Workspace`; it remains Studio-owned.

## CI Checks

GitHub Actions validates PRs into `dev` and `main`.

The workflow:

- installs Rojo,
- installs Selene,
- installs Lune,
- lints Luau with Selene,
- builds the Rojo project,
- generates a sourcemap,
- checks managed non-Workspace structure,
- uploads a build artifact.

Do not merge a PR while CI is failing.

## PR Description Template

Use this structure:

```markdown
## Summary
Briefly describe the change.

## Testing
- [ ] Ran `tools\lune\lune.exe run tests\unit\run.luau`
- [ ] Ran `rojo build default.project.json -o build_check.rbxl`
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

When a PR merges to `dev`, GitHub Actions validates the code. Then publish it to:

```text
Staging Env - Demon Blade 2
```

Staging publish flow:

1. Open the existing snowy staging experience in Studio.
2. Run `rojo serve default.project.json` and connect Rojo.
3. Confirm the snowy `Workspace` is unchanged.
4. Smoke test the changed feature and watch Output.
5. Use **Publish to Roblox** for the staging place.

## Promoting To Main

After staging is good:

1. Open a PR from `dev` to `main`.
2. Confirm CI passes.
3. Get review/approval.
4. Merge to `main`.
5. Open the existing snowy production experience in Studio.
6. Connect Rojo, verify the map, run the production smoke test, and publish to:

```text
Demon Blade 2 Publish
```

Do not run `rojo upload default.project.json`; it does not contain the Studio-owned `Workspace`.

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
4. Keep `Workspace` Studio-owned with no Rojo `$path`.
5. Rerun unit tests and the Rojo build.

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
