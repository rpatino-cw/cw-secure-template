# Glob: **/frontend/**,**/static/**,**/templates/**,**/public/**,**/*.html,**/*.css,**/*.jsx,**/*.tsx,**/*.vue,**/*.svelte

## Frontend — What Belongs Here

Frontend code lives in `frontend/`. It talks to the backend through the API. Period.

### Allowed
- UI components, pages, layouts
- Client-side state management
- API calls to backend routes (fetch/axios)
- Styles, assets, static files

### Not Allowed — Move It
- Backend imports → frontend NEVER imports from `routes/`, `services/`, `models/`, `db/`
- Raw database queries → backend only
- Server-side secrets → backend only, served through API
- Business logic → `services/` on the backend

### Rules
- Frontend and backend are SEPARATE directories. No mixing
- API calls use the routes defined in `routes/`. No direct database access
- Auth tokens stored in httpOnly cookies or secure storage — never localStorage for sensitive tokens
- CORS is configured in `.env` (`CORS_ORIGINS`). Frontend origin must be listed
- All user input sanitized before rendering (XSS prevention)
