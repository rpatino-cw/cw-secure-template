# Blueprint: Batch Processor

This project uses the **Batch Processor** blueprint — a background job worker for async tasks.

## Architecture

```
services/worker.py   → Job definitions, retry logic, dead letter handling
routes/jobs.py       → POST /api/jobs — enqueue jobs, GET /api/jobs/:id — check status
middleware/           → Request ID propagated to job metadata for tracing
```

## Worker-Specific Rules

These rules supplement the base `.claude/rules/`:

### Every job must be idempotent
Jobs may be retried on failure. Design every job so running it twice produces the same result.

### Always set max_retries
Default: 3 retries with exponential backoff. Read from `MAX_RETRIES` env var.
After max retries, move to dead letter queue — never silently drop.

### Log job lifecycle
Every job logs: enqueued, started, completed, failed, retried, dead-lettered.
Include: job_id, job_type, user_id, request_id, duration_ms, attempt_number.

### Never process secrets in job payloads
Job payloads are serialized to Redis. Never include API keys, tokens, or passwords.
Pass secret references (env var names) and resolve at execution time.

### Connection string from env
Redis URL from `REDIS_URL` env var. Never hardcode. Store via `make add-secret`.
