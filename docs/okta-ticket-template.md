# Okta OIDC Application — Freshservice Ticket Template

Copy-paste template for requesting a new Okta OIDC application through IT/Freshservice.

---

## How to File

1. Go to the Freshservice portal (IT service desk).
2. Create a new ticket under **IT Requests > Application Provisioning** (or similar category).
3. Copy the template below into the ticket body.
4. Fill in all bracketed fields.
5. Submit. If urgent, post in **#application-security** on Slack after filing.

---

## Ticket Template

**Subject:** New Okta OIDC Application — [app-name]

**Body:**

```
Requesting a new Okta OIDC application for an internal tool.

APP DETAILS
-----------
App name:           [app-name]
Description:        [1-2 sentence description of what the app does]
App owner:          [your name]
Team:               [your team name, e.g., DCT Ops, Platform Engineering]
GitHub repo:        [org/repo-name, e.g., coreweave/inventory-tracker]

APP TYPE
--------
[ ] Web Application (browser-based, has a UI)
[ ] CLI Tool (terminal-based, no browser)
[ ] Service-to-Service (backend calling backend, no user interaction)

GRANT TYPE
----------
[ ] Authorization Code + PKCE (web apps — user logs in via browser redirect)
[ ] Device Authorization (CLI tools — user approves on a separate device)
[ ] Client Credentials (service-to-service — no user involved)

REDIRECT URIs
-------------
Development:  http://localhost:8080/callback
Production:   https://[app-name].internal.coreweave.com/callback
Logout:       https://[app-name].internal.coreweave.com/ (optional)

Note: Add additional redirect URIs if the app runs on multiple ports or domains.

OKTA GROUPS (RBAC)
------------------
Please create the following Okta groups and assign them as group claims
in the OIDC app's ID token:

| Okta Group               | App Role   | Permissions                              |
|--------------------------|------------|------------------------------------------|
| cw-[app-name]-admins     | admin      | Full read/write, user management, config |
| cw-[app-name]-editors    | editor     | Read/write to app data, no admin access  |
| cw-[app-name]-viewers    | viewer     | Read-only access                         |

Group claim name: "groups" (include in both ID token and access token)

ADDITIONAL DETAILS
------------------
Expected users:     [approximate number, e.g., "~20 engineers on DCT team"]
Expected timeline:  [when you need this by, e.g., "before staging deploy next week"]
Existing app?:      [No — new app / Yes — replacing [old-app-name]]
Staging needed?:    [Yes — separate Okta app for staging / No — same app, different redirect URIs]

NOTES
-----
[Any additional context — e.g., "This app will also need access to the
cw-engineering Okta group for cross-team visibility" or "We need custom
claims for department and manager."]
```

---

## Example: Filled-In Ticket

**Subject:** New Okta OIDC Application — inventory-tracker

**Body:**

```
Requesting a new Okta OIDC application for an internal tool.

APP DETAILS
-----------
App name:           inventory-tracker
Description:        Web dashboard for tracking hardware inventory across data halls.
                    Shows rack locations, asset status, and pending RMAs.
App owner:          Romeo Patino
Team:               DCT Ops
GitHub repo:        coreweave/inventory-tracker

APP TYPE
--------
[x] Web Application (browser-based, has a UI)
[ ] CLI Tool (terminal-based, no browser)
[ ] Service-to-Service (backend calling backend, no user interaction)

GRANT TYPE
----------
[x] Authorization Code + PKCE (web apps — user logs in via browser redirect)
[ ] Device Authorization (CLI tools — user approves on a separate device)
[ ] Client Credentials (service-to-service — no user involved)

REDIRECT URIs
-------------
Development:  http://localhost:8080/callback
Staging:      https://inventory-tracker.staging.internal.coreweave.com/callback
Production:   https://inventory-tracker.internal.coreweave.com/callback
Logout:       https://inventory-tracker.internal.coreweave.com/

OKTA GROUPS (RBAC)
------------------
Please create the following Okta groups and assign them as group claims
in the OIDC app's ID token:

| Okta Group                        | App Role   | Permissions                              |
|-----------------------------------|------------|------------------------------------------|
| cw-inventory-tracker-admins       | admin      | Full CRUD, user management, bulk import  |
| cw-inventory-tracker-editors      | editor     | Create/edit assets, no delete or admin   |
| cw-inventory-tracker-viewers      | viewer     | Read-only dashboard access               |

Group claim name: "groups" (include in both ID token and access token)

ADDITIONAL DETAILS
------------------
Expected users:     ~30 (DCT team + site leads at EVI01 and other sites)
Expected timeline:  Need by April 25 for staging deploy
Existing app?:      No — new app
Staging needed?:    Yes — separate Okta app for staging environment

NOTES
-----
Members of the existing cw-dct-ops Okta group should be auto-added to
cw-inventory-tracker-viewers. Admins will be manually assigned.
```

---

## After You Get the Credentials

Once IT provisions the Okta app, you will receive:

- **Client ID** — goes in Doppler as `OKTA_CLIENT_ID`
- **Client Secret** — goes in Doppler as `OKTA_CLIENT_SECRET` (not applicable for public clients using PKCE only)
- **Issuer URL** — typically `https://coreweave.okta.com/oauth2/default`

Store these in Doppler, not in `.env` files or code. See [Doppler Onboarding](doppler-onboarding.md) for setup instructions.

For local development, add to your `.env` file:

```bash
OKTA_ISSUER=https://coreweave.okta.com/oauth2/default
OKTA_CLIENT_ID=your-client-id-here
OKTA_CLIENT_SECRET=your-client-secret-here  # Only for confidential clients
OKTA_AUDIENCE=api://inventory-tracker
```

Never commit `.env` to git. The template's `.gitignore` already excludes it.
