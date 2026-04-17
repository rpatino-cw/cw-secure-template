"""Worker entrypoint — consumes queue, dispatches to tasks/."""
import structlog
log = structlog.get_logger()


def main():
    log.info("worker starting")
    # TODO: wire your queue client (Celery, RQ, aio-pika, redis streams)
    # Handlers live in src/tasks/. Every handler must be idempotent.
    pass


if __name__ == "__main__":
    main()
