"""Background job worker — Redis-backed queue with retry logic.

Defines job functions and the worker entry point.
Every job must be idempotent — it may be retried on failure.
Never include secrets in job payloads — resolve at execution time.
"""

import os
import time

import redis
import structlog
from rq import Queue, Worker
from rq.job import Job

logger = structlog.get_logger()

# --- Configuration from environment ---
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
WORKER_CONCURRENCY = int(os.environ.get("WORKER_CONCURRENCY", "2"))
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "3"))
JOB_TIMEOUT = int(os.environ.get("JOB_TIMEOUT_SECONDS", "300"))

# --- Redis connection ---
_redis: redis.Redis | None = None


def _get_redis() -> redis.Redis:
    """Return Redis connection, creating on first call.

    SECURITY LESSON: Connection string from env, never hardcoded.
    If Redis is down, fail loud — don't silently drop jobs.
    """
    global _redis  # noqa: PLW0603
    if _redis is None:
        url = REDIS_URL
        if not url:
            raise RuntimeError("REDIS_URL not set. Run: make add-secret")
        _redis = redis.from_url(url, decode_responses=True)
        _redis.ping()  # Fail fast if Redis is unreachable
        logger.info("redis connected", url=url.split("@")[-1])  # Log host only, not creds
    return _redis


def get_queue(name: str = "default") -> Queue:
    """Get a named job queue."""
    return Queue(name, connection=_get_redis())


# --- Job definitions ---
# Add your job functions here. Each must be importable by path
# (RQ serializes the function reference, not the code).


def example_job(item_id: str, action: str, **kwargs) -> dict:
    """Example job — replace with your actual work.

    SECURITY LESSON: Job payloads are serialized to Redis.
    Never include API keys, tokens, or passwords in kwargs.
    Pass secret references and resolve at execution time.
    """
    request_id = kwargs.get("request_id", "")
    user_id = kwargs.get("user_id", "")
    start = time.monotonic()

    logger.info(
        "job_started",
        job_type="example_job",
        item_id=item_id,
        action=action,
        user_id=user_id,
        request_id=request_id,
    )

    # --- Your job logic here ---
    result = {"item_id": item_id, "action": action, "status": "completed"}
    # ---

    duration_ms = int((time.monotonic() - start) * 1000)
    logger.info(
        "job_completed",
        job_type="example_job",
        item_id=item_id,
        duration_ms=duration_ms,
        user_id=user_id,
        request_id=request_id,
    )

    return result


def enqueue_job(
    func,
    *args,
    queue_name: str = "default",
    retry: int | None = None,
    timeout: int | None = None,
    **kwargs,
) -> Job:
    """Enqueue a job with retry and timeout defaults.

    Args:
        func: The job function to call.
        *args: Positional args passed to the function.
        queue_name: Which queue to use (default: "default").
        retry: Max retry count (default: MAX_RETRIES from env).
        timeout: Job timeout in seconds (default: JOB_TIMEOUT from env).
        **kwargs: Keyword args passed to the function.

    Returns:
        The enqueued RQ Job object.
    """
    q = get_queue(queue_name)
    effective_retry = retry if retry is not None else MAX_RETRIES
    effective_timeout = timeout or JOB_TIMEOUT

    job = q.enqueue(
        func,
        *args,
        **kwargs,
        job_timeout=effective_timeout,
        retry=effective_retry,
    )

    logger.info(
        "job_enqueued",
        job_id=job.id,
        job_type=func.__name__,
        queue=queue_name,
        max_retries=effective_retry,
        timeout=effective_timeout,
    )

    return job


# --- Worker entry point ---
def run_worker(queues: list[str] | None = None):
    """Start an RQ worker listening on the given queues.

    Usage: python -m src.services.worker
    """
    queue_names = queues or ["default"]
    conn = _get_redis()
    worker = Worker(
        [Queue(name, connection=conn) for name in queue_names],
        connection=conn,
    )
    logger.info("worker_started", queues=queue_names, concurrency=WORKER_CONCURRENCY)
    worker.work()


if __name__ == "__main__":
    run_worker()
