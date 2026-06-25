# Roblox Deployment Secrets

Add these in GitHub:

`Settings -> Secrets and variables -> Actions -> New repository secret`

## Staging

These deploy the `dev` branch to `Staging Env - Demon Blade 2`.

```text
STAGING_PLACE_ID=93615741926072
STAGING_UNIVERSE_ID=10392501904
ROBLOXSTAGINGAPIKEY=<create this in Roblox Open Cloud>
```

## Production

These deploy the `main` branch to `Demon Blade 2 Publish`.

```text
PRODUCTION_PLACE_ID=89198012995322
PRODUCTION_UNIVERSE_ID=10392511415
ROBLOXPRODUCTIONAPIKEY=<create this in Roblox Open Cloud>
```

Do not commit real API keys. Store them only as GitHub Actions secrets.
