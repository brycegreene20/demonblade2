# Reserved Roblox Deployment Secrets

The current GitHub workflow validates code but does not deploy places.

Direct `rojo upload default.project.json` is intentionally disabled because the snowy `Workspace` is Studio-owned and absent from the Rojo project. Uploading that code-only project would replace the destination place without its map.

Publish staging and production through Roblox Studio:

1. Open the existing snowy target place.
2. Connect `rojo serve default.project.json`.
3. Test and confirm `Workspace` is unchanged.
4. Use **Publish to Roblox**.

The existing Open Cloud secrets can remain reserved for a future deployment pipeline that merges managed code into a verified snowy base place before upload.
