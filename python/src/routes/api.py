"""API routes — authenticated JSON endpoints.

Every route here requires auth via Depends(get_current_user).
Add new resource routes by copying this pattern.
"""

import structlog
from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict

from ..middleware import get_current_user

logger = structlog.get_logger()

router = APIRouter(prefix="/api", tags=["api"])


# --- /api/me — inspect the authenticated user ---
@router.get("/me")
async def get_me(user: dict = Depends(get_current_user)):
    return {
        "sub": user.get("sub"),
        "email": user.get("email"),
        "name": user.get("name"),
        "groups": user.get("groups", []),
    }


# --- Example CRUD: items ---
class ItemCreate(BaseModel):
    model_config = ConfigDict(strict=True)
    name: str
    description: str = ""


_items: list[dict] = []


@router.get("/items")
async def list_items(user: dict = Depends(get_current_user)):
    return _items


@router.post("/items", status_code=201)
async def create_item(item: ItemCreate, user: dict = Depends(get_current_user)):
    entry = {"name": item.name, "description": item.description, "created_by": user.get("sub")}
    _items.append(entry)
    logger.info("item created", name=item.name, user_id=user.get("sub"))
    return entry
