# Doppler Onboarding

How to set up Doppler secret management for your CW application, from project creation to production deployment.

---

## Naming Conventions

### Project name

Format: `[team]-[app-name]`

Examples:
- `dct-inventory-tracker`
- `platform-deploy-bot`
- `infra-node-health`

Use lowercase, hyphens only, no underscores. The team prefix groups related projects in the Doppler dashboard and makes ownership obvious.

### Config names

Every Doppler project gets exactly three configs. Use these names — no aliases, no variations:

| Config | Purpose |
|--------|---------|
| `dev` | Local development and CI test runs |
| `stg` | Staging / pre-production environment |
| `prod` | Production |

Do not use `development`, `staging`, `production`, `local`, `test`, or custom names. The Helm chart and ESO manifests in this template expect `dev`, `stg`, and `prod`.

---

## Baseline Secrets

Every application needs at minimum these secrets in each config:

| Secret | Description | Example value |
|--------|-------------|---------------|
| `OKTA_CLIENT_ID` | Okta OIDC client ID for your app | `0oa1abc2def3ghi4j5k6` |
| `OKTA_CLIENT_SECRET` | Okta OIDC client secret (confidential clients only) | `AbCdEfGhIjKlMnOpQrStUvWxYz012345` |
| `DATABASE_URL` | Database connection string (if applicable) | `postgres://user:pass@host:5432/dbname?sslmode=require` |

Add additional secrets as needed — API keys for third-party services, signing keys, feature flags, etc. Every secret that differs between environments belongs in Doppler. If a value is the same across all environments, it is probably a config constant and should live in code, not Doppler.

---

## Step-by-Step Onboarding

### 1. Create the Doppler project

1. Go to the Doppler web UI (doppler.com or your CW Doppler org).
2. Click **Projects > New Project**.
3. Name it following the convention: `[team]-[app-name]` (e.g., `dct-inventory-tracker`).

### 2. Add configs

Doppler auto-creates `dev`, `stg`, and `prod` configs in new projects. If they are missing:

1. Inside your project, click **Configs > Add Config**.
2. Create `dev`, `stg`, and `prod`.

### 3. Add secrets to each config

1. Select the `dev` config.
2. Click **Add Secret** for each variable your app needs.
3. Repeat for `stg` and `prod` with environment-appropriate values.

Values that differ per environment:
- `DATABASE_URL` — different host/credentials per environment
- `OKTA_CLIENT_ID` / `OKTA_CLIENT_SECRET` — separate Okta apps for staging vs. production (if applicable)
- Feature flags, log levels, etc.

Values that are the same across environments:
- `OKTA_ISSUER` — typically `https://coreweave.okta.com/oauth2/default` everywhere

### 4. Grant cluster service account access

For your Kubernetes cluster to read secrets from Doppler via External Secrets Operator (ESO):

1. In the Doppler project, go to **Access > Service Tokens**.
2. Create a service token scoped to the config your cluster needs (e.g., `prod` for the production cluster).
3. Copy the token.
4. Store it as a Kubernetes secret that ESO references (your cluster admin or platform team can help with this step).

If you are using the CW shared cluster, the platform team may have a standard service account already provisioned. Ask in **#platform-engineering** before creating new tokens.

### 5. Update Helm values

In your `deploy/helm/values.yaml`, set the Doppler project and config names:

```yaml
doppler:
  project: "dct-inventory-tracker"    # Your Doppler project name
  config: "production"                 # Matches the target environment
```

If you use per-environment values files (`values-staging.yaml`, `values-production.yaml`), override the config name in each:

```yaml
# values-staging.yaml
doppler:
  config: "stg"

# values-production.yaml
doppler:
  config: "prod"
```

### 6. Deploy

When the app deploys, ESO reads the Doppler config and materializes the secrets as a Kubernetes Secret object. Your pod mounts them as environment variables automatically — no code changes needed.

Verify secrets are available after deploy:

```bash
# Check that the ExternalSecret synced successfully
kubectl get externalsecret -n your-namespace

# The STATUS column should show "SecretSynced"
```

---

## Dev-Cluster Gotcha

New Doppler projects may not be accessible from the dev cluster immediately. If ESO fails to sync with an "access denied" or "project not found" error:

1. Confirm the service token is scoped to the correct config.
2. Check if the dev cluster's ESO instance has been whitelisted for your Doppler project. New projects sometimes require IT to explicitly grant access.
3. File an IT ticket or ask in **#platform-engineering** to whitelist the project for the dev cluster.

This is a one-time setup per Doppler project per cluster. Once whitelisted, it works automatically.

---

## Local Development

For local development, do NOT install the Doppler CLI and pipe secrets through it. Instead:

1. Copy secrets from the Doppler `dev` config into a local `.env` file.
2. Use `python-dotenv` (Python) or `godotenv` (Go) to load them.
3. Never commit `.env` to git (the template `.gitignore` already excludes it).

```bash
# .env (local only — never committed)
OKTA_ISSUER=https://coreweave.okta.com/oauth2/default
OKTA_CLIENT_ID=0oa1abc2def3ghi4j5k6
OKTA_CLIENT_SECRET=AbCdEfGhIjKlMnOpQrStUvWxYz012345
DATABASE_URL=postgres://localhost:5432/myapp_dev
```

Why not the Doppler CLI locally? It works, but it adds a dependency that other team members may not have installed. A `.env` file is universal, and the `.env.example` in this template documents every required variable with placeholder values.

---

## Common Mistakes

### Putting the wrong secrets in the wrong config

Double-check that production database credentials are in `prod`, not `dev`. Doppler does not warn you if a `prod` config points to a dev database.

### Forgetting to grant cluster service account access

Symptom: ESO shows `SecretSyncedError` or the pod starts with empty environment variables. Fix: create a service token in Doppler and ensure the cluster's ESO can access it.

### Using Doppler CLI locally instead of .env

Not wrong per se, but it creates friction for teammates. Stick with `.env` for local dev and Doppler for deployed environments.

### Creating non-standard config names

Using `production` instead of `prod`, or `local` instead of `dev`, will break the Helm values and ESO references in this template. Always use `dev`, `stg`, `prod`.

### Storing non-secret config in Doppler

Feature flags, log levels, and app-mode toggles are not secrets. Put them in Helm values or environment-specific config files, not Doppler. Reserve Doppler for values that must never appear in git.
