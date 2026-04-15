# Blueprint: Chat Assistant

This project uses the **Chat Assistant** blueprint — a Claude-powered conversational interface.

## Architecture

```
routes/chat.py      → POST /api/chat — accepts messages, streams responses
services/llm.py     → Anthropic client wrapper — token counting, model routing
middleware/          → Auth, rate limiting (per-user for LLM calls)
```

## AI-Specific Rules

These rules supplement the base `.claude/rules/` and are mandatory for AI-powered apps:

### Never log prompt content
User messages may contain PII, passwords, or sensitive data. Log metadata only:
- Log: model, tokens_input, tokens_output, latency_ms, user_id, request_id
- Never log: message content, system prompts, conversation history

### Always set max_tokens
Every API call must include `max_tokens` to prevent runaway costs.
Read from `MAX_TOKENS_PER_REQUEST` env var (default: 4096).

### Always propagate request_id
The existing RequestID middleware generates a UUID per request.
Pass it as `metadata` on the Anthropic API call for trace correlation.

### Rate limit per user for LLM calls
LLM calls are expensive. Rate limit per authenticated user, not just per IP.
Default: 20 LLM requests/minute per user (separate from API rate limit).

### Stream responses over 200 tokens
Use Server-Sent Events (SSE) for any response expected to exceed 200 tokens.
The `services/llm.py` module handles this via `stream_chat()`.

### Validate conversation ownership
Users can only access their own conversations.
Every `conversation_id` must be checked against the authenticated user.
