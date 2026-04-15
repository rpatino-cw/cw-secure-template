"""LLM service — Anthropic Claude API wrapper.

Handles client lifecycle, token budgeting, and streaming.
Never log prompt content — user messages may contain PII.
"""

import os
import time
from collections.abc import AsyncIterator

import anthropic
import structlog

logger = structlog.get_logger()

# --- Configuration from environment ---
ANTHROPIC_MODEL = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-20250514")
MAX_TOKENS = int(os.environ.get("MAX_TOKENS_PER_REQUEST", "4096"))

# Singleton client — created once, reused across requests.
_client: anthropic.Anthropic | None = None


def _get_client() -> anthropic.Anthropic:
    """Return the Anthropic client, creating it on first call.

    SECURITY LESSON: API key read from env, never hardcoded.
    If the key is missing, crash loud at call time — not silently at import.
    """
    global _client  # noqa: PLW0603
    if _client is None:
        api_key = os.environ.get("ANTHROPIC_API_KEY", "")
        if not api_key:
            raise RuntimeError(
                "ANTHROPIC_API_KEY not set. Run: make add-secret"
            )
        _client = anthropic.Anthropic(api_key=api_key)
    return _client


def chat(
    messages: list[dict],
    system: str = "",
    user_id: str = "",
    request_id: str = "",
    max_tokens: int | None = None,
) -> dict:
    """Send a chat request and return the full response.

    Args:
        messages: List of {"role": "user"|"assistant", "content": "..."} dicts.
        system: Optional system prompt.
        user_id: Authenticated user ID for audit logging.
        request_id: Request trace ID from middleware.
        max_tokens: Override default max tokens.

    Returns:
        {"content": str, "model": str, "tokens_input": int, "tokens_output": int}
    """
    client = _get_client()
    effective_max = max_tokens or MAX_TOKENS
    start = time.monotonic()

    kwargs: dict = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": effective_max,
        "messages": messages,
    }
    if system:
        kwargs["system"] = system

    response = client.messages.create(**kwargs)

    latency_ms = int((time.monotonic() - start) * 1000)
    tokens_in = response.usage.input_tokens
    tokens_out = response.usage.output_tokens

    # SECURITY LESSON: Log metadata, never content. Prompts may contain PII.
    logger.info(
        "llm_call",
        model=ANTHROPIC_MODEL,
        tokens_input=tokens_in,
        tokens_output=tokens_out,
        latency_ms=latency_ms,
        user_id=user_id,
        request_id=request_id,
    )

    return {
        "content": response.content[0].text,
        "model": response.model,
        "tokens_input": tokens_in,
        "tokens_output": tokens_out,
    }


async def stream_chat(
    messages: list[dict],
    system: str = "",
    user_id: str = "",
    request_id: str = "",
    max_tokens: int | None = None,
) -> AsyncIterator[str]:
    """Stream a chat response as Server-Sent Events.

    Yields SSE-formatted lines: "data: {chunk}\n\n"
    Final event: "data: [DONE]\n\n"
    """
    client = _get_client()
    effective_max = max_tokens or MAX_TOKENS
    start = time.monotonic()

    kwargs: dict = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": effective_max,
        "messages": messages,
    }
    if system:
        kwargs["system"] = system

    tokens_in = 0
    tokens_out = 0

    with client.messages.stream(**kwargs) as stream:
        for text in stream.text_stream:
            yield f"data: {text}\n\n"

        # Final usage from the completed stream
        final = stream.get_final_message()
        tokens_in = final.usage.input_tokens
        tokens_out = final.usage.output_tokens

    latency_ms = int((time.monotonic() - start) * 1000)

    logger.info(
        "llm_stream",
        model=ANTHROPIC_MODEL,
        tokens_input=tokens_in,
        tokens_output=tokens_out,
        latency_ms=latency_ms,
        user_id=user_id,
        request_id=request_id,
    )

    yield "data: [DONE]\n\n"
