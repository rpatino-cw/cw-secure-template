"""Okta OIDC authentication as FastAPI dependencies.

# SECURITY LESSON: Authentication middleware — every protected endpoint must verify the caller's
# identity through a trusted identity provider (Okta). Never roll your own auth.

Uses JWKS (JSON Web Key Set) fetched from Okta's well-known endpoint to verify
JWT signatures without sharing secrets between services.
"""

import os
import time
from typing import Any

import httpx
import structlog
from fastapi import Depends, HTTPException, Request, status
from jose import JWTError, jwt

logger = structlog.get_logger()

# --- Configuration from environment ---
OKTA_ISSUER = os.environ.get("OKTA_ISSUER", "")
OKTA_AUDIENCE = os.environ.get("OKTA_AUDIENCE", "api://default")
DEV_MODE = os.environ.get("DEV_MODE", "false").lower() == "true"

# SECURITY LESSON: JWKS cache — fetching keys on every request is slow and can be DoS'd.
# Cache them with a TTL so we only re-fetch when keys rotate.
_jwks_cache: dict[str, Any] = {"keys": [], "fetched_at": 0.0}
JWKS_CACHE_TTL_SECONDS = 3600  # 1 hour


async def _fetch_jwks() -> list[dict[str, Any]]:
    """Fetch JWKS from Okta's OpenID Connect discovery endpoint.

    # SECURITY LESSON: Always validate the issuer URL before fetching JWKS.
    # An attacker who controls the issuer URL controls which keys are trusted.
    """
    now = time.monotonic()
    if _jwks_cache["keys"] and (now - _jwks_cache["fetched_at"]) < JWKS_CACHE_TTL_SECONDS:
        return _jwks_cache["keys"]

    if not OKTA_ISSUER:
        # SECURITY LESSON: Fail closed — if the issuer isn't configured, deny all requests
        # rather than silently allowing unauthenticated access.
        logger.error("OKTA_ISSUER not configured — cannot validate tokens")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication service misconfigured",
        )

    discovery_url = f"{OKTA_ISSUER.rstrip('/')}/.well-known/openid-configuration"

    async with httpx.AsyncClient(timeout=10.0) as client:
        # SECURITY LESSON: Set a timeout on outbound HTTP calls. Without one, a slow
        # identity provider can hang your entire request pipeline (DoS by proxy).
        try:
            discovery_resp = await client.get(discovery_url)
            discovery_resp.raise_for_status()
            jwks_uri = discovery_resp.json()["jwks_uri"]

            jwks_resp = await client.get(jwks_uri)
            jwks_resp.raise_for_status()
            keys = jwks_resp.json()["keys"]
        except (httpx.HTTPError, KeyError) as exc:
            logger.error("failed to fetch JWKS", error=str(exc))
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Unable to reach authentication service",
            ) from exc

    _jwks_cache["keys"] = keys
    _jwks_cache["fetched_at"] = now
    logger.info("jwks refreshed", key_count=len(keys))
    return keys


def _extract_bearer_token(request: Request) -> str:
    """Extract Bearer token from the Authorization header.

    # SECURITY LESSON: Always validate the Authorization header format.
    # Accepting malformed headers can lead to confusing error messages or bypasses.
    """
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            # SECURITY LESSON: WWW-Authenticate header tells clients how to authenticate.
            # Required by RFC 6750 when returning 401 for Bearer token auth.
            headers={"WWW-Authenticate": "Bearer"},
        )
    return auth_header[7:]  # Strip "Bearer " prefix


# SECURITY LESSON: DEV_MODE fake user — allows local development without Okta credentials.
# This MUST be gated on an explicit env var and MUST log a warning so it's obvious in logs.
_DEV_USER = {
    "sub": "dev-user-001",
    "email": "dev@localhost",
    "name": "Development User",
    "groups": ["everyone", "developers", "admins"],
}


async def get_current_user(request: Request) -> dict[str, Any]:
    """FastAPI dependency — extracts and validates the user from a Bearer JWT.

    # SECURITY LESSON: This is a dependency, not middleware, so individual routes
    # opt in to auth. This means /healthz stays unauthenticated (required for k8s probes)
    # while all API routes are protected.
    """
    if DEV_MODE:
        # SECURITY LESSON: DEV_MODE bypasses ALL authentication. This must never be enabled
        # in production. Log a warning on every request so it's impossible to miss in logs.
        structlog.get_logger().warning(
            "DEV_MODE: authentication bypassed",
            fake_user=_DEV_USER["sub"],
            path=request.url.path,
        )
        return _DEV_USER

    token = _extract_bearer_token(request)
    jwks = await _fetch_jwks()

    # SECURITY LESSON: RS256 — asymmetric signing. The identity provider signs with a private
    # key; we verify with the public key from JWKS. Never use HS256 with a shared secret
    # for multi-service architectures — any service with the secret can forge tokens.
    try:
        payload = jwt.decode(
            token,
            jwks,
            algorithms=["RS256"],
            audience=OKTA_AUDIENCE,
            issuer=OKTA_ISSUER,
            options={
                "verify_at_hash": False,
                # SECURITY LESSON: verify_exp, verify_iss, verify_aud are True by default
                # in python-jose. We explicitly list them here for documentation.
                "verify_exp": True,
                "verify_iss": True,
                "verify_aud": True,
            },
        )
    except JWTError as exc:
        # SECURITY LESSON: Never expose JWT validation details to the client.
        # Log the real error server-side; return a generic message to the caller.
        logger.warning("jwt validation failed", error=str(exc), path=request.url.path)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    logger.info(
        "authenticated",
        user_id=payload.get("sub"),
        email=payload.get("email"),
        path=request.url.path,
    )
    return payload


def require_group(group: str):
    """Dependency factory — returns a FastAPI dependency that checks group membership.

    Usage:
        @app.get("/admin", dependencies=[Depends(require_group("admins"))])
        async def admin_panel(): ...

    # SECURITY LESSON: RBAC via group claims — Okta embeds group membership in the JWT.
    # Checking groups server-side means access control is centrally managed in Okta,
    # not scattered across application code.
    """

    async def _check_group(user: dict = Depends(get_current_user)) -> dict:
        user_groups = user.get("groups", [])
        if group not in user_groups:
            logger.warning(
                "access denied — missing group",
                user_id=user.get("sub"),
                required_group=group,
                user_groups=user_groups,
            )
            # SECURITY LESSON: 403 Forbidden, not 404. Hiding the existence of endpoints
            # (returning 404) is security-through-obscurity and rarely worth the debugging cost.
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires group membership: {group}",
            )
        return user

    return _check_group
