"""Tests for the chat assistant blueprint.

Uses a mocked Anthropic client — no real API calls in tests.
DEV_MODE=true bypasses auth with a fake user.
"""

import os
from unittest.mock import MagicMock, patch

os.environ["DEV_MODE"] = "true"
os.environ["ALLOWED_HOSTS"] = "localhost,127.0.0.1,testserver"
os.environ["ANTHROPIC_API_KEY"] = "test-key-not-real"

from fastapi.testclient import TestClient

from src.main import app

client = TestClient(app)


def _mock_response(text="Hello from Claude", input_tokens=10, output_tokens=20):
    """Create a mock Anthropic response object."""
    mock = MagicMock()
    mock.content = [MagicMock(text=text)]
    mock.model = "claude-sonnet-4-20250514"
    mock.usage = MagicMock(input_tokens=input_tokens, output_tokens=output_tokens)
    return mock


class TestChatEndpoint:
    """POST /api/chat tests."""

    @patch("src.services.llm._get_client")
    def test_chat_non_streaming(self, mock_get_client):
        """Non-streaming chat returns JSON with content and token counts."""
        mock_client = MagicMock()
        mock_client.messages.create.return_value = _mock_response()
        mock_get_client.return_value = mock_client

        response = client.post(
            "/api/chat",
            json={"message": "Hello", "stream": False},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["content"] == "Hello from Claude"
        assert data["tokens_input"] == 10
        assert data["tokens_output"] == 20

    def test_chat_missing_message(self):
        """Missing message field returns 422."""
        response = client.post("/api/chat", json={})
        assert response.status_code == 422

    def test_chat_empty_message(self):
        """Empty message string returns 422 (min_length=1)."""
        response = client.post("/api/chat", json={"message": ""})
        assert response.status_code == 422

    def test_chat_wrong_type(self):
        """Non-string message returns 422 in strict mode."""
        response = client.post("/api/chat", json={"message": 12345})
        assert response.status_code == 422

    @patch("src.services.llm._get_client")
    def test_chat_streaming_returns_sse(self, mock_get_client):
        """Streaming chat returns text/event-stream content type."""
        mock_client = MagicMock()
        # Mock the stream context manager
        mock_stream = MagicMock()
        mock_stream.__enter__ = MagicMock(return_value=mock_stream)
        mock_stream.__exit__ = MagicMock(return_value=False)
        mock_stream.text_stream = iter(["Hello", " from", " Claude"])
        mock_stream.get_final_message.return_value = _mock_response()
        mock_client.messages.stream.return_value = mock_stream
        mock_get_client.return_value = mock_client

        response = client.post(
            "/api/chat",
            json={"message": "Hello", "stream": True},
        )
        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/event-stream")
