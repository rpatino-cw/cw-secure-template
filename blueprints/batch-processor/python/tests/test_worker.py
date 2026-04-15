"""Tests for the batch processor blueprint.

Uses fakeredis to avoid requiring a real Redis instance.
"""

import os
from unittest.mock import MagicMock, patch

os.environ["DEV_MODE"] = "true"
os.environ["ALLOWED_HOSTS"] = "localhost,127.0.0.1,testserver"
os.environ["REDIS_URL"] = "redis://localhost:6379/0"


class TestExampleJob:
    """Unit tests for the example_job function."""

    def test_example_job_returns_result(self):
        """Job returns a dict with item_id, action, and status."""
        from src.services.worker import example_job

        result = example_job(
            item_id="item-123",
            action="process",
            request_id="req-456",
            user_id="user-789",
        )
        assert result["item_id"] == "item-123"
        assert result["action"] == "process"
        assert result["status"] == "completed"

    def test_example_job_is_idempotent(self):
        """Running the same job twice produces the same result."""
        from src.services.worker import example_job

        kwargs = {"item_id": "item-123", "action": "process"}
        result1 = example_job(**kwargs)
        result2 = example_job(**kwargs)
        assert result1 == result2


class TestEnqueueJob:
    """Tests for the enqueue_job helper."""

    @patch("src.services.worker._get_redis")
    def test_enqueue_creates_job(self, mock_redis):
        """enqueue_job returns an RQ Job with correct parameters."""
        mock_conn = MagicMock()
        mock_redis.return_value = mock_conn

        # Mock the Queue.enqueue method
        with patch("src.services.worker.Queue") as MockQueue:
            mock_queue = MagicMock()
            mock_job = MagicMock()
            mock_job.id = "job-test-123"
            mock_queue.enqueue.return_value = mock_job
            MockQueue.return_value = mock_queue

            from src.services.worker import enqueue_job, example_job

            job = enqueue_job(example_job, item_id="test", action="run")
            assert job.id == "job-test-123"
            mock_queue.enqueue.assert_called_once()


class TestRedisConnection:
    """Tests for Redis connection handling."""

    def test_missing_redis_url_raises(self):
        """Worker raises RuntimeError if REDIS_URL is empty."""
        import src.services.worker as worker_mod

        worker_mod._redis = None  # Reset singleton
        original = os.environ.get("REDIS_URL", "")
        os.environ["REDIS_URL"] = ""
        try:
            try:
                worker_mod._get_redis()
                assert False, "Should have raised RuntimeError"
            except RuntimeError as e:
                assert "REDIS_URL" in str(e)
        finally:
            os.environ["REDIS_URL"] = original
            worker_mod._redis = None
