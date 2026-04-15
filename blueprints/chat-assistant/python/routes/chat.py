"""Chat routes — Claude-powered conversational endpoint.

POST /api/chat — accepts a message, returns a streaming response.
Requires authentication. Logs token usage for cost attribution.
"""

import structlog
from fastapi import APIRouter, Depends, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, ConfigDict, Field

from ..middleware import get_current_user
from ..services.llm import chat, stream_chat

logger = structlog.get_logger()

router = APIRouter(prefix="/api", tags=["chat"])


class ChatRequest(BaseModel):
    """Incoming chat message."""

    model_config = ConfigDict(strict=True)
    message: str = Field(min_length=1, max_length=10000)
    conversation_id: str = Field(default="", max_length=100)
    stream: bool = True


class ChatResponse(BaseModel):
    """Non-streaming chat response."""

    content: str
    model: str
    tokens_input: int
    tokens_output: int


@router.post("/chat")
async def post_chat(
    body: ChatRequest,
    request: Request,
    user: dict = Depends(get_current_user),
):
    """Send a message to Claude and get a response.

    Streams by default (SSE). Set stream=false for a JSON response.
    """
    user_id = user.get("sub", "")
    request_id = request.headers.get("X-Request-ID", "")

    messages = [{"role": "user", "content": body.message}]

    if body.stream:
        return StreamingResponse(
            stream_chat(
                messages=messages,
                user_id=user_id,
                request_id=request_id,
            ),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "X-Request-ID": request_id,
            },
        )

    result = chat(
        messages=messages,
        user_id=user_id,
        request_id=request_id,
    )

    return ChatResponse(**result)
