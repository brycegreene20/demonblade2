# Reserved Roblox Deployment Secrets

The current GitHub workflow validates code but does not deploy places.

Direct `rojo upload default.project.json` is intentionally disabled because the snowy `Workspace` is Studio-owned and absent from the Rojo project. Uploading that code-only project would replace the destination place without its map.

Branch/environment ownership:

| Merged branch | Environment that receives the merged code and manual map publish |
| --- | --- |
| `dev` | Staging Env - Demon Blade 2 |
| `main` | Demon Blade 2 Publish |

The code deployment and the map publish are separate operations. Merging updates the code branch, but it cannot carry the latest Studio-owned map. A developer must manually open the corresponding environment after the merge and publish that environment's current map with the merged code.

Publish staging and production through Roblox Studio:

1. Check out `dev` for staging or `main` for production.
2. Open the corresponding existing snowy target place.
3. Confirm that the target contains the latest approved map.
4. Connect `rojo serve default.project.json`.
5. Test and confirm `Workspace` is unchanged.
6. Manually use **Publish to Roblox** for that same target place.

The existing Open Cloud secrets can remain reserved for a future deployment pipeline that merges managed code into a verified snowy base place before upload.
